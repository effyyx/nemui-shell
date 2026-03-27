import "../managers"
import "../state"
import "../system"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: videoPanel

    visible: AppState.videoVisible
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true }
    implicitWidth: stack.depth === 2 ? 800 : 480
    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    margins.top: -1
    margins.bottom: -1
    color: "transparent"
    focusable: true
    WlrLayershell.keyboardFocus: AppState.videoVisible
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-video"

    property real ani: 0
    Behavior on ani { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    onVisibleChanged: {
        if (visible) {
            ani = 1
            slideContainer.forceActiveFocus()
        } else {
            ani = 0
        }
    }

    // ── API helpers ───────────────────────────────────────────────────────
    function apiGet(url, callback) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    try { callback(JSON.parse(xhr.responseText), null) }
                    catch(e) { callback(null, "parse error: " + e) }
                } else {
                    callback(null, "HTTP " + xhr.status)
                }
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function apiPost(url, data, callback) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && callback)
                callback(xhr.status === 200)
        }
        xhr.open("POST", url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify(data))
    }

    // ── Close timer ───────────────────────────────────────────────────────
    Timer {
        id: closeTimer
        interval: 200
        repeat: false
        onTriggered: AppState.videoVisible = false
    }

    // ── Shared state ──────────────────────────────────────────────────────
    property var    currentSeries: null
    property int    rootTab: 0        // 0 = アニメ  1 = ドラマ
    property string searchText: ""

    // ── Slide-in container (slides from LEFT) ─────────────────────────────
    Rectangle {
        id: slideContainer
        anchors.fill: parent
        transform: Translate { x: -(1 - videoPanel.ani) * videoPanel.width }
        opacity: videoPanel.ani
        color: Qt.rgba(
            WallpaperManager.walBackground.r,
            WallpaperManager.walBackground.g,
            WallpaperManager.walBackground.b, 0.97)

        focus: true
        Keys.onEscapePressed: {
            if (videoPanel.searchText.length > 0) {
                videoPanel.searchText = ""
                searchInput.text = ""
            } else if (stack.depth > 1) {
                stack.pop()
            } else {
                AppState.videoVisible = false
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Top nav bar ───────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 32
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 0

                    // Back button
                    Rectangle {
                        visible: stack.depth > 1
                        width: 28; height: 28; radius: 6
                        color: backHov.containsMouse
                            ? Qt.rgba(1,1,1,0.08) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "󰁍"
                            font.pixelSize: 16
                            color: WallpaperManager.walColor5
                        }
                        MouseArea {
                            id: backHov; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: stack.pop()
                        }
                    }
                    Item { visible: stack.depth === 1; width: 28; height: 28 }

                    Item { Layout.fillWidth: true }

                    // アニメ tab
                    Rectangle {
                        visible: stack.depth === 1
                        width: animeLabel.implicitWidth + 20; height: 24; radius: 6
                        color: videoPanel.rootTab === 0
                            ? Qt.rgba(WallpaperManager.walColor5.r,
                                      WallpaperManager.walColor5.g,
                                      WallpaperManager.walColor5.b, 0.18)
                            : animeTabHov.containsMouse
                                ? Qt.rgba(1,1,1,0.06) : "transparent"
                        border.width: videoPanel.rootTab === 0 ? 1 : 0
                        border.color: Qt.rgba(WallpaperManager.walColor5.r,
                            WallpaperManager.walColor5.g,
                            WallpaperManager.walColor5.b, 0.35)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            id: animeLabel; anchors.centerIn: parent
                            text: "アニメ"
                            font.pixelSize: 12
                            font.bold: videoPanel.rootTab === 0
                            color: videoPanel.rootTab === 0
                                ? WallpaperManager.walColor5
                                : WallpaperManager.walColor8
                        }
                        MouseArea {
                            id: animeTabHov; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: videoPanel.rootTab = 0
                        }
                    }

                    Item { visible: stack.depth === 1; width: 6 }

                    // ドラマ tab
                    Rectangle {
                        visible: stack.depth === 1
                        width: dramaLabel.implicitWidth + 20; height: 24; radius: 6
                        color: videoPanel.rootTab === 1
                            ? Qt.rgba(WallpaperManager.walColor5.r,
                                      WallpaperManager.walColor5.g,
                                      WallpaperManager.walColor5.b, 0.18)
                            : dramaTabHov.containsMouse
                                ? Qt.rgba(1,1,1,0.06) : "transparent"
                        border.width: videoPanel.rootTab === 1 ? 1 : 0
                        border.color: Qt.rgba(WallpaperManager.walColor5.r,
                            WallpaperManager.walColor5.g,
                            WallpaperManager.walColor5.b, 0.35)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            id: dramaLabel; anchors.centerIn: parent
                            text: "ドラマ"
                            font.pixelSize: 12
                            font.bold: videoPanel.rootTab === 1
                            color: videoPanel.rootTab === 1
                                ? WallpaperManager.walColor5
                                : WallpaperManager.walColor8
                        }
                        MouseArea {
                            id: dramaTabHov; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: videoPanel.rootTab = 1
                        }
                    }

                    Item { Layout.fillWidth: true }
                }



                // Drilled-in title
                Text {
                    visible: stack.depth > 1
                    enabled: stack.depth > 1
                    anchors.centerIn: parent
                    width: parent.width - 100
                    text: videoPanel.currentSeries ? videoPanel.currentSeries.name : ""
                    color: WallpaperManager.walForeground
                    font.pixelSize: 13; font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }

            // ── Search bar (library only) ─────────────────────────────────
            Rectangle {
                visible: stack.depth === 1
                Layout.fillWidth: true
                height: 32
                color: "transparent"

                Rectangle {
                    anchors {
                        fill: parent
                        leftMargin: 8; rightMargin: 8; topMargin: 2; bottomMargin: 4
                    }
                    radius: 6
                    color: Qt.rgba(1,1,1,0.05)
                    border.width: searchInput.activeFocus ? 1 : 0
                    border.color: Qt.rgba(WallpaperManager.walColor5.r,
                        WallpaperManager.walColor5.g,
                        WallpaperManager.walColor5.b, 0.4)
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 6
                        spacing: 6

                        Text {
                            text: "󰍉"
                            font.pixelSize: 12
                            color: WallpaperManager.walColor8
                            opacity: 0.5
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            text: videoPanel.searchText
                            onTextChanged: videoPanel.searchText = text
                            color: WallpaperManager.walForeground
                            font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            Keys.onEscapePressed: {
                                if (text.length > 0) {
                                    videoPanel.searchText = ""
                                    text = ""
                                } else {
                                    AppState.videoVisible = false
                                }
                            }
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "検索..."
                                color: WallpaperManager.walColor8
                                font.pixelSize: 12
                                opacity: 0.35
                                visible: searchInput.text.length === 0
                            }
                        }

                        Rectangle {
                            visible: videoPanel.searchText.length > 0
                            width: 16; height: 16; radius: 8
                            color: clearHov.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                            Text {
                                anchors.centerIn: parent
                                text: "✕"; font.pixelSize: 8
                                color: WallpaperManager.walColor8
                            }
                            MouseArea {
                                id: clearHov; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { videoPanel.searchText = ""; searchInput.text = "" }
                            }
                        }
                    }
                }
            }

            // ── StackView ─────────────────────────────────────────────────
            StackView {
                id: stack
                Layout.fillWidth: true
                Layout.fillHeight: true
                initialItem: libraryComponent

                pushEnter: Transition {
                    NumberAnimation { property: "x"; from: -stack.width; to: 0
                        duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
                }
                pushExit: Transition {
                    NumberAnimation { property: "x"; from: 0; to: stack.width * 0.3
                        duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 180 }
                }
                popEnter: Transition {
                    NumberAnimation { property: "x"; from: stack.width * 0.3; to: 0
                        duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
                }
                popExit: Transition {
                    NumberAnimation { property: "x"; from: 0; to: -stack.width
                        duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 180 }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ── Library grid component ────────────────────────────────────────────
    // ══════════════════════════════════════════════════════════════════════
    Component {
        id: libraryComponent
        Item {
            id: libRoot

            property var  allSeries: []
            property var  displaySeries: []
            property bool loading: false
            property int  retryInterval: 800

            function filterByTab() {
                var cat = videoPanel.rootTab === 0 ? "anime" : "drama"
                var query = videoPanel.searchText.toLowerCase()
                var filtered = []
                for (var i = 0; i < allSeries.length; i++) {
                    if (allSeries[i].category !== cat) continue
                    if (query.length > 0 && allSeries[i].name.toLowerCase().indexOf(query) === -1) continue
                    filtered.push(allSeries[i])
                }
                displaySeries = filtered
            }

            function loadLibrary() {
                loading = true
                videoPanel.apiGet("http://127.0.0.1:5176/library", function(data, err) {
                    loading = false
                    if (err || !data || !Array.isArray(data) || data.length === 0) {
                        retryInterval = Math.min(retryInterval * 2, 5000)
                        retryTimer.interval = retryInterval
                        return
                    }
                    retryTimer.stop()
                    retryInterval = 800
                    allSeries = data
                    filterByTab()
                })
            }

            Connections {
                target: videoPanel
                function onRootTabChanged() { libRoot.filterByTab() }
                function onSearchTextChanged() { libRoot.filterByTab() }
                function onVisibleChanged() {
                    if (videoPanel.visible) {
                        if (libRoot.allSeries.length === 0) {
                            // No cache yet — load immediately
                            libRoot.retryInterval = 800
                            retryTimer.interval = 800
                            retryTimer.start()
                        }
                        // If we already have data, inotify handles invalidation
                        // so no need to reload on every open
                    } else {
                        retryTimer.stop()
                        videoPanel.searchText = ""
                    }
                }
            }

            Timer {
                id: retryTimer
                interval: libRoot.retryInterval
                repeat: true
                onTriggered: {
                    if (!videoPanel.visible) { stop(); return }
                    libRoot.loadLibrary()
                }
            }

            Component.onCompleted: retryTimer.start()

            // ── Content ───────────────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Loading / empty states
                Item {
                    visible: libRoot.loading || libRoot.displaySeries.length === 0
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Text {
                        anchors.centerIn: parent
                        text: libRoot.loading ? "読み込み中..."
                            : videoPanel.searchText.length > 0 ? "一致なし"
                            : "動画なし"
                        color: WallpaperManager.walColor8
                        font.pixelSize: 13; opacity: 0.45
                    }
                }

                // 3-column cover grid
                ScrollView {
                    visible: !libRoot.loading && libRoot.displaySeries.length > 0
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ScrollBar.vertical.width: 4

                    GridView {
                        id: seriesGrid
                        anchors.fill: parent
                        anchors.margins: 4
                        cellWidth:  Math.floor(width / 3)
                        cellHeight: cellWidth * 1.65
                        boundsBehavior: Flickable.StopAtBounds
                        model: libRoot.displaySeries

                        delegate: Item {
                            width:  seriesGrid.cellWidth
                            height: seriesGrid.cellHeight

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 3
                                color: "transparent"
                                radius: 0

                                Rectangle {
                                    id: coverRect
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: parent.height - titleArea.height
                                    color: Qt.rgba(
                                        WallpaperManager.walColor1.r,
                                        WallpaperManager.walColor1.g,
                                        WallpaperManager.walColor1.b, 0.6)
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.cover || ""
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true; asynchronous: true
                                    }

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 3
                                        color: Qt.rgba(0,0,0,0.5)
                                        visible: modelData.episode_count > 0
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                                * (modelData.watched_count / Math.max(1, modelData.episode_count))
                                            color: WallpaperManager.walColor5
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Qt.rgba(1,1,1,0.07)
                                        visible: cellHov.containsMouse
                                        Behavior on opacity { NumberAnimation { duration: 80 } }
                                    }

                                    Rectangle {
                                        visible: modelData.watched_count > 0
                                        anchors.top: parent.top; anchors.right: parent.right
                                        anchors.margins: 4
                                        width: badgeTxt.implicitWidth + 8; height: 16; radius: 8
                                        color: Qt.rgba(
                                            WallpaperManager.walColor5.r,
                                            WallpaperManager.walColor5.g,
                                            WallpaperManager.walColor5.b, 0.85)
                                        Text {
                                            id: badgeTxt
                                            anchors.centerIn: parent
                                            text: modelData.watched_count + "/" + modelData.episode_count
                                            font.pixelSize: 8; font.bold: true
                                            color: WallpaperManager.walBackground
                                        }
                                    }
                                }

                                Item {
                                    id: titleArea
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 36

                                    Column {
                                        anchors.fill: parent
                                        anchors.topMargin: 4
                                        anchors.leftMargin: 3
                                        anchors.rightMargin: 3
                                        spacing: 1
                                        Text {
                                            width: parent.width
                                            text: modelData.name || ""
                                            color: WallpaperManager.walForeground
                                            font.pixelSize: 10; font.bold: true
                                            elide: Text.ElideRight
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                        }
                                        Text {
                                            text: modelData.episode_count + " 話"
                                            color: WallpaperManager.walColor5
                                            font.pixelSize: 9; opacity: 0.75
                                        }
                                    }
                                }

                                MouseArea {
                                    id: cellHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        slideContainer.forceActiveFocus()
                                        videoPanel.currentSeries = modelData
                                        stack.push(episodeComponent, {"series": modelData})
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ── Episode list component ────────────────────────────────────────────
    // ══════════════════════════════════════════════════════════════════════
    Component {
        id: episodeComponent
        Item {
            id: epRoot

            property var series: videoPanel.currentSeries || {}
            property var seriesEpisodes: series.episodes || []

            Component.onCompleted: progressRefreshTimer.start()

            Connections {
                target: videoPanel
                function onVisibleChanged() {
                    if (videoPanel.visible) {
                        progressRefreshTimer.restart()
                        progressTimeoutTimer.restart()
                    }
                }
            }

            // Delay gives mpv time to flush watch_later file after closing
            Timer {
                id: progressRefreshTimer
                interval: 1500
                repeat: false
                onTriggered: epRoot.refreshProgress()
            }

            // Second refresh 5s after open — catches slow mpv watch_later flushes
            Timer {
                id: progressTimeoutTimer
                interval: 5000
                repeat: false
                onTriggered: epRoot.refreshProgress()
            }

            // Single bulk request instead of N individual XHRs
            function refreshProgress() {
                if (!epRoot.series || !epRoot.series.episodes) return
                var eps = epRoot.series.episodes
                if (eps.length === 0) return

                var paths = []
                for (var i = 0; i < eps.length; i++)
                    paths.push(eps[i].path)

                var xhr = new XMLHttpRequest()
                xhr.onreadystatechange = function() {
                    if (xhr.readyState !== 4 || xhr.status !== 200) return
                    var progressMap
                    try { progressMap = JSON.parse(xhr.responseText) }
                    catch(e) { return }

                    progressRefreshTimer.stop()
                    progressTimeoutTimer.stop()

                    var updated = []
                    var wc = 0
                    for (var j = 0; j < eps.length; j++) {
                        var ep = JSON.parse(JSON.stringify(eps[j]))
                        var prog = progressMap[ep.path]
                        if (prog) {
                            ep.position        = prog.position
                            ep.watched         = prog.watched
                            ep.progress_exists = prog.exists
                        }
                        if (ep.watched) wc++
                        updated.push(ep)
                    }

                    var updatedSeries = {
                        "id":            epRoot.series.id,
                        "name":          epRoot.series.name,
                        "category":      epRoot.series.category,
                        "cover":         epRoot.series.cover,
                        "episode_count": epRoot.series.episode_count,
                        "watched_count": wc,
                        "episodes":      updated
                    }
                    epRoot.series = updatedSeries
                    epRoot.seriesEpisodes = updated

                    // Sync back to library cache so grid shows correct progress immediately
                    videoPanel.currentSeries = updatedSeries
                    var lib = stack.get(0)
                    if (lib && lib.allSeries) {
                        var newAll = lib.allSeries.slice()
                        for (var k = 0; k < newAll.length; k++) {
                            if (newAll[k].id === updatedSeries.id) {
                                newAll[k] = updatedSeries
                                break
                            }
                        }
                        lib.allSeries = newAll
                        lib.filterByTab()
                    }
                }
                xhr.open("POST", "http://127.0.0.1:5176/progress_bulk")
                xhr.setRequestHeader("Content-Type", "application/json")
                xhr.send(JSON.stringify({ paths: paths }))
            }

            function formatPosition(seconds) {
                if (seconds <= 0) return ""
                var m = Math.floor(seconds / 60)
                var s = Math.floor(seconds % 60)
                return m + ":" + (s < 10 ? "0" : "") + s
            }

            function episodeLabel(filename, category) {
                if (category === "anime") {
                    var m = filename.match(/-\s*(\d+)/)
                    if (m) return "第" + parseInt(m[1]) + "話"
                }
                if (category === "drama") {
                    var m2 = filename.match(/[Ss](\d+)[Ee](\d+)/)
                    if (m2) return "S" + parseInt(m2[1]) + " E" + parseInt(m2[2])
                }
                return ""
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ── Series header ─────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: headerRow.implicitHeight + 24
                    color: "transparent"

                    RowLayout {
                        id: headerRow
                        anchors {
                            left: parent.left; right: parent.right
                            top: parent.top
                            margins: 14
                        }
                        spacing: 14

                        Rectangle {
                            width: 72; height: 100; clip: true
                            color: Qt.rgba(
                                WallpaperManager.walColor1.r,
                                WallpaperManager.walColor1.g,
                                WallpaperManager.walColor1.b, 0.6)
                            Image {
                                anchors.fill: parent
                                source: epRoot.series.cover || ""
                                fillMode: Image.PreserveAspectCrop
                                smooth: true; asynchronous: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: epRoot.series.name || ""
                                color: WallpaperManager.walForeground
                                font.pixelSize: 15; font.bold: true
                                wrapMode: Text.Wrap
                            }

                            Rectangle {
                                width: catLabel.implicitWidth + 16; height: 22; radius: 11
                                color: Qt.rgba(
                                    WallpaperManager.walColor5.r,
                                    WallpaperManager.walColor5.g,
                                    WallpaperManager.walColor5.b, 0.15)
                                border.width: 1
                                border.color: Qt.rgba(
                                    WallpaperManager.walColor5.r,
                                    WallpaperManager.walColor5.g,
                                    WallpaperManager.walColor5.b, 0.3)
                                Text {
                                    id: catLabel; anchors.centerIn: parent
                                    text: epRoot.series.category === "anime" ? "アニメ" : "ドラマ"
                                    font.pixelSize: 10
                                    color: WallpaperManager.walColor5
                                }
                            }

                            Text {
                                text: (epRoot.series.watched_count || 0) + " / "
                                    + (epRoot.series.episode_count || 0) + " 視聴済み"
                                color: WallpaperManager.walColor8
                                font.pixelSize: 11; opacity: 0.65
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 3
                                color: Qt.rgba(1,1,1,0.07)
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                        * ((epRoot.series.watched_count || 0)
                                           / Math.max(1, epRoot.series.episode_count || 1))
                                    color: WallpaperManager.walColor5
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 30; color: "transparent"
                    Text {
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        text: "エピソード (" + (epRoot.series.episode_count || 0) + ")"
                        color: WallpaperManager.walColor5
                        font.pixelSize: 11; font.bold: true; opacity: 0.8
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left; anchors.right: parent.right
                        height: 1
                        color: Qt.rgba(WallpaperManager.walForeground.r,
                            WallpaperManager.walForeground.g,
                            WallpaperManager.walForeground.b, 0.06)
                    }
                }

                // ── Episode list ──────────────────────────────────────────
                ScrollView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ScrollBar.vertical.width: 4

                    Column {
                        width: epRoot.width

                        Repeater {
                            model: epRoot.seriesEpisodes.length

                            delegate: Rectangle {
                                property var ep: index < epRoot.seriesEpisodes.length
                                    ? epRoot.seriesEpisodes[index] : {}
                                readonly property string label: epRoot.episodeLabel(
                                    ep.filename || "", epRoot.series.category || "")
                                readonly property bool watched: ep.watched || false
                                readonly property bool inProgress: ep.progress_exists && !ep.watched

                                width: epRoot.width; height: 52
                                color: epHov.containsMouse
                                    ? Qt.rgba(1,1,1,0.04) : "transparent"
                                Behavior on color { ColorAnimation { duration: 80 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14; anchors.rightMargin: 12
                                    spacing: 10

                                    // Episode number pill
                                    Rectangle {
                                        visible: label !== ""
                                        width: epNumLabel.implicitWidth + 12
                                        height: 20; radius: 4
                                        color: watched
                                            ? Qt.rgba(WallpaperManager.walColor5.r,
                                                      WallpaperManager.walColor5.g,
                                                      WallpaperManager.walColor5.b, 0.25)
                                            : Qt.rgba(1,1,1,0.06)
                                        Text {
                                            id: epNumLabel; anchors.centerIn: parent
                                            text: label
                                            font.pixelSize: 9; font.bold: true
                                            color: watched
                                                ? WallpaperManager.walColor5
                                                : WallpaperManager.walColor8
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: ep.filename || ""
                                            color: watched
                                                ? Qt.rgba(WallpaperManager.walForeground.r,
                                                          WallpaperManager.walForeground.g,
                                                          WallpaperManager.walForeground.b, 0.4)
                                                : WallpaperManager.walForeground
                                            font.pixelSize: 11
                                            elide: Text.ElideMiddle
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }

                                        Row {
                                            visible: inProgress && ep.position > 0
                                            spacing: 4
                                            Text {
                                                text: "󰐎"
                                                color: WallpaperManager.walColor5
                                                font.pixelSize: 9
                                            }
                                            Text {
                                                text: epRoot.formatPosition(ep.position || 0)
                                                color: WallpaperManager.walColor5
                                                font.pixelSize: 9; opacity: 0.8
                                            }
                                        }
                                    }

                                    // Watched / in-progress indicator
                                    // preferredWidth + maximumWidth both 0 when empty so
                                    // RowLayout allocates no space or spacing for it
                                    Text {
                                        text: watched ? "󰄬" : (inProgress ? "󰐎" : "")
                                        color: watched
                                            ? Qt.rgba(WallpaperManager.walColor5.r,
                                                      WallpaperManager.walColor5.g,
                                                      WallpaperManager.walColor5.b, 0.5)
                                            : WallpaperManager.walColor5
                                        font.pixelSize: 14
                                        visible: text !== ""
                                        Layout.preferredWidth: text !== "" ? implicitWidth : 0
                                        Layout.maximumWidth:   text !== "" ? implicitWidth : 0
                                    }

                                    // Play chevron
                                    Text {
                                        text: "›"
                                        color: WallpaperManager.walColor8
                                        font.pixelSize: 18; opacity: 0.4
                                    }
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.leftMargin: 14; height: 1
                                    color: Qt.rgba(WallpaperManager.walForeground.r,
                                        WallpaperManager.walForeground.g,
                                        WallpaperManager.walForeground.b, 0.04)
                                }

                                MouseArea {
                                    id: epHov; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            // Right-click toggles watched/unwatched
                                            videoPanel.apiPost(
                                                "http://127.0.0.1:5176/mark_watched",
                                                { path: ep.path, watched: !watched },
                                                function(ok) { if (ok) epRoot.refreshProgress() }
                                            )
                                            return
                                        }
                                        console.log("[video] launching:", ep.path)
                                        videoPanel.apiPost(
                                            "http://127.0.0.1:5176/play",
                                            { path: ep.path },
                                            null
                                        )
                                        closeTimer.start()
                                    }
                                }
                            }
                        }

                        Item { height: 20 }
                    }
                }
            }
        }
    }
}
