pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire

// Audio devices, reduced to what the control centre shows: which sink and
// source are current, and what else is available to switch to.
//
// Streams are filtered out — those are applications, not devices. Nodes
// without an `audio` interface are filtered too, since they can't be a
// playback or capture target.
//
// Listing devices needs no tracker: name, description and isSink come off
// the registry. Volume and mute do — a PipeWire node's audio interface is
// not bound until something tracks it — so this singleton tracks the current
// sink, and is then the one place that knows the volume.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property bool sinkReady: root.sink !== null && root.sink.audio !== null
    readonly property real volume: root.sinkReady ? root.sink.audio.volume : 0
    readonly property bool muted: root.sinkReady && root.sink.audio.muted

    readonly property var sinks: root.devices(true)
    readonly property var sources: root.devices(false)

    readonly property string sinkLabel: root.label(root.sink)
    readonly property string sourceLabel: root.label(root.source)

    function devices(wantSink: bool): var {
        const out = [];
        const nodes = Pipewire.nodes.values;
        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i];
            if (node.isStream || !node.audio)
                continue;
            if (node.isSink === wantSink)
                out.push(node);
        }
        return out;
    }

    // Nickname where there is one — "BenQ RD280U" beats "Radeon High
    // Definition Audio Controller Pro" — and the description otherwise,
    // because bluetooth nodes come through with no nickname at all.
    function label(node: PwNode): string {
        if (!node)
            return "None";
        return node.nickname !== "" ? node.nickname : node.description;
    }

    function setVolume(fraction: real): void {
        if (root.sinkReady)
            root.sink.audio.volume = Math.max(0, Math.min(1, fraction));
    }

    function toggleMute(): void {
        if (root.sinkReady)
            root.sink.audio.muted = !root.sink.audio.muted;
    }

    function cycleSink(): void {
        const list = root.sinks;
        if (list.length < 2)
            return;
        Pipewire.preferredDefaultAudioSink = list[root.nextIndex(list, root.sink)];
    }

    function cycleSource(): void {
        const list = root.sources;
        if (list.length < 2)
            return;
        Pipewire.preferredDefaultAudioSource = list[root.nextIndex(list, root.source)];
    }

    // Falls out at 0 when the current device isn't in the list, which is the
    // right answer: pick the first one.
    function nextIndex(list: var, current: PwNode): int {
        for (let i = 0; i < list.length; i++) {
            if (current && list[i].id === current.id)
                return (i + 1) % list.length;
        }
        return 0;
    }
}
