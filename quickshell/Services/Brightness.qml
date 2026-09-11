pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Display backlight, via brightnessctl.
//
// There is no Quickshell module for this and the sysfs attribute is root
// owned, so writes go through brightnessctl — which falls back to
// logind's SetBrightness when it can't write sysfs directly, and so works
// without the user being in the video group or a udev rule being installed.
//
// `-c backlight` matters: without it brightnessctl also enumerates LED class
// devices and spews read errors for the ones it can't open.
//
// Machine output is one line: device,class,current,percent,max
Singleton {
    id: root

    // 0..1.
    property real value: 1

    property int max: 0
    property string device: ""

    readonly property bool available: root.max > 0

    // Never all the way off — a backlight at zero looks like a crashed shell.
    readonly property real minimum: 0.01

    // Set optimistically while dragging and written behind a coalescing
    // timer, so a drag doesn't spawn sixty processes a second.
    property real pending: -1

    Process {
        id: query

        command: ["brightnessctl", "-m", "-c", "backlight"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    Process {
        id: apply

        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    Timer {
        id: flush
        interval: 60
        onTriggered: root.flushPending()
    }

    function parse(text: string): void {
        const lines = text.trim().split("\n");
        for (let i = lines.length - 1; i >= 0; i--) {
            const f = lines[i].split(",");
            if (f.length < 5)
                continue;
            const max = parseInt(f[4]);
            const current = parseInt(f[2]);
            if (!(max > 0))
                continue;
            root.device = f[0];
            root.max = max;
            // Don't fight a drag in progress with a stale reading.
            if (root.pending < 0)
                root.value = current / max;
            return;
        }
    }

    function set(fraction: real): void {
        const v = Math.max(root.minimum, Math.min(1, fraction));
        root.value = v;
        root.pending = v;
        if (!flush.running)
            flush.start();
    }

    function flushPending(): void {
        if (root.pending < 0)
            return;
        // One process in flight at a time; try again once it's done.
        if (apply.running) {
            flush.restart();
            return;
        }
        const pct = Math.round(root.pending * 100);
        root.pending = -1;
        apply.command = ["brightnessctl", "-m", "-c", "backlight", "set", `${pct}%`];
        apply.running = true;
    }

    // Worth doing when the panel opens: something else may have changed the
    // backlight since we last looked.
    function refresh(): void {
        if (!query.running)
            query.running = true;
    }
}
