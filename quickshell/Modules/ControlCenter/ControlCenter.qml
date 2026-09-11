pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

// What opens when you hover the time.
//
// Split by the only distinction that matters here: things you read across the
// top, things you touch underneath. Interleaving them was what made the panel
// hard to scan — the eye had to re-learn the rules on every row.
//
// The header holds the time cluster on the left (clock over its day strip)
// and the vitals on the right. Battery is not among them: it moves over hours
// rather than seconds, so a live meter says nothing about it, and it reads
// far better beside the power profile — see PowerBlock.
//
// The header is outside the pager, so it stays put when a radio tile opens a
// device list. The clock in particular has to hold still — it is what the
// notch's own clock flies into.
Item {
    id: root

    clip: true

    // "main" | "wifi" | "bluetooth"
    property string page: "main"

    readonly property real clockX: clockGhost.x
    readonly property real clockY: clockGhost.y

    // The vitals only poll while they are on screen.
    Binding {
        target: SysMon
        property: "active"
        value: root.visible
    }

    onVisibleChanged: {
        if (visible) {
            // The backlights routinely change behind our back — laptop
            // brightness keys don't go through this shell — so re-read them
            // on the way in rather than polling for them.
            Brightness.refresh();
        } else {
            // Always come back to the main page. Reopening the notch onto a
            // wifi list you left there a day ago is not what anyone wants.
            root.page = "main";
        }
    }

    // ── Header: the time cluster ─────────────────────────────────────────

    // Not drawn. Keep its font in sync with NotchClock's expanded end.
    Text {
        id: clockGhost

        x: Config.ccPadX
        y: Config.ccPadX
        text: Time.time
        opacity: 0
        font.family: Config.font
        font.pixelSize: Config.clockLarge
        font.weight: Font.Light
    }

    CalendarStrip {
        id: strip

        anchors.left: parent.left
        anchors.leftMargin: Config.ccPadX
        anchors.right: vitals.left
        anchors.rightMargin: Config.ccGap
        anchors.top: clockGhost.bottom
        anchors.topMargin: Config.ccClockGap
        height: Config.calHeight
    }

    // ── Header: the vitals ───────────────────────────────────────────────
    // Bottomed on the day strip rather than given a height of its own, so
    // the header's two columns end on the same line — the clock and strip on
    // the left, the three meters on the right, one block. StatBar is fully
    // elastic: the reading sits on top, the mark underneath, and the track
    // takes whatever is left, so the bars simply get taller.
    Row {
        id: vitals

        anchors.right: parent.right
        anchors.rightMargin: Config.ccPadX
        anchors.top: parent.top
        anchors.topMargin: Config.ccPadX
        anchors.bottom: strip.bottom

        // Equal cells with each bar centred in its own, rather than bars plus
        // gaps — the latter overflows the block by a gap.
        spacing: 0

        readonly property real cell: Config.statsWidth / 3

        StatBar {
            width: vitals.cell
            height: vitals.height
            icon: "cpu"
            period: Config.cpuInterval
            value: SysMon.cpu
            readout: `${Math.round(SysMon.cpu * 100)}%`
        }

        StatBar {
            width: vitals.cell
            height: vitals.height
            icon: "temp"
            period: Config.tempInterval
            visible: SysMon.hasTemperature
            value: SysMon.temperatureFraction
            readout: `${Math.round(SysMon.temperature)}°`
            fill: SysMon.temperature >= Config.tempHot ? Config.urgent : Config.text
        }

        StatBar {
            width: vitals.cell
            height: vitals.height
            icon: "memory"
            period: Config.memInterval
            // The bar is the proportion; the reading is how much of it is
            // actually gone, which is the number you act on.
            value: SysMon.memory
            readout: SysMon.formatBytes(SysMon.memoryUsedKb)
        }

    }

    Rectangle {
        id: rule

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Config.ccPadX
        anchors.rightMargin: Config.ccPadX
        anchors.top: strip.bottom
        anchors.topMargin: Config.ccRuleGap
        height: 1
        color: Config.hairline
    }

    // ── Body: the controls ───────────────────────────────────────────────
    Item {
        id: pager

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: rule.bottom
        anchors.bottom: parent.bottom
        clip: true

        // The outgoing page moves a fraction of the width while the incoming
        // one comes the whole way, which reads as depth rather than as two
        // things swapping places.
        component Page: Item {
            required property string name
            readonly property bool current: root.page === name

            width: pager.width
            height: pager.height
            opacity: current ? 1 : 0
            visible: opacity > 0

            Behavior on x {
                NumberAnimation {
                    duration: Config.pageDuration
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.fadeDuration
                }
            }
        }

        Page {
            name: "main"
            x: current ? 0 : -width * 0.3

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Config.ccPadX
                anchors.rightMargin: Config.ccPadX
                anchors.bottomMargin: Config.ccPadX
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    spacing: Config.tileGap

                    ToggleTile {
                        Layout.fillWidth: true
                        kind: "wifi"
                        label: "Wi-Fi"
                        detail: Wifi.detail

                        // The bars follow the connected network's signal —
                        // the same number the Wi-Fi page shows as a percent,
                        // and 0 (no bars) when there is no network to measure.
                        level: Wifi.strength
                        active: Wifi.enabled && !Wifi.blocked
                        available: Wifi.available && !Wifi.blocked
                        onActivated: root.page = "wifi"
                    }

                    ToggleTile {
                        Layout.fillWidth: true
                        kind: "bluetooth"
                        label: "Bluetooth"
                        detail: Bt.detail
                        active: Bt.enabled
                        available: Bt.available
                        onActivated: root.page = "bluetooth"
                    }
                }

                // These still cycle rather than opening a page: there are only
                // ever a handful, and no on/off to put anywhere.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Config.tileGap
                    spacing: Config.tileGap

                    ToggleTile {
                        Layout.fillWidth: true
                        kind: "output"
                        label: "Output"
                        detail: Audio.sinkLabel
                        active: Audio.sink !== null
                        available: Audio.sinks.length > 1
                        onActivated: Audio.cycleSink()
                    }

                    ToggleTile {
                        Layout.fillWidth: true
                        kind: "input"
                        label: "Input"
                        detail: Audio.sourceLabel
                        active: Audio.source !== null
                        available: Audio.sources.length > 1
                        onActivated: Audio.cycleSource()
                    }
                }

                // Battery and power profile together: how much you have
                // left, and how fast you would like to spend it.
                PowerBlock {
                    Layout.fillWidth: true
                    Layout.topMargin: Config.tileGap
                    visible: Battery.available
                }

                Item {
                    Layout.fillHeight: true
                }

                SliderRow {
                    Layout.fillWidth: true
                    visible: Brightness.display.available
                    kind: "brightness"
                    label: "Brightness"
                    value: Brightness.display.value

                    // The sun grows with the backlight, the way the speaker
                    // below counts its waves off the volume.
                    level: Brightness.display.value
                    onMoved: v => Brightness.display.set(v)
                }

                // The keyboard's own light, on machines that have one. It
                // goes all the way off, which the screen never does, and the
                // mark says so: the keys drawn in outline when it is dark.
                SliderRow {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    visible: Brightness.keyboard.available
                    kind: "keyboard"
                    label: "Keyboard"
                    value: Brightness.keyboard.value
                    level: Brightness.keyboard.value
                    onMoved: v => Brightness.keyboard.set(v)
                }

                SliderRow {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    visible: Audio.sinkReady
                    kind: "output"
                    label: Audio.muted ? "Muted" : "Volume"
                    value: Audio.volume
                    subdued: Audio.muted

                    // The speaker counts its waves off the volume, and shows
                    // none at all when muted — the row already says "Muted",
                    // and a mark still radiating while it does would be
                    // arguing with it.
                    level: Audio.muted ? 0 : Audio.volume
                    onMoved: v => Audio.setVolume(v)
                }
            }
        }

        Page {
            name: "wifi"
            x: current ? 0 : width

            WifiPage {
                anchors.fill: parent
                onBack: root.page = "main"
            }
        }

        Page {
            name: "bluetooth"
            x: current ? 0 : width

            BtPage {
                anchors.fill: parent
                onBack: root.page = "main"
            }
        }
    }
}
