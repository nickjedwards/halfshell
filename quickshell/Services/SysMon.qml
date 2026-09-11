pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// CPU load, CPU temperature and memory use.
//
// This is the one thing in the shell that genuinely has to poll: the kernel
// exposes these as files with no change notification, and CPU load is a
// delta between two samples rather than a value you can read. So it polls —
// but only while something is looking. `active` is bound to the control
// centre being visible, and the timer stops with it.
//
// Each metric gets its own cadence, because they move at wildly different
// rates: load is bursty and wants a second, a CPU's thermal mass means its
// temperature cannot meaningfully change that fast, and memory drifts slowly
// enough that reading it every second is just noise. Three timers reading one
// file each is also cheaper than one timer reading all three.
Singleton {
    id: root

    property bool active: false

    // 0..1
    readonly property real cpu: root.cpuFraction

    // Held rather than derived, so a partial read of /proc/meminfo can't be
    // turned into a reading. Deriving it meant that a text() with MemTotal
    // but not yet MemAvailable computed (total - 0) / total — a confident,
    // wrong 100%.
    property real memory: 0

    // Kilobytes, as /proc/meminfo reports them.
    readonly property real memoryUsedKb: Math.max(0, root.memTotal - root.memAvailable)
    readonly property real memoryTotalKb: root.memTotal

    // Degrees C, and the same mapped onto the range worth showing. A CPU
    // never sits near zero, so a bar from zero would barely move.
    property real temperature: 0
    readonly property real temperatureFraction: {
        const span = Config.tempMax - Config.tempMin;
        return Math.max(0, Math.min(1, (root.temperature - Config.tempMin) / span));
    }

    readonly property bool hasTemperature: root.tempPath !== ""

    property string tempPath: ""
    property real cpuFraction: 0
    property real memTotal: 0
    property real memAvailable: 0

    // Previous /proc/stat sample. -1 means "no baseline yet", which is why
    // the first tick produces no reading rather than a fake 100%.
    property real prevBusy: -1
    property real prevTotal: -1

    // hwmon numbering is not stable across boots, so the sensor is found by
    // name once at startup rather than hardcoded.
    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/hwmon/*/; do case \"$(cat \"$d/name\" 2>/dev/null)\" in k10temp|coretemp|zenpower|cpu_thermal) printf '%stemp1_input' \"$d\"; break;; esac; done"]

        stdout: StdioCollector {
            onStreamFinished: root.tempPath = this.text.trim()
        }
    }

    FileView {
        id: statFile
        path: "/proc/stat"
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
    }

    FileView {
        id: tempFile
        path: root.tempPath
    }

    Timer {
        running: root.active
        interval: Config.cpuInterval
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sampleCpu()
    }

    Timer {
        running: root.active && root.hasTemperature
        interval: Config.tempInterval
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sampleTemperature()
    }

    Timer {
        running: root.active
        interval: Config.memInterval
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sampleMemory()
    }

    // Starting from cold: drop the stale baseline so the first reading after
    // the panel opens is measured over one interval, not over however long
    // the panel happened to be shut.
    onActiveChanged: {
        if (!root.active) {
            root.prevBusy = -1;
            root.prevTotal = -1;
        }
    }

    function sampleCpu(): void {
        statFile.reload();
        root.readCpu();
    }

    function sampleMemory(): void {
        memFile.reload();
        root.readMemory();
    }

    function sampleTemperature(): void {
        if (root.tempPath === "")
            return;
        tempFile.reload();
        root.readTemperature();
    }

    // Binary units, because that is what everything else on the machine means
    // by GB when it talks about RAM. One decimal below ten and none above, so
    // the reading stays about as wide as the bar it sits over.
    function formatBytes(kb: real): string {
        if (!(kb > 0))
            return "0M";
        const mb = kb / 1024;
        if (mb < 1024)
            return `${Math.round(mb)}MB`;
        const gb = mb / 1024;
        return gb < 10 ? `${gb.toFixed(1)}GB` : `${Math.round(gb)}GB`;
    }

    function readCpu(): void {
        const line = statFile.text().split("\n")[0];
        if (!line.startsWith("cpu "))
            return;

        // cpu user nice system idle iowait irq softirq steal guest guest_nice
        const parts = line.split(/\s+/).slice(1).map(Number);
        if (parts.length < 5)
            return;

        let total = 0;
        for (let i = 0; i < parts.length; i++)
            total += parts[i];

        // idle + iowait: both are the CPU having nothing to do.
        const busy = total - (parts[3] + parts[4]);

        if (root.prevTotal >= 0) {
            const dTotal = total - root.prevTotal;
            const dBusy = busy - root.prevBusy;
            if (dTotal > 0)
                root.cpuFraction = Math.max(0, Math.min(1, dBusy / dTotal));
        }

        root.prevBusy = busy;
        root.prevTotal = total;
    }

    function readMemory(): void {
        const text = memFile.text();
        const total = /MemTotal:\s+(\d+)/.exec(text);
        const available = /MemAvailable:\s+(\d+)/.exec(text);

        // Half a read is not a reading: keep the last good value instead.
        if (!total || !available)
            return;

        const totalKb = Number(total[1]);
        const availableKb = Number(available[1]);
        if (!(totalKb > 0) || availableKb > totalKb)
            return;

        root.memTotal = totalKb;
        root.memAvailable = availableKb;
        root.memory = (totalKb - availableKb) / totalKb;
    }

    function readTemperature(): void {
        if (root.tempPath === "")
            return;
        const raw = Number(tempFile.text().trim());
        // hwmon reports millidegrees.
        if (raw > 0)
            root.temperature = raw / 1000;
    }
}
