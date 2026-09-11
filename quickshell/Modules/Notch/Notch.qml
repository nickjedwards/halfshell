pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Modules.ControlCenter
import qs.Modules.Launcher
import qs.Modules.Media
import qs.Modules.Notifications
import qs.Modules.PowerMenu
import qs.Modules.ThemePicker
import qs.Modules.WallpaperPicker

// One notch window per monitor.
//
// Three ideas do most of the work here:
//
//  1. The window never resizes. It is created once at the size of the
//     largest state and stays there, transparent, with an input mask
//     restricting clicks to the notch itself. Animating a layer-shell
//     surface's size means renegotiating with the compositor every frame;
//     animating a shape inside a fixed surface does not.
//
//  2. The mask follows the *target* geometry, not the animated geometry,
//     so it changes twice per interaction instead of sixty times a second.
//
//  3. The closed bar is three things side by side — the bell, the time, then
//     now playing — and which of them the pointer entered decides which
//     panel opens. The notch is one window and one shape throughout; only
//     its contents and its target size differ.
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    // Only the top anchor, so layer-shell centres the surface horizontally.
    anchors.top: true

    // A notch overlays the screen, it does not reserve space.
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:ndvr"

    // A panel takes the keyboard when it was *asked for* — pinned by a
    // keybind or by right-clicking the bar — and never when it was merely
    // hovered into. That is the whole condition, and it is the honest one:
    // grabbing focus on hover would pull the keyboard out of whatever you
    // were typing into every time the pointer crossed the top of the screen.
    //
    // It also replaces a list of modes that had to be kept in step by hand;
    // the theme picker spent its first minutes unable to see its own Escape
    // key because it had been added to the panels but not to that list. The
    // three keyboard-driven panels are exactly the ones `targetAt` can never
    // return, so they are always pinned and this still covers them.
    readonly property bool wantsKeyboard: NotchState.forced !== ""

    WlrLayershell.keyboardFocus: root.wantsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Escape closes whatever is open, for the panels that don't take the
    // keyboard themselves — the control centre, the notifications, the power
    // menu, now playing. The launcher and the two strips hold activeFocus so
    // they can type and arrow around, and handle their own Escape; this is
    // what has it the rest of the time.
    //
    // One handler rather than one per panel, because "Escape closes the
    // notch" is a property of the notch and not of anything inside it.
    Item {
        id: keyCatcher

        focus: true
        Keys.onEscapePressed: NotchState.close()
    }

    // Sized for the largest state, once, forever — plus room for the shadow
    // to fall into. The extra is transparent and outside the input mask, so
    // it costs nothing but the space it reserves.
    implicitWidth: Config.maxWidth + Config.cornerRadius * 2 + Config.hoverPadX * 2 + Config.shadowMargin * 2
    implicitHeight: Config.maxHeight + Config.hoverPadY * 2 + Config.shadowMargin

    // ── State ────────────────────────────────────────────────────────────

    // Which half of the closed bar the pointer entered, and so which panel is
    // open. "" is closed, otherwise "media" or "control". A forced-open panel
    // from IPC counts the same way.
    property string hoverTarget: ""
    // Something is announcing itself. Notifs keeps what, and for how long.
    readonly property bool peeking: Notifs.peeking.length > 0

    // The peek is built on the first one and kept afterwards.
    property bool peekBuilt: false

    // A pin beats a hover, not the other way round: pressing the launcher
    // keybind while the pointer happens to rest on the notch should open the
    // launcher, and before this it silently did nothing at all.
    readonly property string openTarget: NotchState.forced !== "" ? NotchState.forced : root.hoverTarget
    readonly property bool opened: root.openTarget !== ""

    // Whether the bar has a now-playing third at all. Deliberately hasPlayer
    // rather than isPlaying: the media third has to be a stable thing to aim
    // at, and a paused track is exactly when you want the transport controls.
    readonly property bool showMedia: Media.hasPlayer

    // No workspaces means this is not Hyprland, or it has not answered yet.
    // Either way the strip takes no room rather than reserving it.
    readonly property bool showWorkspaces: Workspaces.count > 0


    readonly property string mode: {
        if (root.opened) {
            if (root.openTarget === "control")
                return "control";
            if (root.openTarget === "launcher")
                return "launcher";
            if (root.openTarget === "notifications")
                return "notifications";
            if (root.openTarget === "power")
                return "power";
            if (root.openTarget === "wallpaper")
                return "wallpaper";
            if (root.openTarget === "theme")
                return "theme";
            return "media";
        }
        if (root.peeking)
            return "notify";
        if (root.showMedia)
            return "bar";
        return "idle";
    }

    readonly property real targetWidth: {
        switch (root.mode) {
        case "media":
            return Config.mediaPanelWidth;
        case "control":
            return Config.ccWidth;
        case "launcher":
            return Config.launcherWidth;
        case "notifications":
            return Config.notifPanelWidth;
        case "power":
            return Config.powerMenuWidth;
        case "wallpaper":
            return Config.wallpaperWidth;
        case "theme":
            return Config.themePanelWidth;
        case "notify":
            return Config.peekWidth;
        case "bar":
            // Sized to its contents, in the order they sit: workspaces, the
            // clock, the bell, now playing. The clock and bell widths are
            // their own; nothing here feeds back into them, so there is no
            // loop.
            return Config.barPadX * 2 + root.workspaceBlockWidth + clock.width + root.bellBlockWidth + Config.barGap + root.barContentWidth;
        default:
            return Config.barPadX * 2 + root.workspaceBlockWidth + clock.width + root.bellBlockWidth;
        }
    }

    readonly property real targetHeight: {
        switch (root.mode) {
        case "media":
            return Config.mediaPanelHeight;
        case "control":
            return Config.ccHeight;
        case "launcher":
            return Config.launcherHeight;
        case "notifications":
            return Config.notifPanelHeight;
        case "power":
            return Config.powerMenuHeight;
        case "wallpaper":
            return Config.wallpaperHeight;
        case "theme":
            return Config.themePanelHeight;
        case "notify":
            // A row for each notification peeking.
            return Config.peekPadY * 2 + Config.peekRowHeight * Math.max(1, Notifs.peeking.length);
        case "bar":
            return Config.barHeight;
        default:
            return Config.idleHeight;
        }
    }

    // The clock is the one piece of content that no state owns: it sits in
    // the bar when the notch is closed and grows into the control centre when
    // that one opens, as a single object rather than two that cross-fade.
    property real clockMorph: root.openTarget === "control" ? 1 : 0

    // Every Behavior below springs on the way in and settles on the way out.
    // OutBack overshoots whichever direction it is given, so using it for
    // both meant a panel closing shrank past its mark and came back — a
    // wobble rather than a spring, and the one bit of motion here that drew
    // attention to itself instead of to what it was carrying.
    //
    // The test is the same expression that computes each target, rather than
    // a blanket "is anything open": switching straight from one panel to
    // another has one morph arriving and another leaving at the same moment,
    // and they want opposite curves.

    // The workspace strip and the gap after it, and nothing at all when there
    // are no workspaces. Same shape as the bell block below it: one property
    // that everything else is expressed in terms of. The strip stops growing
    // at barWorkspaceSlots dots, so past that this no longer changes as
    // workspaces come and go.
    readonly property real workspaceBlockWidth: root.showWorkspaces ? workspaces.width + Config.barWorkspaceGap : 0

    // The gap before the bell and the bell itself, which sit between the
    // clock and now playing. Always there: the bell is in the bar whether or
    // not anything is waiting and says which by its fill, so the bar's width
    // no longer changes when the first notification lands or the last is
    // cleared.
    readonly property real bellBlockWidth: Config.barBellGap + bell.width

    // Where the closed bar's three things sit, in one place rather than
    // scattered across the items that use them — the hover zones below are
    // read off exactly the same numbers the elements are drawn at, so the
    // two cannot drift.
    //
    // The bell and the clock are measured from the left edge, which is a
    // constant, so neither moves while the notch grows underneath them. Now
    // playing is the one measured from the right, against live geometry
    // rather than the target width, so it stays correctly placed for every
    // frame of that growth instead of jumping at the end of it.
    //
    // It is positioned by its *content* width, not the width of the box it
    // is loaded into: CollapsedMedia packs its row to the left of a
    // generously-sized layout, so anchoring the box would leave the slack
    // between the title and the padding rather than after it.
    readonly property real barWorkspacesX: Config.barPadX
    readonly property real barClockX: Config.barPadX + root.workspaceBlockWidth

    // After the clock, measured from its width. Only read in the bar and on
    // the flight into the notification heading, and the clock is at its
    // small size in both — it grows only into the control centre, where the
    // bell has already faded out.
    readonly property real barBellX: root.barClockX + clock.width + Config.barBellGap
    readonly property real barMediaX: contentClip.width - Config.barPadX - root.barContentWidth

    // What the now-playing group actually occupies. Falls back to the widest
    // it could be, so the first frame is never too narrow for its contents.
    readonly property real barContentWidth: root.barItem ? root.barItem.contentWidth : Config.barMediaWidth

    // The art and the title do the same journey between the closed bar and
    // the media panel that the clock does between the bar and the control
    // centre — one object growing, not two cross-fading.
    property real mediaMorph: root.mode === "media" ? 1 : 0

    // Null until the panels finish preloading, which is why every landing
    // point below is guarded.
    readonly property ControlCenter controlItem: controlCentre.item as ControlCenter
    readonly property MediaPanel mediaItem: mediaPanel.item as MediaPanel
    readonly property CollapsedMedia barItem: barMedia.item as CollapsedMedia
    readonly property NotificationCenter notifItem: notifications.item as NotificationCenter

    // The bell's journey, from between the time and now playing to the right
    // of the notification centre's heading.
    property real notifMorph: root.mode === "notifications" ? 1 : 0

    Behavior on clockMorph {
        NumberAnimation {
            duration: Config.growDuration
            easing.type: root.openTarget === "control" ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: Config.overshoot
        }
    }

    Behavior on notifMorph {
        NumberAnimation {
            duration: Config.growDuration
            easing.type: root.mode === "notifications" ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: Config.overshoot
        }
    }

    Behavior on mediaMorph {
        NumberAnimation {
            duration: Config.growDuration
            easing.type: root.mode === "media" ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: Config.overshoot
        }
    }

    // Leaving the notch does not collapse it immediately — otherwise it
    // flickers every time the pointer crosses the top of the screen.
    Timer {
        id: collapseTimer
        interval: Config.collapseDelay

        // Re-checked rather than trusted. If something inside the panel takes
        // the hover for a moment on the way past, the exit that started this
        // timer was a lie — and closing on it would collapse the notch out
        // from under whatever the pointer was reaching for.
        onTriggered: {
            if (pointer.hovered)
                return;
            root.hoverTarget = "";
        }
    }

    Connections {
        target: Notifs

        function onPeeked(): void {
            // Don't interrupt someone who is already using a panel. Ended
            // rather than merely hidden, so it doesn't pop up the moment the
            // panel closes for whatever time it had left.
            if (root.opened) {
                Notifs.endPeeks();
                return;
            }
            root.peekBuilt = true;
        }
    }

    // ── Input ────────────────────────────────────────────────────────────

    // The closed bar is three things, and each leads somewhere: the time,
    // the bell, now playing. The boundaries are taken from where those elements
    // are laid out rather than from configured zone widths, so they cannot
    // drift out of step with what is drawn. Each gap is split down the
    // middle, so there is no dead ground between two zones.
    readonly property real zoneOffset: (hitArea.width - contentClip.width) / 2

    function targetAt(x: real): string {
        const bodyX = x - root.zoneOffset;

        // The workspace strip is a dead zone: its dots are switched by
        // clicking one, not by opening anything, so hovering it leaves the
        // notch closed. "" is what hoverTarget already means by closed, so
        // this needs no special case anywhere else.
        if (root.showWorkspaces && bodyX < root.barClockX - Config.barWorkspaceGap / 2)
            return "";

        if (bodyX < root.barBellX - Config.barBellGap / 2)
            return "control";

        // With no player there is no right third, so everything past the
        // clock is the bell's.
        if (!root.showMedia || bodyX < root.barMediaX - Config.barGap / 2)
            return "notifications";

        return "media";
    }

    // Sized to the target geometry, never animated. Doubles as the window's
    // input mask, so everything outside it is click-through.
    //
    // Deliberately raised above the panels. Hover is tracked here, and the
    // panel content is a sibling drawn on top of it — so at z 0 the first
    // tile the pointer crossed would take the hover, this would see an exit,
    // and the notch would collapse out from under whatever you were reaching
    // for. Raising it means nothing can take the hover away.
    //
    // Raising it costs nothing in clicks because there is no MouseArea here:
    // a non-blocking HoverHandler passes hover through to the tiles below, and
    // a right-button TapHandler never grabs a left press, so taps land on the
    // panel exactly as before.
    // Sized to the target geometry, never animated. Doubles as the window's
    // input mask, so everything outside it is click-through.
    //
    // The shape and the content live inside it, and that nesting is what
    // makes hover work. A HoverHandler reports on geometric containment in
    // the item it is attached to, so an ancestor stays hovered while the
    // pointer is over any of its descendants — the tiles keep their own
    // hover effects and the notch still knows the pointer is inside it.
    //
    // As a sibling this cannot work either way round: below the content, the
    // first tile the pointer crossed took the hover and the notch collapsed
    // out from under it; above the content, the notch kept the hover and the
    // tiles never lit up.
    //
    // There is no MouseArea here, and the TapHandler accepts only the right
    // button, so left presses fall straight through to the controls inside.
    Item {
        id: hitArea

        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: root.targetWidth + Config.cornerRadius * 2 + (root.opened ? 0 : Config.hoverPadX * 2)
        height: root.targetHeight + (root.opened ? 0 : Config.hoverPadY)

        // One handler rather than one per half. Two would have to be enabled
        // and disabled as the notch opens, and the handover drops an exit on
        // the floor — which reads as the notch closing in your face.
        HoverHandler {
            id: pointer

            // The whole point: see the hover without consuming it.
            blocking: false

            // Routing is guarded by `opened` in both handlers, and it has to
            // be in both. A panel pinned open by IPC is already open when the
            // pointer arrives, so an unguarded enter would route on whatever
            // happened to be under it and swap the panel out from under you —
            // the launcher becoming the control centre because you reached
            // across it.
            onHoveredChanged: {
                if (pointer.hovered) {
                    collapseTimer.stop();
                    Notifs.endPeeks();
                    if (!root.opened)
                        root.hoverTarget = root.targetAt(pointer.point.position.x);
                } else {
                    collapseTimer.restart();
                }
            }

            // Once a panel is up, moving across it must not swap it for
            // whatever third is under the pointer now.
            onPointChanged: {
                if (pointer.hovered && !root.opened)
                    root.hoverTarget = root.targetAt(pointer.point.position.x);
            }
        }

        // Right-click anywhere pins whichever panel you are looking at. Left
        // clicks are left alone so they reach the controls underneath.
        //
        // Nothing to pin over the workspace strip: targetAt calls that a dead
        // zone and NotchState.resolve turns an unrecognised target into the
        // media panel, so without this guard right-clicking a dot would open
        // now playing — the one panel you were furthest from asking for.
        TapHandler {
            acceptedButtons: Qt.RightButton

            onTapped: eventPoint => {
                const target = root.opened ? root.openTarget : root.targetAt(eventPoint.position.x);
                if (target !== "")
                    NotchState.toggle(target);
            }
        }

        // ── Shape ────────────────────────────────────────────────────────

        // Declared before the shape so it falls behind it. It draws the
        // shape's own silhouette a second time underneath — identical pixels
        // in the same place, so all you see of it is what spills past the
        // edges — which is what lets the shadow follow the flared corners
        // exactly rather than being a rounded rectangle approximating them.
        //
        // autoPaddingEnabled lets the blur render outside the item's bounds;
        // hitArea does not clip, so it reaches the window's own edge, which
        // is why the window grew by shadowMargin.
        MultiEffect {
            anchors.fill: shape
            source: shape

            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: Config.shadowOpacity
            shadowBlur: 1
            blurMax: Config.shadowBlur
            shadowVerticalOffset: Config.shadowY
            autoPaddingEnabled: true
        }

        NotchShape {
            id: shape

            anchors.horizontalCenter: parent.horizontalCenter
            y: 0

            // Required for the effect above to have something to sample.
            layer.enabled: true

            bodyWidth: root.targetWidth
            bodyHeight: root.targetHeight
            bottomRadius: Config.bottomRadius
            cornerRadius: Config.cornerRadius
            color: Config.surface

            Behavior on bodyWidth {
                NumberAnimation {
                    duration: Config.growDuration
                    easing.type: root.opened ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: Config.overshoot
                }
            }

            Behavior on bodyHeight {
                NumberAnimation {
                    duration: Config.growDuration
                    easing.type: root.opened ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: Config.overshoot
                }
            }
        }

        // ── Content ──────────────────────────────────────────────────────

        // Animated clip window over the body. Children inside are given fixed
        // sizes so they are translated as the notch grows, never re-laid-out.
        Item {
            id: contentClip

            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: shape.bodyWidth
            height: shape.bodyHeight
            clip: true

            // The workspace dots — the left end of the closed bar, and the
            // only thing in it that acts on a click rather than opening
            // something on hover.
            WorkspaceDots {
                id: workspaces

                x: root.barWorkspacesX
                anchors.verticalCenter: parent.verticalCenter

                opacity: root.showWorkspaces && (root.mode === "bar" || root.mode === "idle") ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }

            // Now playing — the right end of the closed bar.
            Loader {
                id: barMedia

                x: root.barMediaX
                anchors.verticalCenter: parent.verticalCenter
                width: Config.barMediaWidth
                height: Config.barHeight

                // Stays loaded while a player exists, so pausing and resuming
                // never rebuilds it.
                active: Media.hasPlayer
                asynchronous: true

                opacity: root.mode === "bar" ? 1 : 0
                visible: opacity > 0

                sourceComponent: CollapsedMedia {}

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }

            Loader {
                id: peek

                // From the top rather than centred, so the rows already up
                // stay where they are while the notch grows for another.
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Config.peekPadY
                width: Config.peekWidth - 32
                height: Config.peekRowHeight * Config.peekMax

                active: root.peekBuilt
                asynchronous: true

                opacity: root.mode === "notify" ? 1 : 0
                visible: opacity > 0

                sourceComponent: NotificationPeek {}

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }

            Loader {
                id: mediaPanel

                anchors.centerIn: parent
                width: Config.mediaPanelWidth
                height: Config.mediaPanelHeight

                // Deliberately not active at startup. See preloadTimer below.
                active: false
                asynchronous: true

                opacity: root.mode === "media" && status === Loader.Ready ? 1 : 0
                visible: opacity > 0

                sourceComponent: MediaPanel {}

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }

            Loader {
                id: launcher

                anchors.centerIn: parent
                width: Config.launcherWidth
                height: Config.launcherHeight

                // Not preloaded with the others: it builds a list of every
                // desktop entry on the machine, and unlike the panels behind
                // the bar it is never a hair-trigger away from being shown.
                active: false
                asynchronous: true

                opacity: root.mode === "launcher" && status === Loader.Ready ? 1 : 0
                visible: opacity > 0

                sourceComponent: LauncherPanel {
                    onDismissed: NotchState.close()
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }

            Loader {
                id: notifications

                anchors.centerIn: parent
                width: Config.notifPanelWidth
                height: Config.notifPanelHeight

                // Built with the others: it is cheap, and the history it
                // shows exists whether anyone is looking or not.
                active: false
                asynchronous: true

                opacity: root.mode === "notifications" && status === Loader.Ready ? 1 : 0
                visible: opacity > 0

                sourceComponent: NotificationCenter {}

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }

            Loader {
                id: powerMenu

                anchors.centerIn: parent
                width: Config.powerMenuWidth
                height: Config.powerMenuHeight

                active: false
                asynchronous: true

                opacity: root.mode === "power" && status === Loader.Ready ? 1 : 0
                visible: opacity > 0

                sourceComponent: PowerMenu {}

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }

            Loader {
                id: wallpaper

                anchors.centerIn: parent
                width: Config.wallpaperWidth
                height: Config.wallpaperHeight

                // Built on demand like the launcher rather than with the
                // panels behind the bar: it decodes a directory of pictures,
                // and nothing here is ever a hair-trigger away from opening
                // it by accident.
                active: false
                asynchronous: true

                opacity: root.mode === "wallpaper" && status === Loader.Ready ? 1 : 0
                visible: opacity > 0

                sourceComponent: WallpaperPanel {
                    onDismissed: NotchState.close()
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }

            Loader {
                id: theme

                anchors.centerIn: parent
                width: Config.themePanelWidth
                height: Config.themePanelHeight

                // On demand, like the launcher and the wallpaper picker: it
                // is reached by keybind rather than by hovering the bar, so
                // it is never a hair-trigger away from being needed.
                active: false
                asynchronous: true

                opacity: root.mode === "theme" && status === Loader.Ready ? 1 : 0
                visible: opacity > 0

                sourceComponent: ThemePanel {
                    onDismissed: NotchState.close()
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }

            Loader {
                id: controlCentre

                anchors.centerIn: parent
                width: Config.ccWidth
                height: Config.ccHeight

                active: false
                asynchronous: true

                opacity: root.mode === "control" && status === Loader.Ready ? 1 : 0
                visible: opacity > 0

                sourceComponent: ControlCenter {}

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }

            // The spectrum around the art. Declared just before it so it
            // draws behind it, and bound to its geometry so it makes the same
            // journey between the bar and the panel.
            NotchSpectrum {
                x: notchArt.x
                y: notchArt.y
                width: notchArt.width
                height: notchArt.height
                artRadius: notchArt.radius
                sizeMorph: notchArt.sizeMorph
                opacity: notchArt.opacity
                visible: notchArt.visible
            }

            // Declared after the panels so they draw over whichever state's
            // content is on screen while they fly across it.
            NotchArt {
                id: notchArt

                morph: root.mediaMorph

                collapsedX: barMedia.x + (root.barItem ? root.barItem.artX : 0)
                collapsedY: barMedia.y + (root.barItem ? root.barItem.artY : 0)
                expandedX: mediaPanel.x + (root.mediaItem ? root.mediaItem.artX : 0)
                expandedY: mediaPanel.y + (root.mediaItem ? root.mediaItem.artY : 0)

                // Only the two states it belongs to. Everything else owns the
                // whole body while it is up.
                opacity: root.mode === "bar" || root.mode === "media" ? 1 : 0
                visible: opacity > 0 && Media.hasPlayer

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }

            NotchTitle {
                morph: root.mediaMorph

                collapsedX: barMedia.x + (root.barItem ? root.barItem.titleX : 0)
                collapsedY: barMedia.y + (root.barItem ? root.barItem.titleY : 0)
                expandedX: mediaPanel.x + (root.mediaItem ? root.mediaItem.titleX : 0)
                expandedY: mediaPanel.y + (root.mediaItem ? root.mediaItem.titleY : 0)

                collapsedWidth: root.barItem ? root.barItem.titleWidth : 0
                expandedWidth: root.mediaItem ? root.mediaItem.titleWidth : 0

                // The panel only. The closed bar has no title — it starts
                // this journey invisible and zero wide beside the art, and
                // fades in as it grows into the panel, so it still arrives as
                // the one object it has always been rather than appearing
                // from nowhere once the panel has finished opening.
                opacity: root.mode === "media" ? 1 : 0
                visible: opacity > 0 && Media.hasPlayer

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }

            NotchBell {
                id: bell

                morph: root.notifMorph

                collapsedX: root.barBellX
                collapsedY: (contentClip.height - height) / 2
                expandedX: notifications.x + (root.notifItem ? root.notifItem.bellX : 0)
                expandedY: notifications.y + (root.notifItem ? root.notifItem.bellY : 0)

                // The closed bar and the panel it opens, and nothing else.
                opacity: root.mode === "bar" || root.mode === "idle" || root.mode === "notifications" ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }

            // Declared last so it draws over whichever state's content is on
            // screen while it flies across it.
            NotchClock {
                id: clock

                morph: root.clockMorph

                // Sits after the bell, measured from the left edge. There is
                // no centred case any more — the clock is never alone in the
                // bar.
                collapsedX: root.barClockX
                collapsedY: (contentClip.height - clock.height) / 2

                // The control centre is a fixed-size child of this clip, so its
                // own position plus the clock offset within it is the landing
                // point. Before the preload finishes there is nowhere to fly to,
                // but nothing is open yet either, so the fallback is never seen.
                expandedX: controlCentre.x + (root.controlItem ? root.controlItem.clockX : 0)
                expandedY: controlCentre.y + (root.controlItem ? root.controlItem.clockY : 0)

                // The media panel and notification peeks own the whole body while
                // they are up; the clock is not part of either.
                opacity: root.mode === "media" || root.mode === "notify" || root.mode === "launcher" || root.mode === "notifications" || root.mode === "power" || root.mode === "wallpaper" || root.mode === "theme" ? 0 : 1
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }
        }
    }

    mask: Region {
        item: hitArea
    }

    // Build both panels in the background once the first frame is safely on
    // screen. By the time anyone hovers, opening either is a visibility
    // change rather than a construction.
    Timer {
        id: preloadTimer
        interval: Config.preloadDelay
        running: true
        onTriggered: {
            mediaPanel.active = true;
            controlCentre.active = true;
            notifications.active = true;
            powerMenu.active = true;
        }
    }

    // If someone opens the notch before the preload timer fires, build them
    // now rather than showing an empty box.
    onOpenedChanged: {
        if (!root.opened)
            return;

        // Take the keyboard back from whichever panel had it last: an item
        // that goes invisible drops activeFocus and nothing hands it on, so
        // without this the first launcher visit would be the last time
        // Escape worked. A panel that wants it grabs it again a frame later,
        // when it becomes visible — which is why this doesn't need to know
        // which panels those are.
        keyCatcher.forceActiveFocus();
        mediaPanel.active = true;
        controlCentre.active = true;
        notifications.active = true;
        powerMenu.active = true;
    }

    onModeChanged: {
        if (root.mode === "launcher")
            launcher.active = true;
        if (root.mode === "wallpaper")
            wallpaper.active = true;
        if (root.mode === "theme")
            theme.active = true;
    }
}
