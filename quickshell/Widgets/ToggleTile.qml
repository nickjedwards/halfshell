pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

// One control-centre toggle: a mark in a badge, what it is, and what it is
// currently doing. Clicking it flips the thing.
//
// The badge carries the state, not the tile background — a whole tile
// changing colour at a glance reads as "selected", which is not what an
// on/off control means.
Item {
    id: root

    // Passed through to TileIcon.
    required property string kind
    required property string label
    required property string detail
    required property bool active

    // False when the hardware isn't there at all, which is different from
    // being switched off: there is nothing to switch.
    property bool available: true

    // Passed through to TileIcon, for a tile whose mark stands for a
    // quantity — the wifi tile's bars follow the signal. Every other tile
    // leaves it at the top, which draws its mark whole.
    property real level: 1

    signal activated

    implicitHeight: Config.tileHeight

    opacity: root.available ? 1 : 0.45

    Behavior on opacity {
        NumberAnimation {
            duration: Config.fadeDuration
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Config.tileRadius
        color: Config.hairline
        opacity: hover.hovered && root.available ? 1 : 0.72

        Behavior on opacity {
            NumberAnimation {
                duration: Config.fadeDuration
            }
        }
    }

    scale: press.pressed && root.available ? 0.97 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Config.pressDuration
        }
    }

    HoverHandler {
        id: hover
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: press
        enabled: root.available
        onTapped: root.activated()
    }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Config.tilePadX
        anchors.rightMargin: Config.tilePadX
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Config.tileBadge
            height: Config.tileBadge
            radius: width / 2
            color: root.active ? Config.accent : Config.surface

            Behavior on color {
                ColorAnimation {
                    duration: Config.fadeDuration
                }
            }

            TileIcon {
                anchors.centerIn: parent
                kind: root.kind
                level: root.level
                size: Math.round(Config.tileBadge * 0.58)
                // Contrasting with the lit badge, knocked back on the
                // unlit one.
                color: root.active ? Config.onAccent : Config.textDim
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Config.tileBadge - parent.spacing
            spacing: 1

            Text {
                width: parent.width
                text: root.label
                color: Config.text
                elide: Text.ElideRight
                font.family: Config.font
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            Text {
                width: parent.width
                text: root.detail
                color: Config.textDim
                elide: Text.ElideRight
                font.family: Config.font
                font.pixelSize: 10
            }
        }
    }
}
