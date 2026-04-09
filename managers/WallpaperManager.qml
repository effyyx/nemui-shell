pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../config"
import "../state"

Singleton {
    id: root

    // ── wallpaper list ────────────────────────────────────────────────────
    property var    wallpaperList:    []
    property var    wallHashMap:      ({})
    property string currentWallpaper: ""
    property bool   wallsLoaded:      false
    property bool   thumbsReady:      false
    property bool   walApplying:      false

    // ── matugen theme colors ──────────────────────────────────────────────
    property color walBackground: "#141318"
    property color walForeground: "#e6e1e9"
    property color walColor1:     "#ffb4ab"
    property color walColor2:     "#eeb8c9"
    property color walColor4:     "#cbc3dc"
    property color walColor5:     "#cdbdff"
    property color walColor8:     "#938f99"
    property color walColor13:    "#eeb8c9"

    // ── filtered list (wall search) ───────────────────────────────────────
    property var filteredWallpapers: {
        if (AppState.wallSearchTerm === "") return wallpaperList
        var q = AppState.wallSearchTerm
        var out = []
        for (var i = 0; i < wallpaperList.length; i++)
            if (wallpaperList[i].name.toLowerCase().includes(q))
                out.push(wallpaperList[i])
        return out
    }

    // ── helpers ───────────────────────────────────────────────────────────
    function isVideo(path) {
        return path.endsWith(".mp4") || path.endsWith(".webm") || path.endsWith(".mkv")
    }
    function isAnimated(path) {
        return isVideo(path) || path.endsWith(".gif")
    }

    // ── public API ────────────────────────────────────────────────────────
    function load() {
        root.wallpaperList = []
        root.wallsLoaded   = false
        root.thumbsReady   = false
        wallpaperListProc.batch   = []
        wallpaperListProc.running = true
    }

    function apply(wallpaper) {
        root.currentWallpaper = wallpaper.path
        root.walApplying = true
        applyWallProc.command = ["bash", "-c",
            "pgrep awww-daemon >/dev/null 2>&1 || (awww-daemon & sleep 0.5); " +
            "ln -sf '" + wallpaper.path + "' '" + Config.wallpaperDir + "/current' && " +
            "awww img '" + wallpaper.path + "' --transition-type any --transition-duration 2 & " +
            "matugen image '" + wallpaper.path + "' --source-color-index 0 && " +
            "sleep 0.3"
        ]
        applyWallProc.running = true
    }

    // ── startup ───────────────────────────────────────────────────────────
    Component.onCompleted: {
        matugenColorsProc.running = true
        currentWallProc.running   = true
        thumbDirProc.running      = true
    }

    // ── processes ─────────────────────────────────────────────────────────
    Process {
        id: thumbDirProc
        command: ["bash", "-c", "mkdir -p '" + Config.thumbCacheDir + "'"]
        onExited: root.load()
    }

    Process {
        id: wallpaperListProc
        property var batch: []
        command: ["bash", "-c",
            "find '" + Config.wallpaperDir + "' -maxdepth 1 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.png' " +
            "   -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' \\) " +
            "! -name '.*' ! -name 'tn_*' ! -name '.current-blurred*' | sort"
        ]
        stdout: SplitParser {
            onRead: data => {
                var path = data.trim()
                if (!path) return
                wallpaperListProc.batch.push({ name: path.split("/").pop(), path: path })
            }
        }
        onExited: {
            root.wallpaperList = wallpaperListProc.batch
            root.wallsLoaded   = true
            batchHashProc.batch   = {}
            batchHashProc.running = true
        }
    }

    Process {
        id: batchHashProc
        property var batch: ({})
        command: ["bash", "-c",
            "find '" + Config.wallpaperDir + "' -maxdepth 1 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.png' " +
            "   -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' \\) " +
            "! -name '.*' ! -name 'tn_*' ! -name '.current-blurred*' | " +
            "awk '{printf \"%s|%s\\n\", $0, $0}' | " +
            "while IFS='|' read -r f _; do printf '%s|%s\\n' \"$f\" \"$(printf '%s' \"$f\" | md5sum | cut -d' ' -f1)\"; done"
        ]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (!line) return
                var idx = line.indexOf("|")
                if (idx < 0) return
                batchHashProc.batch[line.substring(0, idx)] = line.substring(idx + 1)
            }
        }
        onExited: {
            root.wallHashMap = batchHashProc.batch
            thumbGenProc.running = true
        }
    }

    Process {
        id: thumbGenProc
        command: ["bash", "-c",
            "cd '" + Config.thumbCacheDir + "' && " +
            "find '" + Config.wallpaperDir + "' -maxdepth 1 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.png' " +
            "   -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' \\) " +
            "! -name '.*' ! -name 'tn_*' ! -name '.current-blurred*' | " +
            "while IFS= read -r f; do " +
            "    hash=$(printf '%s' \"$f\" | md5sum | cut -d' ' -f1); " +
            "    thumb=\"" + Config.thumbCacheDir + "/${hash}.jpg\"; " +
            "    if [ ! -f \"$thumb\" ] || [ \"$f\" -nt \"$thumb\" ]; then " +
            "        case \"$f\" in " +
            "            *.mp4|*.webm|*.mkv) " +
            "                ffmpeg -y -ss 1 -i \"$f\" -vf 'scale=360:240:force_original_aspect_ratio=increase,crop=360:240' -pix_fmt yuvj420p -frames:v 1 -update 1 -q:v 2 \"$thumb\" 2>/dev/null & ;; " +
            "            *.gif) " +
            "                convert \"${f}[0]\" -define jpeg:size=400x300 -thumbnail 360x240^ -gravity center -extent 360x240 -strip -quality 85 \"$thumb\" 2>/dev/null & ;; " +
            "            *) " +
            "                if command -v vipsthumbnail >/dev/null 2>&1; then " +
            "                    vipsthumbnail \"$f\" -s 360x240 -o \"${thumb}[Q=85,strip]\" 2>/dev/null || " +
            "                    convert \"$f\" -define jpeg:size=400x300 -thumbnail 360x240^ -gravity center -extent 360x240 -strip -quality 85 \"$thumb\" 2>/dev/null & " +
            "                else " +
            "                    convert \"$f\" -define jpeg:size=400x300 -thumbnail 360x240^ -gravity center -extent 360x240 -strip -quality 85 \"$thumb\" 2>/dev/null & " +
            "                fi ;; " +
            "        esac; " +
            "    fi; " +
            "done; wait"
        ]
        onExited: root.thumbsReady = true
    }

    Process {
        id: applyWallProc
        onExited: {
            matugenColorsProc.running = true
            walStepMako.running = true
        }
    }

    Process {
        id: matugenColorsProc
        command: ["bash", "-c",
            "wp=$(readlink -f '" + Config.wallpaperDir + "/current' 2>/dev/null || echo ''); " +
            "case \"$wp\" in " +
            "    *.mp4|*.webm|*.mkv) src=/tmp/qs-video-frame.jpg ;; " +
            "    *) src=\"$wp\" ;; " +
            "esac; " +
            "matugen image \"$src\" --dry-run --json hex --old-json-output --source-color-index 0 2>/dev/null | " +
            "jq -c '{background:.colors.surface.default,foreground:.colors.on_surface.default," +
            "color1:.colors.error.default,color2:.colors.tertiary.default," +
            "color4:.colors.secondary.default,color5:.colors.primary.default," +
            "color8:.colors.outline.default,color13:.colors.tertiary.default}'"
        ]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var j = JSON.parse(data)
                    if (j.background) root.walBackground = j.background
                    if (j.foreground) root.walForeground = j.foreground
                    if (j.color1)     root.walColor1  = j.color1
                    if (j.color2)     root.walColor2  = j.color2
                    if (j.color4)     root.walColor4  = j.color4
                    if (j.color5)     root.walColor5  = j.color5
                    if (j.color8)     root.walColor8  = j.color8
                    if (j.color13)    root.walColor13 = j.color13
                } catch(e) {}
            }
        }
        onExited: { if (root.walApplying) walStepBlur.running = true }
    }

    Process { id: walStepMako; command: ["bash", "-c", "makoctl reload"] }

    Process {
        id: walStepBlur
        command: {
            var wp  = root.currentWallpaper
            var res = Config.resolution
            var out = Config.wallpaperDir + "/.current-blurred.jpg"
            var filter = "scale=" + res + ":force_original_aspect_ratio=increase,crop=" + res + ",gblur=sigma=40"
            if (isVideo(wp))
                return ["bash", "-c", "ffmpeg -y -ss 1 -i '" + wp + "' -vf '" + filter + "' -frames:v 1 -q:v 2 '" + out + "'"]
            if (wp.endsWith(".gif"))
                return ["bash", "-c", "ffmpeg -y -i '" + wp + "' -vf '" + filter + "' -vframes 1 -q:v 2 '" + out + "'"]
            return ["bash", "-c", "ffmpeg -y -i '" + wp + "' -vf '" + filter + "' -q:v 2 '" + out + "'"]
        }
        onExited: root.walApplying = false
    }

    Process {
        id: currentWallProc
        command: ["bash", "-c", "readlink -f '" + Config.wallpaperDir + "/current' 2>/dev/null || echo ''"]
        stdout: SplitParser { onRead: data => root.currentWallpaper = data.trim() }
    }
}
