import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../state"
import "../managers"
import "../services"

PanelWindow {
    id: launcherPanel

    visible: AppState.launcherVisible
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    focusable: AppState.launcherVisible
    WlrLayershell.keyboardFocus: AppState.launcherVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent; enabled: AppState.launcherVisible; z: -1
        onClicked: { AppState.launcherVisible = false; searchInput.text = "" }
    }

    Rectangle {
        id: panel
        width: 520
        height: Math.min(620, searchInput.height + 16 + listContainer.implicitHeight + 24)
        anchors.centerIn: parent
        color: Qt.rgba(WallpaperManager.walBackground.r, WallpaperManager.walBackground.g, WallpaperManager.walBackground.b, 0.92)
        radius: 0; clip: true
        visible: AppState.launcherVisible
        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 8

            // Search field
            Rectangle {
                Layout.fillWidth: true; height: 44; radius: 0
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: searchInput.activeFocus ? 1 : 0
                border.color: WallpaperManager.walColor5

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 10

                    Text { text: ""; color: WallpaperManager.walColor8; font.pixelSize: 15; font.family: "Hiragino Sans" }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true; Layout.fillHeight: true
                        color: WallpaperManager.walForeground; font.pixelSize: 15; font.family: "Hiragino Sans"
                        verticalAlignment: TextInput.AlignVCenter; selectByMouse: true; clip: true

                        Text { text: "Search apps..."; color: WallpaperManager.walColor8; visible: !parent.text; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; font: parent.font }

                        onTextChanged: {
                            AppState.searchTerm  = text.toLowerCase()
                            AppState.selectedIndex = 0
                            appListView.positionViewAtBeginning()
                        }

                        Keys.onPressed: function(event) {
                            if      (event.key === Qt.Key_Down)                            { AppState.selectedIndex = Math.min(AppState.selectedIndex + 1, AppProcesses.filteredApps.length - 1); appListView.positionViewAtIndex(AppState.selectedIndex, ListView.Contain); event.accepted = true }
                            else if (event.key === Qt.Key_Up)                              { AppState.selectedIndex = Math.max(AppState.selectedIndex - 1, 0); appListView.positionViewAtIndex(AppState.selectedIndex, ListView.Contain); event.accepted = true }
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (AppProcesses.filteredApps.length > 0) AppProcesses.launch(AppProcesses.filteredApps[AppState.selectedIndex]); event.accepted = true }
                            else if (event.key === Qt.Key_Escape)                          { AppState.launcherVisible = false; searchInput.text = ""; event.accepted = true }
                        }
                    }

                    Text {
                        visible: searchInput.text.length > 0; text: "󰅖"
                        color: WallpaperManager.walColor8; font.pixelSize: 13; font.family: "Hiragino Sans"
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: searchInput.text = "" }
                    }
                }
            }

            // App list
            Item {
                id: listContainer
                Layout.fillWidth: true; Layout.fillHeight: true
                implicitHeight: Math.min(appListView.contentHeight, 540); clip: true

                ListView {
                    id: appListView
                    anchors.fill: parent; spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: AppState.selectedIndex
                    highlightFollowsCurrentItem: true; highlightMoveDuration: 80; clip: true
                    model: AppProcesses.filteredApps

                    delegate: Rectangle {
                        width: appListView.width; height: 46; radius: 0
                        color: {
                            if (index === AppState.selectedIndex) return Qt.rgba(WallpaperManager.walColor5.r, WallpaperManager.walColor5.g, WallpaperManager.walColor5.b, 0.15)
                            if (itemMouse.containsMouse)          return Qt.rgba(1, 1, 1, 0.04)
                            return "transparent"
                        }
                        Behavior on color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
                            Rectangle { visible: index === AppState.selectedIndex; width: 3; height: 20; radius: 2; color: WallpaperManager.walColor5 }
                            Text {
                                Layout.fillWidth: true; text: modelData.name
                                color: index === AppState.selectedIndex ? WallpaperManager.walColor5 : WallpaperManager.walForeground
                                font.pixelSize: 14; font.family: "Hiragino Sans"; font.bold: index === AppState.selectedIndex
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            Text { visible: index === AppState.selectedIndex; text: "↵"; color: WallpaperManager.walColor5; font.pixelSize: 14; font.family: "Hiragino Sans"; opacity: 0.7 }
                        }

                        MouseArea {
                            id: itemMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: AppProcesses.launch(modelData)
                            onContainsMouseChanged: { if (containsMouse) AppState.selectedIndex = index }
                        }
                    }

                    ScrollBar.vertical: ScrollBar { active: true; width: 3 }
                }

                Text {
                    anchors.centerIn: parent; visible: AppProcesses.filteredApps.length === 0
                    text: "No apps found"; color: WallpaperManager.walColor8; font.pixelSize: 14; font.family: "Hiragino Sans"
                }
            }
        }
    }

    Connections {
        target: AppState
        function onLauncherVisibleChanged() {
            if (AppState.launcherVisible) {
                AppState.selectedIndex = 0; searchInput.text = ""; AppState.searchTerm = ""; focusTimer.start()
            }
        }
    }

    Timer { id: focusTimer; interval: 50; repeat: false; onTriggered: searchInput.forceActiveFocus() }
}
