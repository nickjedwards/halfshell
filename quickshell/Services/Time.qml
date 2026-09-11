pragma Singleton

import Quickshell

// One clock for the whole shell, at minute precision so we wake 60x less
// often than a seconds clock would. If you add a seconds display somewhere,
// change precision here rather than adding a second clock.
Singleton {
    id: root

    readonly property date now: clock.date
    readonly property string time: Qt.formatDateTime(clock.date, "h:mm A")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
