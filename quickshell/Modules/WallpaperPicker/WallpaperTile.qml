pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.Common

// One wallpaper in the strip.
//
// Two different things are true of a tile and they are said two different
// ways: the one you are looking at is the one at full strength, and the one
// actually on the desktop is the one wearing the ring. They are usually the
// same tile, and the panel is no use on the occasions they aren't.
Item {
    id: root

    required property var entry

    // Sitting on the centre line.
    required property bool focused

    // The one the link points at.
    required property bool current

    signal activated

    implicitWidth: Config.stripTileWidth
    implicitHeight: Config.stripTileHeight

    opacity: root.focused ? 1 : Config.stripTileDim

    Behavior on opacity {
        NumberAnimation {
            duration: Config.fadeDuration
        }
    }

    scale: press.pressed ? 0.98 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Config.pressDuration
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: Config.stripTileRadius

        // Stands in while the picture decodes, so the strip is a row of
        // tiles from the first frame rather than a row of holes.
        color: Config.hairline

        Image {
            anchors.fill: parent
            source: root.entry.url

            // Decoded at tile size rather than at 4K. Ten wallpapers at their
            // full resolution is most of a gigabyte of pixels for a strip
            // 135 tall; twice the tile width is enough for any display this
            // will be drawn on.
            sourceSize.width: Config.stripTileWidth * 2

            fillMode: Image.PreserveAspectCrop
            asynchronous: true

            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.fadeDuration
                }
            }
        }
    }

    // The one in use is ringed rather than badged: a badge would have to sit
    // on top of the picture, and the picture is the whole point of the tile.
    Rectangle {
        anchors.fill: parent
        radius: Config.stripTileRadius
        color: "transparent"
        border.width: 2
        border.color: Config.accent
        opacity: root.current ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.fadeDuration
            }
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    // Default gesture policy, which takes a *passive* grab. Inside a
    // ListView the Flickable takes the exclusive grab on press to see
    // whether you are flicking, so a handler asking for an exclusive one is
    // refused and never taps — which is what made these tiles unclickable.
    // It also means dragging across a picture flicks the strip, rather than
    // the tile swallowing the drag.
    TapHandler {
        id: press

        onTapped: root.activated()
    }
}
