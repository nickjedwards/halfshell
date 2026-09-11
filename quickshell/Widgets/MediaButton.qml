pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

// Transport controls, as Material Design glyphs from the icon font — the same
// set every other mark in the shell comes from (see TileIcon).
Item {
    id: root

    // "previous" | "next" | "play" | "pause"
    required property string kind

    // `enabled` is Item's own property — setting it false also stops the
    // handlers below from firing, which is exactly what we want.
    property real size: 15

    signal activated

    implicitWidth: 34
    implicitHeight: 34

    opacity: enabled ? (hover.hovered ? 1 : 0.82) : 0.28
    Behavior on opacity {
        NumberAnimation {
            duration: Config.fadeDuration
        }
    }

    scale: press.pressed ? 0.88 : 1
    Behavior on scale {
        NumberAnimation {
            duration: Config.pressDuration
        }
    }

    HoverHandler {
        id: hover
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: press
        enabled: root.enabled
        onTapped: root.activated()
    }

    readonly property int codepoint: {
        switch (root.kind) {
        case "pause":
            return 0xF03E4; // pause
        case "play":
            return 0xF040A; // play
        case "previous":
            return 0xF04AE; // skip_previous
        default:
            return 0xF04AD; // skip_next
        }
    }

    Text {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        text: String.fromCodePoint(root.codepoint)
        color: Config.text
        font.family: Config.iconFont

        // Set larger than the box. MDI draws its transport glyphs well inside
        // the padded 24-unit square — measured, their ink is 0.58–0.63 of the
        // pixel size — where the old drawn marks filled their box edge to
        // edge. 1.6 is roughly the reciprocal, so they occupy the same space.
        font.pixelSize: Math.round(root.size * Config.iconScale * 1.6)
    }
}
