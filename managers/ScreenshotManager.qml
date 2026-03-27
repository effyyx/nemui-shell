pragma Singleton
import Quickshell
import QtQuick
import "../config"
import "../state"
import "../system"

// All screenshot actions close the menu then fire the script.
// IpcHandler shorthands forward here; panels call the same methods.
Singleton {
    function take(flags) {
        AppState.wallpickerVisible = false
        Dispatch.run(Config.scriptScreenshot + " " + flags + " >/tmp/qs-screenshot.log 2>&1")
    }

    function region()     { take("--region") }
    function fullscreen() { take("--fullscreen") }
    function ocr()        { take("--ocr") }
    function annotate()   { take("--annotate") }
}
