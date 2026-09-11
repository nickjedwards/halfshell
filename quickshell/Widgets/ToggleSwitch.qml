pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

// An on/off switch: a track that takes the accent when it is on, and a knob
// that slides across it.
//
// It replaced a pill with "On" or "Off" written in it. The words were doing
// two jobs at once — naming the state and being the control — and a switch
// says the same thing by where the knob is, in a shape that is obviously
// something you can flip.
Item {
    id: root

    required property bool active

    signal toggled

    implicitWidth: Config.switchWidth
    implicitHeight: Config.switchHeight

    scale: press.pressed ? 0.94 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Config.pressDuration
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.active ? Config.accent : Config.hairline

        Behavior on color {
            ColorAnimation {
                duration: Config.fadeDuration
            }
        }
    }

    Rectangle {
        x: root.active ? root.width - width - Config.switchInset : Config.switchInset
        y: Config.switchInset
        width: root.height - Config.switchInset * 2
        height: width
        radius: width / 2

        // Reads against the accent track when on, and dimmed when off
        // rather than bright at both ends: everything else in this shell
        // says "not doing anything" by receding, and a knob at full strength
        // on a quiet track is a loud way to say off.
        color: root.active ? Config.onAccent : Config.textDim

        Behavior on color {
            ColorAnimation {
                duration: Config.fadeDuration
            }
        }

        // Slides rather than jumping, for the same reason the segmented
        // control's thumb does: the movement is what says which way the
        // switch just went. Quicker than that one, because it is a shorter
        // journey and a switch should feel like it snaps.
        Behavior on x {
            NumberAnimation {
                duration: Config.switchDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: press

        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.toggled()
    }
}
