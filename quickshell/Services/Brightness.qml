pragma Singleton

import Quickshell

// The two backlights the control centre has sliders for. Each is a Backlight:
// the same query and the same coalesced writes, pointed at a different
// device.
Singleton {
    id: root

    // The screen. `-c backlight` matters: without it brightnessctl also
    // enumerates LED class devices and spews read errors for the ones it
    // can't open.
    //
    // Never all the way off — a backlight at zero looks like a crashed shell.
    readonly property Backlight display: Backlight {
        selector: ["-c", "backlight"]
        minimum: 0.01
    }

    // The keyboard, on machines that have one. The kernel names every
    // keyboard backlight *::kbd_backlight, whoever made the machine —
    // chromeos:: on a Framework, tpacpi:: on a ThinkPad — so the name finds
    // it without this having to know what it is running on. Finding it still
    // means brightnessctl reads every LED on the way, and it complains on
    // stderr about the ones it can't; nothing collects stderr.
    //
    // All the way off is an ordinary setting for a keyboard, so no minimum.
    readonly property Backlight keyboard: Backlight {
        selector: ["-c", "leds", "-d", "*kbd_backlight"]
    }

    // Worth doing when the panel opens: something else may have changed
    // either one since we last looked.
    function refresh(): void {
        root.display.refresh();
        root.keyboard.refresh();
    }
}
