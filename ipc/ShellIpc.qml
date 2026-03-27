import Quickshell
import Quickshell.Io
import QtQuick
import "../state"
import "../managers"

// All IpcHandler definitions live here so shell.qml stays clean.
// Add a new handler below whenever a new IPC target is needed.
Item {
    IpcHandler {
        target: "screentime"
        function toggle() { AppState.screenTimeVisible = !AppState.screenTimeVisible }
    }

    IpcHandler {
        target: "launcher"
        function toggle() {
            AppState.activeTab       = 0
            AppState.launcherVisible = !AppState.launcherVisible
        }
    }

    IpcHandler {
        target: "calendar"
        function toggle() { AppState.dashboardVisible = !AppState.dashboardVisible }
    }

    IpcHandler {
        target: "music"
        function toggle() { AppState.musicVisible = !AppState.musicVisible }
    }

    IpcHandler {
        target: "manga"
        function toggle() { AppState.mangaVisible = !AppState.mangaVisible }
    }

    IpcHandler {
        target: "video"
        function toggle() { AppState.videoVisible = !AppState.videoVisible }
    }

    IpcHandler {
        target: "cheatsheet"
        function toggle() { AppState.cheatsheetVisible = !AppState.cheatsheetVisible }
    }

    IpcHandler {
        target: "menu"
        function toggle()        { AppState.activeTab = 0; AppState.wallpickerVisible = !AppState.wallpickerVisible }
        function wallpaper()     { AppState.activeTab = 0; AppState.wallpickerVisible = true }
        function recorder()      { AppState.activeTab = 1; AppState.wallpickerVisible = true }
        function screenshot()    { AppState.activeTab = 2; AppState.wallpickerVisible = true }
        function notifications() { AppState.activeTab = 3; AppState.wallpickerVisible = true }
    }

    IpcHandler {
        target: "screenshot"
        function take()     { ScreenshotManager.fullscreen() }
        function region()   { ScreenshotManager.region() }
        function ocr()      { ScreenshotManager.ocr() }
        function annotate() { ScreenshotManager.annotate() }
    }

    IpcHandler {
        target: "recorder"
        function fullscreen() {
            if (RecordingManager.isRecording) { RecordingManager.stop(); return }
            RecordingManager.isRecording  = true
            RecordingManager.recordingMode = "全画面"
            RecordingManager.start("--fullscreen")
        }
        function region() {
            if (RecordingManager.isRecording) { RecordingManager.stop(); return }
            RecordingManager.startRegion()
        }
        function stop()          { RecordingManager.stop() }
        function replayToggle()  {
            if (RecordingManager.isReplayRunning) RecordingManager.stopReplay()
            else RecordingManager.startReplay()
        }
        function replaySave()    { RecordingManager.saveReplay() }
        function replayStart()   { RecordingManager.startReplay() }
        function replayStop()    { RecordingManager.stopReplay() }
    }
}
