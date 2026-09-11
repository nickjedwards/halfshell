pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

// What opens when you hover the now-playing half of the closed bar: the
// track, a scrubber, and transport. Volume is not here — it is a system
// control rather than a property of this track, and lives in the control
// centre next to brightness.
//
// The art and the title are not drawn here either. They fly in from the bar
// as single objects (see NotchArt/NotchTitle), so this keeps invisible
// stand-ins of exactly their size and reports where they belong — the same
// trick ControlCenter uses for the clock.
//
// Built once in the background shortly after startup and then kept, so
// opening the notch never pays construction cost.
Item {
    id: root

    // Where the flying art and title should land when this panel is open.
    readonly property real artX: content.x + art.x
    readonly property real artY: content.y + art.y
    readonly property real titleX: content.x + column.x + titleRow.x + title.x
    readonly property real titleY: content.y + column.y + titleRow.y + title.y
    readonly property real titleWidth: title.width

    // MPRIS does not push position updates. Tick it only while this panel is
    // actually on screen and something is actually playing — which is now a
    // tighter condition than it was, since the control centre no longer counts
    // as the panel being open.
    Timer {
        running: root.visible && Media.isPlaying
        interval: 1000
        repeat: true
        onTriggered: {
            if (Media.active)
                Media.active.positionChanged();
        }
    }

    RowLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Config.ccPadX
        spacing: Config.mediaArtGap

        // Not drawn. Reserves the art's place and reports it; the real thing
        // flies in from the bar.
        Item {
            id: art

            Layout.preferredWidth: Config.panelArtSize
            Layout.preferredHeight: Config.panelArtSize
            Layout.alignment: Qt.AlignVCenter
        }

        // ── Track, scrubber, transport ───────────────────────────────────
        ColumnLayout {
            id: column

            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                Layout.fillHeight: true
            }

            // Not drawn, for the same reason as the art above.
            RowLayout {
                id: titleRow

                Layout.fillWidth: true
                spacing: 12

                Text {
                    id: title

                    Layout.fillWidth: true
                    text: Media.hasPlayer ? Media.title : "Nothing playing"
                    opacity: 0
                    elide: Text.ElideRight
                    font.family: Config.font
                    font.pixelSize: Config.panelTitleSize
                    font.weight: Font.DemiBold
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: Media.hasPlayer ? Media.artist : "Start something and it will show up here"
                color: Config.textDim
                elide: Text.ElideRight
                font.family: Config.font
                font.pixelSize: 12
            }

            Item {
                Layout.fillHeight: true
            }

            // Scrubber. Click anywhere on the track to seek.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 14
                visible: Media.hasPlayer && Media.length > 0

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 3
                    radius: 1.5
                    color: Config.hairline

                    Rectangle {
                        width: parent.width * Media.progress
                        height: parent.height
                        radius: parent.radius
                        color: Config.text
                        opacity: 0.9
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => Media.seek(mouse.x / width)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: Media.hasPlayer && Media.length > 0

                Text {
                    text: Media.formatTime(Media.position)
                    color: Config.textDim
                    font.family: Config.font
                    font.pixelSize: 10
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: Media.formatTime(Media.length)
                    color: Config.textDim
                    font.family: Config.font
                    font.pixelSize: 10
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 0

                MediaButton {
                    kind: "previous"
                    enabled: Media.hasPlayer
                    onActivated: Media.previous()
                }

                MediaButton {
                    kind: Media.isPlaying ? "pause" : "play"
                    enabled: Media.hasPlayer
                    size: 17
                    onActivated: Media.playPause()
                }

                MediaButton {
                    kind: "next"
                    enabled: Media.hasPlayer
                    onActivated: Media.next()
                }

                Item {
                    Layout.fillWidth: true
                }

                // Tap to step to the next player. The position is shown only
                // when there is somewhere to step to — "Spotify 1/1" would be
                // noise, and its absence is what tells you there is one
                // player rather than leaving you to hover and find out.
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Media.canCyclePlayer ? `${Media.identity} ${Media.playerIndex}/${Media.playerCount}` : Media.identity
                    color: Media.canCyclePlayer && playerHover.hovered ? Config.text : Config.textDim
                    font.family: Config.font
                    font.pixelSize: 10

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.fadeDuration
                        }
                    }

                    HoverHandler {
                        id: playerHover
                        enabled: Media.canCyclePlayer
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: Media.canCyclePlayer
                        onTapped: Media.cyclePlayer()
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
