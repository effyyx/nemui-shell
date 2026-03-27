pragma Singleton
import Quickshell
import QtQuick

Singleton {
    readonly property string home:          Quickshell.env("HOME")
    readonly property string configDir:     home + "/.config/quickshell"
    readonly property string cacheDir:      home + "/.cache"

    // ── wallpaper ─────────────────────────────────────────────────────────
    readonly property string wallpaperDir:  home + "/Pictures/Wallpaper"
    readonly property string thumbCacheDir: cacheDir + "/wallpaper-thumbs"
    readonly property string resolution:    "2560:1440"

    // ── scripts ───────────────────────────────────────────────────────────
    readonly property string scriptsRoot:        configDir + "/scripts"
    readonly property string scriptScreenshot:   scriptsRoot + "/screenshot/screenshot.sh"
    readonly property string scriptRecord:       scriptsRoot + "/record/record.sh"
    readonly property string scriptMangaServer:  scriptsRoot + "/manga/manga-server"
    readonly property string scriptVideoServer:  scriptsRoot + "/video/video-server"

    // ── data files ────────────────────────────────────────────────────────
    readonly property string appUsageFile:  configDir + "/state/app_usage.json"
    readonly property string localAppsDir:  home + "/.local/share/applications"
}
