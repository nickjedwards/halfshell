pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

// Everything one sender has waiting, as one item in the centre.
//
// A group of one is just a card. More than one is a stack: the newest card
// in front, and up to two more peeking out beneath it — each inset a little
// further and a little fainter, as tall as the front card so the edges that
// show are even. No header while it is stacked; the stack says "several"
// by being one, and the front card says how many after the sender's name.
// A click anywhere on it fans the cards out into a list under a header
// carrying what applies to the whole of it: the name, how many, and
// clearing the lot.
Item {
    id: root

    required property var group
    required property bool expanded

    // Keys of the entries being cleared one at a time, from the centre.
    property var leavingKeys: ({})

    // The whole group being cleared, by its own Clear or the panel's. It
    // slides out as one after `leaveDelay`, which is how Clear sends the
    // groups out one after another, and folds away afterwards unless the
    // whole list is going anyway.
    property bool leaving: false
    property bool foldOnLeave: true
    property int leaveDelay: 0

    signal toggled
    signal groupDismissed
    signal dismissed(int key, bool folds)
    signal invoked(int key, var action)

    readonly property var entries: root.group.entries

    // What is left once the ones on their way out are gone, so a group
    // cleared down to one turns back into a single card — header folding —
    // while the other is still sliding away, rather than snapping at the end.
    readonly property var remaining: root.entries.filter(e => root.leavingKeys[e.key] !== true)
    readonly property bool grouped: root.remaining.length > 1

    readonly property bool stacked: root.entries.length > 1 && !root.expanded

    // 0 stacked, 1 fanned out into a list. Every card's place is worked out
    // from this one animated number and the cards' own heights, rather than
    // each card carrying Behaviors on its position. A Behavior chasing a
    // position that is itself moving — a card folding away above it — lands
    // late, and the list would jump when the model is finally rebuilt.
    property real fan: root.stacked ? 0 : 1

    Behavior on fan {
        NumberAnimation {
            duration: Config.notifStackDuration
            easing.type: Easing.OutCubic
        }
    }

    // The header, over an opened group of more than one only.
    property real headerShown: root.expanded && root.grouped ? 1 : 0

    Behavior on headerShown {
        NumberAnimation {
            duration: Config.notifStackDuration
            easing.type: Easing.OutCubic
        }
    }

    readonly property real headerBlock: (Config.notifGroupHeaderHeight + Config.notifCardGap) * root.headerShown

    // The cards by index, as the Repeater builds them, so each can find the
    // one above it. Reassigned rather than edited, so bindings see it.
    property var cards: []

    readonly property real topHeight: root.cards.length > 0 && root.cards[0] ? root.cards[0].naturalHeight : 0

    // How far down the cards reach where they actually are, mid-animation
    // included — so the group's height follows the fan and the folds rather
    // than needing an animation of its own.
    readonly property real contentHeight: {
        let bottom = root.headerBlock;
        for (let i = 0; i < root.cards.length; i++) {
            const card = root.cards[i];
            if (card && card.visible)
                bottom = Math.max(bottom, card.y + card.height);
        }
        return bottom;
    }

    property real slide: root.leaving ? 1 : 0
    property real fold: root.leaving && root.foldOnLeave ? 1 : 0

    Behavior on slide {
        SequentialAnimation {
            PauseAnimation {
                duration: root.leaveDelay
            }

            NumberAnimation {
                duration: Config.notifSlideDuration
                easing.type: Easing.InCubic
            }
        }
    }

    Behavior on fold {
        SequentialAnimation {
            PauseAnimation {
                duration: root.leaveDelay + Config.notifSlideDuration
            }

            NumberAnimation {
                duration: Config.notifCollapseDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    enabled: !root.leaving
    opacity: 1 - root.slide
    clip: root.fold > 0

    transform: Translate {
        x: root.slide * root.width
    }

    // The gap to the next group is the group's own rather than the list's
    // spacing, so folding away takes it too.
    implicitHeight: (root.contentHeight + Config.notifGroupSpacing) * (1 - root.fold)

    // A click on the slivers under a stack opens it, as a click on the card
    // in front does. Only below the front card: that card's own tap already
    // opens it, and both would fire on the same press.
    HoverHandler {
        enabled: root.stacked
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.stacked

        onTapped: eventPoint => {
            if (eventPoint.position.y > root.topHeight)
                root.toggled();
        }
    }

    // ── Header ───────────────────────────────────────────────────────────
    // Two separate targets side by side rather than one strip with a control
    // sitting on top of it. The toggle is the chevron, the name and the
    // count; "Clear" is its own item to the right and they do not overlap,
    // so neither has to beat the other to a press.
    //
    // Both use the default gesture policy, which takes a *passive* grab.
    // That matters inside a ListView: the Flickable takes the exclusive grab
    // on press to see whether you are flicking, so a handler asking for an
    // exclusive one — ReleaseWithinBounds — is refused and never taps at
    // all. A passive grab survives alongside the Flickable's and fires on
    // release.
    Item {
        id: header

        width: parent.width
        height: Config.notifGroupHeaderHeight * root.headerShown
        visible: root.headerShown > 0
        opacity: root.headerShown
        clip: true

        // Spans the whole strip, so "Clear" appears whenever the header is
        // under the pointer rather than only over its own few pixels.
        HoverHandler {
            id: headerHover
        }

        Item {
            id: toggleTarget

            anchors.left: parent.left
            anchors.top: parent.top
            width: chevron.width + 8 + name.implicitWidth + 7 + count.implicitWidth + Config.rowPadX * 2
            height: Config.notifGroupHeaderHeight

            RowHighlight {
                on: toggleHover.hovered
            }

            HoverHandler {
                id: toggleHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.toggled()
            }

            // Points up, at the list it would fold back into a stack.
            TileIcon {
                id: chevron

                anchors.left: parent.left
                anchors.leftMargin: Config.rowPadX
                anchors.verticalCenter: parent.verticalCenter
                kind: "back"
                size: 13
                rotation: 90
                color: toggleHover.hovered ? Config.text : Config.textDim

                Behavior on color {
                    ColorAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }

            Text {
                id: name

                anchors.left: chevron.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.group.appName
                color: Config.text
                font.family: Config.font
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            // Counts down as they are cleared, not when the last slide ends.
            Text {
                id: count

                anchors.left: name.right
                anchors.leftMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                text: root.remaining.length
                color: Config.textDim
                font.family: Config.font
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        // Clears the sender, not the panel. Appears on hover for the same
        // reason the cross on a card does. An item around the word rather
        // than the word itself — 25px by 13 is a thing to read, not to hit.
        Item {
            id: clearTarget

            anchors.right: parent.right
            anchors.top: parent.top
            width: clearLabel.implicitWidth + Config.rowPadX * 2
            height: Config.notifGroupHeaderHeight
            visible: headerHover.hovered

            RowHighlight {
                on: clearHover.hovered
            }

            HoverHandler {
                id: clearHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.groupDismissed()
            }

            Text {
                id: clearLabel

                anchors.centerIn: parent
                text: "Clear"
                color: clearHover.hovered ? Config.text : Config.textDim
                font.family: Config.font
                font.pixelSize: 10
                font.weight: Font.Medium

                Behavior on color {
                    ColorAnimation {
                        duration: Config.fadeDuration
                    }
                }
            }
        }
    }

    // ── The cards ────────────────────────────────────────────────────────
    // All of them, always, laid out by hand from `fan`: stacked, each sits
    // behind the front card; opened, each sits under the one above it.
    Repeater {
        model: root.entries

        onItemAdded: (index, item) => {
            const next = root.cards.slice();
            next[index] = item;
            root.cards = next;
        }

        onItemRemoved: (index, item) => {
            const next = root.cards.slice();
            next[index] = null;
            root.cards = next;
        }

        NotificationRow {
            id: card

            required property var modelData
            required property int index

            readonly property var above: card.index > 0 ? (root.cards[card.index - 1] || null) : null

            // Stacked: behind the front card, inset and dropped a sliver
            // more at each level, the fourth and later waiting exactly
            // behind the third. As tall as the front card, so the edges that
            // show are even whatever each one says.
            readonly property int level: Math.min(card.index, 2)
            readonly property real stackX: card.level * Config.notifStackInset
            readonly property real stackY: card.level * Config.notifStackPeek
            readonly property real stackHeight: card.index === 0 ? card.naturalHeight : root.topHeight

            // Opened: under the one above it, or under the header. From the
            // card above's own list position and folding height — not its
            // animated one — so a card folding away above pulls this one up
            // exactly, frame for frame.
            readonly property real listY: card.above ? card.above.listY + card.above.naturalHeight + Config.notifCardGap : root.headerBlock

            x: card.stackX * (1 - root.fan)
            y: card.stackY + (card.listY - card.stackY) * root.fan
            width: root.width - 2 * card.x
            height: card.stackHeight + (card.naturalHeight - card.stackHeight) * root.fan
            z: -card.index

            visible: card.index < 3 || root.fan > 0

            // Fainter at each level, so the slivers read as further back.
            // Not much fainter: the card fill is only a step off the panel,
            // and at half of it the slivers all but vanish into the surface.
            plateOpacity: {
                if (card.index === 0)
                    return 1;
                const behind = card.index === 1 ? 0.7 : card.index === 2 ? 0.45 : 0;
                return behind + (1 - behind) * root.fan;
            }

            // The card in front's shadow on this one's sliver, only while
            // stacked: opened, the cards are apart and cast nothing.
            edgeAt: card.above ? card.above.y + card.above.height - card.y : 0
            edgeShade: card.index > 0 && card.index < 3 ? 1 - root.fan : 0

            // Late in the fan-out rather than with it, so a card's words
            // don't show while it is still squeezed behind the front one.
            contentOpacity: card.index === 0 ? 1 : root.fan * root.fan
            interactive: card.index === 0 || root.fan === 1

            entry: modelData

            // The header names the sender once a group is opened.
            showApp: !(root.expanded && root.grouped)

            stackTop: card.index === 0 && root.stacked
            extra: card.index === 0 && root.stacked ? root.entries.length - 1 : 0

            leaving: root.leavingKeys[modelData.key] === true

            onOpened: root.toggled()

            // On the front of a stack, the cross clears the stack: until it
            // is opened the stack is one thing. Opened, a card is itself.
            onDismissed: {
                if (root.stacked)
                    root.groupDismissed();
                else
                    root.dismissed(modelData.key, true);
            }

            onInvoked: action => root.invoked(modelData.key, action)
        }
    }
}
