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
                    title: "ナビゲーション (カスタム)"
                    entries: [
                        { key: "→ (Right)",      desc: "スマートエンター: ディレクトリ/ファイル" },
                        { key: "← (Left)",       desc: "親ディレクトリへ" },
                        { key: "gd",             desc: "~/Downloads へ" },
                        { key: "gv",             desc: "~/Videos へ" },
                        { key: "gp",             desc: "~/Pictures へ" },
                        { key: "g.",             desc: "~/.config へ" },
                        { key: "gm",             desc: "~/Music へ" },
                        { key: "gr",             desc: "~/Manga へ" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "ナビゲーション (デフォルト)"
                    entries: [
                        { key: "h / j / k / l",  desc: "左/下/上/右" },
                        { key: "H / L",          desc: "前/次の履歴" },
                        { key: "g / G",          desc: "先頭/末尾" },
                        { key: "Ctrl+u / d",     desc: "半ページ上/下" },
                        { key: "/",              desc: "検索" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "ファイル操作"
                    entries: [
                        { key: "o",              desc: "ファイルを開く" },
                        { key: "O",              desc: "アプリを選んで開く" },
                        { key: "Enter",          desc: "デフォルトで開く" },
                        { key: "y",              desc: "ヤンク (コピー)" },
                        { key: "x",              desc: "カット" },
                        { key: "p",              desc: "ペースト" },
                        { key: "d",              desc: "ゴミ箱へ" },
                        { key: "D",              desc: "完全削除" },
                        { key: "r",              desc: "名前変更" },
                        { key: "a",              desc: "新規ファイル/ディレクトリ" },
                    ]
                }
            }

            Column {
                width: (parent.width - 16) / 2
                spacing: 8

                KbSection {
                    width: parent.width
                    title: "選択 / フィルタ"
                    entries: [
                        { key: "Space",          desc: "選択切替" },
                        { key: "v",              desc: "ビジュアル選択" },
                        { key: "V",              desc: "ビジュアル選択解除" },
                        { key: "Ctrl+a",         desc: "全選択" },
                        { key: "Ctrl+r",         desc: "選択反転" },
                        { key: "f / F",          desc: "フィルタ / 解除" },
                        { key: "z",              desc: "ソート" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "表示"
                    entries: [
                        { key: ".",              desc: "隠しファイル切替" },
                        { key: "Tab",            desc: "プレビューパネル" },
                        { key: "g?",             desc: "ヘルプ" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "プラグイン (カスタム)"
                    entries: [
                        { key: "S",              desc: "ここでシェルを開く" },
                        { key: "ca",             desc: "選択ファイルをアーカイブ" },
                        { key: "ce",             desc: "7zで展開" },
                        { key: "cC",             desc: "MozJPEGで漫画を圧縮" },
                        { key: "M",              desc: "マウントマネージャー" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "タブ"
                    entries: [
                        { key: "t",              desc: "新規タブ" },
                        { key: "1-9",            desc: "タブ切替" },
                        { key: "[ / ]",          desc: "前/次のタブ" },
                        { key: "Ctrl+c",         desc: "タブを閉じる" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "その他"
                    entries: [
                        { key: "q",              desc: "yazi を終了" },
                        { key: "w",              desc: "タスクマネージャー" },
                    ]
                }
            }
        }
    }
}
