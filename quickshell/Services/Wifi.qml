pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// WiFi reduced to the handful of facts the control centre shows.
//
// Quickshell.Networking hands back a list of devices; picking the wifi one
// out of it and then finding the network that device is actually on is
// derivation, and derivation belongs here rather than in the view.
//
// Everything is a binding, deliberately. The backend populates a second or
// two after startup — read any of this once at construction and you get an
// empty answer that never corrects itself.
Singleton {
    id: root

    readonly property WifiDevice device: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        }
        return null;
    }

    // The network the device is currently on, if any.
    readonly property WifiNetwork network: {
        if (!root.device)
            return null;
        const networks = root.device.networks.values;
        for (let i = 0; i < networks.length; i++) {
            if (networks[i].connected)
                return networks[i];
        }
        return null;
    }

    readonly property bool available: root.device !== null
    readonly property bool enabled: Networking.wifiEnabled
    readonly property bool connected: root.network !== null
    readonly property string ssid: root.network ? root.network.name : ""

    // 0..1, as the backend reports it.
    readonly property real strength: root.network ? root.network.signalStrength : 0

    // Full is the only connectivity that means "this actually works" —
    // Portal and Limited both look connected from the device's point of view
    // and aren't.
    readonly property bool online: Networking.connectivity === NetworkConnectivity.Full

    // Blocked in hardware, by a switch or rfkill. Toggling won't help.
    readonly property bool blocked: root.available && !Networking.wifiHardwareEnabled

    readonly property string detail: {
        if (!root.available)
            return "No adapter";
        if (root.blocked)
            return "Blocked";
        if (!root.enabled)
            return "Off";
        if (!root.connected)
            return "Not connected";
        return root.online ? root.ssid : `${root.ssid} · no internet`;
    }

    // Everything the adapter can see, current network first and then
    // strongest first. Sorted on a copy — the model's own array is not ours
    // to reorder.
    readonly property var networks: {
        if (!root.device)
            return [];
        const out = root.device.networks.values.slice();
        out.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
        return out;
    }

    // Scanning costs airtime, so it only runs while someone is looking at
    // the list. Driven through a Binding because the device arrives late and
    // may be replaced.
    property bool scanning: false

    Binding {
        target: root.device
        property: "scannerEnabled"
        value: root.scanning
        when: root.device !== null
    }

    function isOpen(network: WifiNetwork): bool {
        return network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe;
    }

    // Known networks have stored secrets to reuse and open ones need none.
    // Anything else wants a password, and a notch has nowhere to ask for one
    // — so the list shows those but won't pretend it can join them.
    function canJoin(network: WifiNetwork): bool {
        if (!network || network.connected)
            return false;
        return network.known || root.isOpen(network);
    }

    function join(network: WifiNetwork): void {
        if (!root.canJoin(network))
            return;
        if (network.known && network.nmSettings.length > 0)
            network.connect(network.nmSettings[0]);
        else
            network.connectWithPsk("");
    }

    function toggle(): void {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }
}
