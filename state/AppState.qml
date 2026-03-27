pragma Singleton
import Quickshell
import QtQuick

Singleton {
    // ── panel visibility ──────────────────────────────────────────────────
    property bool dashboardVisible:  false
    property bool musicVisible:      false
    property bool launcherVisible:   false
    property bool wallpickerVisible: false
    property bool wifiVisible:       false
    property bool btVisible:         false
    property bool cheatsheetVisible: false
    property bool mangaVisible:      false
    property bool videoVisible:      false
    property bool screenTimeVisible: false

    // ── navigation ────────────────────────────────────────────────────────
    property int activeTab:        0
    property int selectedIndex:    0
    property int savedGifIndex:    0

    // ── search ────────────────────────────────────────────────────────────
    property string searchTerm:        ""
    property string wallSearchTerm:    ""
    property int    wallSelectedIndex: 0

    // ── misc ──────────────────────────────────────────────────────────────
    property var pfpFiles: []
}
