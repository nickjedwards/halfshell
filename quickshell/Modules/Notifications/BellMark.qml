pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// The bell, at whatever size it is asked for. Always in the bar, and says by
// its fill whether anything is waiting: the outline, knocked back to textDim
// like every other mark at rest, while the list is empty; solid and bright
// once there is something in it.
//
// Presentation only, so the notification centre can hold an invisible one of
// exactly the right size to say where the real one should land. NotchBell is
// the one that moves.
Item {
    id: root

    property real iconSize: Config.barBellSize

    readonly property bool unread: Notifs.count > 0

    implicitWidth: root.iconSize
    implicitHeight: root.iconSize

    TileIcon {
        anchors.centerIn: parent
        kind: "bell"
        size: root.iconSize
        filled: root.unread
        color: root.unread ? Config.text : Config.textDim

        Behavior on color {
            ColorAnimation {
                duration: Config.fadeDuration
            }
        }
    }
}
