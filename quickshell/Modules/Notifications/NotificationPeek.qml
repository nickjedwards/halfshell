pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services

// Shown when notifications arrive, and again when a sender replaces one in
// place: the newest few, stacked newest first, each for Config.peekDuration
// from its own arrival. Notifs decides what is peeking and for how long;
// this only draws it.
//
// A ListModel of keys kept in step with Notifs.peeking by hand, rather than
// the array itself as the model. The array is rebuilt on every change, and a
// view over it would rebuild every row with it — so a second arrival would
// re-fade the first. Diffed into a ListModel, an arrival is an insert, an
// expiry a remove and a replacement a move, and the view animates each: the
// new one fades in on top while the others slide down to make room.
Item {
    id: root

    ListModel {
        id: rows
    }

    function sync(): void {
        const keys = Notifs.peeking.map(e => e.key);

        for (let i = rows.count - 1; i >= 0; i--) {
            if (keys.indexOf(rows.get(i).entryKey) === -1)
                rows.remove(i);
        }

        for (let i = 0; i < keys.length; i++) {
            let at = -1;
            for (let j = i; j < rows.count; j++) {
                if (rows.get(j).entryKey === keys[i]) {
                    at = j;
                    break;
                }
            }

            if (at === -1)
                rows.insert(i, {
                    entryKey: keys[i]
                });
            else if (at !== i)
                rows.move(at, i, 1);
        }
    }

    Component.onCompleted: root.sync()

    Connections {
        target: Notifs

        function onPeekingChanged(): void {
            root.sync();
        }
    }

    ListView {
        anchors.fill: parent
        model: rows
        interactive: false
        spacing: 0

        add: Transition {
            id: arrive

            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Config.fadeDuration
            }

            NumberAnimation {
                property: "y"
                from: arrive.ViewTransition.destination.y - 10
                duration: Config.peekMoveDuration
                easing.type: Easing.OutCubic
            }
        }

        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Config.fadeDuration
            }
        }

        move: Transition {
            NumberAnimation {
                property: "y"
                duration: Config.peekMoveDuration
                easing.type: Easing.OutCubic
            }
        }

        // Finishes the fade too, in case a row is pushed down while it is
        // still arriving — otherwise it would be left half-faded where the
        // displacement caught it.
        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: Config.peekMoveDuration
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                property: "opacity"
                to: 1
                duration: Config.fadeDuration
            }
        }

        delegate: Item {
            id: row

            required property int entryKey

            // The entry, held onto once found, so a row fading out after its
            // entry has gone keeps saying what it said on the way out.
            readonly property var found: Notifs.peeking.find(e => e.key === row.entryKey) || null
            property var notif: null

            onFoundChanged: {
                if (row.found)
                    row.notif = row.found;
            }

            Component.onCompleted: row.notif = row.found

            // The sender's live object where it still has one, so a
            // notification replaced while it peeks says the new thing.
            readonly property var view: Notifs.view(row.notif)

            width: ListView.view.width
            height: Config.peekRowHeight

            RowLayout {
                anchors.fill: parent
                spacing: 11

                ClippingRectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignVCenter
                    radius: 9
                    color: Config.hairline

                    // Prefer the notification's own image (message avatars
                    // and so on), fall back to the sending application's
                    // icon.
                    IconImage {
                        anchors.fill: parent
                        anchors.margins: row.view && row.view.image ? 0 : 7
                        source: {
                            if (!row.view)
                                return "";
                            if (row.view.image)
                                return row.view.image;
                            return Notifs.appIconSource(row.view.appIcon);
                        }
                        asynchronous: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    RowLayout {
                        spacing: 6

                        Text {
                            text: row.notif ? row.notif.appName : ""
                            color: Config.textDim
                            font.family: Config.font
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            visible: row.notif !== null && row.notif.urgent
                            Layout.alignment: Qt.AlignVCenter
                            width: 5
                            height: 5
                            radius: 2.5
                            color: Config.urgent
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.view ? row.view.summary : ""
                        color: Config.text
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        font.family: Config.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: row.view ? Notifs.bodyLine(row.view.body) : ""
                        color: Config.textDim
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                        font.family: Config.font
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
