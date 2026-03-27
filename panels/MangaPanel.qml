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
    id: mangaPanel

    visible: AppState.mangaVisible
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; right: true }
    implicitWidth: stack.depth === 3 ? 800 : 480
    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    margins.top: -1
    color: "transparent"
    focusable: true
    WlrLayershell.keyboardFocus: AppState.mangaVisible
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-manga"

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
                    catch(e) { callback(null, "parse error: " + e.toString()) }
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

    // ── Shared state ──────────────────────────────────────────────────────
    property var currentSeries: null
    property var currentChapter: null
    property var favorites: []
    property int rootTab: 0   // 0 = Browser, 1 = Library
    property string searchText: ""

    function loadFavorites() {
        apiGet("http://127.0.0.1:5175/favorites", function(data, err) {
            if (data && Array.isArray(data)) mangaPanel.favorites = data
        })
    }

    function isFavorite(id) {
        for (var i = 0; i < favorites.length; i++)
            if (favorites[i].id === id) return true
        return false
    }

    function addFavorite(series) {
        apiPost("http://127.0.0.1:5175/favorites/add", {
            id: series.id, title: series.title,
            image: series.image,
            url: "https://rawkuma.net/manga/" + series.id + "/"
        }, function() { loadFavorites() })
    }

    function removeFavorite(id) {
        apiPost("http://127.0.0.1:5175/favorites/remove", { id: id },
            function() { loadFavorites() })
    }

    Component.onCompleted: loadFavorites()

    // ── Slide-in container ────────────────────────────────────────────────
    // FIX: ESC handling is on this Rectangle with focus:true, not on PanelWindow
    Rectangle {
        id: slideContainer
        anchors.fill: parent
        transform: Translate { x: (1 - mangaPanel.ani) * mangaPanel.width }
        opacity: mangaPanel.ani
        color: Qt.rgba(
            WallpaperManager.walBackground.r,
            WallpaperManager.walBackground.g,
            WallpaperManager.walBackground.b, 0.97)
        border.width: 0
        focus: true

        // Reclaim focus whenever user clicks anywhere in the panel
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onPressed: slideContainer.forceActiveFocus()
        }

        Keys.onEscapePressed: {
            if (searchField.text.length > 0) {
                searchField.text = ""
                mangaPanel.searchText = ""
            } else if (stack.depth > 1) {
                stack.pop()
            } else {
                AppState.mangaVisible = false
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Top nav bar ───────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: (stack.depth === 1 && mangaPanel.rootTab === 0) ? 72 : 40
                color: "transparent"
                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                // Tab row + back button
                RowLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 6
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    height: 28
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

                    // Tabs (only on root)
                    Row {
                        visible: stack.depth === 1
                        spacing: 6

                        Repeater {
                            model: [{ label: "ブラウザ", idx: 0 }, { label: "ライブラリ", idx: 1 }]
                            Rectangle {
                                property bool active: mangaPanel.rootTab === modelData.idx
                                width: lbl.implicitWidth + 20; height: 28; radius: 6
                                color: active
                                    ? Qt.rgba(WallpaperManager.walColor5.r,
                                              WallpaperManager.walColor5.g,
                                              WallpaperManager.walColor5.b, 0.18)
                                    : th.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent"
                                border.width: active ? 1 : 0
                                border.color: Qt.rgba(WallpaperManager.walColor5.r,
                                    WallpaperManager.walColor5.g,
                                    WallpaperManager.walColor5.b, 0.35)
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    id: lbl; anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: 12; font.bold: active
                                    color: active ? WallpaperManager.walColor5
                                                  : WallpaperManager.walColor8
                                }
                                MouseArea {
                                    id: th; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: mangaPanel.rootTab = modelData.idx
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Drilled-in title (depth > 1)
                    Text {
                        visible: stack.depth > 1
                        width: mangaPanel.width - 100
                        text: {
                            if (stack.depth === 3)
                                return mangaPanel.currentChapter
                                    ? mangaPanel.currentChapter.title : "リーダー"
                            if (stack.depth === 2)
                                return mangaPanel.currentSeries
                                    ? mangaPanel.currentSeries.title : "シリーズ"
                            return ""
                        }
                        color: WallpaperManager.walForeground
                        font.pixelSize: 13; font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }

                // ── Search bar (only visible on browser tab, root) ────────
                Rectangle {
                    visible: stack.depth === 1 && mangaPanel.rootTab === 0
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 8; anchors.rightMargin: 8
                    anchors.bottomMargin: 4
                    height: 26; radius: 6
                    color: Qt.rgba(1,1,1,0.05)
                    border.width: searchField.activeFocus ? 1 : 0
                    border.color: Qt.rgba(WallpaperManager.walColor5.r,
                        WallpaperManager.walColor5.g,
                        WallpaperManager.walColor5.b, 0.4)
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 6
                        spacing: 6

                        Text {
                            text: "󰍉"; font.pixelSize: 12
                            color: WallpaperManager.walColor8; opacity: 0.5
                        }

                        TextInput {
                            id: searchField
                            Layout.fillWidth: true
                            color: WallpaperManager.walForeground
                            font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true

                            onTextChanged: mangaPanel.searchText = text

                            Keys.onEscapePressed: {
                                if (text.length > 0) {
                                    text = ""
                                } else {
                                    slideContainer.forceActiveFocus()
                                }
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "検索..."
                                color: WallpaperManager.walColor8
                                font.pixelSize: 12
                                opacity: 0.35
                                visible: searchField.text.length === 0
                            }
                        }

                        // Clear button
                        Rectangle {
                            visible: searchField.text.length > 0
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
                                onClicked: { searchField.text = ""; mangaPanel.searchText = "" }
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
                initialItem: browseComponent

                pushEnter: Transition {
                    NumberAnimation { property: "x"; from: stack.width; to: 0
                        duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
                }
                pushExit: Transition {
                    NumberAnimation { property: "x"; from: 0; to: -stack.width * 0.3
                        duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 180 }
                }
                popEnter: Transition {
                    NumberAnimation { property: "x"; from: -stack.width * 0.3; to: 0
                        duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
                }
                popExit: Transition {
                    NumberAnimation { property: "x"; from: 0; to: stack.width
                        duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 180 }
                }
            }
        }
    }

    // ── Browse component ──────────────────────────────────────────────────
    Component {
        id: browseComponent
        Item {
            id: browseStack

            property var  browseItems: []
            property bool loading: false
            property int  currentPage: 1
            property real lastLoadTime: 0  // ms timestamp of last successful page 1 load

            // Client-side filter over cached browse items — no server round-trip needed
            property var gridItems: {
                if (mangaPanel.rootTab === 1) return mangaPanel.favorites
                var q = mangaPanel.searchText.trim().toLowerCase()
                if (q.length === 0) return browseItems
                var filtered = []
                for (var i = 0; i < browseItems.length; i++) {
                    if (browseItems[i].title.toLowerCase().indexOf(q) !== -1)
                        filtered.push(browseItems[i])
                }
                return filtered
            }

            function loadPage(p) {
                if (mangaPanel.rootTab === 1) return
                loading = true
                currentPage = p
                mangaPanel.apiGet("http://127.0.0.1:5175/latest?page=" + p, function(data, err) {
                    if (err) {
                        console.log("browse err:", err)
                        loading = false
                        if (mangaPanel.visible && browseItems.length === 0)
                            retryTimer.start()
                        return
                    }
                    if (data && Array.isArray(data)) {
                        browseItems = data.slice()
                        if (p === 1) lastLoadTime = Date.now()
                    }
                    loading = false
                })
            }

            Connections {
                target: mangaPanel
                function onRootTabChanged() {
                    if (mangaPanel.rootTab === 1) {
                        loading = false
                    } else {
                        if (browseStack.browseItems.length === 0)
                            browseStack.loadPage(1)
                    }
                }
                function onFavoritesChanged() {}
                function onVisibleChanged() {
                    if (!mangaPanel.visible) return
                    if (mangaPanel.rootTab !== 0) return
                    // Reload if empty or cache older than 3 minutes
                    var age = Date.now() - browseStack.lastLoadTime
                    if (browseStack.browseItems.length === 0 || age > 3 * 60 * 1000)
                        retryTimer.start()
                }
            }

            Component.onCompleted: retryTimer.start()

            Timer {
                id: retryTimer
                interval: 800; repeat: false
                onTriggered: {
                    if (mangaPanel.rootTab === 0)
                        browseStack.loadPage(1)
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        visible: browseStack.loading
                        text: "読み込み中..."
                        color: WallpaperManager.walColor8
                        font.pixelSize: 13; opacity: 0.5
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !browseStack.loading && browseStack.gridItems.length === 0
                        text: mangaPanel.rootTab === 1 ? "お気に入りなし" : "結果なし"
                        color: WallpaperManager.walColor8
                        font.pixelSize: 13; opacity: 0.4
                    }

                    ScrollView {
                        anchors.fill: parent; clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        ScrollBar.vertical.width: 4
                        visible: !browseStack.loading

                        GridView {
                            id: gridView
                            anchors.fill: parent
                            anchors.margins: 4
                            cellWidth:  Math.floor(width / 3)
                            cellHeight: cellWidth * 1.6
                            boundsBehavior: Flickable.StopAtBounds

                            model: browseStack.gridItems

                            delegate: Item {
                                width:  gridView.cellWidth
                                height: gridView.cellHeight

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    color: "transparent"

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: parent.height - titleArea.height
                                        color: Qt.rgba(0,0,0,0.3)
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: modelData.image || ""
                                            fillMode: Image.PreserveAspectCrop
                                            smooth: true; asynchronous: true; cache: true
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            color: Qt.rgba(1,1,1,0.08)
                                            visible: cellHov.containsMouse
                                        }
                                    }

                                    Item {
                                        id: titleArea
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 38

                                        Column {
                                            anchors.fill: parent
                                            anchors.topMargin: 3
                                            anchors.leftMargin: 2
                                            anchors.rightMargin: 2
                                            spacing: 1
                                            Text {
                                                width: parent.width
                                                text: modelData.title || ""
                                                color: WallpaperManager.walForeground
                                                font.pixelSize: 10; font.bold: true
                                                elide: Text.ElideRight
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                            }
                                            Text {
                                                visible: (modelData.chapter || "") !== ""
                                                width: parent.width
                                                text: modelData.chapter ? "Ch." + modelData.chapter : ""
                                                color: WallpaperManager.walColor5
                                                font.pixelSize: 9; opacity: 0.8
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: cellHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            mangaPanel.currentSeries = modelData
                                            stack.push(seriesComponent)
                                        }
                                    }
                                }
                            }

                            // Pagination — only shown on browse tab, not library, not search
                            footer: Rectangle {
                                width: gridView.width; height: 48
                                color: "transparent"
                                visible: mangaPanel.rootTab === 0 && !browseStack.isSearching

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Repeater {
                                        model: 5
                                        Rectangle {
                                            width: 32; height: 32; radius: 6
                                            color: browseStack.currentPage === (index + 1)
                                                ? Qt.rgba(WallpaperManager.walColor5.r,
                                                          WallpaperManager.walColor5.g,
                                                          WallpaperManager.walColor5.b, 0.25)
                                                : pageHov.containsMouse
                                                    ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
                                            border.width: browseStack.currentPage === (index + 1) ? 1 : 0
                                            border.color: Qt.rgba(WallpaperManager.walColor5.r,
                                                WallpaperManager.walColor5.g,
                                                WallpaperManager.walColor5.b, 0.4)
                                            Behavior on color { ColorAnimation { duration: 80 } }
                                            Text {
                                                anchors.centerIn: parent
                                                text: index + 1
                                                font.pixelSize: 12
                                                font.bold: browseStack.currentPage === (index + 1)
                                                color: browseStack.currentPage === (index + 1)
                                                    ? WallpaperManager.walColor5
                                                    : WallpaperManager.walColor8
                                            }
                                            MouseArea {
                                                id: pageHov; anchors.fill: parent
                                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: browseStack.loadPage(index + 1)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Series component ──────────────────────────────────────────────────
    Component {
        id: seriesComponent
        Item {
            id: seriesRoot
            property var seriesData: null
            property bool loading: true
            property var readChapters: []

            function load() {
                loading = true
                seriesData = null
                var slug = mangaPanel.currentSeries.id
                mangaPanel.apiGet(
                    "http://127.0.0.1:5175/info?id=" + slug,
                    function(d, err) {
                        if (err) console.log("series err:", err)
                        if (d) seriesData = d
                        loading = false
                    })
                mangaPanel.apiGet(
                    "http://127.0.0.1:5175/progress?id=" + slug,
                    function(d, err) {
                        if (d && Array.isArray(d)) readChapters = d
                    })
            }

            function isRead(chapterId) {
                for (var i = 0; i < readChapters.length; i++)
                    if (readChapters[i] === chapterId) return true
                return false
            }

            function markRead(chapterId) {
                if (!isRead(chapterId)) {
                    readChapters = readChapters.concat([chapterId])
                    mangaPanel.apiPost("http://127.0.0.1:5175/progress/set", {
                        manga_id: mangaPanel.currentSeries.id,
                        chapter_id: chapterId
                    }, null)
                }
            }

            Component.onCompleted: load()

            ScrollView {
                anchors.fill: parent; clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.vertical.width: 4

                ColumnLayout {
                    width: seriesRoot.width
                    spacing: 0

                    Item {
                        visible: seriesRoot.loading
                        Layout.fillWidth: true; height: 200
                        Text {
                            anchors.centerIn: parent
                            text: "読み込み中..."
                            color: WallpaperManager.walColor8
                            font.pixelSize: 13; opacity: 0.5
                        }
                    }

                    Item {
                        visible: !seriesRoot.loading && seriesRoot.seriesData !== null
                        Layout.fillWidth: true
                        implicitHeight: headerCol.implicitHeight + 24

                        ColumnLayout {
                            id: headerCol
                            anchors {
                                left: parent.left; right: parent.right
                                top: parent.top; margins: 14
                            }
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true; spacing: 14

                                Rectangle {
                                    width: 80; height: 110
                                    color: Qt.rgba(0,0,0,0.3); clip: true; radius: 4
                                    Image {
                                        anchors.fill: parent
                                        source: mangaPanel.currentSeries
                                            ? mangaPanel.currentSeries.image : ""
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true; asynchronous: true
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 6

                                    Text {
                                        Layout.fillWidth: true
                                        text: seriesRoot.seriesData
                                            ? (seriesRoot.seriesData.title || "") : ""
                                        color: WallpaperManager.walForeground
                                        font.pixelSize: 14; font.bold: true
                                        wrapMode: Text.Wrap
                                    }

                                    Row {
                                        spacing: 8
                                        Text {
                                            visible: seriesRoot.seriesData &&
                                                (seriesRoot.seriesData.status || "") !== ""
                                            text: seriesRoot.seriesData
                                                ? (seriesRoot.seriesData.status || "") : ""
                                            color: WallpaperManager.walColor5
                                            font.pixelSize: 11
                                        }
                                        Text {
                                            visible: seriesRoot.seriesData &&
                                                (seriesRoot.seriesData.type || "") !== ""
                                            text: seriesRoot.seriesData
                                                ? (seriesRoot.seriesData.type || "") : ""
                                            color: WallpaperManager.walColor8
                                            font.pixelSize: 11; opacity: 0.6
                                        }
                                    }

                                    Rectangle {
                                        property bool faved: mangaPanel.currentSeries
                                            ? mangaPanel.isFavorite(mangaPanel.currentSeries.id) : false
                                        width: favTxt.implicitWidth + 20; height: 28; radius: 6
                                        color: faved
                                            ? Qt.rgba(WallpaperManager.walColor5.r,
                                                      WallpaperManager.walColor5.g,
                                                      WallpaperManager.walColor5.b, 0.2)
                                            : Qt.rgba(1,1,1,0.06)
                                        border.width: 1
                                        border.color: Qt.rgba(WallpaperManager.walColor5.r,
                                            WallpaperManager.walColor5.g,
                                            WallpaperManager.walColor5.b, 0.3)
                                        Text {
                                            id: favTxt; anchors.centerIn: parent
                                            text: parent.faved ? "󰓎 お気に入り済み" : "󰓒 追加"
                                            font.pixelSize: 11
                                            color: WallpaperManager.walColor5
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var id = mangaPanel.currentSeries.id
                                                if (mangaPanel.isFavorite(id))
                                                    mangaPanel.removeFavorite(id)
                                                else
                                                    mangaPanel.addFavorite(
                                                        seriesRoot.seriesData
                                                        || mangaPanel.currentSeries)
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: seriesRoot.seriesData &&
                                    (seriesRoot.seriesData.synopsis || "") !== ""
                                Layout.fillWidth: true
                                text: seriesRoot.seriesData
                                    ? (seriesRoot.seriesData.synopsis || "") : ""
                                color: WallpaperManager.walColor8
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                maximumLineCount: 4; elide: Text.ElideRight; opacity: 0.7
                            }
                        }
                    }

                    Rectangle {
                        visible: !seriesRoot.loading && seriesRoot.seriesData !== null
                        Layout.fillWidth: true; height: 32; color: "transparent"
                        Text {
                            anchors { left: parent.left; leftMargin: 14
                                verticalCenter: parent.verticalCenter }
                            text: seriesRoot.seriesData
                                ? ("チャプター ("
                                   + (seriesRoot.seriesData.chapters
                                      ? seriesRoot.seriesData.chapters.length : 0)
                                   + ")")
                                : ""
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

                    Repeater {
                        model: (!seriesRoot.loading && seriesRoot.seriesData !== null)
                            ? seriesRoot.seriesData.chapters.length : 0

                        delegate: Rectangle {
                            readonly property var ch: (seriesRoot.seriesData && seriesRoot.seriesData.chapters)
                                ? seriesRoot.seriesData.chapters[index] : {}
                            readonly property bool read: seriesRoot.isRead(ch.id || "")
                            width: seriesRoot.width; height: 48
                            color: chHov.containsMouse ? Qt.rgba(1,1,1,0.04) : "transparent"
                            // FIX: no flicker — use initialized guard
                            property bool initialized: false
                            Component.onCompleted: Qt.callLater(function() { initialized = true })
                            Behavior on opacity { enabled: initialized; NumberAnimation { duration: 150 } }
                            opacity: read ? 0.35 : 1.0
                            Behavior on color { ColorAnimation { duration: 80 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14; anchors.rightMargin: 14
                                spacing: 8
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: ch.title || ""
                                        color: WallpaperManager.walForeground
                                        font.pixelSize: 12; elide: Text.ElideRight
                                    }
                                    Text {
                                        visible: (ch.date || "") !== ""
                                        text: ch.date || ""
                                        color: WallpaperManager.walColor8
                                        font.pixelSize: 10; opacity: 0.5
                                    }
                                }
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
                                id: chHov; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    seriesRoot.markRead(ch.id)
                                    mangaPanel.currentChapter = ch
                                    stack.push(readerComponent)
                                }
                            }
                        }
                    }

                    Item { height: 20 }
                }
            }
        }
    }

    // ── Reader component ──────────────────────────────────────────────────
    Component {
        id: readerComponent
        Item {
            id: readerRoot
            focus: true
            property var  pages: []
            property bool loading: true
            property string nextUrl: ""
            property string currentUrl: mangaPanel.currentChapter
                ? mangaPanel.currentChapter.url : ""

            function load(url) {
                loading = true
                pages = []
                nextUrl = ""
                reader.currentIndex = 0
                mangaPanel.apiGet(
                    "http://127.0.0.1:5175/pages?url=" + encodeURIComponent(url),
                    function(d, err) {
                        if (err) console.log("reader err:", err)
                        if (d) {
                            pages = d.pages || []
                            nextUrl = d.nextUrl || ""
                        }
                        loading = false
                    })
            }

            Component.onCompleted: {
                forceActiveFocus()
                if (currentUrl) load(currentUrl)
            }

            // FIX: manga is read right-to-left, so left key = next page, right = previous
            Keys.onLeftPressed:  reader.currentIndex = Math.min(reader.currentIndex + 1, reader.count - 1)
            Keys.onRightPressed: reader.currentIndex = Math.max(reader.currentIndex - 1, 0)

            Text {
                anchors.centerIn: parent; visible: readerRoot.loading
                text: "読み込み中..."
                color: WallpaperManager.walColor8; font.pixelSize: 13; opacity: 0.5
            }

            Rectangle {
                visible: !readerRoot.loading && readerRoot.pages.length > 0
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 12
                width: pageCounter.implicitWidth + 20; height: 26; radius: 13
                color: Qt.rgba(0,0,0,0.6); z: 10
                Text {
                    id: pageCounter; anchors.centerIn: parent
                    text: (reader.currentIndex + 1) + " / " + readerRoot.pages.length
                    color: "white"; font.pixelSize: 11
                }
            }

            Rectangle {
                visible: !readerRoot.loading && readerRoot.nextUrl !== ""
                    && reader.currentIndex === reader.count - 1
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 44
                width: nextLabel.implicitWidth + 24; height: 34; radius: 8
                color: Qt.rgba(WallpaperManager.walColor5.r,
                               WallpaperManager.walColor5.g,
                               WallpaperManager.walColor5.b, 0.85)
                z: 10
                Text {
                    id: nextLabel; anchors.centerIn: parent
                    text: "次のチャプター →"
                    color: "white"; font.pixelSize: 12; font.bold: true
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: readerRoot.load(readerRoot.nextUrl)
                }
            }

            ListView {
                id: reader
                anchors.fill: parent
                visible: !readerRoot.loading
                focus: true
                orientation: ListView.Horizontal
                layoutDirection: Qt.RightToLeft
                snapMode: ListView.SnapOneItem
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: 200
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                model: readerRoot.pages.length
                keyNavigationEnabled: false

                delegate: Item {
                    readonly property var page: readerRoot.pages[index] || {}
                    width: reader.width
                    height: reader.height

                    Image {
                        id: pageImg
                        anchors.fill: parent
                        source: page.img || ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: reader.width
                        sourceSize.height: reader.height
                        smooth: true; asynchronous: true; cache: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0,0,0,0.3)
                        visible: pageImg.status !== Image.Ready
                        Text {
                            anchors.centerIn: parent
                            text: "p." + (page.page || "")
                            color: Qt.rgba(1,1,1,0.3); font.pixelSize: 11
                        }
                    }

                    // Left half = next page (RTL), right half = previous page
                    MouseArea {
                        x: 0; y: 0
                        width: reader.width / 2; height: reader.height
                        cursorShape: Qt.PointingHandCursor
                        onClicked: reader.currentIndex = Math.min(reader.currentIndex + 1, reader.count - 1)
                    }
                    MouseArea {
                        x: reader.width / 2; y: 0
                        width: reader.width / 2; height: reader.height
                        cursorShape: Qt.PointingHandCursor
                        onClicked: reader.currentIndex = Math.max(reader.currentIndex - 1, 0)
                    }
                }
            }
        }
    }
}
