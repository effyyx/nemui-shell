pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../config"
import "../system"

Singleton {
    id: root

    property bool   isRecording:    false
    property bool   isReplayRunning: false
    property string recordingMode:  ""
    property string recordingTime:  "00:00"
    property int    recordingSeconds: 0

    readonly property int maxSeconds: 3 * 60 * 60   // 3-hour safety cap

    function start(flags) {
        root.recordingSeconds = 0
        root.recordingTime    = "00:00"
        Dispatch.run(Config.scriptRecord + " " + flags + " >/tmp/qs-record.log 2>&1")
    }

    function startRegion() {
        root.recordingMode = "範囲選択"
        regionDelayTimer.start()
    }

    Timer {
        id: regionDelayTimer
        interval: 350
        repeat: false
        onTriggered: {
            root.isRecording = true
            root.start("--region")
        }
    }

    function stop() {
        root.isRecording      = false
        root.recordingSeconds = 0
        root.recordingTime    = "00:00"
        root.recordingMode    = ""
        Dispatch.run(Config.scriptRecord + " --stop >/tmp/qs-record.log 2>&1")
    }

    function startReplay() {
        root.isReplayRunning = true
        Dispatch.run(Config.scriptRecord + " --replay-start >/tmp/qs-record.log 2>&1")
    }

    function saveReplay() {
        if (!root.isReplayRunning) {
            Dispatch.run("notify-send 'リプレイ無効' 'バッファが起動していません' -a recorder")
            return
        }
        Dispatch.run(Config.scriptRecord + " --replay-save >/tmp/qs-record.log 2>&1")
    }

    function stopReplay() {
        root.isReplayRunning = false
        Dispatch.run(Config.scriptRecord + " --replay-stop >/tmp/qs-record.log 2>&1")
    }

    Timer {
        id: recordTimer
        interval: 1000
        repeat:   true
        running:  root.isRecording
        onTriggered: {
            root.recordingSeconds++
            var m = Math.floor(root.recordingSeconds / 60)
            var s = root.recordingSeconds % 60
            root.recordingTime = (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s

            if (root.recordingSeconds >= root.maxSeconds) {
                console.warn("RecordingManager: 3-hour limit reached — stopping")
                root.stop()
            }
        }
    }
}
