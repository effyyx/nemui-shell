pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../config"
import "../state"
import "../system"

Singleton {
    id: root

    property var appList:  []
    property var appUsage: ({})

    property var filteredApps: {
        var usage = appUsage
        var source
        if (AppState.searchTerm === "") {
            source = appList
        } else {
            var q = AppState.searchTerm
            source = []
            for (var i = 0; i < appList.length; i++) {
                var e = appList[i]
                if (e.name.toLowerCase().includes(q) || e.exec.toLowerCase().includes(q))
                    source.push(e)
            }
        }
        // appList is pre-sorted alphabetically by the shell command;
        // JS sort is stable so equal-usage entries stay alpha-ordered without localeCompare
        return source.slice().sort(function(a, b) {
            return (usage[b.name] || 0) - (usage[a.name] || 0)
        })
    }

    function launch(app) {
        launchProc.command = ["bash", "-c", "nohup " + app.exec + " >/dev/null 2>&1 &"]
        launchProc.running = true

        var updated = Object.assign({}, root.appUsage)
        updated[app.name] = (updated[app.name] || 0) + 1
        root.appUsage = updated

        saveUsageProc.command = [
            "bash", "-c", "printf '%s' \"$1\" > \"$2\"",
            "--", JSON.stringify(updated), Config.appUsageFile
        ]
        saveUsageProc.running = true
        AppState.launcherVisible = false
    }

    Component.onCompleted: {
        loadUsageProc.running = true
        appListProc.running   = true
    }

    Process {
        id: loadUsageProc
        command: ["bash", "-c", "cat '" + Config.appUsageFile + "' 2>/dev/null || echo '{}'"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try { root.appUsage = JSON.parse(data.trim()) }
                catch(e) { root.appUsage = {} }
            }
        }
    }

    Process { id: saveUsageProc }
    Process { id: launchProc }

    Process {
        id: appListProc
        property var batch: []
        command: ["bash", "-c",
            "for f in /usr/share/applications/*.desktop '" + Config.localAppsDir + "'/*.desktop; do\n" +
            "    [ -f \"$f\" ] || continue\n" +
            "    grep -qi '^NoDisplay=true' \"$f\" && continue\n" +
            "    grep -qi '^Hidden=true'   \"$f\" && continue\n" +
            "    name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-)\n" +
            "    exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/ %[fFuUdDnNickvm]//g')\n" +
            "    icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-)\n" +
            "    [ -z \"$name\" ] && continue\n" +
            "    [ -z \"$exec\" ] && continue\n" +
            "    printf '%s\\t%s\\t%s\\n' \"$name\" \"$exec\" \"$icon\"\n" +
            "done | sort -f -t$'\\t' -k1,1 | awk -F'\\t' '!seen[$1]++'"
        ]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (!line) return
                var parts = line.split("\t")
                if (parts.length < 2) return
                appListProc.batch.push({ name: parts[0], exec: parts[1], icon: parts[2] || "" })
            }
        }
        onExited: root.appList = appListProc.batch
    }
}
