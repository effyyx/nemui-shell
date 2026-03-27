import "../managers"
import "../state"
import "../parts"
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: popupWindow

    visible: NotificationManager.popupList.length > 0
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    WlrLayershell.margins.top: 48
    WlrLayershell.margins.right: 8
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-notifications"

    implicitWidth: 340
    implicitHeight: notifColumn.implicitHeight
    color: "transparent"

    Column {
        id: notifColumn
        width: parent.width
        spacing: 6

        Repeater {
            model: NotificationManager.popupList

            Rectangle {
                width: 340
                height: contentRow.implicitHeight + 20
                radius: 0
                color: Qt.rgba(WallpaperManager.walBackground.r, WallpaperManager.walBackground.g, WallpaperManager.walBackground.b, 0.92)
                border.width: 1
                border.color: Qt.rgba(WallpaperManager.walColor5.r, WallpaperManager.walColor5.g, WallpaperManager.walColor5.b, 0.3)

                opacity: 0
                x: 30
                Component.onCompleted: { opacity = 1; x = 0 }
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                RowLayout {
                    id: contentRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 12
                    }
                    spacing: 10

                    Rectangle {
                        visible: modelData.image !== ""
                        Layout.preferredWidth: 52
                        Layout.preferredHeight: 52
                        Layout.alignment: Qt.AlignVCenter
                        clip: true
                        color: "transparent"

                        Image {
                            anchors.fill: parent
                            source: modelData.image
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: false
                            cache: false
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: modelData.appName
                                color: WallpaperManager.walColor5
                                font.pixelSize: 11
                                font.family: "Hiragino Sans"
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: Qt.formatTime(new Date(modelData.time), "hh:mm")
                                color: WallpaperManager.walColor8
                                font.pixelSize: 10
                                font.family: "Hiragino Sans"
                                opacity: 0.6
                            }
                        }

                        Text {
                            visible: modelData.summary !== ""
                            text: modelData.summary
                            color: WallpaperManager.walForeground
                            font.pixelSize: 13
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
                            font.pixelSize: 11
                            font.family: "Hiragino Sans"
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            opacity: 0.8
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationManager.dismiss(modelData.notificationId)
                }
            }
        }
    }
}
