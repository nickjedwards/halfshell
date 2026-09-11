pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

// The workspace strip at the left of the closed bar: one dot per workspace,
// the one you are on picked out in the accent.
//
// Dots rather than numbers. The bar is a glance — you are checking which of
// four or five you are on, not reading a label — and numbers at this size
// would be the smallest text in the shell by some way.
//
// At most barWorkspaceSlots dots wide. Past that it is a window the row
// slides under, the same shape as the wallpaper and theme strips: the focused
// dot is kept towards the middle, and an end with more dots beyond it
// dissolves into the notch. Switching never changes the width. That matters
// more here than anywhere else in the bar: the notch is centred and hugs its
// contents, so anything that resizes shifts everything sideways, and a
// positional indicator that moves when you use it is worse than useless.
Item {
    id: root

    // Never wider than the dots it has, so with fewer workspaces than slots
    // there is no empty stretch before the time.
    width: Math.min(Workspaces.count, Config.barWorkspaceSlots) * Config.barWorkspaceCell
    height: Config.barWorkspaceCell
    clip: true

    // The dot on the centre line. Follows focus, and holds its place while
    // no numbered workspace is focused — a special workspace toggled over
    // the top — rather than sliding off somewhere to mean "none".
    property int centreIndex: 0

    Binding on centreIndex {
        value: Workspaces.focusedIndex
        when: Workspaces.focusedIndex >= 0
        restoreMode: Binding.RestoreNone
    }

    readonly property real rowWidth: Workspaces.count * Config.barWorkspaceCell

    // The focused dot on the centre line, clamped so the row never pulls
    // away from either end of the window: on the first or last workspace the
    // focused dot sits at the edge rather than leaving an empty stretch
    // beside it. When every dot fits this is always zero, so nothing slides.
    readonly property real offset: {
        const centred = root.width / 2 - (root.centreIndex + 0.5) * Config.barWorkspaceCell;
        return Math.max(root.width - root.rowWidth, Math.min(0, centred));
    }

    // Whether there are dots past each end — which is when that end fades.
    // Half a pixel of slack so float error can't raise a fade over nothing.
    readonly property bool moreLeft: root.offset < -0.5
    readonly property bool moreRight: root.offset + root.rowWidth > root.width + 0.5

    Row {
        id: dots

        x: root.offset
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        // Slides rather than jumps, over the same time a picker tile takes to
        // reach the middle. On x rather than on `offset` because a Behavior
        // can't sit on a readonly property.
        Behavior on x {
            NumberAnimation {
                duration: Config.stripSlideDuration
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            model: Workspaces.all

            Item {
                id: cell

                required property var modelData

                readonly property bool focused: cell.modelData.focused
                readonly property bool occupied: cell.modelData.toplevels.values.length > 0

                width: Config.barWorkspaceCell
                height: Config.barWorkspaceCell

                Rectangle {
                    anchors.centerIn: parent

                    // The focused dot grows inside its cell rather than
                    // widening it, so the row's spacing never changes.
                    width: cell.focused ? Config.barWorkspaceDotFocused : Config.barWorkspaceDot
                    height: width
                    radius: width / 2

                    // Urgent outranks focused: a workspace shouting for
                    // attention is worth more than one saying where you
                    // already are, and you cannot be urgent at yourself.
                    color: {
                        if (cell.modelData.urgent)
                            return Config.urgent;
                        return cell.focused ? Config.accent : Config.textDim;
                    }

                    // An empty workspace still exists and still has its place
                    // in the row; it just has nothing to say.
                    opacity: cell.focused || cell.occupied || cell.modelData.urgent ? 1 : Config.barWorkspaceEmpty

                    Behavior on width {
                        NumberAnimation {
                            duration: Config.pressDuration
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.fadeDuration
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.fadeDuration
                        }
                    }
                }

                // The whole cell is the target, not the 5px dot inside it.
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: Workspaces.focus(cell.modelData)
                }
            }
        }
    }

    // Dissolves the row into the notch, the same way the day strip and the
    // pickers do: the surface colour at decreasing alpha, eased so the
    // outermost cell goes most of the way out and its neighbour is left
    // alone. They carry no handlers, so a click on a half-faded dot still
    // reaches it.
    //
    // Only at an end with dots beyond it. A fade over the last dot there is
    // would dim it, and a dim dot already means an empty workspace — so
    // with every dot in view there is no fade at all.
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Config.barWorkspaceFade

        opacity: root.moreLeft ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.stripSlideDuration
            }
        }

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: Config.fade(1)
            }

            GradientStop {
                position: 0.5
                color: Config.fade(0.38)
            }

            GradientStop {
                position: 1
                color: Config.fade(0)
            }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Config.barWorkspaceFade

        opacity: root.moreRight ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.stripSlideDuration
            }
        }

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: Config.fade(0)
            }

            GradientStop {
                position: 0.5
                color: Config.fade(0.38)
            }

            GradientStop {
                position: 1
                color: Config.fade(1)
            }
        }
    }
}
