pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.Services

// The album art, which is one object in both states rather than a small copy
// in the bar cross-fading with a large one in the panel. Same reasoning as
// NotchClock: two copies swapping places reads as two pieces of art, and the
// thing you were looking at appears to vanish.
ClippingRectangle {
    id: root

    // 0 = sitting in the closed bar, 1 = sitting in the media panel. Driven
    // with an overshooting curve, so it can briefly exceed 1.
    property real morph: 0

    property real collapsedX: 0
    property real collapsedY: 0
    property real expandedX: 0
    property real expandedY: 0

    // Position rides the overshoot with the shape; size does not, because art
    // briefly larger than its final size reads as a glitch.
    readonly property real sizeMorph: Math.max(0, Math.min(1, morph))

    x: collapsedX + (expandedX - collapsedX) * morph
    y: collapsedY + (expandedY - collapsedY) * morph

    width: Config.barArtSize + (Config.panelArtSize - Config.barArtSize) * sizeMorph
    height: width
    radius: Config.barArtRadius + (Config.panelArtRadius - Config.barArtRadius) * sizeMorph
    color: Config.hairline

    Image {
        anchors.fill: parent
        source: Media.artUrl
        visible: Media.artUrl !== ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        // Requested at the larger of the two sizes, so growing into the panel
        // doesn't have to re-fetch and doesn't go soft on the way.
        sourceSize.width: Config.panelArtSize * 2
        sourceSize.height: Config.panelArtSize * 2
    }

    // Placeholder when there is no art: a quiet disc outline, scaled with the
    // frame it sits in.
    Rectangle {
        anchors.centerIn: parent
        visible: Media.artUrl === ""
        width: parent.width * 0.3
        height: width
        radius: width / 2
        color: "transparent"
        border.width: Math.max(1, parent.width * 0.018)
        border.color: Config.textDim
        opacity: 0.5
    }
}
