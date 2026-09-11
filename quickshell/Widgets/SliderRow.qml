pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

// A labelled bar you can drag — brightness, and anything else that is a
// single 0..1 value rather than an on/off.
//
// Dragging reports continuously rather than on release, because a backlight
// that only moves when you let go feels broken. Whoever owns the value is
// responsible for not turning that into one write per frame.
Item {
    id: root

    required property string kind
    required property string label
    required property real value

    // Knocks the fill and the reading back without hiding them — for a
    // muted output, which still has a volume, it just isn't doing anything.
    property bool subdued: false

    // Passed through to the mark, for the kinds that have something to say
    // about their own value — the speaker counts its waves off this. Left at
    // -1 the mark draws itself whole, which is what the brightness row wants.
    property real level: -1

    signal moved(real value)

    implicitHeight: track.y + track.height

    Text {
        id: caption

        anchors.left: icon.right
        anchors.leftMargin: 8
        anchors.verticalCenter: icon.verticalCenter
        text: root.label
        color: Config.textDim
        font.family: Config.font
        font.pixelSize: 11
    }

    TileIcon {
        id: icon

        anchors.left: parent.left
        y: 0
        kind: root.kind
        size: 14
        color: Config.textDim
        level: root.level < 0 ? 1 : root.level
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: icon.verticalCenter
        text: `${Math.round(root.value * 100)}%`
        color: Config.text
        opacity: root.subdued ? 0.4 : 1
        font.family: Config.font
        font.pixelSize: 11
        font.weight: Font.Medium
    }

    Rectangle {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        y: icon.height + 8
        height: 4
        radius: 2
        color: Config.hairline

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: parent.radius
            color: Config.text
            opacity: root.subdued ? 0.3 : 0.9
        }

        // Generous vertical margins: a 4px bar is not a pointer target.
        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -10
            anchors.bottomMargin: -10
            cursorShape: Qt.PointingHandCursor

            onPressed: mouse => root.moved(mouse.x / width)
            onPositionChanged: mouse => {
                if (pressed)
                    root.moved(mouse.x / width);
            }

            // Both sliders take a scroll, which is how the volume bar behaved
            // when it lived in the media panel.
            onWheel: wheel => {
                const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                root.moved(Math.max(0, Math.min(1, root.value + step)));
            }
        }
    }
}
