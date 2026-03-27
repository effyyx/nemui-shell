import "../../managers"
import "../../state"
import "../../parts"
import QtQuick
import QtQuick.Layouts

Item {
    id: screenshotRoot
    focus: true
    Keys.onEscapePressed: AppState.wallpickerVisible = false

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16
        width: 480

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            RecordButton {
                Layout.fillWidth: true
                icon: "󰹑"; label: "範囲選択"; sublabel: "保存 + クリップボード"
                accent: WallpaperManager.walColor5
                onTriggered: ScreenshotManager.region()
            }
            RecordButton {
                Layout.fillWidth: true
                icon: "󰹑"; label: "全画面"; sublabel: "保存 + クリップボード"
                accent: WallpaperManager.walColor5
                onTriggered: ScreenshotManager.fullscreen()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            RecordButton {
                Layout.fillWidth: true
                icon: "󰹑"; label: "注釈"; sublabel: "範囲 + swappy"
                accent: WallpaperManager.walColor5
                onTriggered: ScreenshotManager.annotate()
            }
            RecordButton {
                Layout.fillWidth: true
                icon: "󰹑"; label: "OCR"; sublabel: "tesseract → クリップボード"
                accent: WallpaperManager.walColor5
                onTriggered: ScreenshotManager.ocr()
            }
        }
    }
}
