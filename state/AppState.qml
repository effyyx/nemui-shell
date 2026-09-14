pragma Singleton
import Quickshell
import QtQuick

Singleton {
    // ── panel visibility ──────────────────────────────────────────────────
    property bool dashboardVisible:  false
    property bool musicVisible:      false
    property bool launcherVisible:   false
    property bool wallpickerVisible: false
    property bool cheatsheetVisible: false

    // ── navigation ────────────────────────────────────────────────────────
    property int activeTab:        0
    property int selectedIndex:    0

    // ── search ────────────────────────────────────────────────────────────
    property string searchTerm:        ""
    property string wallSearchTerm:    ""
    property int    wallSelectedIndex: 0

}
