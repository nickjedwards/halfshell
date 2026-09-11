pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

// The spectrum around the album art: the art's own outline pushed out by
// every band of whatever is playing, all the way round, as one smooth shape
// filled in the art's colour.
//
// Bands are laid clockwise from the bottom in cava's stereo order — the left
// channel up the left side from treble to bass, the right channel down the
// right side from bass to treble — so the bass sits at the top, the treble
// meets itself at the bottom, and the two sides differ as the channels do.
// Each band's distance is measured out from the art's rounded-square edge,
// not from a circle, so the shape follows the art; silence leaves a thin
// even halo.
//
// Positioned over NotchArt by Notch and drawn behind it, and sized from it,
// so it makes the art's journey between the bar and the panel with it. It
// can't be a child of the art: that is a ClippingRectangle, which would cut
// off everything outside its own edge, which is all of this.
Item {
    id: root

    property real artRadius: 0

    // 0 in the bar, 1 in the panel; the art's own clamped morph.
    property real sizeMorph: 0

    readonly property bool live: root.visible && Media.isPlaying

    // How far out the shape sits at silence, and how much further a band at
    // full level pushes it — both scaled with the art.
    readonly property real gap: Config.barSpectrumGap + (Config.panelSpectrumGap - Config.barSpectrumGap) * root.sizeMorph
    readonly property real reach: Config.barSpectrumReach + (Config.panelSpectrumReach - Config.barSpectrumReach) * root.sizeMorph

    // How strongly the shape is filled, quieter in the bar. Applied in the
    // paint rather than as the canvas's opacity, which is the fade on play
    // and pause: a Behavior there would chase this every frame of the morph
    // and trail behind it.
    readonly property real strength: Config.barSpectrumOpacity + (Config.panelSpectrumOpacity - Config.barSpectrumOpacity) * root.sizeMorph

    onStrengthChanged: canvas.requestPaint()

    property color colour: ArtColour.colour

    Behavior on colour {
        ColorAnimation {
            duration: Config.spectrumColourDuration
        }
    }

    onColourChanged: canvas.requestPaint()

    Binding {
        target: Cava
        property: "active"
        value: root.live
    }

    // Distance from the centre of a rounded square to its edge along a ray,
    // for a ray in the first quadrant (c = |cos|, s = |sin|). The square is
    // `h` from centre to side with corners of radius `r`; `a` is h - r, the
    // half-size of the square the corner circles are centred on.
    function edge(c: real, s: real, h: real, a: real, r: real): real {
        if (c < 1e-6 || s < 1e-6)
            return h;

        // A flat side, if the ray meets it before the corner starts.
        const side = h / c;
        if (side * s <= a)
            return side;

        const top = h / s;
        if (top * c <= a)
            return top;

        // Otherwise the corner circle centred on (a, a).
        const k = a * (c + s);
        return k + Math.sqrt(Math.max(0, k * k - 2 * a * a + r * r));
    }

    Canvas {
        id: canvas

        // Room for the furthest a band can reach, plus a pixel or two so the
        // antialiased edge isn't clipped.
        readonly property real margin: root.gap + root.reach + 2

        x: -margin
        y: -margin
        width: root.width + 2 * margin
        height: root.height + 2 * margin

        // Fades with the music rather than snapping off on pause.
        opacity: root.live ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.fadeDuration
            }
        }

        onWidthChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            // Without cava — or before its first frame — draw the resting
            // halo from silence rather than nothing.
            const levels = Cava.levels.length > 2 ? Cava.levels : [0, 0, 0, 0, 0, 0, 0, 0];
            const n = levels.length;

            const cx = width / 2;
            const cy = height / 2;
            const h = root.width / 2;
            const r = Math.min(root.artRadius, h);
            const a = h - r;

            const pts = [];
            for (let i = 0; i < n; i++) {
                // Clockwise from the bottom: (−sin, cos) is straight down at
                // 0 and straight up at π, on a y-down canvas.
                const phi = (i + 0.5) / n * 2 * Math.PI;
                const dx = -Math.sin(phi);
                const dy = Math.cos(phi);
                const d = root.edge(Math.abs(dx), Math.abs(dy), h, a, r) + root.gap + Math.min(1, levels[i]) * root.reach;
                pts.push([cx + dx * d, cy + dy * d]);
            }

            // A smooth closed curve: through the midpoints between bands,
            // with each band's own point as the control, so the shape swells
            // towards a loud band without a corner at it.
            ctx.beginPath();
            const last = pts[n - 1];
            ctx.moveTo((last[0] + pts[0][0]) / 2, (last[1] + pts[0][1]) / 2);
            for (let i = 0; i < n; i++) {
                const p = pts[i];
                const q = pts[(i + 1) % n];
                ctx.quadraticCurveTo(p[0], p[1], (p[0] + q[0]) / 2, (p[1] + q[1]) / 2);
            }
            ctx.closePath();

            ctx.globalAlpha = root.strength;
            ctx.fillStyle = root.colour;
            ctx.fill();
        }
    }

    // One repaint per cava frame, and none at all while hidden.
    Connections {
        target: Cava
        enabled: canvas.visible

        function onLevelsChanged(): void {
            canvas.requestPaint();
        }
    }
}
