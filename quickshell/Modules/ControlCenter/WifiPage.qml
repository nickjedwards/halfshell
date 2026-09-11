pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Networking
import qs.Common
import qs.Services

// Visible networks. Scanning runs only while this page is up.
DevicePage {
    id: root

    title: "Wi-Fi"
    toggleActive: Wifi.enabled
    onToggled: Wifi.toggle()

    // Bound rather than set in a handler, so it switches off on the way out
    // however the page is left — including the notch simply closing.
    Binding {
        target: Wifi
        property: "scanning"
        value: root.visible
    }

    ListView {
        anchors.fill: parent
        anchors.leftMargin: Config.ccPadX
        anchors.rightMargin: Config.ccPadX
        clip: true
        spacing: 2
        model: Wifi.networks
        boundsBehavior: Flickable.StopAtBounds

        delegate: DeviceRow {
            required property var modelData

            width: ListView.view.width
            title: modelData.name !== "" ? modelData.name : "Hidden network"
            current: modelData.connected

            // Signal strength is 0..1 from the backend.
            detail: {
                const strength = `${Math.round(modelData.signalStrength * 100)}%`;
                if (modelData.connected)
                    return `Connected · ${strength}`;
                if (modelData.known)
                    return `Saved · ${strength}`;
                if (Wifi.isOpen(modelData))
                    return `Open · ${strength}`;
                return `Needs a password · ${strength}`;
            }

            enabled: Wifi.canJoin(modelData)
            // The one you're on stays bright; the ones you can't join fade.
            subdued: !modelData.connected && !Wifi.canJoin(modelData)
            onActivated: Wifi.join(modelData)
        }

        Text {
            anchors.centerIn: parent
            visible: Wifi.networks.length === 0
            text: Wifi.enabled ? "Looking…" : "Wi-Fi is off"
            color: Config.textDim
            font.family: Config.font
            font.pixelSize: 11
        }
    }
}
