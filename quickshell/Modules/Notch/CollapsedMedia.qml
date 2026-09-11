import QtQuick
import QtQuick.Layouts
import qs.Common

// What the notch shows when it is closed but something is playing: the art,
// with its spectrum around it, and nothing else.
//
// The title used to be here too, capped at ten characters. It is gone from
// the closed bar entirely — the art already says what is playing at a
// glance, and the title was the one thing in the bar whose width changed
// with every track, which is what moved the whole centred notch sideways on
// a song change. It still exists in the media panel, and still arrives there
// as one object growing into place; it simply grows out of nothing beside
// the art rather than out of a truncated copy of itself.
//
// The art is not drawn here. It is a single object that morphs into the
// media panel (see NotchArt, and NotchSpectrum riding on it), so this holds an
// invisible stand-in of exactly its size and reports where the layout put it.
RowLayout {
    id: root

    readonly property real artX: art.x
    readonly property real artY: art.y

    // Where the title starts its journey into the panel: zero wide, at the
    // art's right edge, level with its middle. It is invisible at this end,
    // so what matters is not the point itself but that the flight starts
    // from the art — the title reads as coming out of the thing it names
    // rather than out of the clock or the middle of the bar.
    readonly property real titleX: art.x + art.width
    readonly property real titleY: art.y + (art.height - Config.barTitleSize) / 2
    readonly property real titleWidth: 0

    // What the strip actually occupies — a constant, since nothing in it
    // depends on the track.
    readonly property real contentWidth: art.width

    spacing: Config.barSpacing

    Item {
        id: art

        Layout.preferredWidth: Config.barArtSize
        Layout.preferredHeight: Config.barArtSize
        Layout.alignment: Qt.AlignVCenter
    }

    // Takes whatever slack the box has, so the art stays packed against the
    // left rather than floating in it.
    Item {
        Layout.fillWidth: true
    }
}
