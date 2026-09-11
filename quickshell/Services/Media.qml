pragma Singleton

import Quickshell
import Quickshell.Services.Mpris

// One MPRIS player selection shared by every notch on every monitor.
// Nothing polls here — MPRIS is D-Bus signal driven. Position is the one
// exception, and it is only ticked by whoever is actually displaying it
// (see Modules/Media/MediaPanel.qml).
Singleton {
    id: root

    // An explicit pick, by bus name, for as long as that player is around.
    // Bus name rather than uniqueId because it survives the player being
    // restarted — relaunching Spotify gets you Spotify back, where a
    // per-session id would silently fall through to whatever else is open.
    property string pinned: ""

    readonly property int playerCount: Mpris.players.values.length
    readonly property bool canCyclePlayer: root.playerCount > 1

    // 1-based position of the active player, so the panel can say which of
    // how many you are looking at without you having to hover to find out.
    readonly property int playerIndex: {
        const players = Mpris.players.values;
        const current = root.active;
        if (!current)
            return 0;
        for (let i = 0; i < players.length; i++) {
            if (players[i].dbusName === current.dbusName)
                return i + 1;
        }
        return 0;
    }

    readonly property MprisPlayer active: {
        const players = Mpris.players.values;
        if (players.length === 0)
            return null;

        // A pick beats the automatic choice, which is the whole point of
        // making it: otherwise whatever started playing last would win back
        // the panel the moment you looked away.
        if (root.pinned !== "") {
            for (let i = 0; i < players.length; i++) {
                if (players[i].dbusName === root.pinned)
                    return players[i];
            }
        }

        // Read every playbackState so this binding re-evaluates when any
        // player starts or stops, not just the first one we look at.
        //
        // Paused beats stopped, which matters more than it sounds: a browser
        // sitting on a page with a dead media element is a stopped player
        // with no metadata, and it would otherwise win the panel from a
        // paused music player that has a track in it.
        let playing = null;
        let paused = null;
        for (let i = 0; i < players.length; i++) {
            const state = players[i].playbackState;
            if (state === MprisPlaybackState.Playing && playing === null)
                playing = players[i];
            else if (state === MprisPlaybackState.Paused && paused === null)
                paused = players[i];
        }

        return playing ?? paused ?? players[0];
    }

    readonly property bool hasPlayer: active !== null
    readonly property bool isPlaying: hasPlayer && active.playbackState === MprisPlaybackState.Playing

    readonly property string title: hasPlayer ? (active.trackTitle || "Unknown track") : ""
    readonly property string artist: hasPlayer ? (active.trackArtist || "Unknown artist") : ""
    readonly property string album: hasPlayer ? active.trackAlbum : ""
    readonly property string artUrl: hasPlayer ? active.trackArtUrl : ""
    readonly property string identity: hasPlayer ? active.identity : ""

    readonly property real position: hasPlayer ? active.position : 0
    readonly property real length: hasPlayer ? active.length : 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0

    // Steps to the next player and pins it. Wraps, so two players is a
    // toggle and there is no dead end at the end of the list.
    function cyclePlayer(): void {
        const players = Mpris.players.values;
        if (players.length < 2)
            return;

        const current = root.active;
        let index = -1;
        for (let i = 0; i < players.length; i++) {
            if (current && players[i].dbusName === current.dbusName) {
                index = i;
                break;
            }
        }

        root.pinned = players[(index + 1) % players.length].dbusName;
    }

    function playPause(): void {
        if (root.active && root.active.canTogglePlaying)
            root.active.togglePlaying();
    }

    function next(): void {
        if (root.active && root.active.canGoNext)
            root.active.next();
    }

    function previous(): void {
        if (root.active && root.active.canGoPrevious)
            root.active.previous();
    }

    function seek(fraction: real): void {
        if (root.active && root.active.canSeek && root.active.positionSupported)
            root.active.position = fraction * root.active.length;
    }

    function formatTime(seconds: real): string {
        if (!isFinite(seconds) || seconds <= 0)
            return "0:00";
        const total = Math.floor(seconds);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return `${m}:${s.toString().padStart(2, "0")}`;
    }
}
