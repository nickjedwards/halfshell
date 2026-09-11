pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Widgets

// One application in the launcher list: its icon, its name, and whatever the
// desktop entry offers as a subtitle.
//
// Selection is a filled lozenge rather than a colour change on the text, so
// the keyboard selection and the mouse hover can be the same thing and the
// list still reads as a list.
Item {
    id: root

    required property var app
    required property bool selected

    signal activated
    signal hovered

    implicitHeight: Config.appRowHeight

    RowHighlight {
        on: root.selected
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        // Moving the mouse takes over the selection, so the highlight is
        // never in two places at once.
        onHoveredChanged: {
            if (hovered)
                root.hovered();
        }
    }

    TapHandler {
        onTapped: root.activated()
    }

    IconImage {
        id: icon

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: Config.appIconSize
        source: Quickshell.iconPath(root.app.icon, "application-x-executable")
        asynchronous: true
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.app.name
            color: Config.text
            elide: Text.ElideRight
            font.family: Config.font
            font.pixelSize: 13
            font.weight: root.selected ? Font.DemiBold : Font.Normal
        }

        Text {
            width: parent.width
            text: root.app.genericName !== "" ? root.app.genericName : root.app.comment
            visible: text !== ""
            color: Config.textDim
            elide: Text.ElideRight
            font.family: Config.font
            font.pixelSize: 10
        }
    }
}
