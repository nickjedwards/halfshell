pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

// The frame a device list sits in: a back chevron, a title, an on/off switch,
// and whatever the caller puts below. Children go into the body, which is
// what `default property alias` buys — the pages read as a list of rows
// rather than a list of rows wrapped in scaffolding.
//
// The radio's on/off moved here when tapping its tile started navigating
// instead of toggling. It has to live somewhere, and next to the list of
// things it governs is the honest place for it.
Item {
    id: root

    required property string title
    property bool toggleActive: false

    signal back
    signal toggled

    default property alias content: body.data

    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Config.ccPadX
        anchors.rightMargin: Config.ccPadX
        height: Config.rowHeight

        // Back target is the chevron and title together — a 15px glyph is
        // not a pointer target — but stops short of the pill. It wears the
        // same lozenge the rows below it do, because it is the same kind of
        // thing: something under the pointer that a click will act on.
        Item {
            id: backTarget

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            // Starts where the rows below it start, so the two lozenges share
            // an edge. The chevron keeps its own place at the page's content
            // inset — it lines up with the clock and the tiles on the page
            // behind this one, and the mark is drawn inset within its own box
            // anyway, so it doesn't sit against the lozenge.
            width: chevron.width + 8 + label.width + Config.rowPadX

            // Shorter than the header it sits in: at full height the lozenge
            // ran into the rule below it and the top of the panel above.
            height: Config.backHeight

            RowHighlight {
                on: backHover.hovered
            }

            TileIcon {
                id: chevron

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                kind: "back"
                size: 15
                color: backHover.hovered ? Config.text : Config.textDim

                Behavior on color {
                    ColorAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }

            Text {
                id: label

                anchors.left: chevron.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                color: Config.text
                font.family: Config.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            HoverHandler {
                id: backHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.back()
            }
        }

        ToggleSwitch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            active: root.toggleActive
            onToggled: root.toggled()
        }
    }

    Rectangle {
        id: rule

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.leftMargin: Config.ccPadX
        anchors.rightMargin: Config.ccPadX
        height: 1
        color: Config.hairline
    }

    Item {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: rule.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Config.ccPadX
    }
}
