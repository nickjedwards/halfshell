pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

// One vertical meter: a reading on top, a bar that fills from the bottom,
// and a mark under it saying which metric it is.
//
// Styled to match SliderRow, which is the other kind of bar in this panel:
// same hairline track, same track colour, same white fill at the same
// opacity. The only thing it keeps for itself is turning red when a reading
// is alarming, because nothing a slider shows can be.
//
// The fill is animated over `period`, the cadence of whatever feeds it, so
// each bar glides between its own samples instead of ticking. A bar sampled
// every five seconds animating over one would stall for four of them.
Item {
    id: root

    // A TileIcon kind rather than a word — three of these side by side is a
    // place for a mark, not a caption.
    required property string icon
    required property string readout

    // How often `value` changes, which is how long the fill has to move.
    required property int period

    // 0..1
    required property real value

    property color fill: Config.text

    Text {
        id: reading

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        text: root.readout
        color: Config.text
        font.family: Config.font
        font.pixelSize: 11
        font.weight: Font.Medium
    }

    Rectangle {
        id: track

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: reading.bottom
        anchors.topMargin: 8
        anchors.bottom: caption.top
        anchors.bottomMargin: 8
        width: Config.statBarWidth
        radius: width / 2
        color: Config.hairline

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * Math.max(0, Math.min(1, root.value))
            radius: parent.radius
            color: root.fill
            opacity: 0.9

            Behavior on height {
                NumberAnimation {
                    duration: root.period * 0.8
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Config.fadeDuration
                }
            }
        }
    }

    TileIcon {
        id: caption

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        kind: root.icon
        size: 14
        color: Config.textDim
    }
}
