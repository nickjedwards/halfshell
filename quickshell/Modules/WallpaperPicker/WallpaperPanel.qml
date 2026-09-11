pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// The wallpaper picker: everything in Config.wallpaperDir as a strip that
// slides under a fixed window, one tile on the centre line at a time.
//
// Clicking a tile off to the side brings it to the middle; clicking the one
// already there sets it, as do Enter and "Set". A wallpaper is worth looking
// at before you commit the desktop to it, and a strip where every click
// changed it would leave nowhere to look from.
Item {
    id: root

    signal dismissed

    readonly property var focused: Wallpaper.all[strip.currentIndex] || null
    readonly property bool focusedInUse: Wallpaper.isCurrent(root.focused)

    // Read again on the way in rather than watched: something else may have
    // moved the link or dropped a picture in the directory since we last
    // looked, and this is two short-lived processes twice a session.
    onVisibleChanged: {
        if (!visible)
            return;

        Wallpaper.refresh();
        root.centre();
        strip.forceActiveFocus();
    }

    // Opens on the wallpaper you are already using rather than at the start
    // of the list, and lands there rather than sliding — the panel should
    // look like it was always showing this.
    function centre(): void {
        const i = Wallpaper.currentIndex;
        if (i < 0)
            return;

        strip.currentIndex = i;
        strip.positionViewAtIndex(i, ListView.Center);
    }

    // The first listing arrives a moment after the panel is first shown, and
    // an empty strip has nothing to centre on. This is that second chance.
    // The listing and the link are two readings that land a moment after the
    // panel is first shown, in either order, and an empty strip has nothing
    // to centre on. This is the second chance for both.
    Connections {
        target: Wallpaper

        function onCurrentIndexChanged(): void {
            root.centre();
        }
    }

    PanelHeading {
        id: heading

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        title: "Wallpaper"
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
        model: Wallpaper.all
        spacing: Config.stripTileGap
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // The sliding window: one tile is held on the centre line and the
        // strip moves under it, whether it was moved by a key, a flick or a
        // click on a neighbour. Snapping falls out of the same rule, so
        // there is no half-tile resting position to design around.
        preferredHighlightBegin: (width - Config.stripTileWidth) / 2
        preferredHighlightEnd: (width + Config.stripTileWidth) / 2
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: Config.stripSlideDuration
        snapMode: ListView.SnapToItem

        // The arrows move the centre tile on their own; the rest is ours.
        // Deliberately not wrapping: stepping off the last picture would
        // fling the strip back across every other one, which is a long way
        // to travel for a wrap.
        focus: true
        Keys.onReturnPressed: Wallpaper.set(root.focused)
        Keys.onEnterPressed: Wallpaper.set(root.focused)
        Keys.onEscapePressed: root.dismissed()

        delegate: WallpaperTile {
            required property var modelData
            required property int index

            entry: modelData
            focused: index === strip.currentIndex
            current: Wallpaper.isCurrent(modelData)

            // The tile you are looking at is the one a click sets. Anywhere
            // else, a click means "show me that one": it slides over, and
            // the click after that sets it.
            onActivated: {
                if (index === strip.currentIndex)
                    Wallpaper.set(modelData);
                else
                    strip.currentIndex = index;
            }
        }
    }

    // Siblings of the strip rather than children of it: a Flickable puts its
    // children in the content item, where they would scroll away with the
    // tiles they are supposed to be covering.
    //
    // Dissolves the strip into the panel at both ends rather than cutting it
    // off, the same way the day strip does — built from the surface colour at
    // decreasing alpha rather than fading to Qt.transparent, which is a
    // transparent *white* and would wash the pictures out before it hid them.
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

    Text {
        anchors.centerIn: strip
        visible: Wallpaper.count === 0
        text: `Nothing in ${Wallpaper.dirPath.replace(Quickshell.env("HOME"), "~")}`
        color: Config.textDim
        font.family: Config.font
        font.pixelSize: 12
    }

    // ── Caption ──────────────────────────────────────────────────────────
    Text {
        id: caption

        anchors.left: parent.left
        anchors.leftMargin: Config.ccPadX
        anchors.right: action.left
        anchors.rightMargin: 14
        anchors.top: strip.bottom
        anchors.topMargin: 12

        text: root.focused ? root.focused.title : ""
        color: Config.text
        elide: Text.ElideRight
        font.family: Config.font
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    // Says which of the two states the centred tile is in, and is a control
    // in only one of them — "Current" is a label, because setting the
    // wallpaper you are already using does nothing except restart the daemon
    // that is already showing it.
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
            onTapped: Wallpaper.set(root.focused)
        }
    }
}
