//@ pragma UseQApplication

// Nothing is ever written next to these files. This directory may be a
// symlink into a dotfiles repo, or a package's install under /usr/share that
// users can't write to at all, so what the shell keeps goes to Quickshell.stateDir
// (what you chose, which should survive) and Quickshell.cacheDir (what can be
// fetched again). These two lines name them: $BASE is $XDG_STATE_HOME and
// $XDG_CACHE_HOME respectively, and Quickshell creates both. Pragmas are only
// read above the first import.
//@ pragma StateDir $BASE/halfshell
//@ pragma CacheDir $BASE/halfshell

import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Notch

ShellRoot {
    id: root

    // One notch per monitor. All shared state lives in singletons in
    // Services/ and Common/, so adding a monitor costs one window, not one of everything.
    Variants {
        model: Quickshell.screens

        Notch {}
    }

    // Control the notch from keybinds without spawning a second Quickshell:
    //   halfshell ipc call notch toggle
    //   halfshell ipc call notch control
    //   halfshell ipc call notch launcher
    //   halfshell ipc call notch wallpaper
    //   halfshell ipc call notch theme
    //   halfshell ipc call notch close
    //
    // toggle/open act on the media panel, which is the one a "show me the
    // notch" keybind almost always means. The control centre has its own pair.
    IpcHandler {
        target: "notch"

        function toggle(): void {
            NotchState.toggle("media");
        }

        function open(): void {
            NotchState.open("media");
        }

        function control(): void {
            NotchState.toggle("control");
        }

        function openControl(): void {
            NotchState.open("control");
        }

        // The launcher is keyboard-driven and has no half of the bar to
        // hover, so IPC is the only way in.
        function launcher(): void {
            NotchState.toggle("launcher");
        }

        function openLauncher(): void {
            NotchState.open("launcher");
        }

        function notifications(): void {
            NotchState.toggle("notifications");
        }

        function openNotifications(): void {
            NotchState.open("notifications");
        }

        function power(): void {
            NotchState.toggle("power");
        }

        function openPower(): void {
            NotchState.open("power");
        }

        function wallpaper(): void {
            NotchState.toggle("wallpaper");
        }

        function openWallpaper(): void {
            NotchState.open("wallpaper");
        }

        function theme(): void {
            NotchState.toggle("theme");
        }

        function openTheme(): void {
            NotchState.open("theme");
        }

        function close(): void {
            NotchState.close();
        }

        // "closed", or one of NotchState.targets.
        function status(): string {
            return NotchState.forced === "" ? "closed" : NotchState.forced;
        }
    }

    // Cheaper still on Hyprland — no process spawn at all. Bind it in
    // hyprland.conf with:  bind = SUPER, N, global, quickshell:notchToggle
    //
    // import Quickshell.Hyprland
    // GlobalShortcut {
    //     appid: "quickshell"
    //     name: "notchToggle"
    //     onPressed: NotchState.toggle()
    // }
}
