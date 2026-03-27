import "../../managers"
import "../../state"
import "../../parts"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    focus: true
    Keys.onEscapePressed: AppState.wallpickerVisible = false

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 12

            Text {
                text: "通知"
                color: WallpaperManager.walColor5
                font.pixelSize: 13
                font.family: "Hiragino Sans"
                opacity: 0.7
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                visible: NotificationManager.list.length > 0
                text: "クリア"
                color: WallpaperManager.walColor8
                font.pixelSize: 11
                font.family: "Hiragino Sans"
                opacity: 0.5
                Layout.rightMargin: 4
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationManager.clearHistory()
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.width: 4

            ListView {
                id: historyList
                anchors.fill: parent
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds
                model: NotificationManager.list

                delegate: Rectangle {
                    width: historyList.width
                    height: itemCol.implicitHeight + 16
                    radius: 0
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.width: 1
                    border.color: Qt.rgba(WallpaperManager.walColor8.r, WallpaperManager.walColor8.g, WallpaperManager.walColor8.b, 0.1)

                    ColumnLayout {
                        id: itemCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: modelData.appName
                                color: WallpaperManager.walColor5
                                font.pixelSize: 10
                                font.family: "Hiragino Sans"
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                opacity: 0.8
                            }
                            Text {
                                text: Qt.formatTime(new Date(modelData.time), "hh:mm")
                                color: WallpaperManager.walColor8
                                font.pixelSize: 9
                                font.family: "Hiragino Sans"
                                opacity: 0.45
                            }
                        }

                        Text {
                            visible: modelData.summary !== ""
                            text: modelData.summary
                            color: WallpaperManager.walForeground
                            font.pixelSize: 12
                            font.family: "Hiragino Sans"
                            font.bold: true
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: modelData.body !== ""
                            text: modelData.body
                            color: WallpaperManager.walColor8
                            font.pixelSize: 10
                            font.family: "Hiragino Sans"
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            opacity: 0.7
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: NotificationManager.list.length === 0
                    text: "通知なし"
                    color: WallpaperManager.walColor8
                    font.pixelSize: 13
                    font.family: "Hiragino Sans"
                    opacity: 0.35
                }
            }
        }
    }

    Component.onCompleted: NotificationManager.clearUnread()
}
