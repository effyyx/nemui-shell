import QtQuick
import QtQuick.Layouts
import "../managers"

// A titled section of keyboard shortcut rows.
// Used by all Cheatsheet* panels.
//
//   KbSection {
//       width: parent.width
//       title: "アプリ"
//       entries: [
//           { key: "Mod + Space", desc: "ターミナル" },
//           …
//       ]
//   }
Item {
    property string title:   ""
    property var    entries: []

    implicitHeight: secCol.implicitHeight

    Column {
        id: secCol
        width: parent.width
        spacing: 0

        // Section header
        Rectangle {
            width: parent.width; height: 22
            color: "transparent"

            Text {
                text: title
                color: WallpaperManager.walColor5
                font.pixelSize: 10; font.family: "Hiragino Sans"
                font.bold: true; opacity: 0.8
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 2
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: Qt.rgba(WallpaperManager.walColor5.r, WallpaperManager.walColor5.g, WallpaperManager.walColor5.b, 0.15)
            }
        }

        // Rows
        Repeater {
            model: entries

            Rectangle {
                width: secCol.width; height: 20
                color: index % 2 === 0 ? "transparent" : Qt.rgba(1, 1, 1, 0.02)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4; anchors.rightMargin: 4
                    spacing: 6

                    Text {
                        text: modelData.key
                        color: WallpaperManager.walColor5
                        font.pixelSize: 10; font.family: "Hiragino Sans"; font.bold: true
                        Layout.minimumWidth: 130
                        elide: Text.ElideRight
                    }
                    Text {
                        text: modelData.desc
                        color: WallpaperManager.walForeground
                        font.pixelSize: 10; font.family: "Hiragino Sans"
                        opacity: 0.7
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
