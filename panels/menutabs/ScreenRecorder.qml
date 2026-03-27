import "../../managers"
import "../../state"
import "../../parts"
import QtQuick
import QtQuick.Layouts

Item {
    focus: true
    Keys.onEscapePressed: AppState.wallpickerVisible = false

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16
        width: 480

        // ── Replay section ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: !RecordingManager.isReplayRunning

            RecordButton {
                Layout.fillWidth: true
                icon: "󰻃"; label: "インスタントリプレイ"; sublabel: "180秒 RAMバッファ"
                accent: WallpaperManager.walColor2
                onTriggered: {
                    RecordingManager.startReplay()
                    AppState.wallpickerVisible = false
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: RecordingManager.isReplayRunning

            RecordButton {
                Layout.fillWidth: true
                icon: "󰻃"; label: "クリップ保存"; sublabel: "最後の180秒"
                accent: WallpaperManager.walColor5
                onTriggered: RecordingManager.saveReplay()
            }
            RecordButton {
                Layout.fillWidth: true
                icon: "󰹊"; label: "停止"; sublabel: "バッファ解放"
                accent: WallpaperManager.walColor1
                onTriggered: RecordingManager.stopReplay()
            }
        }

        // ── Recording status ──────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            visible: RecordingManager.isRecording

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                visible: RecordingManager.isRecording
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10
                    Rectangle {
                        width: 10; height: 10; radius: 5
                        color: WallpaperManager.walColor1
                        SequentialAnimation on opacity {
                            running: RecordingManager.isRecording
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 500 }
                            NumberAnimation { to: 1.0; duration: 500 }
                        }
                    }
                    Text {
                        text: "REC  " + RecordingManager.recordingTime
                        color: WallpaperManager.walColor1; font.pixelSize: 18
                        font.family: "Hiragino Sans"; font.bold: true
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: RecordingManager.recordingMode
                    color: WallpaperManager.walColor8; font.pixelSize: 11
                    font.family: "Hiragino Sans"; opacity: 0.6
                }
            }
        }

        // ── Recording buttons ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: !RecordingManager.isRecording

            RecordButton {
                Layout.fillWidth: true
                icon: "󰹑"; label: "全画面"; sublabel: "録画開始"
                accent: WallpaperManager.walColor5
                onTriggered: {
                    RecordingManager.isRecording = true
                    RecordingManager.recordingMode = "全画面"
                    AppState.wallpickerVisible = false
                    RecordingManager.start("--fullscreen")
                }
            }
            RecordButton {
                Layout.fillWidth: true
                icon: "󰆞"; label: "範囲選択"; sublabel: "録画開始"
                accent: WallpaperManager.walColor5
                onTriggered: {
                    AppState.wallpickerVisible = false
                    RecordingManager.startRegion()
                }
            }
        }

        // ── Stop button ───────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 52; radius: 0
            visible: RecordingManager.isRecording
            color: stopHov.containsMouse
                ? Qt.rgba(WallpaperManager.walColor1.r, WallpaperManager.walColor1.g, WallpaperManager.walColor1.b, 0.25)
                : Qt.rgba(WallpaperManager.walColor1.r, WallpaperManager.walColor1.g, WallpaperManager.walColor1.b, 0.12)
            border.width: 1
            border.color: Qt.rgba(WallpaperManager.walColor1.r, WallpaperManager.walColor1.g, WallpaperManager.walColor1.b, 0.4)
            Behavior on color { ColorAnimation { duration: 110 } }
            RowLayout {
                anchors.centerIn: parent
                spacing: 10
                Rectangle { width: 14; height: 14; radius: 2; color: WallpaperManager.walColor1 }
                Text {
                    text: "録画停止"
                    color: WallpaperManager.walColor1; font.pixelSize: 13
                    font.family: "Hiragino Sans"; font.bold: true
                }
            }
            MouseArea {
                id: stopHov; anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: RecordingManager.stop()
            }
        }
    }


}
