import QtQuick
import qs.Common
import qs.Services

// The clock that lives in the notch at all times.
//
// There is only ever one of these. Cross-fading a small clock in the pill
// with a large one in the panel reads as two clocks swapping places, so this
// single Text interpolates its own position and size between the two
// instead: opening the notch grows the clock you were already looking at.
//
// The caller owns both endpoints, because only the notch knows where the
// panel ended up. See Notch.qml.
Text {
    id: root

    // 0 = sitting in the collapsed pill, 1 = sitting in the panel's status
    // rail. Driven with an overshooting curve, so it can exceed 1 in flight.
    property real morph: 0

    // Top-left corner of the text in each state, in the parent's coordinates.
    property real collapsedX: 0
    property real collapsedY: 0
    property real expandedX: 0
    property real expandedY: 0

    // Position rides the overshoot so it springs with the shape around it.
    // Size does not: a font briefly larger than its final size reads as a
    // glitch rather than as momentum.
    readonly property real sizeMorph: Math.max(0, Math.min(1, morph))

    x: collapsedX + (expandedX - collapsedX) * morph
    y: collapsedY + (expandedY - collapsedY) * morph

    text: Time.time
    color: Config.text

    font.family: Config.font
    font.pixelSize: Config.clockSmall + (Config.clockLarge - Config.clockSmall) * sizeMorph

    // Medium down to Light — small text needs the weight, large text does
    // not. Snapped to whole font weights so the animation cycles through
    // three faces instead of asking the font cache for a new one per frame.
    font.weight: Math.round((Font.Medium + (Font.Light - Font.Medium) * sizeMorph) / 100) * 100
}
