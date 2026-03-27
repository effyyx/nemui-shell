import "../../managers"
import "../../state"
import "../../parts"
import QtQuick
import QtQuick.Controls

Item {
    focus: true
    Keys.onEscapePressed: AppState.cheatsheetVisible = false

    ScrollView {
        anchors.fill: parent
        anchors.margins: 16
        clip: true
        ScrollBar.vertical.width: 4

        Flow {
            width: parent.width
            spacing: 16

            Column {
                width: (parent.width - 32) / 3
                spacing: 8

                KbSection {
                    width: parent.width
                    title: "アプリ"
                    entries: [
                        { key: "Mod + Space",          desc: "ターミナル (kitty)" },
                        { key: "Mod + N",              desc: "yazi" },
                        { key: "Mod + W",              desc: "Firefox" },
                        { key: "Mod + E",              desc: "rmpc (音楽)" },
                        { key: "Mod + A",              desc: "Anki" },
                        { key: "Mod + Alt + L",        desc: "画面ロック" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "メディア"
                    entries: [
                        { key: "Ctrl + ↑ / ↓",        desc: "音量 +5% / -5%" },
                        { key: "Ctrl + M",             desc: "ミュート切替" },
                        { key: "Ctrl + P",             desc: "再生/一時停止" },
                        { key: "Ctrl + → / ←",        desc: "次/前のトラック" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "Quickshell"
                    entries: [
                        { key: "Mod + Alt + Q",        desc: "Quickshell 再起動" },
                        { key: "Mod + M",              desc: "メニュー切替" },
                        { key: "Mod + Return",         desc: "ランチャー" },
                        { key: "Mod + Alt + R",        desc: "レコーダー" },
                        { key: "Mod + Alt + N",        desc: "通知" },
                        { key: "Mod + Alt + P",        desc: "音楽パネル" },
                        { key: "Mod + Alt + C",        desc: "カレンダー" },
                        { key: "Mod + Shift + /",      desc: "チートシート" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "スクリーンショット"
                    entries: [
                        { key: "F1",                   desc: "範囲選択" },
                        { key: "F2",                   desc: "全画面" },
                        { key: "Mod + Shift + O",      desc: "OCR" },
                        { key: "Mod + Shift + P",      desc: "manga-ocr" },
                        { key: "Mod + Shift + A",      desc: "注釈 (swappy)" },
                        { key: "Print",                desc: "niri スクリーンショット" },
                        { key: "Ctrl + Print",         desc: "niri 全画面" },
                        { key: "Alt + Print",          desc: "niri ウィンドウ" },
                    ]
                }
            }

            Column {
                width: (parent.width - 32) / 3
                spacing: 8

                KbSection {
                    width: parent.width
                    title: "ウィンドウ操作"
                    entries: [
                        { key: "Mod + Q",              desc: "ウィンドウを閉じる" },
                        { key: "Mod + V",              desc: "フロート切替" },
                        { key: "Mod + Shift + V",      desc: "フロート/タイル フォーカス切替" },
                        { key: "Mod + Alt + W",        desc: "タブ表示切替" },
                        { key: "Mod + F",              desc: "カラムを最大化" },
                        { key: "Mod + Shift + F",      desc: "フルスクリーン" },
                        { key: "Mod + Shift + M",      desc: "エッジまで最大化" },
                        { key: "Mod + Ctrl + F",       desc: "カラムを利用可能幅に拡張" },
                        { key: "Mod + C",              desc: "カラムを中央に" },
                        { key: "Mod + Ctrl + C",       desc: "表示カラムを中央に" },
                        { key: "Mod + O",              desc: "オーバービュー切替" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "サイズ変更"
                    entries: [
                        { key: "Mod + R",              desc: "カラム幅プリセット切替" },
                        { key: "Mod + Shift + R",      desc: "ウィンドウ高さプリセット切替" },
                        { key: "Mod + Ctrl + R",       desc: "ウィンドウ高さリセット" },
                        { key: "Mod + - / =",          desc: "カラム幅 -10% / +10%" },
                        { key: "Mod + Shift + - / =",  desc: "ウィンドウ高さ -10% / +10%" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "カラム操作"
                    entries: [
                        { key: "Mod + ,",              desc: "ウィンドウをカラムに取り込む" },
                        { key: "Mod + .",              desc: "ウィンドウをカラムから出す" },
                        { key: "Mod + [ / ]",          desc: "左/右にウィンドウを移動" },
                    ]
                }
            }

            Column {
                width: (parent.width - 32) / 3
                spacing: 8

                KbSection {
                    width: parent.width
                    title: "フォーカス移動"
                    entries: [
                        { key: "Mod + hjkl / ←↓↑→",   desc: "左/下/上/右" },
                        { key: "Mod + Page Up/Down",   desc: "最初/最後のカラム" },
                        { key: "Mod + Shift + hjkl",   desc: "モニター間フォーカス" },
                        { key: "Mod + U / I",          desc: "ワークスペース下/上" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "ウィンドウ移動"
                    entries: [
                        { key: "Mod + Ctrl + hjkl",    desc: "カラム/ウィンドウ移動" },
                        { key: "Mod + Ctrl + Page Up/Down", desc: "最初/最後に移動" },
                        { key: "Mod + Shift + Ctrl + hjkl", desc: "モニター間移動" },
                        { key: "Mod + Ctrl + U / I",   desc: "ワークスペース下/上に移動" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "ワークスペース"
                    entries: [
                        { key: "Mod + 1-9",            desc: "ワークスペース切替" },
                        { key: "Mod + Shift + 1-9",    desc: "カラムをワークスペースへ" },
                        { key: "Mod + Shift + U / I",  desc: "ワークスペースを下/上へ" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "スクロール操作"
                    entries: [
                        { key: "Mod + ホイール上/下",   desc: "ワークスペース下/上" },
                        { key: "Mod + ホイール左/右",   desc: "カラム左/右フォーカス" },
                        { key: "Mod + Ctrl + ホイール", desc: "カラムをワークスペース/移動" },
                        { key: "Mod + Shift + ホイール", desc: "カラム左/右フォーカス" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "その他"
                    entries: [
                        { key: "Mod + Escape",         desc: "キーショートカット抑制切替" },
                        { key: "Mod + Shift + E",      desc: "Niri 終了" },
                        { key: "Ctrl + Alt + Delete",  desc: "Niri 終了" },
                    ]
                }
            }
        }
    }
}
