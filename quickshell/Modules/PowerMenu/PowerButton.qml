pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

// One action in the power menu: a mark over a word, in a card.
//
// The destructive two turn red under the pointer. It is the only warning
// there is — the menu acts on the first click, because a power menu that
// asks "are you sure" is a power menu you press twice every time — so it is
// worth the moment of colour before you commit.
Item {
    id: root

    required property string kind
    required property string label

    property bool danger: false

    signal activated

    implicitWidth: Config.powerButtonWidth
    implicitHeight: Config.powerButtonHeight

    Rectangle {
        anchors.fill: parent
        radius: Config.tileRadius
        color: Config.hairline
        opacity: hover.hovered ? 1 : 0.72

        Behavior on opacity {
            NumberAnimation {
                duration: Config.fadeDuration
            }
        }
    }

    scale: press.pressed ? 0.96 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Config.pressDuration
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: press
        onTapped: root.activated()
    }

    TileIcon {
        id: mark

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.26)
        kind: root.kind
        size: Config.powerIconSize
        color: root.danger && hover.hovered ? Config.urgent : Config.text

        Behavior on color {
            ColorAnimation {
                duration: Config.fadeDuration
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: mark.bottom
        anchors.topMargin: 10
        text: root.label
        color: Config.textDim
        font.family: Config.font
        font.pixelSize: 11
        font.weight: Font.Medium
    }
}
