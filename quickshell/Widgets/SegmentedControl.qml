pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

// One of a small set of mutually exclusive modes.
//
// A segmented control rather than a tile that cycles: with three options,
// cycling makes you tap twice to go backwards and never shows you what the
// other choices are. Here all of them are visible and any is one tap away.
//
// The thumb slides rather than jumping, so it is obvious which segment you
// came from — the same reason the notch's panels slide.
Item {
    id: root

    // [{ value, label }]
    required property var options
    required property int current

    // The groove behind the segments. Overridable because this sits inside a
    // card of its own colour in PowerBlock — hairline on hairline would be
    // invisible, so there it recesses to the surface instead.
    property color trackColor: Config.hairline

    signal selected(int value)

    implicitHeight: Config.segmentHeight

    readonly property int index: {
        for (let i = 0; i < root.options.length; i++) {
            if (root.options[i].value === root.current)
                return i;
        }
        return 0;
    }

    readonly property real segmentWidth: {
        const count = Math.max(1, root.options.length);
        return (width - Config.segmentInset * 2) / count;
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
    }

    Rectangle {
        x: Config.segmentInset + root.index * root.segmentWidth
        y: Config.segmentInset
        width: root.segmentWidth
        height: parent.height - Config.segmentInset * 2
        radius: height / 2
        color: Config.accent

        Behavior on x {
            NumberAnimation {
                duration: Config.segmentDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: Config.segmentInset

        Repeater {
            model: root.options

            Item {
                id: segment

                required property int index
                required property var modelData

                width: root.segmentWidth
                height: parent.height

                Text {
                    anchors.centerIn: parent
                    text: segment.modelData.label
                    // On the thumb when selected, on the groove otherwise —
                    // two different backdrops, so two different colours.
                    color: segment.index === root.index ? Config.onAccent : Config.textDim
                    font.family: Config.font
                    font.pixelSize: 11
                    font.weight: segment.index === root.index ? Font.DemiBold : Font.Medium

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.fadeDuration
                        }
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.selected(segment.modelData.value)
                }
            }
        }
    }
}
