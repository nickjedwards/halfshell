pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

// The power menu. Four actions in a 2x2, no confirmation step — opening this
// panel is already deliberate, and every one of these is undoable except by
// doing it.
//
// The order is the row's, wrapped: the two that take the machine down on top,
// the two that act on the session under them. That puts Lock — the only one
// of the four that isn't destructive, and the one most often wanted — in the
// bottom right, which is the corner nearest everything else in the notch.
//
// The commands live in Config rather than here, so a different session, init
// or locker is a config change instead of a code change.
Item {
    id: root

    PanelHeading {
        id: heading

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        title: "Power"
    }

    // A GridLayout rather than two Rows: the buttons stretch to fill the
    // panel, and a real grid keeps the two columns the same width without
    // either row being told about the other.
    GridLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: heading.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: Config.ccPadX
        anchors.rightMargin: Config.ccPadX
        anchors.topMargin: Config.panelHeadingGap
        anchors.bottomMargin: Config.ccPadX

        columns: 2
        columnSpacing: Config.powerButtonGap
        rowSpacing: Config.powerButtonGap

        PowerButton {
            Layout.fillWidth: true
            Layout.fillHeight: true
            kind: "lock"
            label: "Lock"

            // Closes the notch on the way, unlike the three around it: they
            // end the session, so what the notch does afterwards is nobody's
            // business, while this one leaves the power menu sitting there
            // waiting for you when you unlock.
            onActivated: {
                Power.lock();
                NotchState.close();
            }
        }

        PowerButton {
            Layout.fillWidth: true
            Layout.fillHeight: true
            kind: "logout"
            label: "Log out"
            danger: true
            onActivated: Power.logout()
        }

        PowerButton {
            Layout.fillWidth: true
            Layout.fillHeight: true
            kind: "restart"
            label: "Restart"
            danger: true
            onActivated: Power.reboot()
        }

        PowerButton {
            Layout.fillWidth: true
            Layout.fillHeight: true
            kind: "power"
            label: "Shut down"
            danger: true
            onActivated: Power.shutdown()
        }
    }
}
