pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Common

// Power profiles, from power-profiles-daemon by way of Quickshell's UPower
// module. `profile` is writable, so switching is an assignment rather than a
// call out to powerprofilesctl.
//
// As with everything else here it populates a beat after startup — the first
// read reports Balanced with no performance profile, and corrects itself a
// second later — so all of this is bindings.
Singleton {
    id: root

    readonly property int profile: PowerProfiles.profile

    // Not every machine offers all three: a laptop without the thermal
    // headroom reports no performance profile, and the daemon will refuse it.
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

    // What to offer, in the order they belong on a slider from thrift to
    // speed. Built from what the daemon actually has rather than assumed.
    readonly property var profiles: {
        const out = [
            {
                value: PowerProfile.PowerSaver,
                label: "Saver"
            },
            {
                value: PowerProfile.Balanced,
                label: "Balanced"
            }
        ];
        if (root.hasPerformance) {
            out.push({
                value: PowerProfile.Performance,
                label: "Performance"
            });
        }
        return out;
    }

    function set(value: int): void {
        PowerProfiles.profile = value;
    }

    // ── Session actions ──────────────────────────────────────────────────
    // One process, because every one of these ends the session anyway — and
    // guarded, so a double-tap can't start a second poweroff on top of the
    // first.
    Process {
        id: session
    }

    function run(command: var): void {
        if (session.running)
            return;
        session.command = command;
        session.running = true;
    }

    function shutdown(): void {
        root.run(Config.shutdownCommand);
    }

    function reboot(): void {
        root.run(Config.rebootCommand);
    }

    // Which spelling of the logout dispatcher this Hyprland wants. A binding
    // rather than a read at the moment of the click: `usingLua` is false
    // until the module has asked Hyprland what it is running, and the answer
    // arrives a moment after the singleton is built. Read once, too early,
    // and every session would get the wrong syntax.
    readonly property string logoutRequest: Hyprland.usingLua ? Config.logoutDispatchLua : Config.logoutDispatch

    // Down the request socket rather than out to hyprctl. No process to
    // spawn, and Quickshell logs a warning if Hyprland refuses the
    // dispatcher — which is what was missing when this silently did nothing.
    function logout(): void {
        Hyprland.dispatch(root.logoutRequest);
    }

    // The one session action you come back from, and the only one that must
    // not be a child of this shell: Quickshell kills a Process it owns when
    // the object goes away, and the object goes away on every config reload.
    // A locker killed by someone saving a QML file is an unlocked screen.
    function lock(): void {
        Quickshell.execDetached(Config.lockCommand);
    }
}
