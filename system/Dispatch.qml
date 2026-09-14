pragma Singleton
import Quickshell
import QtQuick

// Fire-and-forget shell command runner.
// Usage:  Dispatch.run("some-command --arg")
Singleton {
    function run(cmd) {
        Quickshell.execDetached(["bash", "-c", cmd])
    }
}
