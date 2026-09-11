pragma ComponentBehavior: Bound

import qs.Common
import qs.Modules.Notifications

// The bell, morphing between its place in the closed bar — between the time
// and now playing — and the right end of the notification centre's heading.
// It is the same journey the art and title make into the media panel, for
// the same reason: the thing you aimed at should still be there when you
// arrive.
BellMark {
    id: root

    property real morph: 0

    property real collapsedX: 0
    property real collapsedY: 0
    property real expandedX: 0
    property real expandedY: 0

    // Position rides the overshoot with the shape; size does not, because a
    // mark briefly larger than its final size reads as a glitch.
    readonly property real sizeMorph: Math.max(0, Math.min(1, morph))

    x: collapsedX + (expandedX - collapsedX) * morph
    y: collapsedY + (expandedY - collapsedY) * morph

    iconSize: Config.barBellSize + (Config.panelBellSize - Config.barBellSize) * sizeMorph
}
