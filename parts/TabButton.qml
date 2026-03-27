import QtQuick
import "../managers"

// Reusable tab button used in Menu and Cheatsheet.
//
// Icon-only mode (Menu):    set `icon`, leave `label` empty  → 34×34 square
// Label mode (Cheatsheet):  set `icon` and/or `label`        → pill
Rectangle {
    id: root

    property string icon:        ""
    property string label:       ""
    property bool   active:      false
    property bool   showDot:     true
    property color  accentColor: WallpaperManager.walColor5

    signal clicked

    width:  label !== "" ? tabRow.implicitWidth + 24 : 34
    height: label !== "" ? 28 : 34
    radius: label !== "" ? 6  : 10

    color: active
        ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18)
        : hov.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    border.width: label !== "" && active ? 1 : 0
    border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.3)

    // ── icon-only ─────────────────────────────────────────────────────────
    Text {
        visible: root.label === ""
        anchors.centerIn: parent
        text:           root.icon
        font.pixelSize: 16; font.family: "Hiragino Sans"
        color:          root.active ? root.accentColor : WallpaperManager.walColor8
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // ── icon + label ──────────────────────────────────────────────────────
    Row {
        id: tabRow
        visible: root.label !== ""
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: root.icon !== ""
            text:           root.icon
            font.pixelSize: 13; font.family: "Hiragino Sans"
            color:          root.active ? root.accentColor : WallpaperManager.walColor8
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        Text {
            text:           root.label
            font.pixelSize: 12; font.family: "Hiragino Sans"
            color:          root.active ? root.accentColor : WallpaperManager.walColor8
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 100 } }
        }
    }

    // Active indicator dot (icon-only mode)
    Rectangle {
        visible: root.showDot && root.active && root.label === ""
        anchors.bottom: parent.bottom; anchors.bottomMargin: 3
        anchors.horizontalCenter: parent.horizontalCenter
        width: 4; height: 4; radius: 2
        color: root.accentColor
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
