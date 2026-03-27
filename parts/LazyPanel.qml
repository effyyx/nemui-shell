import QtQuick

// Loads its panel component lazily when `shown` becomes true,
// and destroys it after `destroyDelay` ms once `shown` goes false.
// This avoids keeping heavy panels in memory when they are never opened.
Item {
    id: root

    property bool      shown:        false
    property int       destroyDelay: 200
    property Component panel

    Loader {
        id: loader
        asynchronous:    false
        active:          root.shown || destroyTimer.running
        sourceComponent: root.panel
    }

    Timer {
        id: destroyTimer
        interval: root.destroyDelay
        repeat:   false
    }

    onShownChanged: { if (!shown) destroyTimer.restart() }
}
