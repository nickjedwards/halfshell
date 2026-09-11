pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

// The track title, morphing between the closed bar and the media panel for
// the same reason the art and the clock do.
Text {
    id: root

    property real morph: 0

    property real collapsedX: 0
    property real collapsedY: 0
    property real expandedX: 0
    property real expandedY: 0

    // The width it elides against at each end. Not the width of the glyphs —
    // the text is left-aligned, so both ends start in the same place and this
    // only decides where it truncates.
    //
    // Both start at zero rather than at some stand-in width: each end is
    // measured by the strip or the panel it belongs to, and until one of them
    // has been built there is no honest number to use. The art falls back
    // to the same nothing for the same reason.
    property real collapsedWidth: 0
    property real expandedWidth: 0

    readonly property real sizeMorph: Math.max(0, Math.min(1, morph))

    x: collapsedX + (expandedX - collapsedX) * morph
    y: collapsedY + (expandedY - collapsedY) * morph
    width: collapsedWidth + (expandedWidth - collapsedWidth) * sizeMorph

    text: Media.title
    color: Config.text
    elide: Text.ElideRight
    font.family: Config.font
    font.pixelSize: Config.barTitleSize + (Config.panelTitleSize - Config.barTitleSize) * sizeMorph
    // Medium to DemiBold, snapped to whole weights so the animation asks the
    // font cache for two faces rather than a new one every frame.
    font.weight: Math.round((Font.Medium + (Font.DemiBold - Font.Medium) * sizeMorph) / 100) * 100
}
