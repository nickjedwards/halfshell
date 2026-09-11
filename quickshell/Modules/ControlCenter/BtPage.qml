pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import qs.Common
import qs.Services

// Paired bluetooth devices. Tapping one connects it, or disconnects it if it
// is already connected — unlike wifi, where disconnecting isn't on offer.
DevicePage {
    id: root

    title: "Bluetooth"
    toggleActive: Bt.enabled
    onToggled: Bt.toggle()

    ListView {
        anchors.fill: parent
        anchors.leftMargin: Config.ccPadX
        anchors.rightMargin: Config.ccPadX
        clip: true
        spacing: 2
        model: Bt.knownDevices
        boundsBehavior: Flickable.StopAtBounds

        delegate: DeviceRow {
            required property var modelData

            width: ListView.view.width
            title: modelData.name
            current: modelData.connected

            detail: {
                if (modelData.state === BluetoothDeviceState.Connecting)
                    return "Connecting…";
                if (modelData.state === BluetoothDeviceState.Disconnecting)
                    return "Disconnecting…";
                if (!modelData.connected)
                    return "Tap to connect";
                return modelData.batteryAvailable ? `Connected · ${Math.round(modelData.battery * 100)}%` : "Connected";
            }

            enabled: Bt.enabled
            onActivated: Bt.setConnected(modelData, !modelData.connected)
        }

        Text {
            anchors.centerIn: parent
            visible: Bt.knownDevices.length === 0
            text: Bt.enabled ? "No paired devices" : "Bluetooth is off"
            color: Config.textDim
            font.family: Config.font
            font.pixelSize: 11
        }
    }
}
