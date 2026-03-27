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
                width: (parent.width - 16) / 2
                spacing: 8

                KbSection {
                    width: parent.width
                    title: "メニュー / パネル"
                    entries: [
                        { key: "Super + M",          desc: "メニュー切替" },
                        { key: "Super + Return",     desc: "ランチャー切替" },
                        { key: "Super + Shift + P",  desc: "音楽パネル切替" },
                        { key: "Super + Shift + C",  desc: "カレンダー切替" },
                        { key: "Super + Ctrl + R",   desc: "Quickshell 再起動" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "メニュータブ"
                    entries: [
                        { key: "Super + Shift + W",  desc: "壁紙タブ" },
                        { key: "Super + Shift + R",  desc: "レコーダータブ" },
                        { key: "Super + Shift + S",  desc: "スクリーンショットタブ" },
                        { key: "Super + Shift + N",  desc: "通知タブ" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "スクリーンショット"
                    entries: [
                        { key: "F1",                 desc: "範囲選択" },
                        { key: "F2",                 desc: "全画面" },
                        { key: "Super + Shift + O",  desc: "OCR (tesseract)" },
                        { key: "Super + Shift + M",  desc: "manga-ocr" },
                        { key: "Super + Shift + A",  desc: "注釈 (swappy)" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "チートシート"
                    entries: [
                        { key: "Super + Shift + /",   desc: "チートシート切替" },
                        { key: "← / → または h / l",  desc: "タブ切替" },
                        { key: "1 / 2 / 3 / 4",       desc: "タブ直接選択" },
                        { key: "Escape",               desc: "閉じる" },
                    ]
                }
            }

            Column {
                width: (parent.width - 16) / 2
                spacing: 8

                KbSection {
                    width: parent.width
                    title: "画面録画"
                    entries: [
                        { key: "Super + Alt + R",    desc: "範囲録画" },
                        { key: "Super + Alt + E",    desc: "範囲録画 (音声付)" },
                        { key: "Super + Alt + A",    desc: "全画面録画" },
                        { key: "Super + Alt + S",    desc: "全画面録画 (音声付)" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "IPC コマンド"
                    entries: [
                        { key: "menu toggle",        desc: "メニュー切替" },
                        { key: "launcher toggle",    desc: "ランチャー切替" },
                        { key: "music toggle",       desc: "音楽パネル切替" },
                        { key: "calendar toggle",    desc: "カレンダー切替" },
                        { key: "cheatsheet toggle",  desc: "チートシート切替" },
                        { key: "screenshot region",  desc: "範囲選択" },
                        { key: "screenshot take",    desc: "全画面" },
                        { key: "screenshot ocr",     desc: "OCR" },
                        { key: "screenshot mangaOcr", desc: "manga-ocr" },
                        { key: "screenshot annotate", desc: "注釈" },
                    ]
                }
            }
        }
    }
}
