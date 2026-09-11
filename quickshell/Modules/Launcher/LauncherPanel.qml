pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// The application launcher.
//
// Unlike the other panels this one takes the keyboard, which is why the notch
// only asks the compositor for keyboard focus while it is open — see
// Notch.qml. Everything is driven from the search field: it keeps focus for
// the whole life of the panel and the arrow keys move a selection in the list
// beneath rather than moving focus into it, so typing never stops working.
Item {
    id: root

    signal dismissed

    property int selected: 0

    // Reset on the way in rather than the way out, so the panel is never
    // briefly showing yesterday's search while it animates open.
    onVisibleChanged: {
        if (!visible)
            return;
        Apps.query = "";
        root.selected = 0;
        input.forceActiveFocus();
    }

    // Any change to the results puts the selection back at the top —
    // otherwise typing a second letter leaves you pointing at whatever
    // happens to be at the old index.
    Connections {
        target: Apps

        function onResultsChanged(): void {
            root.selected = 0;
            list.positionViewAtBeginning();
        }
    }

    function move(delta: int): void {
        const count = Apps.results.length;
        if (count === 0)
            return;
        // Wraps, because a launcher list is a ring, not a wall.
        root.selected = (root.selected + delta + count) % count;
        list.positionViewAtIndex(root.selected, ListView.Contain);
    }

    function launch(index: int): void {
        const app = Apps.results[index];
        if (!app)
            return;
        Apps.launch(app);
        root.dismissed();
    }

    // ── Search ───────────────────────────────────────────────────────────
    Rectangle {
        id: field

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Config.ccPadX
        height: Config.searchHeight
        radius: height / 2
        color: Config.hairline

        TileIcon {
            id: glass

            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            kind: "search"
            size: 15
            color: Config.textDim
        }

        TextInput {
            id: input

            anchors.left: glass.right
            anchors.leftMargin: 10
            anchors.right: count.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter

            text: Apps.query
            onTextChanged: Apps.query = text

            color: Config.text
            selectionColor: Config.accent
            selectedTextColor: Config.onAccent
            font.family: Config.font
            font.pixelSize: 14
            clip: true

            // The list is a sibling, not a focus target: the arrows drive a
            // selection index so the field never gives up the keyboard.
            Keys.onDownPressed: root.move(1)
            Keys.onUpPressed: root.move(-1)
            Keys.onReturnPressed: root.launch(root.selected)
            Keys.onEnterPressed: root.launch(root.selected)
            Keys.onEscapePressed: root.dismissed()

            Text {
                anchors.fill: parent
                visible: input.text === ""
                text: "Search applications"
                color: Config.textDim
                verticalAlignment: Text.AlignVCenter
                font.family: Config.font
                font.pixelSize: 14
            }
        }

        Text {
            id: count

            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: Apps.results.length
            color: Config.textDim
            font.family: Config.font
            font.pixelSize: 11
        }
    }

    // ── Results ──────────────────────────────────────────────────────────
    ListView {
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: field.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: Config.ccPadX
        anchors.rightMargin: Config.ccPadX
        anchors.topMargin: 10
        anchors.bottomMargin: Config.ccPadX

        clip: true
        spacing: 2
        model: Apps.results
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: root.selected

        delegate: AppRow {
            required property var modelData
            required property int index

            width: ListView.view.width
            app: modelData
            selected: index === root.selected

            onHovered: root.selected = index
            onActivated: root.launch(index)
        }

        Text {
            anchors.centerIn: parent
            visible: Apps.results.length === 0
            text: Apps.all.length === 0 ? "Looking for applications…" : "Nothing matches"
            color: Config.textDim
            font.family: Config.font
            font.pixelSize: 12
        }
    }
}
