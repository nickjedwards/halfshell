pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

// The lozenge behind the row the pointer is on, or the one the keyboard has
// landed on. Filled rather than a colour change on the text, so a mouse
// hover and a keyboard selection can be the same mark and the list still
// reads as a list.
//
// One component rather than one per list: the launcher, the device lists and
// the back control all mean the same thing by it, and a highlight that is
// slightly rounder or slightly slower in one list than another is the sort of
// difference you feel without being able to name.
Rectangle {
    id: root

    required property bool on

    anchors.fill: parent
    radius: Config.rowRadius
    color: Config.hairline
    opacity: root.on ? 1 : 0

    // Quicker than fadeDuration, because this follows the pointer. A
    // highlight that eases in over a sixth of a second reads as the pointer
    // being slow rather than the highlight being smooth.
    Behavior on opacity {
        NumberAnimation {
            duration: Config.highlightDuration
        }
    }
}
