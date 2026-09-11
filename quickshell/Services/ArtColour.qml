pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// The colour of the album art, for the spectrum around it.
//
// ColorQuantizer only reads local files, and players hand over art as a URL —
// Spotify's is https. So a remote cover is fetched once per track into the
// cache directory and quantised from there; a file:// one is read where it
// is. Only the current track's file is kept.
//
// Of the eight colours the quantiser finds, the most vivid is taken rather
// than the most common — the most common colour of most covers is a
// background, and a dark brown halo says nothing. It is then pushed light
// enough to read on the notch (or dark enough, on a light theme). A cover
// with no real colour in it is drawn in the text colour, like the bars were.
Singleton {
    id: root

    readonly property string url: Media.artUrl
    // $XDG_CACHE_HOME/halfshell/art, by shell.qml's CacheDir pragma: the cover
    // can always be fetched again, which is what the cache is for. Its own
    // subdirectory, because every fetch empties it first.
    readonly property string cacheDir: Quickshell.cachePath("art")

    readonly property color colour: root.pick(quantizer.colors)

    property string fetchedFor: ""

    onUrlChanged: root.load()
    Component.onCompleted: root.load()

    function load(): void {
        // One fetch at a time. A track change mid-download is picked up when
        // it finishes, by noticing the URL has moved on.
        if (fetch.running)
            return;

        if (root.url === "" || root.url.startsWith("file://")) {
            quantizer.source = root.url;
            return;
        }

        const name = Qt.md5(root.url);
        root.fetchedFor = root.url;
        fetch.target = "file://" + root.cacheDir + "/" + name;
        fetch.command = ["sh", "-c", 'mkdir -p "$1" && rm -f "$1"/* && curl -sfL --max-time 10 -o "$1/$2" "$3"', "sh", root.cacheDir, name, root.url];
        fetch.running = true;
    }

    function pick(colors: var): color {
        let best = null;
        let bestScore = -1;

        for (let i = 0; i < colors.length; i++) {
            const c = colors[i];
            const l = c.hslLightness;
            if (l < 0.06 || l > 0.96)
                continue;

            // Saturated, and not at either end of lightness, where even a
            // saturated colour reads as black or white.
            const score = c.hslSaturation * (1 - Math.abs(l - 0.5));
            if (score > bestScore) {
                best = c;
                bestScore = score;
            }
        }

        if (!best || best.hslSaturation < 0.15)
            return Config.text;

        const light = Config.luminance(Config.surface) > 0.5;
        const l = light ? Math.min(best.hslLightness, 0.42) : Math.max(best.hslLightness, 0.64);
        return Qt.hsla(best.hslHue, Math.max(best.hslSaturation, 0.5), l, 1);
    }

    Process {
        id: fetch

        property string target: ""

        onExited: (code, status) => {
            if (root.fetchedFor !== root.url)
                root.load();
            else if (code === 0)
                quantizer.source = fetch.target;
        }
    }

    ColorQuantizer {
        id: quantizer

        depth: 3
        rescaleSize: 64
    }
}
