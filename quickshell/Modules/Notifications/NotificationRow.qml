pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

// One notification in the centre, as a card: who sent it, how long ago, what
// it said, and what can still be done about it. The dismiss cross appears on
// hover rather than sitting on every card — twenty crosses down the panel is
// a list of crosses, not a list of notifications. The action buttons don't
// hide, because a button you have to go looking for is not a button.
//
// The card is the control centre's tile — the hairline fill at a tile's
// radius — so the panels read as one set rather than each inventing a
// surface. It sizes itself to what it says rather than to a fixed row, which
// a filled card needs: a two-line body used to run past the bottom of its
// row, where nobody could see the overrun until there was an edge to cross.
Item {
    id: root

    required property var entry

    // Off inside an opened group, whose header already names the sender —
    // repeating it on every card would say "Chat" four times down a column
    // whose heading says Chat.
    property bool showApp: true

    // ── Stack roles, set by the group ────────────────────────────────────
    // The front card of a collapsed stack. A click opens the stack rather
    // than acting on the notification, and the cross clears the whole stack:
    // until it is opened, a stack is one thing, the way macOS treats them.
    property bool stackTop: false

    // How many more are behind it, said quietly after the sender's name.
    property int extra: 0

    // A card behind the front one is only its plate — a sliver below the
    // card in front — so its content fades with the fan-out, and it takes no
    // input until the stack is opened.
    property real contentOpacity: 1
    property real plateOpacity: 1
    property bool interactive: true

    // Where the card in front ends, in this card's own coordinates, and how
    // strongly it shades the sliver below it. See the shadow below.
    property real edgeAt: 0
    property real edgeShade: 0

    // ── Clearing ─────────────────────────────────────────────────────────
    // Set by the group while this card is being cleared. It slides out to
    // the right, fading as it goes, and then folds its height away, so the
    // cards under it close up rather than jump. The list is rebuilt whenever
    // any notification changes, and a card built already leaving starts out
    // gone rather than replaying the slide: Behaviors don't run on a
    // property's first value.
    property bool leaving: false
    property bool foldOnLeave: true

    property real slide: root.leaving ? 1 : 0
    property real fold: root.leaving && root.foldOnLeave ? 1 : 0

    Behavior on slide {
        NumberAnimation {
            duration: Config.notifSlideDuration
            easing.type: Easing.InCubic
        }
    }

    Behavior on fold {
        SequentialAnimation {
            PauseAnimation {
                duration: Config.notifSlideDuration
            }

            NumberAnimation {
                duration: Config.notifCollapseDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    // The sender's own object, while it still has one. Only a live
    // notification can be acted on, and only it knows about a replacement.
    readonly property var live: root.entry.notification

    // What to draw: the live object where there is one, the copy taken on
    // arrival where the sender has since closed it.
    readonly property var view: Notifs.view(root.entry)

    readonly property var actions: root.live ? root.live.actions.filter(action => action.identifier !== "default") : []

    // Not a button. The spec's "default" action is what clicking the
    // notification itself does, so the card carries it rather than drawing
    // it at the end of the others.
    readonly property var defaultAction: root.live ? (root.live.actions.find(action => action.identifier === "default") || null) : null

    signal dismissed
    signal invoked(action: var)
    signal opened

    // What the card comes to on its own, folding included. The group reads
    // this rather than `height`, which it sets — a card behind a stack is
    // drawn at the front card's height, whatever its own content.
    readonly property real naturalHeight: (Math.max(Config.notifIconSize, column.implicitHeight) + Config.notifCardPad * 2) * (1 - root.fold)

    implicitHeight: root.naturalHeight

    enabled: !root.leaving && root.interactive
    opacity: 1 - root.slide

    // Always, because a card is sometimes drawn shorter than its content: a
    // sliver in a stack, or folding away.
    clip: true

    transform: Translate {
        x: root.slide * root.width
    }

    Rectangle {
        anchors.fill: parent
        radius: Config.notifCardRadius
        color: Config.hairline
        opacity: root.plateOpacity

        // Lifts a touch under the pointer rather than drawing a second
        // lozenge inside the first.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Config.raise(0.04)
            opacity: hover.hovered ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.highlightDuration
                }
            }
        }
    }

    // The shadow the card in front casts along the top of the sliver that
    // shows beneath it. It is what makes a stack read as cards behind cards
    // rather than stripes under one: the fills alone are only a step off the
    // panel, and fainter copies of a faint step barely register.
    //
    // Soft rather than crisp: a light edge spread over most of the sliver and
    // eased out, rather than a dark line under the card in front. Inset from
    // the sides so the darker top stays inside the plate's rounded corners;
    // by the time it reaches the bottom corners there is nothing left of it.
    Rectangle {
        x: 5
        y: root.edgeAt
        width: parent.width - 10
        height: Config.notifStackPeek
        visible: root.edgeShade > 0
        opacity: root.edgeShade

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(0, 0, 0, 0.14)
            }

            GradientStop {
                position: 0.4
                color: Qt.rgba(0, 0, 0, 0.05)
            }

            GradientStop {
                position: 1
                color: Qt.rgba(0, 0, 0, 0)
            }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: root.stackTop || root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    // The default action, on the card itself — or, on the front of a stack,
    // opening it.
    //
    // Everything here is a passive grab, because an exclusive one is refused
    // inside a ListView — the Flickable has one — and would never tap at
    // all. That means this handler and a control's both fire on the same
    // press, in no guaranteed order. Hence the guard: a tap that landed on a
    // control is that control's, not the card's.
    function overControl(pos: point): bool {
        if (closeMark.visible && closeMark.contains(closeMark.mapFromItem(root, pos)))
            return true;
        if (buttons.visible && buttons.contains(buttons.mapFromItem(root, pos)))
            return true;

        return false;
    }

    TapHandler {
        enabled: root.stackTop || root.defaultAction !== null

        onTapped: eventPoint => {
            if (root.overControl(eventPoint.position))
                return;

            if (root.stackTop)
                root.opened();
            else
                root.invoked(root.defaultAction);
        }
    }

    // Everything drawn on the card, faded as one.
    Item {
        anchors.fill: parent
        opacity: root.contentOpacity
        visible: opacity > 0

        ClippingRectangle {
            id: icon

            anchors.left: parent.left
            anchors.leftMargin: Config.notifCardPad
            anchors.top: parent.top
            anchors.topMargin: Config.notifCardPad
            width: Config.notifIconSize
            height: Config.notifIconSize
            radius: 9

            // A step off the card rather than the card's own colour, so an
            // app icon drawn with margins still sits in a square of its own.
            color: Config.raise(0.06)

            // The notification's own image where there is one — message
            // avatars and album art — and the sending application's icon
            // otherwise.
            IconImage {
                anchors.fill: parent
                anchors.margins: root.view.image ? 0 : 6
                source: root.view.image ? root.view.image : Notifs.appIconSource(root.view.appIcon)
                asynchronous: true
            }
        }

        ColumnLayout {
            id: column

            anchors.left: icon.right
            anchors.leftMargin: 11
            anchors.right: parent.right
            anchors.rightMargin: Config.notifCardPad
            anchors.top: parent.top
            anchors.topMargin: Config.notifCardPad - 2
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    visible: root.showApp
                    text: root.entry.appName
                    color: Config.textDim
                    font.family: Config.font
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }

                Text {
                    visible: root.extra > 0
                    text: `+${root.extra}`
                    color: Config.textDim
                    opacity: 0.7
                    font.family: Config.font
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.entry.urgent
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Config.urgent
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    // Time.now is read here so this re-evaluates every
                    // minute; Notifs.formatAge deliberately doesn't read the
                    // clock.
                    text: Notifs.formatAge(root.entry.time, Time.now)
                    color: Config.textDim
                    visible: !hover.hovered
                    font.family: Config.font
                    font.pixelSize: 10
                }

                // Takes the age's place rather than sitting beside it, so the
                // card doesn't reflow under the pointer.
                TileIcon {
                    id: closeMark

                    Layout.alignment: Qt.AlignVCenter
                    visible: hover.hovered
                    kind: "close"
                    size: 13
                    color: close.hovered ? Config.text : Config.textDim

                    HoverHandler {
                        id: close
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.dismissed()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.view.summary
                color: Config.text
                elide: Text.ElideRight
                textFormat: Text.PlainText
                font.family: Config.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: Notifs.bodyBlock(root.view.body)
                color: Config.textDim
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 2
                textFormat: Text.PlainText
                font.family: Config.font
                font.pixelSize: 11
            }

            // A Flow rather than a Row: a sender can send as many actions as
            // it likes, and the card is told how tall this came out rather
            // than assuming one line of them.
            Flow {
                id: buttons

                Layout.fillWidth: true
                Layout.topMargin: Config.notifActionGap
                visible: root.actions.length > 0
                spacing: Config.notifActionSpacing

                Repeater {
                    model: root.actions

                    ActionChip {
                        required property var modelData

                        label: modelData.text
                        onActivated: root.invoked(modelData)
                    }
                }
            }
        }
    }
}
