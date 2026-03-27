import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../state"
import "../managers"
import "../system"

Scope {
    // ── niri workspace state via event-stream ─────────────────────────────
    property var    niriWorkspaces:    ({})
    property string niriFocusedOutput: ""
    property var    _wsStore:          []   // [{id, idx, output, active, focused}]

    function _rebuildWorkspaces() {
        var result = {}
        var focused = ""
        for (var i = 0; i < _wsStore.length; i++) {
            var ws = _wsStore[i]
            if (!result[ws.output]) result[ws.output] = []
            result[ws.output].push({ idx: ws.idx, active: ws.active })
            if (ws.focused) focused = ws.output
        }
        for (var out in result)
            result[out].sort(function(a, b) { return a.idx - b.idx })
        niriWorkspaces = result
        if (focused) niriFocusedOutput = focused
    }

    Process {
        id: niriEventProc
        command: ["niri", "msg", "-j", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (!line) return
                try {
                    var ev = JSON.parse(line)
                    if (ev.WorkspacesChanged) {
                        // Full rebuild from authoritative list
                        var wsList = ev.WorkspacesChanged.workspaces
                        var store = []
                        for (var i = 0; i < wsList.length; i++) {
                            var ws = wsList[i]
                            store.push({ id: ws.id, idx: ws.idx, output: ws.output,
                                         active: ws.is_active, focused: ws.is_focused })
                        }
                        _wsStore = store
                        _rebuildWorkspaces()
                    } else if (ev.WorkspaceActivated) {
                        // Incremental update — just flip active/focused flags
                        var actId      = ev.WorkspaceActivated.id
                        var isFocused  = ev.WorkspaceActivated.focused
                        var actOutput  = ""
                        for (var j = 0; j < _wsStore.length; j++) {
                            if (_wsStore[j].id === actId) { actOutput = _wsStore[j].output; break }
                        }
                        var store = []
                        for (var j = 0; j < _wsStore.length; j++) {
                            var ws = _wsStore[j]
                            store.push({ id: ws.id, idx: ws.idx, output: ws.output,
                                active:  ws.output === actOutput ? (ws.id === actId) : ws.active,
                                focused: ws.id === actId ? isFocused : (isFocused ? false : ws.focused)
                            })
                        }
                        _wsStore = store
                        if (isFocused) niriFocusedOutput = actOutput
                        _rebuildWorkspaces()
                    }
                } catch(e) {}
            }
        }
        onExited: Qt.callLater(function() { niriEventProc.running = true })
    }

    // ── one bar per screen ────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            exclusionMode: ExclusionMode.Auto
            anchors { top: true; left: true; right: true }
            implicitHeight: 32
            color: "transparent"

            readonly property string screenName: bar.screen ? bar.screen.name : ""
            readonly property var    wsLabels:   ["一","二","三","四","五","六","七","八","九","十"]

            // Drop last (empty) workspace slot
            property var screenWorkspaces: {
                var ws = niriWorkspaces[bar.screenName] || []
                return ws.slice(0, ws.length - 1)
            }

            function wsToKanji(idx) {
                return idx >= 1 && idx <= 10 ? wsLabels[idx - 1] : idx.toString()
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(WallpaperManager.walBackground.r, WallpaperManager.walBackground.g, WallpaperManager.walBackground.b, 0.88)
                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.InOutQuad } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    spacing: 8

                    // ── workspaces ────────────────────────────────────────
                    Row {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter

                        Repeater {
                            model: bar.screenWorkspaces
                            delegate: Item {
                                required property var modelData
                                width: wsLabel.implicitWidth
                                height: bar.implicitHeight

                                property bool isActive: modelData.active

                                Text {
                                    id: wsLabel
                                    anchors.centerIn: parent
                                    text:           bar.wsToKanji(modelData.idx)
                                    color:          isActive ? WallpaperManager.walColor5 : WallpaperManager.walColor8
                                    opacity:        isActive ? 1.0 : 0.5
                                    font.pixelSize: 14; font.family: "Hiragino Sans"
                                    Behavior on color   { ColorAnimation { duration: 150 } }
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }

                                Rectangle {
                                    visible: isActive
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: wsLabel.implicitWidth; height: 1
                                    color: WallpaperManager.walColor5
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', bar)
                                        proc.command = ["niri", "msg", "action", "focus-workspace", modelData.idx.toString()]
                                        proc.running = true
                                    }
                                }
                            }
                        }
                    }

                    // ── now playing (centre) ──────────────────────────────
                    Item {
                        Layout.fillWidth: true
                        height: bar.implicitHeight

                        Text {
                            anchors.centerIn: parent
                            text: MprisHub.title !== ""
                                ? (MprisHub.artist !== "" ? MprisHub.artist + "  —  " + MprisHub.title : MprisHub.title)
                                : "再生なし"
                            color:          MprisHub.title !== "" ? WallpaperManager.walColor5 : WallpaperManager.walColor8
                            opacity:        MprisHub.title !== "" ? 1.0 : 0.4
                            font.pixelSize: 14; font.family: "Hiragino Sans"
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width - 20)
                            horizontalAlignment: Text.AlignHCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: AppState.musicVisible = !AppState.musicVisible
                            }
                        }
                    }

                    // ── right: recording indicator + clock ────────────────
                    Row {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter

                        // replay indicator — click to save clip
                        Rectangle {
                            visible: RecordingManager.isReplayRunning
                            width: replayRow.implicitWidth; height: bar.implicitHeight
                            color: "transparent"

                            Row {
                                id: replayRow
                                spacing: 6
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    width: 7; height: 7; radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: WallpaperManager.walColor2
                                }

                                Text {
                                    text:           "REPLAY"
                                    color:          WallpaperManager.walColor2
                                    font.pixelSize: 11; font.family: "Hiragino Sans"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: RecordingManager.saveReplay()
                            }
                        }

                        // recording indicator — click to stop
                        Rectangle {
                            visible: RecordingManager.isRecording
                            width: recRow.implicitWidth; height: bar.implicitHeight
                            color: "transparent"

                            Row {
                                id: recRow
                                spacing: 6
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    width: 7; height: 7; radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: WallpaperManager.walColor1
                                    SequentialAnimation on opacity {
                                        running: RecordingManager.isRecording
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.2; duration: 500 }
                                        NumberAnimation { to: 1.0; duration: 500 }
                                    }
                                }

                                Text {
                                    text:           RecordingManager.recordingTime
                                    color:          WallpaperManager.walColor1
                                    font.pixelSize: 14; font.family: "Hiragino Sans"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: RecordingManager.stop()
                            }
                        }

                        Text {
                            id: clockText
                            text:           Qt.formatDateTime(new Date(), "hh:mm")
                            color:          WallpaperManager.walColor5
                            font.pixelSize: 14; font.family: "Hiragino Sans"
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: AppState.dashboardVisible = !AppState.dashboardVisible
                            }
                        }
                    }
                }
            }

            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: clockText.text = Qt.formatDateTime(new Date(), "hh:mm")
            }
        }
    }
}
