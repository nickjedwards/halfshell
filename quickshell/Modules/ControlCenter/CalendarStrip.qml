pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

// The day strip under the clock.
//
// The month sits pinned to the left, knocked back and set off by a gap so it
// heads the row rather than being the first thing in it, then days run past
// it as weekday-over-date columns with today picked out in blue. Today is also the
// only column that spells its weekday out — "THU" rather than "T" — which is
// what stops a row of single letters reading as a wall of Ts and Ss.
//
// A thirty-day window slides under a fixed viewport: today is pinned to the
// middle and the dates move, rather than the strip reflowing. Only six or so
// columns are ever visible, but the ones running off both edges are what make
// it read as a continuing calendar instead of a row that starts and stops.
//
// Dates only. Nothing here reads a calendar backend; the whole strip derives
// from Time.now, so it costs one binding re-evaluation a minute.
Item {
    id: root

    // Even-sized window, so "centred" is fifteen days back and fourteen
    // forward. The extra day goes behind rather than ahead.
    readonly property int windowDays: 30
    readonly property int centerIndex: Math.floor(windowDays / 2)

    // How far the window has been dragged away from today, in pixels. Reset
    // whenever the panel hides, so opening the notch always lands on today
    // rather than wherever it was last left.
    property real scroll: 0

    onVisibleChanged: {
        if (!visible)
            scroll = 0;
    }

    Behavior on scroll {
        NumberAnimation {
            duration: Config.calScrollDuration
            easing.type: Easing.OutCubic
        }
    }

    readonly property date windowStart: {
        const d = new Date(Time.now);
        d.setHours(0, 0, 0, 0);
        d.setDate(d.getDate() - root.centerIndex);
        return d;
    }

    // Saturday and Sunday. Asked by index rather than by date so a cell can
    // ask about its neighbours without building three Date objects to find
    // out whether it is at the end of a run — and so an index off either end
    // of the window answers false rather than throwing.
    function isWeekend(i: int): bool {
        if (i < 0 || i >= root.windowDays)
            return false;

        const day = root.dateAt(i).getDay();
        return day === 0 || day === 6;
    }

    function dateAt(i: int): date {
        const d = new Date(root.windowStart);
        d.setDate(d.getDate() + i);
        return d;
    }

    // Measured rather than guessed, so the month's baseline lands exactly on
    // the dates' baseline at any font size.
    FontMetrics {
        id: weekdayFm
        font.family: Config.font
        font.pixelSize: Config.calWeekdaySize
    }

    FontMetrics {
        id: dateFm
        font.family: Config.font
        font.pixelSize: Config.calDateSize
    }

    FontMetrics {
        id: monthFm
        font.family: Config.font
        font.pixelSize: Config.calMonthSize
    }

    // Both rows are pushed down by the weekend band's padding, and the block
    // grows by it again underneath, so the band — which fills the block —
    // has air above the weekdays and below the dates.
    readonly property real weekdaysY: Config.calWeekendPadY
    readonly property real datesY: root.weekdaysY + weekdayFm.height + Config.calRowGap

    Item {
        id: block

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: root.datesY + dateFm.height + Config.calWeekendPadY

        Text {
            id: month

            // Sits on the same baseline as the dates, not the same top edge.
            y: root.datesY + dateFm.ascent - monthFm.ascent
            width: Config.calMonthWidth

            // Names the month you are actually looking at, not today's —
            // scrolled back into August, "Sep" over a row of August dates
            // would just be wrong.
            text: Qt.formatDateTime(root.dateAt(strip.visibleCenterIndex), "MMM")

            // Knocked back so the clock above leads. This is a label for the
            // row beside it, not a second headline competing with the time.
            color: Config.textDim
            font.family: Config.font
            font.pixelSize: Config.calMonthSize
            font.weight: Font.Medium
        }

        Item {
            id: strip

            anchors.left: month.right
            anchors.leftMargin: Config.calGap
            anchors.right: parent.right
            height: parent.height
            clip: true

            // Shifts the whole window left so today's column lands on the
            // centre line. Everything before it sits at a negative x and is
            // clipped away.
            readonly property real base: width / 2 - (root.centerIndex + 0.5) * Config.calCellWidth

            // Clamped here as well as in the wheel handler, so a stored scroll
            // can't strand the window off-viewport if the rail is ever
            // resized under it.
            readonly property real offset: base - clampScroll(root.scroll)

            // Scrolled all the way back puts the first day flush left;
            // all the way forward puts the last one flush right. There is
            // nothing beyond the window, so it stops rather than rubber-bands.
            readonly property real minScroll: base
            readonly property real maxScroll: base + root.windowDays * Config.calCellWidth - width

            function clampScroll(v: real): real {
                return Math.max(minScroll, Math.min(maxScroll, v));
            }

            // Whichever day is sitting on the centre line — what the month
            // label names.
            readonly property int visibleCenterIndex: {
                const i = Math.round((width / 2 - offset) / Config.calCellWidth - 0.5);
                return Math.max(0, Math.min(root.windowDays - 1, i));
            }

            Repeater {
                model: root.windowDays

                Item {
                    id: cell

                    required property int index

                    readonly property date date: root.dateAt(cell.index)

                    // The window is built around today, so this is positional
                    // rather than a date comparison.
                    readonly property bool isToday: cell.index === root.centerIndex

                    readonly property bool isWeekend: root.isWeekend(cell.index)

                    // Saturday and Sunday sit next to each other, so a band
                    // per column would pinch where two rounded corners meet.
                    // Each cell rounds only the ends of the run it is in,
                    // which makes a weekend one block rather than two marks —
                    // and still rounds both ends of a lone Saturday or Sunday
                    // stranded at the edge of the window.
                    readonly property bool opensRun: cell.isWeekend && !root.isWeekend(cell.index - 1)
                    readonly property bool closesRun: cell.isWeekend && !root.isWeekend(cell.index + 1)

                    x: strip.offset + cell.index * Config.calCellWidth
                    width: Config.calCellWidth
                    height: strip.height

                    // Declared first so it sits behind the day it is behind.
                    Rectangle {
                        anchors.fill: parent
                        visible: cell.isWeekend
                        color: Config.raise(Config.calWeekendWash)

                        topLeftRadius: cell.opensRun ? Config.calWeekendRadius : 0
                        bottomLeftRadius: cell.opensRun ? Config.calWeekendRadius : 0
                        topRightRadius: cell.closesRun ? Config.calWeekendRadius : 0
                        bottomRightRadius: cell.closesRun ? Config.calWeekendRadius : 0
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.weekdaysY

                        text: {
                            const name = Qt.formatDateTime(cell.date, "ddd").toUpperCase();
                            return cell.isToday ? name : name.charAt(0);
                        }

                        color: Config.text
                        // Every other day is knocked well back — the strip is
                        // there to place today, not to be read across.
                        opacity: cell.isToday ? 0.92 : 0.42
                        font.family: Config.font
                        font.pixelSize: Config.calWeekdaySize
                        font.weight: cell.isToday ? Font.DemiBold : Font.Medium
                        font.letterSpacing: 0.6
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.datesY

                        text: cell.date.getDate()
                        color: cell.isToday ? Config.accent : Config.textDim
                        font.family: Config.font
                        font.pixelSize: Config.calDateSize
                        font.weight: cell.isToday ? Font.DemiBold : Font.Medium
                    }
                }
            }

            // Dissolves the window into the rail at both edges, since it now
            // runs off in both directions. Config.fade is the surface's own
            // colour at decreasing alpha — an alpha ramp towards
            // Qt.transparent is a ramp towards transparent *white*, which
            // would wash the dates out before it hid them.
            //
            // Eased rather than linear, so the ramp takes the outermost
            // column most of the way out while leaving its neighbour alone
            // instead of making both look dirty.
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Config.calFade

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: Config.fade(1)
                    }

                    GradientStop {
                        position: 0.5
                        color: Config.fade(0.38)
                    }

                    GradientStop {
                        position: 1
                        color: Config.fade(0)
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Config.calFade

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: Config.fade(0)
                    }

                    GradientStop {
                        position: 0.5
                        color: Config.fade(0.38)
                    }

                    GradientStop {
                        position: 1
                        color: Config.fade(1)
                    }
                }
            }
        }
    }

    // Scrolls anywhere on the band, month label included, rather than only
    // over the days — the whole row reads as one object. NoButton so it
    // takes wheel events without swallowing the notch's clicks or the
    // right-click that pins it open.
    //
    // Horizontal deltas come from touchpad swipes, vertical from a wheel;
    // either scrolls the window, because there is nothing else a scroll
    // could mean here.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        onWheel: wheel => {
            const delta = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y;
            root.scroll = strip.clampScroll(root.scroll - delta * Config.calScrollStep);
        }
    }
}
