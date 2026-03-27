import QtQuick
import QtQuick.Layouts
import "../managers"

// Icon + label + sublabel action button.
// Used in ScreenRecorder and ScreenshotTab.
Rectangle {
    id: root

    height: 52
    radius: 10

    property string icon:     ""
    property string label:    ""
    property string sublabel: ""
    property color  accent:   WallpaperManager.walColor5

    signal triggered

    color: hov.containsMouse
        ? Qt.rgba(accent.r, accent.g, accent.b, 0.15)
        : Qt.rgba(1, 1, 1, 0.05)
    border.width: 1
    border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.2)
    Behavior on color { ColorAnimation { duration: 110 } }

    RowLayout {
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: root.icon
            font.pixelSize: 18; font.family: "Hiragino Sans"
            color: root.accent
        }

        ColumnLayout {
            spacing: 1
            Text {
                text: root.label
                color: WallpaperManager.walForeground
                font.pixelSize: 12; font.family: "Hiragino Sans"
            }
            Text {
                text: root.sublabel
                color: WallpaperManager.walColor8
                font.pixelSize: 9; font.family: "Hiragino Sans"
                opacity: 0.6
            }
        }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onPressed: root.triggered()
    }
}
