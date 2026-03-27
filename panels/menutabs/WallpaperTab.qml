import "../../managers"
import "../../config"
import "../../state"
import "../../parts"
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Item {
    id: wallpaperTab

    GridView {
        id: wallGrid
        anchors.fill: parent
        anchors.rightMargin: 4
        cellWidth: Math.floor(width / 5)
        cellHeight: cellWidth * 0.62 + 30
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        cacheBuffer: 400
        model: WallpaperManager.wallpaperList
        currentIndex: AppState.wallSelectedIndex

        Keys.onPressed: function(event) {
            var cols = 5
            var total = WallpaperManager.wallpaperList.length
            if (event.key === Qt.Key_Right) {
                AppState.wallSelectedIndex = Math.min(AppState.wallSelectedIndex + 1, total - 1)
                event.accepted = true
            } else if (event.key === Qt.Key_Left) {
                AppState.wallSelectedIndex = Math.max(AppState.wallSelectedIndex - 1, 0)
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                AppState.wallSelectedIndex = Math.min(AppState.wallSelectedIndex + cols, total - 1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                AppState.wallSelectedIndex = Math.max(AppState.wallSelectedIndex - cols, 0)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (total > 0)
                    WallpaperManager.apply(WallpaperManager.wallpaperList[AppState.wallSelectedIndex])
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                AppState.wallpickerVisible = false
                event.accepted = true
            }
        }

        delegate: Item {
            width: wallGrid.cellWidth
            height: wallGrid.cellHeight
            property bool isSelected: index === AppState.wallSelectedIndex
            property bool isCurrent: modelData.path === WallpaperManager.currentWallpaper

            Rectangle {
                anchors.fill: parent
                anchors.margins: 5
                radius: 12
                color: isSelected
                    ? Qt.rgba(WallpaperManager.walColor5.r, WallpaperManager.walColor5.g, WallpaperManager.walColor5.b, 0.18)
                    : tileHov.containsMouse
                        ? Qt.rgba(1,1,1,0.07)
                        : Qt.rgba(0,0,0,0.20)
                border.width: isCurrent ? 2 : isSelected ? 1 : 0
                border.color: isCurrent ? WallpaperManager.walColor2 : WallpaperManager.walColor5
                Behavior on color { ColorAnimation { duration: 110 } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 3

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.fill: parent; radius: 8
                            color: Qt.rgba(0.13, 0.13, 0.16, 0.8)
                            visible: tImg.status !== Image.Ready
                            Text {
                                anchors.centerIn: parent; text: "󰸉"
                                color: WallpaperManager.walColor8; font.pixelSize: 20
                                font.family: "Hiragino Sans"; opacity: 0.18
                            }
                        }

                        Image {
                            id: tImg
                            anchors.fill: parent
                            source: WallpaperManager.thumbsReady && WallpaperManager.wallHashMap[modelData.path]
                                ? "file://" + Config.thumbCacheDir + "/"
                                  + WallpaperManager.wallHashMap[modelData.path] + ".jpg"
                                : ""
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            cache: false
                            sourceSize.width: 400
                            sourceSize.height: 260
                            visible: false
                            onStatusChanged: {
                                if (status === Image.Error && modelData.path)
                                    source = "file://" + modelData.path
                            }
                        }

                        Rectangle { id: tMsk; anchors.fill: parent; radius: 8; visible: false }
                        OpacityMask { anchors.fill: parent; source: tImg; maskSource: tMsk }

                        Rectangle {
                            anchors.fill: parent; radius: 8
                            color: Qt.rgba(1,1,1, tileHov.containsMouse ? 0.07 : 0)
                            Behavior on color { ColorAnimation { duration: 110 } }
                        }

                        Rectangle {
                            visible: isCurrent
                            anchors.top: parent.top; anchors.right: parent.right
                            anchors.margins: 5
                            width: 20; height: 20; radius: 10
                            color: WallpaperManager.walColor2
                            Text {
                                anchors.centerIn: parent; text: "󰄬"
                                color: WallpaperManager.walBackground
                                font.pixelSize: 11; font.family: "Hiragino Sans"
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        text: modelData.name
                        color: isCurrent ? WallpaperManager.walColor2
                             : isSelected ? WallpaperManager.walColor5
                             : Qt.rgba(WallpaperManager.walForeground.r, WallpaperManager.walForeground.g, WallpaperManager.walForeground.b, 0.55)
                        font.pixelSize: 9; font.family: "Hiragino Sans"
                        font.bold: isSelected || isCurrent
                        elide: Text.ElideMiddle
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Behavior on color { ColorAnimation { duration: 110 } }
                    }
                }

                MouseArea {
                    id: tileHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WallpaperManager.apply(modelData)
                    onContainsMouseChanged: {
                        if (containsMouse) AppState.wallSelectedIndex = index
                    }
                }
            }
        }

        ScrollBar.vertical: ScrollBar {
            active: true; width: 4
            contentItem: Rectangle {
                radius: 2
                color: Qt.rgba(WallpaperManager.walColor5.r, WallpaperManager.walColor5.g, WallpaperManager.walColor5.b, 0.35)
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !WallpaperManager.wallsLoaded
        text: "Loading…"
        color: WallpaperManager.walColor8; font.pixelSize: 13
        font.family: "Hiragino Sans"; opacity: 0.45
    }

    Text {
        anchors.centerIn: parent
        visible: WallpaperManager.wallsLoaded && WallpaperManager.wallpaperList.length === 0
        text: "No wallpapers found"
        color: WallpaperManager.walColor8; font.pixelSize: 13
        font.family: "Hiragino Sans"
    }

    function focusGrid() { wallGrid.forceActiveFocus() }

    Connections {
        target: AppState
        function onWallSelectedIndexChanged() {
            wallGrid.positionViewAtIndex(AppState.wallSelectedIndex, GridView.Contain)
        }
    }
}
