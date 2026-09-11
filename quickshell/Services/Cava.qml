pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The spectrum of whatever the system is playing, read from cava.
//
// cava only runs while something asks for it through `active` — the spectrum
// around the art sets it while that is on screen and a track is playing — so
// a paused player, or a notch showing some other panel, costs nothing. It
// hears the whole system output rather than one player: that is all PipeWire
// offers it, which is why the spectrum gates on Media.isPlaying as well.
//
// No cava installed means `available` stays false, nothing runs and
// `levels` stays empty — the spectrum sits at rest rather than faking it.
Singleton {
    id: root

    property bool active: false
    property bool available: false
    readonly property bool running: proc.running

    // One level per band, 0–1 after cava's own gain control, in cava's
    // stereo order: the left channel from treble down to bass, then the
    // right from bass back up to treble. Reassigned whole every frame, so
    // anything bound to it redraws. Empty while cava isn't running.
    property var levels: []

    function frame(line: string): void {
        const parts = line.split(";");
        const out = [];

        // Every frame ends in a delimiter, so the last part is empty.
        for (let i = 0; i < parts.length; i++) {
            if (parts[i] !== "")
                out.push(Number(parts[i]) / 1000);
        }

        root.levels = out;
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v cava"]
        onExited: (code, status) => root.available = code === 0
    }

    Process {
        id: proc

        command: ["cava", "-p", Quickshell.shellPath("Services/cava.conf")]
        running: root.active && root.available

        stdout: SplitParser {
            onRead: line => root.frame(line)
        }

        onRunningChanged: {
            if (!running)
                root.levels = [];
        }
    }
}
