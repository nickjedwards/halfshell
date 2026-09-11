pragma Singleton

import Quickshell

// Global open/close state, so a keybind can drive the notch without any
// window needing to know about the keybind. Hover is tracked per-notch in
// Notch.qml — this is only the forced-open case.
//
// The notch has several open panels, so this holds *which* one rather than a
// bare bool: "" is closed, otherwise one of `targets`.
Singleton {
    id: root

    property string forced: ""

    // Anything unrecognised falls back to the media panel, which is what a
    // bare "show me the notch" means.
    readonly property var targets: ["media", "control", "launcher", "notifications", "power", "wallpaper", "theme"]

    function resolve(target: string): string {
        return root.targets.indexOf(target) >= 0 ? target : "media";
    }

    function open(target: string): void {
        root.forced = root.resolve(target);
    }

    function close(): void {
        root.forced = "";
    }

    // Toggling to the panel you are already showing closes it; toggling to
    // the other one switches without a trip through closed.
    function toggle(target: string): void {
        const want = root.resolve(target);
        root.forced = root.forced === want ? "" : want;
    }
}
