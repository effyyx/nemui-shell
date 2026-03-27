import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "../state"
import "../managers"
import "../system"

PanelWindow {
    id: musicPanel

    visible: AppState.musicVisible
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true
    WlrLayershell.margins.top: 32
    implicitWidth: 430; implicitHeight: 180
    color: "transparent"
    focusable: true
    WlrLayershell.keyboardFocus: AppState.musicVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function formatTime(seconds) {
        var m = Math.floor(seconds / 60)
        var s = Math.floor(seconds % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(WallpaperManager.walBackground.r, WallpaperManager.walBackground.g, WallpaperManager.walBackground.b, 0.88)
        radius: 0
        focus: true

        Keys.onEscapePressed: AppState.musicVisible = false
        Keys.onPressed: function(event) {
            if      (event.key === Qt.Key_Escape) { AppState.musicVisible = false; event.accepted = true }
            else if (event.key === Qt.Key_Space)  { if (MprisHub.player) MprisHub.player.togglePlaying(); event.accepted = true }
            else if (event.key === Qt.Key_N)      { if (MprisHub.player) MprisHub.player.next();         event.accepted = true }
            else if (event.key === Qt.Key_P)      { if (MprisHub.player) MprisHub.player.previous();     event.accepted = true }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 15
            anchors.rightMargin: 20
            spacing: 15

            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                spacing: 8

                // Title
                Text {
                    text: MprisHub.title || "再生なし"
                    color: WallpaperManager.walColor5
                    font.pixelSize: 15; font.bold: true; font.family: "Hiragino Sans"
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true; Layout.maximumWidth: 220
                    elide: Text.ElideRight; wrapMode: Text.Wrap
                }

                // Artist
                Text {
                    text:    MprisHub.artist
                    color:   WallpaperManager.walForeground
                    font.pixelSize: 12; font.family: "Hiragino Sans"
                    opacity: 0.7
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true; Layout.maximumWidth: 220
                    elide: Text.ElideRight
                    visible: MprisHub.artist !== ""
                }

                Item { Layout.fillHeight: true; Layout.minimumHeight: 4 }

                // Progress bar + timestamps
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    visible: MprisHub.hasTrack

                    Text {
                        text:           MprisHub.player ? musicPanel.formatTime(MprisHub.player.position) : "0:00"
                        color:          WallpaperManager.walColor8
                        font.pixelSize: 10; font.family: "Hiragino Sans"
                    }

                    Rectangle {
                        Layout.preferredWidth: 160; height: 4; radius: 2
                        color: Qt.rgba(0, 0, 0, 0.3)

                        Rectangle {
                            width: MprisHub.player && MprisHub.player.length > 0
                                ? parent.width * (MprisHub.player.position / MprisHub.player.length) : 0
                            height: parent.height; radius: 2
                            color: WallpaperManager.walColor5
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                if (MprisHub.player && MprisHub.player.length > 0)
                                    MprisHub.player.position = (mouse.x / parent.width) * MprisHub.player.length
                            }
                        }
                    }

                    Text {
                        text:           MprisHub.player ? musicPanel.formatTime(MprisHub.player.length) : "0:00"
                        color:          WallpaperManager.walColor8
                        font.pixelSize: 10; font.family: "Hiragino Sans"
                    }
                }

                // Controls
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16
                    opacity: MprisHub.hasTrack ? 1.0 : 0.5

                    Rectangle {
                        width: 36; height: 36; radius: 10
                        color: prevMa.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
                        Text { anchors.centerIn: parent; text: "󰒮"; color: WallpaperManager.walForeground; font.pixelSize: 18; font.family: "Hiragino Sans" }
                        MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (MprisHub.player) MprisHub.player.previous() }
                    }

                    Rectangle {
                        width: 48; height: 48; radius: 24
                        color: WallpaperManager.walColor5
                        Text { anchors.centerIn: parent; text: MprisHub.isPlaying ? "󰏤" : "󰐊"; color: WallpaperManager.walBackground; font.pixelSize: 22; font.family: "Hiragino Sans" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (MprisHub.player) MprisHub.player.togglePlaying() }
                    }

                    Rectangle {
                        width: 36; height: 36; radius: 10
                        color: nextMa.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
                        Text { anchors.centerIn: parent; text: "󰒭"; color: WallpaperManager.walForeground; font.pixelSize: 18; font.family: "Hiragino Sans" }
                        MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (MprisHub.player) MprisHub.player.next() }
                    }
                }
            }

            // Album art
            Image {
                Layout.preferredWidth: 150; Layout.preferredHeight: 150
                Layout.alignment: Qt.AlignVCenter
                source: MprisHub.player ? (MprisHub.player.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectFit
                mipmap: true; asynchronous: true; smooth: true

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0,0,0,0.35)
                    visible: parent.status !== Image.Ready
                    Text {
                        anchors.centerIn: parent
                        text:           MprisHub.hasTrack ? "カバーなし" : "再生なし"
                        color:          Qt.rgba(1,1,1,0.65)
                        font.pixelSize: 13; font.family: "Hiragino Sans"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    // Nudge MPRIS position property so the progress bar updates
    Timer {
        interval: 1000
        running:  AppState.musicVisible && MprisHub.isPlaying
        repeat:   true
        onTriggered: { if (MprisHub.player) MprisHub.player.position }
    }
}
