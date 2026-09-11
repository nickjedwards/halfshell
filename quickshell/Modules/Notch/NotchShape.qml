import QtQuick
import QtQuick.Shapes

// The notch silhouette. A rectangle hanging from the top edge with rounded
// bottom corners, plus the two concave flares at the top that make it read
// as cut out of the bezel rather than pasted on top of it.
//
// Painted width is bodyWidth + cornerRadius * 2, because the flares live
// outside the body. Content should be laid out against bodyWidth.
Item {
    id: root

    property real bodyWidth: 190
    property real bodyHeight: 32
    property real bottomRadius: 18
    property real cornerRadius: 14
    property color color: "#000000"

    // Clamped so the path stays valid while the notch is mid-animation.
    readonly property real r: Math.max(0.01, Math.min(bottomRadius, bodyHeight, bodyWidth / 2))
    readonly property real c: Math.max(0.01, Math.min(cornerRadius, bodyHeight - r))

    implicitWidth: bodyWidth + c * 2
    implicitHeight: bodyHeight

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false

        ShapePath {
            fillColor: root.color
            strokeWidth: -1

            // Top-left flare: concave, curving from the screen edge down
            // into the left side of the body.
            startX: 0
            startY: 0
            PathArc {
                x: root.c
                y: root.c
                radiusX: root.c
                radiusY: root.c
                direction: PathArc.Clockwise
            }

            // Left side, then the rounded bottom-left corner.
            PathLine {
                x: root.c
                y: root.bodyHeight - root.r
            }
            PathArc {
                x: root.c + root.r
                y: root.bodyHeight
                radiusX: root.r
                radiusY: root.r
                direction: PathArc.Counterclockwise
            }

            // Bottom edge, then the rounded bottom-right corner.
            PathLine {
                x: root.implicitWidth - root.c - root.r
                y: root.bodyHeight
            }
            PathArc {
                x: root.implicitWidth - root.c
                y: root.bodyHeight - root.r
                radiusX: root.r
                radiusY: root.r
                direction: PathArc.Counterclockwise
            }

            // Right side, then the top-right flare back out to the edge.
            PathLine {
                x: root.implicitWidth - root.c
                y: root.c
            }
            PathArc {
                x: root.implicitWidth
                y: 0
                radiusX: root.c
                radiusY: root.c
                direction: PathArc.Clockwise
            }

            // Close along the top edge.
            PathLine {
                x: 0
                y: 0
            }
        }
    }
}
