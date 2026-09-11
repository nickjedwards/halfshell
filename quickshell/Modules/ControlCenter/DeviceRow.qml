pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

// One line in a device list: what it is, what it's doing, and whether it is
// the current one. Tapping it switches to it.
//
// Built like a row in the launcher — a filled lozenge the width of the list
// with the content padded inside it, rather than a highlight that bleeds
// past the text it is meant to be behind.
//
// `enabled` is Item's own property — setting it false also stops the
// handlers below from firing.
//
// Dimming is deliberately separate from that. The row you are already on is
// not tappable either, and dimming it would make the current device the
// faintest thing in the list; only a row you *can't* act on should recede.
Item {
    id: root

    required property string title
    required property string detail
    required property bool current

    // Not tappable and not worth reading — a network we have no password
    // for. Distinct from `enabled`, which the current row also clears.
    property bool subdued: false

    signal activated

    implicitHeight: Config.rowHeight

    opacity: root.subdued ? 0.4 : 1

    RowHighlight {
        on: hover.hovered && root.enabled
    }

    HoverHandler {
        id: hover
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.enabled
        onTapped: root.activated()
    }

    // The current device gets a filled dot rather than a tick: it reads at a
    // glance and doesn't need a second colour.
    Rectangle {
        id: marker

        anchors.left: parent.left
        anchors.leftMargin: Config.rowPadX
        anchors.verticalCenter: parent.verticalCenter
        width: 6
        height: 6
        radius: 3
        color: Config.accent
        opacity: root.current ? 1 : 0
    }

    Column {
        anchors.left: marker.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: Config.rowPadX
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.title
            color: Config.text
            elide: Text.ElideRight
            font.family: Config.font
            font.pixelSize: 12
            font.weight: root.current ? Font.DemiBold : Font.Normal
        }

        Text {
            width: parent.width
            text: root.detail
            visible: text !== ""
            color: Config.textDim
            elide: Text.ElideRight
            font.family: Config.font
            font.pixelSize: 10
        }
    }
}
