pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// The notification centre: everything the daemon has kept, newest first.
//
// A live surface, not just a log. Notifs holds each notification's D-Bus
// object for as long as its sender does, so dismissing a row tells the
// sender, and a row can offer whatever actions came with it.
Item {
    id: root

    // Which groups are open, by sender name.
    //
    // Here rather than in Notifs, because it is a fact about this panel and
    // not about the notifications: the service would be holding view state
    // for a view that may not even be built. It outlives the panel closing
    // all the same — the loader keeps it — so a group you opened is still
    // open the next time you look, which is what anyone would expect of
    // something they opened.
    //
    // A plain object used as a set, reassigned rather than mutated so the
    // delegates re-evaluate: QML does not watch the inside of a var.
    property var expandedGroups: ({})

    function isExpanded(key: string): bool {
        return root.expandedGroups[key] === true;
    }

    function toggle(key: string): void {
        root.expandedGroups = root.withKey(root.expandedGroups, key, !root.expandedGroups[key]);
    }

    function withKey(set: var, key: var, on: bool): var {
        const next = Object.assign({}, set);

        if (on)
            next[key] = true;
        else
            delete next[key];

        return next;
    }

    // ── Clearing ─────────────────────────────────────────────────────────
    // A cleared notification slides out to the right before it is actually
    // dropped. It has to be that way round: the list's model is a plain array
    // rebuilt on every change, so the moment Notifs lets go of an entry every
    // delegate is rebuilt and there is nothing left to animate. So a clear
    // marks what is leaving, the rows animate off that, and only once they
    // have gone does Notifs hear about it.
    //
    // The marks live here rather than in the rows for the same reason: a
    // notification arriving mid-slide rebuilds the list, and a row rebuilt
    // while still marked starts out gone instead of popping back.
    property var leavingKeys: ({})
    property var leavingGroups: ({})

    // Clear sends every group out one after another and drops the lot at
    // the end. Nothing folds: everything is going, so there is nothing below
    // to close up, and folding would drag the rest up under the slide.
    property bool clearingAll: false

    function dismissOne(key: int, folds: bool): void {
        if (root.leavingKeys[key])
            return;

        root.leavingKeys = root.withKey(root.leavingKeys, key, true);

        // Dropped first, unmarked second — the other way round, the row
        // would be back for a frame before it went.
        root.after(Config.notifSlideDuration + (folds ? Config.notifCollapseDuration : 0), () => {
            Notifs.dismiss(key);
            root.leavingKeys = root.withKey(root.leavingKeys, key, false);
        });
    }

    function dismissGroup(key: string): void {
        if (root.leavingGroups[key])
            return;

        root.leavingGroups = root.withKey(root.leavingGroups, key, true);

        root.after(Config.notifSlideDuration + Config.notifCollapseDuration, () => {
            Notifs.dismissGroup(key);
            root.leavingGroups = root.withKey(root.leavingGroups, key, false);
        });
    }

    // Group by group rather than Notifs.clear(), so something that arrives
    // while the others are sliding out isn't swept away unseen with them.
    function clearAll(): void {
        if (root.clearingAll || Notifs.count === 0)
            return;

        const keys = Notifs.groups.map(g => g.key);
        const all = {};
        keys.forEach(k => all[k] = true);

        root.clearingAll = true;
        root.leavingGroups = all;

        const lastDelay = Math.min(keys.length - 1, Config.notifClearStaggerMax) * Config.notifClearStagger;

        root.after(lastDelay + Config.notifSlideDuration, () => {
            keys.forEach(k => Notifs.dismissGroup(k));
            root.leavingGroups = ({});
            root.clearingAll = false;
        });
    }

    // One-shot timers made on demand, so overlapping clears each keep their
    // own clock.
    Component {
        id: afterTimer

        Timer {
            id: timer

            property var action: null

            running: true
            onTriggered: {
                timer.action();
                timer.destroy();
            }
        }
    }

    function after(ms: int, action: var): void {
        afterTimer.createObject(root, {
            interval: ms,
            action: action
        });
    }

    // Where the bell should land when this panel is open. The panel keeps an
    // invisible one of exactly the right size — the same trick the clock, art
    // and title use — so the flying bell has somewhere exact to aim at.
    readonly property real bellX: heading.x + bellGhost.x
    readonly property real bellY: heading.y + bellGhost.y

    PanelHeading {
        id: heading

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        title: "Notifications"

        // Not drawn. The real bell flies in from the bar and lands on top of
        // it.
        BellMark {
            id: bellGhost

            anchors.right: parent.right
            anchors.rightMargin: Config.ccPadX
            anchors.verticalCenter: parent.line.verticalCenter
            opacity: 0
            iconSize: Config.panelBellSize
        }

        // Only offered when there is something to clear, so the panel never
        // shows an action that would do nothing. Just "Clear" — the list
        // under it is what says how much of it there is.
        Text {
            id: clear

            anchors.right: bellGhost.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.line.verticalCenter
            visible: Notifs.count > 0
            text: "Clear"
            color: clearHover.hovered ? Config.text : Config.textDim
            font.family: Config.font
            font.pixelSize: 11
            font.weight: Font.Medium

            Behavior on color {
                ColorAnimation {
                    duration: Config.fadeDuration
                }
            }

            HoverHandler {
                id: clearHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.clearAll()
            }
        }
    }

    ListView {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: heading.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: Config.ccPadX
        anchors.rightMargin: Config.ccPadX
        anchors.topMargin: Config.panelHeadingGap
        anchors.bottomMargin: Config.ccPadX

        // Clipped, which is also what a cleared row slides out of sight
        // behind.
        clip: true

        // None here: each group carries its own gap below it, so that
        // folding away takes the gap with it. See NotificationGroup.
        spacing: 0

        model: Notifs.groups
        boundsBehavior: Flickable.StopAtBounds

        delegate: NotificationGroup {
            required property var modelData
            required property int index

            width: ListView.view.width
            group: modelData
            expanded: root.isExpanded(modelData.key)

            leavingKeys: root.leavingKeys
            leaving: root.leavingGroups[modelData.key] === true
            foldOnLeave: !root.clearingAll
            leaveDelay: root.clearingAll ? Math.min(index, Config.notifClearStaggerMax) * Config.notifClearStagger : 0

            onToggled: root.toggle(modelData.key)
            onGroupDismissed: root.dismissGroup(modelData.key)
            onDismissed: (key, folds) => root.dismissOne(key, folds)
            onInvoked: (key, action) => Notifs.invoke(key, action)
        }

        Text {
            anchors.centerIn: parent
            visible: Notifs.count === 0
            text: "Nothing new"
            color: Config.textDim
            font.family: Config.font
            font.pixelSize: 12
        }
    }
}
