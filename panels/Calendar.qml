import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../state"
import "../managers"

PanelWindow {
    id: calendarPanel

    visible: AppState.dashboardVisible
    WlrLayershell.namespace: "quickshell:calendar"
    WlrLayershell.keyboardFocus: AppState.dashboardVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; right: true }
    WlrLayershell.margins.top:   0
    WlrLayershell.margins.right: 0
    implicitWidth:  calRoot.implicitWidth
    implicitHeight: calRoot.implicitHeight
    color: "transparent"
    focusable: true

    MouseArea { anchors.fill: parent; onClicked: AppState.dashboardVisible = false; z: -1 }

    Rectangle {
        id: calRoot
        focus: true
        anchors { top: parent.top; right: parent.right }
        implicitWidth:  320
        implicitHeight: col.implicitHeight + 36
        radius: 0
        color: Qt.rgba(WallpaperManager.walBackground.r, WallpaperManager.walBackground.g, WallpaperManager.walBackground.b, 0.88)
        border.width: 0

        MouseArea { anchors.fill: parent; onClicked: {} }
        Keys.onEscapePressed: AppState.dashboardVisible = false

        // ── date state ────────────────────────────────────────────────────
        property int todayDay:   new Date().getDate()
        property int todayMonth: new Date().getMonth()
        property int todayYear:  new Date().getFullYear()
        property int viewMonth:  todayMonth
        property int viewYear:   todayYear

        readonly property var monthNames: ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]

        // Japanese public holidays; update this table when adding a new year.
        readonly property var holidays: ({
            "2026-01-01":"元日", "2026-01-12":"成人の日", "2026-02-11":"建国記念の日", "2026-02-23":"天皇誕生日", "2026-03-20":"春分の日", "2026-04-29":"昭和の日", "2026-05-03":"憲法記念日", "2026-05-04":"みどりの日", "2026-05-05":"こどもの日", "2026-05-06":"振替休日", "2026-07-20":"海の日", "2026-08-11":"山の日", "2026-09-21":"敬老の日", "2026-09-22":"国民の休日", "2026-09-23":"秋分の日", "2026-10-12":"スポーツの日", "2026-11-03":"文化の日", "2026-11-23":"勤労感謝の日",
            "2027-01-01":"元日", "2027-01-11":"成人の日", "2027-02-11":"建国記念の日", "2027-02-23":"天皇誕生日", "2027-03-21":"春分の日", "2027-03-22":"振替休日", "2027-04-29":"昭和の日", "2027-05-03":"憲法記念日", "2027-05-04":"みどりの日", "2027-05-05":"こどもの日", "2027-07-19":"海の日", "2027-08-11":"山の日", "2027-09-20":"敬老の日", "2027-09-23":"秋分の日", "2027-10-11":"スポーツの日", "2027-11-03":"文化の日", "2027-11-23":"勤労感謝の日",
            "2028-01-01":"元日", "2028-01-02":"振替休日", "2028-01-10":"成人の日", "2028-02-11":"建国記念の日", "2028-02-23":"天皇誕生日", "2028-03-20":"春分の日", "2028-04-29":"昭和の日", "2028-04-30":"振替休日", "2028-05-03":"憲法記念日", "2028-05-04":"みどりの日", "2028-05-05":"こどもの日", "2028-07-17":"海の日", "2028-08-11":"山の日", "2028-09-18":"敬老の日", "2028-09-22":"秋分の日", "2028-10-09":"スポーツの日", "2028-11-03":"文化の日", "2028-11-23":"勤労感謝の日",
            "2029-01-01":"元日", "2029-01-08":"成人の日", "2029-02-11":"建国記念の日", "2029-02-12":"振替休日", "2029-02-23":"天皇誕生日", "2029-03-20":"春分の日", "2029-04-29":"昭和の日", "2029-04-30":"振替休日", "2029-05-03":"憲法記念日", "2029-05-04":"みどりの日", "2029-05-05":"こどもの日", "2029-07-16":"海の日", "2029-08-11":"山の日", "2029-09-17":"敬老の日", "2029-09-23":"秋分の日", "2029-09-24":"振替休日", "2029-10-08":"スポーツの日", "2029-11-03":"文化の日", "2029-11-23":"勤労感謝の日",
            "2030-01-01":"元日", "2030-01-14":"成人の日", "2030-02-11":"建国記念の日", "2030-02-23":"天皇誕生日", "2030-03-20":"春分の日", "2030-04-29":"昭和の日", "2030-05-03":"憲法記念日", "2030-05-04":"みどりの日", "2030-05-05":"こどもの日", "2030-05-06":"振替休日", "2030-07-15":"海の日", "2030-08-11":"山の日", "2030-08-12":"振替休日", "2030-09-16":"敬老の日", "2030-09-23":"秋分の日", "2030-10-14":"スポーツの日", "2030-11-03":"文化の日", "2030-11-04":"振替休日", "2030-11-23":"勤労感謝の日"
        })

        readonly property var observances: ({
            "01-01":"元日", "02-03":"節分", "02-14":"バレンタインデー", "03-03":"ひな祭り", "03-14":"ホワイトデー",
            "07-07":"七夕", "10-31":"ハロウィン", "12-24":"クリスマス・イブ",
            "11-15":"七五三", "12-25":"クリスマス", "12-31":"大晦日"
        })

        readonly property var observanceRanges: [
            { start: "08-13", end: "08-16", name: "お盆" }
        ]

        readonly property var tokyoEvents: [
            { start: "2026-05-15", end: "2026-05-17", name: "三社祭" },
            { start: "2026-06-07", end: "2026-06-16", name: "山王祭" },
            { start: "2026-07-11", end: "2026-07-26", name: "Vket 2026 Summer" },
            { start: "2026-07-25", end: "2026-07-25", name: "隅田川花火大会" },
            { start: "2026-08-15", end: "2026-08-16", name: "コミックマーケット108" },
            { start: "2026-09-17", end: "2026-09-21", name: "東京ゲームショウ2026" }
        ]

        readonly property var holidayDescriptions: ({
            "元日":"年のはじめを祝う日",
            "節分":"季節の変わり目に豆まきや恵方巻きを楽しむ日",
            "成人の日":"大人になった青年を祝い、励ます日",
            "建国記念の日":"建国をしのび、国を愛する心を養う日",
            "天皇誕生日":"天皇の誕生日を祝う日",
            "春分の日":"自然をたたえ、生物をいつくしむ日",
            "昭和の日":"昭和の時代を振り返り、将来に思いをはせる日",
            "憲法記念日":"日本国憲法の施行を記念する日",
            "みどりの日":"自然に親しみ、その恩恵に感謝する日",
            "こどもの日":"子どもの幸福と成長を願い、母に感謝する日",
            "ひな祭り":"女の子の健やかな成長と幸せを願う日",
            "海の日":"海の恩恵に感謝し、日本の繁栄を願う日",
            "山の日":"山に親しみ、山の恩恵に感謝する日",
            "敬老の日":"高齢者を敬い、長寿を祝う日",
            "秋分の日":"祖先を敬い、亡くなった人々をしのぶ日",
            "スポーツの日":"スポーツを楽しみ、健康な心身を育む日",
            "文化の日":"自由と平和を愛し、文化をすすめる日",
            "勤労感謝の日":"勤労を尊び、生産を祝い、互いに感謝する日",
            "振替休日":"日曜日の祝日の代わりに設けられる休日",
            "国民の休日":"祝日に挟まれた平日に設けられる休日",
            "バレンタインデー":"恋人や大切な人に気持ちを伝える日",
            "ホワイトデー":"バレンタインデーのお返しをする日",
            "七夕":"短冊に願いを書き、星に祈る日",
            "お盆":"先祖を供養し、家族や故郷を思う時期",
            "ハロウィン":"仮装やお菓子を楽しむ行事",
            "七五三":"子どもの成長を祝い、健やかな未来を願う行事",
            "クリスマス・イブ":"クリスマスの前夜。家族や友人と過ごす日",
            "クリスマス":"イエス・キリストの誕生を祝う日",
            "大晦日":"一年の最後の日。新年を迎える準備をする日",
            "三社祭":"浅草神社で行われる東京を代表する祭り",
            "山王祭":"日枝神社で行われる江戸三大祭のひとつ",
            "Vket 2026 Summer":"VRChat上で開催されるバーチャルマーケット",
            "隅田川花火大会":"隅田川沿いで開催される東京の大規模な花火大会",
            "コミックマーケット108":"東京ビッグサイトで開催される同人誌・創作物の大規模イベント",
            "東京ゲームショウ2026":"ゲームの最新作や関連製品が集まる展示会"
        })

        function dateKey(day) {
            return viewYear + "-" + String(viewMonth + 1).padStart(2, "0") + "-" + String(day).padStart(2, "0")
        }

        function holidayName(day) {
            if (day < 1) return ""
            return holidays[dateKey(day)] || ""
        }

        function observanceRangeName(day) {
            var key = String(viewMonth + 1).padStart(2, "0") + "-" + String(day).padStart(2, "0")
            for (var i = 0; i < observanceRanges.length; i++) {
                var range = observanceRanges[i]
                if (key >= range.start && key <= range.end) return range.name
            }
            return ""
        }

        function tokyoEventName(day) {
            var key = dateKey(day)
            for (var i = 0; i < tokyoEvents.length; i++) {
                var event = tokyoEvents[i]
                if (key >= event.start && key <= event.end) return event.name
            }
            return ""
        }

        function eventName(day) {
            if (day < 1) return ""
            return holidayName(day) || observances[String(viewMonth + 1).padStart(2, "0") + "-" + String(day).padStart(2, "0")] || observanceRangeName(day) || tokyoEventName(day)
        }

        function holidayType(day, name) {
            if (!holidays[dateKey(day)]) {
                if (observanceRangeName(day) === name) return "期間イベント"
                return tokyoEventName(day) === name ? "東京イベント" : "文化・行事"
            }
            if (name === "振替休日") return "振替休日"
            if (name === "国民の休日") return "国民の休日"
            return "国民の祝日"
        }

        function holidayColor(day, name) {
            if (!holidays[dateKey(day)]) {
                if (observanceRangeName(day) === name) return "#64b5f6"
                return tokyoEventName(day) === name ? "#4db6ac" : "#ba68c8"
            }
            return name === "振替休日" || name === "国民の休日"
                ? "#ffb74d" : "#e57373"
        }

        property var selectedHoliday: null
        function showHoliday(cell) {
            if (!cell.holiday) return
            var p = cell.mapToItem(calRoot, 0, cell.height)
            selectedHoliday = {
                name: cell.holiday,
                type: holidayType(cell.dayNum, cell.holiday),
                description: holidayDescriptions[cell.holiday] || "",
                date: viewYear + "年" + (viewMonth + 1) + "月" + cell.dayNum + "日"
            }
            holidayPopup.x = Math.max(8, Math.min(p.x, calRoot.width - holidayPopup.width - 8))
            holidayPopup.y = Math.min(p.y, calRoot.height - holidayPopup.height - 8)
            holidayPopup.open()
        }

        // ── weather ───────────────────────────────────────────────────────
        property var    forecastDays:    []
        property double lastFetchTime:   0
        property int    fetchCooldown:   600000   // 10 min

        function fetchWeather() {
            var xhr = new XMLHttpRequest()
            xhr.open("GET",
                "https://api.open-meteo.com/v1/forecast" +
                "?latitude=35.68&longitude=139.69" +
                "&daily=weathercode,temperature_2m_max,temperature_2m_min" +
                "&timezone=auto&forecast_days=7")
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                try {
                    var d    = JSON.parse(xhr.responseText)
                    var days = []
                    var iconMap = { 0:"󰖙", 1:"󰖕", 2:"󰖕", 3:"󰖐" }
                    for (var i = 0; i < 7; i++) {
                        var code = d.daily.weathercode[i]
                        var icon = code === 0 ? "󰖙"
                                 : code <= 2  ? "󰖕"
                                 : code <= 3  ? "󰖐"
                                 : code <= 57 ? "󰖗"
                                 : code <= 67 ? "󰖖"
                                 : code <= 77 ? "󰖘"
                                 : code <= 82 ? "󰖖"
                                 :              "󰖓"
                        var date     = new Date(d.daily.time[i])
                        var dayNames = ["日","月","火","水","木","金","土"]
                        days.push({
                            day:  i === 0 ? "今日" : dayNames[date.getDay()],
                            icon: icon,
                            max:  Math.round(d.daily.temperature_2m_max[i]),
                            min:  Math.round(d.daily.temperature_2m_min[i])
                        })
                    }
                    calRoot.forecastDays = days
                } catch(e) {}
            }
            xhr.send()
        }

        Component.onCompleted: { fetchWeather(); lastFetchTime = Date.now() }

        Connections {
            target: AppState
            function onDashboardVisibleChanged() {
                if (!AppState.dashboardVisible) return
                calRoot.todayDay   = new Date().getDate()
                calRoot.todayMonth = new Date().getMonth()
                calRoot.todayYear  = new Date().getFullYear()
                calRoot.viewMonth  = calRoot.todayMonth
                calRoot.viewYear   = calRoot.todayYear
                var now = Date.now()
                if (now - calRoot.lastFetchTime > calRoot.fetchCooldown) {
                    calRoot.fetchWeather()
                    calRoot.lastFetchTime = now
                }
            }
        }

        ColumnLayout {
            id: col
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 18 }
            spacing: 14

            // Month nav
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "󰍞"; font.pixelSize: 18; font.family: "Hiragino Sans"; color: WallpaperManager.walColor8
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (calRoot.viewMonth === 0) { calRoot.viewMonth = 11; calRoot.viewYear-- } else calRoot.viewMonth-- } }
                }
                Text {
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                    text: calRoot.viewYear + "年  " + calRoot.monthNames[calRoot.viewMonth]
                    font.pixelSize: 14; font.family: "Hiragino Sans"; font.weight: Font.Medium; color: WallpaperManager.walForeground
                }
                Text {
                    text: "󰍟"; font.pixelSize: 18; font.family: "Hiragino Sans"; color: WallpaperManager.walColor8
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (calRoot.viewMonth === 11) { calRoot.viewMonth = 0; calRoot.viewYear++ } else calRoot.viewMonth++ } }
                }
            }

            // Day-of-week headers
            Grid {
                Layout.fillWidth: true; columns: 7; columnSpacing: 0; rowSpacing: 0
                Repeater {
                    model: ["日","月","火","水","木","金","土"]
                    Text { width: (calRoot.implicitWidth - 36) / 7; horizontalAlignment: Text.AlignHCenter; text: modelData; font.pixelSize: 11; font.family: "Hiragino Sans"; color: WallpaperManager.walColor8 }
                }
            }

            // Calendar grid
            Grid {
                id: calGrid
                Layout.fillWidth: true; columns: 7; columnSpacing: 0; rowSpacing: 4
                property int cellW: (calRoot.implicitWidth - 36) / 7
                property var days: {
                    var d = []
                    var firstDay = new Date(calRoot.viewYear, calRoot.viewMonth, 1).getDay()
                    for (var b = 0; b < firstDay; b++) d.push(-1)
                    var daysInMonth = new Date(calRoot.viewYear, calRoot.viewMonth + 1, 0).getDate()
                    for (var n = 1; n <= daysInMonth; n++) d.push(n)
                    while (d.length % 7 !== 0) d.push(-1)
                    return d
                }
                Repeater {
                    model: calGrid.days.length
                    Rectangle {
                        width: calGrid.cellW; height: calGrid.cellW; radius: width / 2
                        property int  dayNum:  calGrid.days[index]
                        property string holiday: calRoot.eventName(dayNum)
                        property color holidayAccent: calRoot.holidayColor(dayNum, holiday)
                        property bool isToday: dayNum > 0 && dayNum === calRoot.todayDay && calRoot.viewMonth === calRoot.todayMonth && calRoot.viewYear === calRoot.todayYear
                        color: isToday ? Qt.rgba(WallpaperManager.walColor5.r, WallpaperManager.walColor5.g, WallpaperManager.walColor5.b, 0.25) : "transparent"
                        border.color: isToday ? WallpaperManager.walColor5 : "transparent"; border.width: 1
                        Text {
                            anchors.centerIn: parent; text: dayNum > 0 ? dayNum : ""
                            anchors.verticalCenterOffset: parent.holiday ? -5 : 0
                            font.pixelSize: 13; font.family: "Hiragino Sans"; font.weight: parent.isToday ? Font.Bold : Font.Normal
                            color: parent.isToday ? WallpaperManager.walColor5 : parent.holiday ? parent.holidayAccent : WallpaperManager.walForeground
                        }
                        Text {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 2 }
                            text: parent.holiday
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font.pixelSize: 7; font.family: "Hiragino Sans"
                            color: parent.holidayAccent
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: parent.holiday !== ""
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calRoot.showHoliday(parent)
                        }
                    }
                }
            }

            Popup {
                id: holidayPopup
                parent: calRoot
                width: 200; height: 122
                padding: 12
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(WallpaperManager.walBackground.r, WallpaperManager.walBackground.g, WallpaperManager.walBackground.b, 0.98)
                    border.width: 1
                    border.color: WallpaperManager.walColor5
                }
                contentItem: Column {
                    spacing: 4
                    Text {
                        text: calRoot.selectedHoliday ? calRoot.selectedHoliday.name : ""
                        color: WallpaperManager.walForeground
                        font.family: "Hiragino Sans"; font.pixelSize: 14; font.bold: true
                    }
                    Text {
                        text: calRoot.selectedHoliday ? calRoot.selectedHoliday.type : ""
                        color: WallpaperManager.walColor5
                        font.family: "Hiragino Sans"; font.pixelSize: 10
                    }
                    Text {
                        width: parent.width
                        text: calRoot.selectedHoliday ? calRoot.selectedHoliday.description : ""
                        color: WallpaperManager.walForeground
                        font.family: "Hiragino Sans"; font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        text: calRoot.selectedHoliday ? calRoot.selectedHoliday.date : ""
                        color: WallpaperManager.walColor8
                        font.family: "Hiragino Sans"; font.pixelSize: 10
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(WallpaperManager.walColor5.r, WallpaperManager.walColor5.g, WallpaperManager.walColor5.b, 0.2) }

            // Weather forecast row
            Row {
                Layout.fillWidth: true; spacing: 0
                Repeater {
                    model: calRoot.forecastDays
                    Column {
                        width: (calRoot.implicitWidth - 36) / 7; spacing: 3
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.day;        font.pixelSize: 9;  font.family: "Hiragino Sans"; color: index === 0 ? WallpaperManager.walColor5 : WallpaperManager.walColor8; font.weight: index === 0 ? Font.Bold : Font.Normal }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon;       font.pixelSize: 14; font.family: "Hiragino Sans"; color: index === 0 ? WallpaperManager.walColor5 : WallpaperManager.walForeground }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.max + "°"; font.pixelSize: 10; font.family: "Hiragino Sans"; color: index === 0 ? WallpaperManager.walColor5 : WallpaperManager.walForeground }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.min + "°"; font.pixelSize: 9;  font.family: "Hiragino Sans"; color: WallpaperManager.walColor8 }
                    }
                }
            }

            Item { height: 4 }
        }
    }
}
