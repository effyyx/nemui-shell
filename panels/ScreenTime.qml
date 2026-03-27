import "../managers"
import "../state"
import "../system"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: screenTimePanel
    visible: AppState.screenTimeVisible

    implicitWidth: 430
    // Height follows content (see listViewportMaxHeight); not a Quickshell limitation — plain QML implicit sizing.
    implicitHeight: Math.max(140, panelColumn.implicitHeight + 30)
    anchors.top: true
    anchors.right: true
    WlrLayershell.margins.top: 32
    WlrLayershell.margins.right: 32
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    focusable: true
    WlrLayershell.keyboardFocus: AppState.screenTimeVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property int selectedDay: 0
    property var apps: []
    property int totalSeconds: 0
    property var rawData: ["", "", "", "", "", "", ""]

    function parseDur(str) {
        if (!str) return 0;
        let t = 0;
        let clean = str.replace(/\d+ms/g, "").trim();
        let h = clean.match(/(\d+)h/);
        let m = clean.match(/(\d+)m/);
        let s = clean.match(/(\d+)s/);
        if (h) t += parseInt(h[1]) * 3600;
        if (m) t += parseInt(m[1]) * 60;
        if (s) t += parseInt(s[1]);
        return t;
    }

    function applyRaw(raw) {
        if (!raw) { apps = []; totalSeconds = 0; return; }
        let list = [];
        let lines = raw.split("\n");
        let foundTotal = 0;

        for (let line of lines) {
            line = line.trim();
            if (!line || line.includes("Report period")) continue;

            if (line.includes("Summary screen time:")) {
                foundTotal = parseDur(line.split(":")[1]);
            } else {
                let match = line.match(/^(.+?)\s{2,}(\d+.*)$/);
                if (match) {
                    let name = match[1].trim();
                    let d = parseDur(match[2].trim());
                    if (d > 0) list.push({name: name, seconds: d});
                }
            }
        }
        list.sort((a, b) => b.seconds - a.seconds);
        apps = list;
        totalSeconds = foundTotal || list.reduce((a, b) => a + b.seconds, 0);
    }

    function applyPayload(raw) {
        let t = (raw || "").trim();
        if (!t) { apps = []; totalSeconds = 0; return; }
        if (t.charAt(0) === "[") {
            try {
                let arr = JSON.parse(t);
                if (Array.isArray(arr)) {
                    let list = [];
                    for (let i = 0; i < arr.length; i++) {
                        let r = arr[i];
                        let ms = r.time_ms !== undefined ? r.time_ms : 0;
                        let sec = Math.floor(ms / 1000);
                        if (sec > 0)
                            list.push({ name: String(r.name || ""), seconds: sec });
                    }
                    list.sort((a, b) => b.seconds - a.seconds);
                    apps = list;
                    totalSeconds = list.reduce((a, b) => a + b.seconds, 0);
                    return;
                }
            } catch (e) { }
        }
        applyRaw(raw);
    }

    function dateKey(d) {
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }

    property string screenTimeExecutable: "niri-screen-time"
    // List grows with app count; caps here so the panel does not eat the whole screen (scrolls inside when taller).
    property int listViewportMinHeight: 48
    property int listViewportMaxHeight: 400

    function getCmd(idx) {
        let from = new Date();
        from.setDate(from.getDate() - idx);
        let toExclusive = new Date(from);
        toExclusive.setDate(toExclusive.getDate() + 1);
        return [screenTimeExecutable, "-json", "-from=" + dateKey(from), "-to=" + dateKey(toExclusive)];
    }

    function formatTotalShort() {
        if (totalSeconds <= 0) return "0m";
        let h = Math.floor(totalSeconds / 3600);
        let m = Math.floor((totalSeconds % 3600) / 60);
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    Process {
        id: p0
        command: getCmd(0)
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                rawData[0] = this.text;
                if (selectedDay === 0) applyPayload(this.text);
            }
        }
    }
    Process {
        id: p1
        command: getCmd(1)
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                rawData[1] = this.text;
                if (selectedDay === 1) applyPayload(this.text);
            }
        }
    }
    Process {
        id: p2
        command: getCmd(2)
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                rawData[2] = this.text;
                if (selectedDay === 2) applyPayload(this.text);
            }
        }
    }
    Process {
        id: p3
        command: getCmd(3)
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                rawData[3] = this.text;
                if (selectedDay === 3) applyPayload(this.text);
            }
        }
    }
    Process {
        id: p4
        command: getCmd(4)
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                rawData[4] = this.text;
                if (selectedDay === 4) applyPayload(this.text);
            }
        }
    }
    Process {
        id: p5
        command: getCmd(5)
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                rawData[5] = this.text;
                if (selectedDay === 5) applyPayload(this.text);
            }
        }
    }
    Process {
        id: p6
        command: getCmd(6)
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                rawData[6] = this.text;
                if (selectedDay === 6) applyPayload(this.text);
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(WallpaperManager.walBackground.r, WallpaperManager.walBackground.g, WallpaperManager.walBackground.b, 0.88)
        radius: 0
        focus: true

        Keys.onEscapePressed: AppState.screenTimeVisible = false
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                AppState.screenTimeVisible = false;
                event.accepted = true;
            }
        }

        ColumnLayout {
            id: panelColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 15
            anchors.rightMargin: 20
            anchors.topMargin: 15
            spacing: 15

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "使用時間"
                    color: WallpaperManager.walColor5
                    font.pixelSize: 15
                    font.bold: true
                    font.family: "Hiragino Sans"
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: screenTimePanel.formatTotalShort()
                    color: WallpaperManager.walForeground
                    font.pixelSize: 13
                    font.family: "Hiragino Sans"
                    font.bold: true
                }
            }

            Text {
                Layout.fillWidth: true
                text: "この日の記録はありません"
                visible: apps.length === 0 && rawData[selectedDay] !== ""
                color: WallpaperManager.walForeground
                font.pixelSize: 12
                font.family: "Hiragino Sans"
                opacity: 0.55
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: 7

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 10
                        color: selectedDay === index
                            ? WallpaperManager.walColor5
                            : (dayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

                        Text {
                            anchors.centerIn: parent
                            text: index === 0 ? "今" : index === 1 ? "昨" : ["日", "月", "火", "水", "木", "金", "土"][(new Date(new Date().setDate(new Date().getDate() - index))).getDay()]
                            color: selectedDay === index ? WallpaperManager.walBackground : WallpaperManager.walForeground
                            font.pixelSize: 11
                            font.family: "Hiragino Sans"
                        }

                        MouseArea {
                            id: dayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                selectedDay = index;
                                applyPayload(rawData[index]);
                            }
                        }
                    }
                }
            }

            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(listViewportMaxHeight, Math.max(listViewportMinHeight, contentHeight))
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: apps
                spacing: 14

                delegate: Column {
                    width: ListView.view.width
                    spacing: 6

                    Row {
                        width: parent.width

                        Text {
                            text: modelData.name
                            color: WallpaperManager.walForeground
                            width: parent.width - 72
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            font.family: "Hiragino Sans"
                        }

                        Text {
                            text: modelData.seconds >= 60 ? Math.floor(modelData.seconds / 60) + "m" : modelData.seconds + "s"
                            color: WallpaperManager.walColor8
                            width: 72
                            horizontalAlignment: Text.AlignRight
                            font.pixelSize: 10
                            font.family: "Hiragino Sans"
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.rgba(0, 0, 0, 0.3)

                        Rectangle {
                            width: Math.max(2, parent.width * (modelData.seconds / (apps[0] ? apps[0].seconds : 1)))
                            height: parent.height
                            radius: 2
                            color: WallpaperManager.walColor5
                        }
                    }
                }
            }
        }
    }
}
