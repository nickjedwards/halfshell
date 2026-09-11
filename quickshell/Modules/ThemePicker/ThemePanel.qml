pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

// The theme picker, built as a strip exactly like the wallpaper one: the
// palettes slide under a fixed window, one on the centre line at a time.
//
// Clicking a tile off to the side brings it to the middle; clicking the one
// already there sets it, as do Enter and "Set". Same rule as the wallpapers,
// and for the same reason — a palette is worth looking at before you commit
// the whole shell to it, and a strip where every click repainted everything
// would leave nowhere to look from.
//
// Choosing repaints immediately: Config's palette is bound to the selection,
// so there is nothing to apply and nothing to restart. The choice is written
// to Themes.path, which is what makes it outlive the shell.
Item {
    id: root

    signal dismissed

    readonly property var focused: Themes.all[strip.currentIndex] || null
    readonly property bool focusedInUse: Themes.isCurrent(root.focused)

    onVisibleChanged: {
        if (!visible)
            return;

        root.centre();
        strip.forceActiveFocus();
    }

    // Opens on the palette you are already using rather than at the start of
    // the list, and lands there rather than sliding.
    function centre(): void {
        const i = Themes.currentIndex;
        if (i < 0)
            return;

        strip.currentIndex = i;
        strip.positionViewAtIndex(i, ListView.Center);
    }

    // The stored choice is read from a file, which lands a moment after the
    // singleton is built — possibly after this panel first opened. This is
    // the second chance to centre on it.
    Connections {
        target: Themes

        function onCurrentIndexChanged(): void {
            root.centre();
        }
    }

    PanelHeading {
        id: heading

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        title: "Theme"
    }

    // ── Strip ────────────────────────────────────────────────────────────
    // Full width rather than inset like the panel's text, so the tiles run
    // off both edges and the row reads as continuing past what you can see.
    ListView {
        id: strip

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: heading.bottom
        anchors.topMargin: Config.panelHeadingGap
        height: Config.stripTileHeight

        orientation: ListView.Horizontal
        model: Themes.all
        spacing: Config.stripTileGap
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // The sliding window: one tile is held on the centre line and the
        // strip moves under it, however it was moved. Snapping falls out of
        // the same rule.
        preferredHighlightBegin: (width - Config.stripTileWidth) / 2
        preferredHighlightEnd: (width + Config.stripTileWidth) / 2
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: Config.stripSlideDuration
        snapMode: ListView.SnapToItem

        // The arrows move the centre tile on their own; the rest is ours.
        focus: true
        Keys.onReturnPressed: Themes.set(root.focused)
        Keys.onEnterPressed: Themes.set(root.focused)
        Keys.onEscapePressed: root.dismissed()

        delegate: ThemeTile {
            required property var modelData
            required property int index

            theme: modelData
            focused: index === strip.currentIndex
            current: Themes.isCurrent(modelData)

            onActivated: {
                if (index === strip.currentIndex)
                    Themes.set(modelData);
                else
                    strip.currentIndex = index;
            }
        }
    }

    // Siblings of the strip rather than children of it: a Flickable puts its
    // children in the content item, where they would scroll away with the
    // tiles they are supposed to be covering.
    Rectangle {
        anchors.left: strip.left
        anchors.top: strip.top
        anchors.bottom: strip.bottom
        width: Config.stripFade

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: Config.surface
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
        anchors.right: strip.right
        anchors.top: strip.top
        anchors.bottom: strip.bottom
        width: Config.stripFade

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
                color: Config.surface
            }
        }
    }

    // ── Caption ──────────────────────────────────────────────────────────
    Text {
        id: caption

        anchors.left: parent.left
        anchors.leftMargin: Config.ccPadX
        anchors.right: action.left
        anchors.rightMargin: 14
        anchors.top: strip.bottom
        anchors.topMargin: Config.stripCaptionGap

        text: root.focused ? root.focused.name : ""
        color: Config.text
        elide: Text.ElideRight
        font.family: Config.font
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    // A control in only one of its two states — "Current" is a label,
    // because setting the palette already on screen would do nothing.
    Text {
        id: action

        anchors.right: parent.right
        anchors.rightMargin: Config.ccPadX
        anchors.verticalCenter: caption.verticalCenter

        visible: root.focused !== null
        text: root.focusedInUse ? "Current" : "Set"
        color: !root.focusedInUse && hover.hovered ? Config.text : Config.textDim
        font.family: Config.font
        font.pixelSize: 11
        font.weight: Font.Medium

        Behavior on color {
            ColorAnimation {
                duration: Config.fadeDuration
            }
        }

        HoverHandler {
            id: hover
            enabled: !root.focusedInUse
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: !root.focusedInUse
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: Themes.set(root.focused)
        }
    }
}
