import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../state"
import "../managers"
import "../parts"
import "menutabs"

PanelWindow {
    id: menu

    visible: AppState.wallpickerVisible
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    focusable: true
    WlrLayershell.keyboardFocus: AppState.wallpickerVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-menu"

    property int  pickerTab: 0
    property real ani: 0
    Behavior on ani { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    onPickerTabChanged: if (pickerTab !== 0) card.forceActiveFocus()

    onVisibleChanged: {
        if (visible) {
            menu.pickerTab = AppState.activeTab; ani = 1
            if (!WallpaperManager.wallsLoaded) WallpaperManager.load()
            NotificationManager.clearUnread()
            focusTimer.start()
        } else { ani = 0 }
    }

    // Dim backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.52 * menu.ani)
        MouseArea { anchors.fill: parent; onClicked: AppState.wallpickerVisible = false }
    }

    // Main card — focus lives here so Keys work
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 1100; height: 620
        opacity: menu.ani; scale: 0.92 + 0.08 * menu.ani
        color: Qt.rgba(WallpaperManager.walBackground.r, WallpaperManager.walBackground.g, WallpaperManager.walBackground.b, 0.92)
        border.width: 1; border.color: WallpaperManager.walColor5
        layer.enabled: true
        layer.effect: DropShadow { radius: 24; samples: 25; color: "#72000000"; verticalOffset: 10 }

        focus: true
        Keys.onEscapePressed: AppState.wallpickerVisible = false

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout { anchors.fill: parent; spacing: 0

            // Tab bar
            Rectangle {
                Layout.fillWidth: true; height: 46; color: "transparent"

                Row { anchors.centerIn: parent; spacing: 4

                    TabButton { icon: "󰸉"; active: menu.pickerTab === 0; onClicked: { menu.pickerTab = 0; wallpaperTab.focusGrid() } }

                    // Recorder tab pulses when recording
                    Item { width: recTab.width; height: recTab.height
                        TabButton { id: recTab; icon: "󰄀"; active: menu.pickerTab === 1; accentColor: RecordingManager.isRecording ? WallpaperManager.walColor1 : WallpaperManager.walColor5; onClicked: menu.pickerTab = 1 }
                        Text {
                            visible: RecordingManager.isRecording; anchors.centerIn: parent
                            text: "󰻃"; font.pixelSize: 16; font.family: "Hiragino Sans"; color: WallpaperManager.walColor1
                            SequentialAnimation on opacity { running: RecordingManager.isRecording; loops: Animation.Infinite; NumberAnimation { to: 0.3; duration: 600 } NumberAnimation { to: 1.0; duration: 600 } }
                        }
                    }

                    TabButton { icon: "󰹑"; active: menu.pickerTab === 2; onClicked: menu.pickerTab = 2 }

                    // Notification tab with unread badge
                    Item { width: notifTab.width; height: notifTab.height
                        TabButton { id: notifTab; icon: "󰂚"; active: menu.pickerTab === 3; accentColor: WallpaperManager.walColor13; onClicked: { menu.pickerTab = 3; NotificationManager.clearUnread() } }
                        Rectangle {
                            visible: NotificationManager.unreadCount > 0 && menu.pickerTab !== 3
                            anchors.top: parent.top; anchors.right: parent.right
                            anchors.topMargin: 4; anchors.rightMargin: 4
                            width: 8; height: 8; radius: 4; color: WallpaperManager.walColor13
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                    height: 1
                    color: Qt.rgba(WallpaperManager.walForeground.r, WallpaperManager.walForeground.g, WallpaperManager.walForeground.b, 0.07)
                }
            }

            // Tab content
            Item { Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 16
                WallpaperTab    { id: wallpaperTab; anchors.fill: parent; visible: menu.pickerTab === 0 }
                ScreenRecorder  {                   anchors.fill: parent; visible: menu.pickerTab === 1 }
                ScreenshotTab   {                   anchors.fill: parent; visible: menu.pickerTab === 2 }
                NotificationTab {                   anchors.fill: parent; visible: menu.pickerTab === 3 }
            }
        }
    }

    Timer {
        id: focusTimer; interval: 60; repeat: false
        onTriggered: if (menu.pickerTab === 0) wallpaperTab.focusGrid()
    }

    Connections {
        target: AppState
        function onWallpickerVisibleChanged() {
            if (!AppState.wallpickerVisible) return
            menu.pickerTab = AppState.activeTab
            AppState.wallSelectedIndex = 0
            if (!WallpaperManager.wallsLoaded) WallpaperManager.load()
        }
        function onActiveTabChanged() { menu.pickerTab = AppState.activeTab }
    }
}
