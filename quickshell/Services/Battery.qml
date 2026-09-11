pragma Singleton

import Quickshell
import Quickshell.Services.UPower

// The battery, reduced to a percentage and one line about what it is doing.
//
// That line is state-driven rather than a bare on-AC test. This machine sits
// in PendingCharge — plugged in and holding at a charge limit — which a naive
// "charging unless on battery" reading calls Charging, and it is not.
//
// timeToEmpty and timeToFull are only meaningful in their own states: while
// on AC the daemon still reports a timeToEmpty, and it is nonsense.
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available: device !== null && device.ready && device.isLaptopBattery

    readonly property real level: root.available ? root.device.percentage : 0
    readonly property int state: root.available ? root.device.state : 0

    readonly property bool discharging: root.state === UPowerDeviceState.Discharging
    readonly property bool low: root.discharging && root.level < 0.15

    readonly property string detail: {
        if (!root.available)
            return "";

        switch (root.state) {
        case UPowerDeviceState.Charging:
            return root.device.timeToFull > 0 ? `${root.formatDuration(root.device.timeToFull)} to full` : "Charging";
        case UPowerDeviceState.Discharging:
            return root.device.timeToEmpty > 0 ? `${root.formatDuration(root.device.timeToEmpty)} left` : "On battery";
        case UPowerDeviceState.FullyCharged:
            return "Full";
        default:
            // PendingCharge and PendingDischarge both mean plugged in and
            // holding, which is what a charge limit looks like.
            return UPower.onBattery ? "On battery" : "Plugged in";
        }
    }

    function formatDuration(seconds: real): string {
        const minutes = Math.round(seconds / 60);
        const hours = Math.floor(minutes / 60);
        const rest = minutes % 60;
        if (hours <= 0)
            return `${rest}m`;
        return rest === 0 ? `${hours}h` : `${hours}h ${rest}m`;
    }
}
