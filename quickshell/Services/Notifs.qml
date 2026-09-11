pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Common

// The notch is the notification daemon. Every notification becomes a plain
// JavaScript entry — key, text, time — with a live handle on the D-Bus object
// kept beside it, because acting on a notification means talking back to
// whoever sent it.
//
// The handle is only good while the sender still has the notification open,
// so everything drawable is copied into the entry as well. A row whose sender
// has closed it then stays in history as a record with no buttons, rather
// than a row of buttons over a pointer to nothing.
Singleton {
    id: root

    readonly property int historyLimit: 20

    property var history: []

    // What is peeking right now: the keys of the newest few arrivals, newest
    // first, each with its own deadline. Keys rather than entries, with
    // `peeking` derived from history, so a notification dismissed or closed
    // mid-peek is drawn as it now is — or not at all — without anything
    // here having to be told.
    property var peekKeys: []
    property var peekUntil: ({})

    readonly property var peeking: root.peekKeys.map(k => root.history.find(e => e.key === k)).filter(e => e !== undefined)

    readonly property int count: root.history.length

    // Our own key rather than the D-Bus id, which the spec allows a sender to
    // reuse. Dismissing the wrong row because two apps picked the same id is
    // exactly the kind of bug that would take an afternoon to believe.
    property int nextKey: 1

    signal peeked

    function push(notification: var): void {
        const entry = {
            key: root.nextKey++,
            id: notification.id,
            appName: notification.appName || "Notification",
            appIcon: notification.appIcon,
            summary: notification.summary,
            body: notification.body,
            image: notification.image,
            urgent: notification.urgency === NotificationUrgency.Critical,
            // The sender's own object. What the panel draws and acts on until
            // it closes; null from then on.
            notification: notification,
            time: new Date()
        };

        // Without this the server closes the notification the moment this
        // handler returns, and every action on it goes with it.
        notification.tracked = true;
        notification.closed.connect(() => root.deactivate(entry));

        // A sender may replace a notification in place rather than send
        // another — a download's percentage, a chat's message count — and
        // quickshell updates the object instead of emitting again. Rows read
        // from the object, so they rewrite themselves; the peek has to be
        // asked for, or the new text would only ever appear in the panel.
        // Through Qt.callLater so one replacement is one peek rather than one
        // per property it moved.
        const updated = () => Qt.callLater(root.replaced, entry);
        notification.summaryChanged.connect(updated);
        notification.bodyChanged.connect(updated);

        const all = [entry, ...root.history];
        root.history = all.slice(0, root.historyLimit);

        // History is assigned before the overflow is released, because
        // releasing closes a notification, and that lands straight back here
        // in `deactivate` looking through the history it is given.
        all.slice(root.historyLimit).forEach(dropped => root.release(dropped));

        root.peek(entry);
    }

    // History folded by sender, newest group first, newest entry first
    // within each. Grouped by app name rather than by desktop entry because
    // the name is what the panel puts at the top of the group — grouping by
    // something the reader can't see would look arbitrary the first time two
    // apps shared an id.
    //
    // Derived rather than kept: `history` is already rebuilt on every push,
    // dismiss and close, so a second structure to maintain alongside it is a
    // second structure to forget to maintain.
    readonly property var groups: {
        const byApp = {};
        const out = [];

        for (let i = 0; i < root.history.length; i++) {
            const entry = root.history[i];
            let group = byApp[entry.appName];

            if (!group) {
                group = {
                    key: entry.appName,
                    appName: entry.appName,
                    entries: []
                };
                byApp[entry.appName] = group;
                out.push(group);
            }

            group.entries.push(entry);
        }

        return out;
    }

    // Everything one sender has waiting, in one go. Same order as `clear`:
    // history is assigned first, and only then are the notifications closed,
    // because closing lands back in `deactivate` looking through it.
    function dismissGroup(key: string): void {
        const dropped = root.history.filter(e => e.appName === key);
        if (dropped.length === 0)
            return;

        root.history = root.history.filter(e => e.appName !== key);


        dropped.forEach(entry => root.release(entry));
    }

    // What to draw for an entry: the sender's live object where there still
    // is one, because it is the only thing that knows about a replacement,
    // and the copy taken on arrival once there isn't.
    function view(entry: var): var {
        return entry ? (entry.notification || entry) : null;
    }

    // Chrome — and so every web app running inside it — sends the origin, a
    // blank line, and then the message. A blank line inside a two-line body
    // is a line we haven't got: it costs the message itself, which is the
    // part anybody wanted. Runs of blank lines collapse to one break.
    function bodyBlock(text: string): string {
        return text.replace(/\n\s*\n+/g, "\n").trim();
    }

    // The same body on the one line a peek has room for. The break becomes a
    // separator rather than being dropped, so "teams.microsoft.com" and what
    // was actually said stay legibly two things.
    function bodyLine(text: string): string {
        return root.bodyBlock(text).replace(/\n/g, " · ");
    }

    // The spec lets app_icon be either a themed icon name or a file:// URI,
    // and Chrome sends the second — a PNG it writes to a temp directory per
    // notification. Handing that to iconPath looks it up as a theme name,
    // finds nothing, and the row draws an empty square where the sender's
    // icon should be.
    function appIconSource(icon: string): string {
        if (!icon)
            return "";
        if (icon.startsWith("file:"))
            return icon;
        // encodeURI rather than plain concatenation, for the same reason the
        // wallpapers are: a space in a path is not a space in a URL.
        if (icon.startsWith("/"))
            return `file://${encodeURI(icon)}`;

        return Quickshell.iconPath(icon, true);
    }

    function dismiss(key: int): void {
        const entry = root.history.find(e => e.key === key);

        root.history = root.history.filter(e => e.key !== key);

        if (entry)
            root.release(entry);
    }

    function clear(): void {
        const dropped = root.history;

        root.history = [];

        dropped.forEach(entry => root.release(entry));
    }

    // Taking an action is the last thing that happens to a notification:
    // quickshell closes it on invoke unless the sender asked to stay
    // resident, which is the difference between "Reply" and a player's
    // "Next". The row follows the notification — an action already taken is
    // not one to offer again — while a resident one stays where it is.
    function invoke(key: int, action: var): void {
        const entry = root.history.find(e => e.key === key);
        if (!entry || !entry.notification)
            return;

        // Read before the invoke, because by the time it returns there may be
        // nothing left to ask.
        const resident = entry.notification.resident;

        action.invoke();

        if (!resident)
            root.dismiss(key);
    }

    // Tell the sender its notification is gone. The close comes back through
    // `deactivate`, which is a no-op for an entry already out of history.
    function release(entry: var): void {
        if (entry.notification)
            entry.notification.dismiss();
    }

    // The sender has taken the notification back — closed it, or acted on it
    // somewhere else. The entry stays as a record; only the handle goes,
    // because a Notification doesn't outlive its close. A copy rather than an
    // edit, so the panel and the peek rebuild against an entry that no longer
    // points at anything, instead of sitting on bindings that do.
    function deactivate(entry: var): void {
        const inert = Object.assign({}, entry, {
            notification: null
        });

        root.history = root.history.map(e => e === entry ? inert : e);

    }

    // ── Peeking ──────────────────────────────────────────────────────────
    // A notification peeks for peekDuration from when it arrived, or from its
    // latest replacement. Several arriving together stack rather than each
    // replacing the last — newest on top, at most peekMax — and each leaves
    // when its own time is up, so a burst drains away oldest first, in the
    // order it came, rather than all at once.
    function peek(entry: var): void {
        root.peekKeys = [entry.key, ...root.peekKeys.filter(k => k !== entry.key)].slice(0, Config.peekMax);

        const until = {};
        root.peekKeys.forEach(k => until[k] = root.peekUntil[k]);
        until[entry.key] = Date.now() + Config.peekDuration;
        root.peekUntil = until;

        root.schedulePeeks();
        root.peeked();
    }

    // Everything stops peeking at once: the pointer has arrived, or a panel
    // is open, and either way the notifications are about to be in view.
    function endPeeks(): void {
        root.peekKeys = [];
        root.peekUntil = ({});
        peekTimer.stop();
    }

    // One timer, set for whichever peek runs out first.
    function schedulePeeks(): void {
        if (root.peekKeys.length === 0) {
            peekTimer.stop();
            return;
        }

        const next = Math.min(...root.peekKeys.map(k => root.peekUntil[k]));
        peekTimer.interval = Math.max(1, next - Date.now());
        peekTimer.restart();
    }

    Timer {
        id: peekTimer

        onTriggered: {
            // A little slack, so two peeks due within a frame of each other
            // go together rather than one timer tick apart.
            const now = Date.now() + 20;
            const keep = root.peekKeys.filter(k => root.peekUntil[k] > now);
            const until = {};
            keep.forEach(k => until[k] = root.peekUntil[k]);

            root.peekKeys = keep;
            root.peekUntil = until;
            root.schedulePeeks();
        }
    }

    // Replacements are new information, so they peek like a new arrival —
    // unless the entry has already been pushed out of history, in which case
    // there is nothing left to peek at.
    function replaced(entry: var): void {
        if (root.history.indexOf(entry) === -1)
            return;

        root.peek(entry);
    }

    // `now` is passed in rather than read here so the caller can bind it to
    // Time.now — a function that reads the clock itself would compute once
    // and then sit there being wrong.
    function formatAge(when: date, now: date): string {
        const seconds = Math.max(0, (now.getTime() - when.getTime()) / 1000);
        if (seconds < 60)
            return "now";

        const minutes = Math.floor(seconds / 60);
        if (minutes < 60)
            return `${minutes}m`;

        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return `${hours}h`;

        return `${Math.floor(hours / 24)}d`;
    }

    // Kept behind a LazyLoader so that turning the daemon off in Config means
    // the D-Bus name is never claimed at all, rather than claimed and ignored.
    LazyLoader {
        active: Config.actAsNotificationDaemon

        NotificationServer {
            bodySupported: true

            // Off, because the rows render plain text. Saying otherwise is
            // not harmless: a sender that believes the body is markup escapes
            // it before sending, so an ampersand in a message arrives as
            // "&amp;" and gets drawn that way. Chrome does exactly this.
            bodyMarkupSupported: false

            imageSupported: true

            // Chromium refuses to use a notification server that doesn't
            // advertise both "body" and "actions", and draws its own
            // notifications inside the browser window instead. It asks once,
            // when the browser starts, and never asks again — so a Chrome
            // that was running before this was true stays fallen back until
            // it is restarted.
            actionsSupported: true

            // Says there is somewhere for a notification to go after it
            // leaves the screen, which is what the panel is. Senders that
            // check are told the truth rather than left to assume.
            persistenceSupported: true

            keepOnReload: false

            onNotification: notification => root.push(notification)
        }
    }
}
