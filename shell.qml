// Read this file first — it is the module layout reference.
//
// state/      AppState.qml        — global visibility flags + transient UI state
// config/     Config.qml          — all paths (scripts, wallpaper, cache, etc.)
// managers/   WallpaperManager, NotificationManager, RecordingManager, ScreenshotManager
// system/     Dispatch, HttpClient, MprisHub — cross-cutting helpers
// services/   AppProcesses.qml   — long-lived process wrappers (manga / video servers)
// parts/      LazyPanel, RecordButton, KbSection, TabButton, StyledText
// panels/     All PanelWindow UIs
// ipc/        ShellIpc.qml        — every IpcHandler in one place
// scripts/    Non-QML assets invoked by managers / services
//   screenshot/  screenshot.sh
//   record/      record.sh
//   manga/       manga-server (Go)
//   video/       video-server, video-overrides.json (Go)
//
// Import rule: prefer the smallest folder that owns the type.
// panels → state + managers + system  (not everything through one barrel)

import Quickshell
import Quickshell.Wayland
import QtQuick
import "state"
import "managers"
import "panels"
import "parts"
import "ipc"

ShellRoot {
    id: root

    // ── persistent surfaces ───────────────────────────────────────────────
    Bar {}
    NotificationPopups {}
    Calendar {}
    MusicPanel {}
    LauncherPanel {}
    Cheatsheet {}
    MangaPanel {}
    VideoPanel {}
    ScreenTime {}

    // ── lazy overlay (wallpicker / menu) ──────────────────────────────────
    LazyPanel {
        shown: AppState.wallpickerVisible
        panel: Component {
            Menu {
                visible: AppState.wallpickerVisible
                Component.onCompleted: if (AppState.wallpickerVisible) forceActiveFocus()
            }
        }
    }

    // ── all IPC bindings ──────────────────────────────────────────────────
    ShellIpc {}
}
