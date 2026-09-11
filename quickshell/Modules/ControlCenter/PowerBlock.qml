pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

// Battery and power profile in one card, because they are the same subject:
// how much you have left, and how fast you would like to spend it.
//
// On a bare row they still read as two things — a naked reading beside a
// filled pill. The card is the same shape, colour and radius as a ToggleTile,
// so it lands as another row of the same grid rather than a new kind of
// object, and the picker recesses into it.
//
// Battery also sat badly among the vitals. CPU, temperature and memory move
// by the second and are worth a live meter; a battery moves over hours, and
// what you actually want from it is a number and a sentence.
Item {
    id: root

    implicitHeight: Config.tileHeight

    Rectangle {
        anchors.fill: parent
        radius: Config.tileRadius
        color: Config.hairline
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Config.tilePadX
        anchors.rightMargin: Config.tilePadX
        spacing: 10

        // The mark says what the figure beside it says — a tenth of charge
        // per step — and wears a bolt only while charge is going in. Plugged
        // in and holding at a limit, or full, is the plain ladder: the line
        // beside it is what says so.
        TileIcon {
            Layout.alignment: Qt.AlignVCenter
            kind: Battery.charging ? "batteryCharging" : "battery"
            size: 15
            level: Battery.level
            color: Battery.low ? Config.urgent : Config.textDim
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: -4
            text: `${Math.round(Battery.level * 100)}%`
            color: Battery.low ? Config.urgent : Config.text
            font.family: Config.font
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            text: Battery.detail
            color: Config.textDim
            elide: Text.ElideRight
            font.family: Config.font
            font.pixelSize: 11
        }

        SegmentedControl {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Config.powerPickerWidth
            trackColor: Config.surface
            options: Power.profiles
            current: Power.profile
            onSelected: value => Power.set(value)
        }
    }
}
