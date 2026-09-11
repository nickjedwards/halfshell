pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

// Every mark in the shell, as a Material Design glyph from the Nerd Font
// symbols set (Config.iconFont).
//
// These used to be drawn as geometry, on the grounds that no icon font would
// then have to be installed. They are glyphs now: a real, consistent icon set
// rather than hand-built approximations, and one that recolours through
// `color` like any text — so every theme works with nothing extra, where
// themed SVGs would need a colorize layer per icon.
//
// The API is unchanged, so nothing that uses a mark had to change: `kind`
// picks it, `size` is the box it is centred in, `filled` and `level` are read
// by the few marks that have states.
Item {
    id: root

    // "wifi" | "bluetooth" | "output" | "input" | "brightness" | "keyboard"
    // | "back" | "search" | "cpu" | "temp" | "memory" | "battery" | "close"
    // | "bell" | "power" | "restart" | "lock" | "logout"
    required property string kind
    required property color color

    property real size: 16

    // The bell's two faces: filled when something is waiting, the outline
    // otherwise. The bar's bell uses both — BellMark sets it off the
    // notification count.
    property bool filled: false

    // 0..1, read by the three marks that stand for a quantity. The speaker,
    // the sun and the wifi fan each have MDI glyphs for a few levels, and
    // this picks between them. It defaults to the top, so a use of one of
    // those marks that isn't about the quantity — the output tile's badge,
    // which is about which device is selected rather than how loud it is —
    // shows the whole mark without being told anything.
    property real level: 1

    implicitWidth: root.size
    implicitHeight: root.size

    // One table of names to codepoints, so a mark is changed in one place.
    // Two entries are chosen by look rather than by name: MDI's "memory"
    // (pins on all four sides) is what a CPU looks like, and its "chip" (pins
    // top and bottom) is what a stick of RAM looks like.
    readonly property var glyphs: ({
            bluetooth: 0xF00AF, // bluetooth
            input: 0xF036C,     // microphone
            back: 0xF0141,      // chevron_left
            search: 0xF0349,    // magnify
            cpu: 0xF035B,       // memory — reads as a CPU
            memory: 0xF061A,    // chip — reads as RAM
            temp: 0xF050F,      // thermometer
            battery: 0xF0079,   // battery
            close: 0xF0156,     // close
            power: 0xF0425,     // power
            restart: 0xF0709,   // restart
            lock: 0xF033E,      // lock
            logout: 0xF0343     // logout
        })

    readonly property int codepoint: {
        const t = Math.max(0, Math.min(1, root.level));

        switch (root.kind) {
        // Four steps, the same four the drawn speaker had: silent (muted, or
        // wound all the way down), then a wave for each third.
        case "output":
            if (t <= 0)
                return 0xF0581; // volume_off
            if (t < 1 / 3)
                return 0xF057F; // volume_low
            if (t < 2 / 3)
                return 0xF0580; // volume_medium
            return 0xF057E;     // volume_high

        // Four suns, one per quarter, so the slider steps as often as the
        // volume mark beside it: the centre fills hollow, crescent, half,
        // full. MDI numbers them out of that order — the crescent is
        // brightness_4, before the hollow brightness_5 — which is how it
        // was missed the first time. Not F00E1, which sits next to them and
        // looks like the top of the sequence but is the *auto* brightness
        // sun, with an A in it.
        case "brightness":
            if (t < 0.25)
                return 0xF00DE; // brightness_5 — hollow
            if (t < 0.5)
                return 0xF00DD; // brightness_4 — crescent
            if (t < 0.75)
                return 0xF00DF; // brightness_6 — half
            return 0xF00E0;     // brightness_7 — full

        // Signal bars, one per quarter of the connected network's strength
        // — the same number the Wi-Fi page prints as a percent, so the mark
        // and the figure agree. Equal quarters rather than GNOME's
        // perceptual cut-offs, which would put a 79% link at three bars and
        // read as a mismatch next to the percentage. No network means no
        // bars: the empty outline, not a full fan on a tile saying "Off".
        //
        // MDI's fan-shaped strength set, not the arcs of its plain "wifi"
        // glyph, because only the fans come in steps.
        case "wifi":
            if (t <= 0)
                return 0xF092F; // wifi_strength_outline — no bars
            if (t < 0.25)
                return 0xF091F; // wifi_strength_1
            if (t < 0.5)
                return 0xF0922; // wifi_strength_2
            if (t < 0.75)
                return 0xF0925; // wifi_strength_3
            return 0xF0928;     // wifi_strength_4

        case "bell":
            return root.filled ? 0xF009A : 0xF009C; // bell / bell_outline

        // Lit or dark, not a scale: MDI has no steps for a keyboard, and the
        // slider beside it already says how bright. The outline when the
        // light is off, like the bell's with nothing waiting — not
        // keyboard_off, whose slash says the keyboard itself is disabled.
        case "keyboard":
            return t > 0 ? 0xF030C : 0xF097B; // keyboard / keyboard_outline

        default:
            return root.glyphs[root.kind] || 0;
        }
    }

    // Centring the text box centres the ink: MDI glyphs sit centred in their
    // own advance and their line box, which was measured rather than assumed.
    // Rotation — the notification group turns the chevron — happens about
    // this item's centre, so it turns about the glyph's centre too.
    Text {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: root.codepoint ? String.fromCodePoint(root.codepoint) : ""
        color: root.color

        font.family: Config.iconFont

        // Whole pixels, so a mark whose size animates — the bell flying from
        // the bar into the notification heading — asks the glyph cache for a
        // handful of sizes rather than a new one every frame.
        font.pixelSize: Math.round(root.size * Config.iconScale)
    }
}
