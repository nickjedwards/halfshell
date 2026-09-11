pragma Singleton

import Quickshell
import Quickshell.Bluetooth

// Bluetooth reduced to what the control centre shows.
//
// Named Bt rather than Bluetooth on purpose: a singleton called Bluetooth in
// qs.services would collide with the Quickshell.Bluetooth singleton this
// wraps, and the collision is silent enough to be worth avoiding entirely.
//
// As with Wifi, everything is a binding — the adapter appears a second or
// two after startup rather than being there at construction.
Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    readonly property bool available: root.adapter !== null
    readonly property bool enabled: root.available && root.adapter.enabled

    // Plain array rather than a typed list: this is derived per change, not
    // a model anything binds a delegate to.
    readonly property var connectedDevices: {
        const out = [];
        const devices = Bluetooth.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].connected)
                out.push(devices[i]);
        }
        return out;
    }

    readonly property int connectedCount: root.connectedDevices.length

    // One device by name, several by count. A list of names doesn't fit in a
    // tile and isn't what you want at a glance anyway.
    readonly property string detail: {
        if (!root.available)
            return "No adapter";
        if (!root.enabled)
            return "Off";
        if (root.connectedCount === 0)
            return "On";
        if (root.connectedCount === 1)
            return root.connectedDevices[0].name;
        return `${root.connectedCount} connected`;
    }

    // Paired devices only: everything else in range is noise you can't do
    // anything useful with from here. Connected first, then by name.
    readonly property var knownDevices: {
        const out = [];
        const devices = Bluetooth.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].paired)
                out.push(devices[i]);
        }
        out.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return a.name.localeCompare(b.name);
        });
        return out;
    }

    // `connected` is writable, so there is no connect/disconnect pair to
    // call — assigning it is the operation.
    function setConnected(device: BluetoothDevice, on: bool): void {
        if (device)
            device.connected = on;
    }

    function toggle(): void {
        if (root.adapter)
            root.adapter.enabled = !root.adapter.enabled;
    }
}
