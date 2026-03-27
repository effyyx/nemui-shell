import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
    id: root

    // ── Theme colors ──────────────────────────────────────────────────────
    // Defaults mirror WallpaperManager; updated from matugen at startup.
    property color bg:     "#141318"
    property color fg:     "#e6e1e9"
    property color accent: "#cdbdff"
    property color red:    "#ffb4ab"
    property color dim:    "#938f99"
    property color warn:   "#cbc3dc"

    Process {
        running: true
        command: ["bash", "-c",
            "wp=$(readlink -f \"$HOME/Pictures/Wallpaper/current\" 2>/dev/null); " +
            "case \"$wp\" in *.mp4|*.webm|*.mkv) src=/tmp/qs-video-frame.jpg ;; *) src=\"$wp\" ;; esac; " +
            "matugen image \"$src\" --dry-run --json hex --old-json-output --source-color-index 0 2>/dev/null | " +
            "jq -c '{bg:.colors.surface.default,fg:.colors.on_surface.default," +
            "accent:.colors.primary.default,red:.colors.error.default," +
            "dim:.colors.outline.default,warn:.colors.secondary.default}'"
        ]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var j = JSON.parse(data.trim())
                    if (j.bg)     root.bg     = j.bg
                    if (j.fg)     root.fg     = j.fg
                    if (j.accent) root.accent = j.accent
                    if (j.red)    root.red    = j.red
                    if (j.dim)    root.dim    = j.dim
                    if (j.warn)   root.warn   = j.warn
                } catch(e) {}
            }
        }
    }

    // ── Shared state (all surfaces read these) ────────────────────────────
    QtObject {
        id: lockState
        property bool   failed: false
        property bool   busy:   false
        property string status: "ロック中"
    }

    QtObject {
        id: mediaState
        property string title:  ""
        property string artist: ""
    }

    Process {
        id: mediaPoller
        command: ["bash", "-c", "playerctl metadata --format '{{title}}\n{{artist}}' 2>/dev/null || true"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                var lines = data.trim().split("\n")
                mediaState.title  = lines[0] || ""
                mediaState.artist = lines.length > 1 ? lines[1] : ""
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: mediaPoller.running = true }

    // ── PAM Authentication ────────────────────────────────────────────────
    PamContext {
        id: pam
        Component.onCompleted: pam.start()
        onCompleted: result => {
            lockState.busy = false
            if (result === PamResult.Success) {
                rootLock.locked = false
                Qt.quit()
            } else {
                lockState.failed = true
                lockState.status = "拒否されました"
                pam.start()
            }
        }
    }

    // ── Session Lock ──────────────────────────────────────────────────────
    WlSessionLock {
        id: rootLock
        locked: true

        WlSessionLockSurface {
                id: lockSurface

                // ── Per-surface state ─────────────────────────────────────
                property bool inputActive: false
                property string _prev: ""

                ListModel { id: dotModel }

                Item {
                    id: screenRoot
                    anchors.fill: parent

                    // ── Background ────────────────────────────────────────
                    Image {
                        anchors.fill: parent
                        source: Quickshell.env("HOME") + "/Pictures/Wallpaper/.current-blurred.jpg"
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.45)
                        Behavior on color { ColorAnimation { duration: 500 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            lockSurface.inputActive = true
                            inputField.forceActiveFocus()
                        }
                    }

                    // ── Avatar (center 50px above screen center) ──────────
                    Rectangle {
                        width: 180; height: 180; radius: 90
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter:   parent.verticalCenter
                        anchors.verticalCenterOffset: -50
                        clip: true
                        color: "transparent"
                        border.color: root.accent
                        border.width: 4
                        Behavior on border.color { ColorAnimation { duration: 400 } }

                        Image {
                            anchors.fill: parent
                            source: Quickshell.env("HOME") + "/Pictures/discord/30662-pfp.jpeg"
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

                    // ── Greeting (100px below center) ─────────────────────
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter:   parent.verticalCenter
                        anchors.verticalCenterOffset: 100
                        text: "おかえりなさい"
                        font.family: "Hiragino Sans"
                        font.pixelSize: 22
                        color: root.fg
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }

                    // ── Status (between greeting and input) ───────────────
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter:   parent.verticalCenter
                        anchors.verticalCenterOffset: 134
                        text: lockState.status
                        font.family: "Hiragino Sans"
                        font.pixelSize: 13
                        color: lockState.failed ? root.red : root.dim
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    // ── Input field (160px below center) ──────────────────
                    Rectangle {
                        id: inputBox
                        width: 350; height: 50
                        radius: 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter:   parent.verticalCenter
                        anchors.verticalCenterOffset: 172
                        color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.65)
                        border.width: 3
                        border.color: {
                            if (lockState.failed) return root.red
                            if (lockState.busy)   return root.warn
                            if (lockSurface.inputActive) return root.accent
                            return Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.2)
                        }
                        scale: lockState.failed ? 1.03 : 1.0
                        Behavior on border.color { ColorAnimation { duration: 250 } }
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                        // Invisible capture field — always holds keyboard focus
                        TextInput {
                            id: inputField
                            anchors.fill: parent
                            opacity: 0
                            echoMode: TextInput.Password
                            Component.onCompleted: forceActiveFocus()
                            onActiveFocusChanged: {
                                if (!activeFocus) forceActiveFocus()
                            }
                            Keys.onPressed: event => {
                                if (!lockSurface.inputActive) lockSurface.inputActive = true
                                if (event.key === Qt.Key_Escape) {
                                    text = ""
                                    dotModel.clear()
                                    lockSurface.inputActive = false
                                    lockSurface._prev = ""
                                    lockState.failed = false
                                    lockState.status = "ロック中"
                                    event.accepted = true
                                }
                            }
                            onAccepted: {
                                if (text.length > 0 && pam.responseRequired && !lockState.busy) {
                                    lockState.busy   = true
                                    lockState.status = "認証中..."
                                    lockState.failed = false
                                    pam.respond(text)
                                    text = ""
                                    dotModel.clear()
                                    lockSurface._prev = ""
                                }
                            }
                            onTextChanged: {
                                if (lockState.busy) return
                                if (!lockSurface.inputActive && text.length > 0) lockSurface.inputActive = true
                                if (text.length > lockSurface._prev.length) {
                                    for (var i = lockSurface._prev.length; i < text.length; i++) dotModel.append({})
                                } else if (text.length < lockSurface._prev.length) {
                                    for (var j = 0; j < lockSurface._prev.length - text.length; j++) dotModel.remove(dotModel.count - 1)
                                }
                                lockSurface._prev = text
                                if (text.length > 0 && lockState.failed) {
                                    lockState.failed = false
                                    lockState.status = "ロック中"
                                }
                            }
                        }

                        // Password dots
                        Row {
                            anchors.centerIn: parent
                            spacing: 10
                            Repeater {
                                model: dotModel
                                Text {
                                    text: "•"
                                    font.pixelSize: 24
                                    color: lockState.failed ? root.red : root.fg
                                    Behavior on color { ColorAnimation { duration: 250 } }
                                    NumberAnimation on opacity { from: 0; to: 1; duration: 120 }
                                }
                            }
                        }
                    }

                    // ── Bottom Left: Time + Date ──────────────────────────
                    // Time bottom edge at 100px from screen bottom
                    Text {
                        id: timeText
                        anchors.left:         parent.left
                        anchors.leftMargin:   50
                        anchors.bottom:       parent.bottom
                        anchors.bottomMargin: 100
                        font.family: "Hiragino Sans"
                        font.pixelSize: 14
                        color: root.fg
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                    // Date bottom edge at 60px from screen bottom
                    Text {
                        id: dateText
                        anchors.left:         parent.left
                        anchors.leftMargin:   50
                        anchors.bottom:       parent.bottom
                        anchors.bottomMargin: 60
                        font.family: "Hiragino Sans"
                        font.pixelSize: 14
                        color: root.fg
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                    Timer {
                        interval: 1000; running: true; repeat: true; triggeredOnStart: true
                        onTriggered: {
                            var d = new Date()
                            timeText.text = Qt.formatDateTime(d, "HH:mm")
                            dateText.text = Qt.formatDateTime(d, "yyyy年MM月dd日")
                        }
                    }

                    // ── Bottom Right: Music ───────────────────────────────
                    // Mirrors hyprlock: right edge 130px from screen right, y at 85/65px from bottom
                    Text {
                        anchors.right:        parent.right
                        anchors.rightMargin:  130
                        anchors.bottom:       parent.bottom
                        anchors.bottomMargin: 85
                        visible: mediaState.title !== ""
                        text: mediaState.title
                        font.family: "JetBrains Mono"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: root.fg
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                    Text {
                        anchors.right:        parent.right
                        anchors.rightMargin:  130
                        anchors.bottom:       parent.bottom
                        anchors.bottomMargin: 65
                        visible: mediaState.artist !== ""
                        text: mediaState.artist
                        font.family: "JetBrains Mono"
                        font.pixelSize: 12
                        color: root.dim
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }

                    // ── Bottom Center: Power buttons ──────────────────────
                    // Mirrors hyprlock: 再起動 at +120, 電源オフ at 0, サスペンド at -120
                    Item {
                        anchors.bottom:            parent.bottom
                        anchors.horizontalCenter:  parent.horizontalCenter
                        anchors.bottomMargin:      60
                        width: parent.width; height: 36

                        Repeater {
                            model: [
                                { label: " 再起動",   cmd: "reboot",             xOff: 120  },
                                { label: " 電源オフ",  cmd: "shutdown now",       xOff: 0    },
                                { label: " サスペンド", cmd: "systemctl suspend",  xOff: -120 }
                            ]
                            Rectangle {
                                required property var modelData
                                required property int index
                                height: 36
                                width: btnText.implicitWidth + 24
                                radius: 4
                                x: parent.width / 2 + modelData.xOff - width / 2
                                y: 0
                                color: btnMa.containsMouse
                                    ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                                    : Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.4)
                                border.color: btnMa.containsMouse
                                    ? root.accent
                                    : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)
                                border.width: 1
                                scale: btnMa.pressed ? 0.93 : (btnMa.containsMouse ? 1.04 : 1.0)
                                Behavior on color       { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                Behavior on scale       { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                                Text {
                                    id: btnText
                                    anchors.centerIn: parent
                                    text: parent.modelData.label
                                    font.family: "Hiragino Sans"
                                    font.pixelSize: 13
                                    color: btnMa.containsMouse ? root.accent : root.dim
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                MouseArea {
                                    id: btnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        var cmd = parent.modelData.cmd
                                        Qt.createQmlObject(
                                            'import Quickshell.Io; Process { command: ["bash", "-c", "' + cmd + '"]; running: true }',
                                            screenRoot
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }
}
