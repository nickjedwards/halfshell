pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

// One palette in the theme strip, in the frame the wallpaper tiles use.
//
// Where a wallpaper tile shows the picture, this shows the shell: a notch
// with a clock and an accent dot, a pair of tiles with lit and unlit badges,
// and a half-filled slider. Six colours in the arrangement they will
// actually appear in, which tells you more than six squares of colour would.
//
// Everything inside is painted from `theme`, never from Config — this is the
// one place in the shell that draws in a palette other than the one that is
// on, and it has to, because that is the whole point of it.
Item {
    id: root

    required property var theme

    // Sitting on the centre line.
    required property bool focused

    // The palette actually in use.
    required property bool current

    signal activated

    implicitWidth: Config.stripTileWidth
    implicitHeight: Config.stripTileHeight

    opacity: root.focused ? 1 : Config.themeTileDim

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

    Rectangle {
        id: card

        anchors.fill: parent
        radius: Config.stripTileRadius
        color: root.theme.surface

        // A hairline edge in the theme's own hairline, so a palette whose
        // surface is close to the panel it sits on still reads as an object
        // rather than a hole. Latte on Latte is exactly that case.
        border.width: 1
        border.color: root.theme.hairline

        // The notch, with its clock and the urgency dot beside it.
        Rectangle {
            id: bar

            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: 104
            height: 20
            radius: 10
            color: root.theme.hairline

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: 16
                width: 34
                height: 4
                radius: 2
                color: root.theme.text
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: 58
                width: 20
                height: 4
                radius: 2
                color: root.theme.textDim
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: 84
                width: 5
                height: 5
                radius: 2.5
                color: root.theme.urgent
            }
        }

        // The body, centred in whatever the bar leaves rather than stacked
        // down from it — the bar hangs off the top edge like the real notch
        // does, so measuring the rest from the top left the card bottom-heavy.
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: bar.bottom
            anchors.bottom: parent.bottom

            Column {
                anchors.centerIn: parent
                spacing: 16

                // Two control-centre tiles, one lit and one not — the pair
                // is what shows the accent doing its job rather than just
                // existing.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Repeater {
                        model: [true, false]

                        Rectangle {
                            required property bool modelData

                            width: 92
                            height: 32
                            radius: 8
                            color: root.theme.hairline

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 8
                                width: 16
                                height: 16
                                radius: 8
                                color: modelData ? root.theme.accent : root.theme.surface
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 32
                                width: 38
                                height: 4
                                radius: 2
                                color: modelData ? root.theme.text : root.theme.textDim
                            }
                        }
                    }
                }

                // A slider, half filled, for the one place the accent is a
                // quantity rather than a state.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 192
                    height: 4
                    radius: 2
                    color: root.theme.hairline

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * 0.55
                        radius: parent.radius
                        color: root.theme.accent
                    }
                }
            }
        }
    }

    // The one in use is ringed, the same way the current wallpaper is.
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
    // It also means dragging across a palette flicks the strip, rather than
    // the tile swallowing the drag.
    TapHandler {
        id: press

        onTapped: root.activated()
    }
}
