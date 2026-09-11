import QtQuick
import Quickshell
import Quickshell.Io

// One backlight, driven through brightnessctl — the screen's or the
// keyboard's. Brightness holds one of each, and this is everything they have
// in common: the query, the coalesced writes, and reading the answer.
//
// There is no Quickshell module for this and the sysfs attribute is root
// owned, so writes go through brightnessctl — which falls back to logind's
// SetBrightness when it can't write sysfs directly, and so works without the
// user being in the video group or a udev rule being installed. logind does
// that for LEDs as well as backlights, which is why the keyboard's works the
// same way as the screen's.
//
// Machine output is one line: device,class,current,percent,max
Scope {
    id: root

    // What picks the device out, as brightnessctl arguments: a class, a
    // device name, or both.
    required property var selector

    // The lowest set() will go.
    property real minimum: 0

    // 0..1.
    property real value: 1

    property int max: 0
    property string device: ""

    // No such device, or no brightnessctl: either way, nothing to draw.
    readonly property bool available: root.max > 0

    // Set optimistically while dragging and written behind a coalescing
    // timer, so a drag doesn't spawn sixty processes a second.
    property real pending: -1

    // Running as soon as this exists, unlike nearly every other process in
    // this shell: the answer decides whether a control-centre row exists at
    // all, and a row popping into a panel already on screen is worse than one
    // query whenever the shell starts.
    Process {
        id: query

        command: ["brightnessctl", "-m"].concat(root.selector)
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
            // Don't fight a drag in progress with a stale reading. Once the
            // drag has been written, the reading that comes back replaces the
            // value it set — so a device with only a few levels settles on
            // the one the write actually landed on.
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
        apply.command = ["brightnessctl", "-m"].concat(root.selector, ["set", `${pct}%`]);
        apply.running = true;
    }

    function refresh(): void {
        if (!query.running)
            query.running = true;
    }
}
