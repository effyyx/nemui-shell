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
                    title: "ナビゲーション"
                    entries: [
                        { key: "h j k l",        desc: "左/下/上/右" },
                        { key: "w / b",          desc: "次/前の単語" },
                        { key: "e / ge",         desc: "単語末尾" },
                        { key: "0 / $",          desc: "行頭/行末" },
                        { key: "gg / G",         desc: "ファイル先頭/末尾" },
                        { key: "{ / }",          desc: "段落移動" },
                        { key: "Ctrl+d / u",     desc: "半ページ下/上" },
                        { key: "Ctrl+o / i",     desc: "ジャンプリスト" },
                        { key: "%",              desc: "対応括弧へ" },
                        { key: "zz / zt / zb",   desc: "カーソル中央/上/下" },
                        { key: ":20 / 20G",      desc: "20行目へ" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "編集"
                    entries: [
                        { key: "i / a",          desc: "挿入 カーソル前/後" },
                        { key: "I / A",          desc: "行頭/行末に挿入" },
                        { key: "o / O",          desc: "下/上に新規行" },
                        { key: "x",              desc: "文字削除" },
                        { key: "dd / yy",        desc: "行削除/ヤンク" },
                        { key: "p / P",          desc: "下/上にペースト" },
                        { key: "u / Ctrl+r",     desc: "アンドゥ/リドゥ" },
                        { key: ".",              desc: "直前の変更を繰り返す" },
                        { key: "J",              desc: "行を結合" },
                        { key: "Ctrl+a / x",     desc: "数字 +1 / -1" },
                        { key: ">> / <<",        desc: "インデント/逆" },
                        { key: "Alt+j/k",        desc: "行を移動" },
                    ]
                }
            }

            Column {
                width: (parent.width - 32) / 3
                spacing: 8

                KbSection {
                    width: parent.width
                    title: "ビジュアルモード"
                    entries: [
                        { key: "v / V / Ctrl+v", desc: "文字/行/ブロック選択" },
                        { key: "ggVG",           desc: "全選択" },
                        { key: "> / <",          desc: "インデント維持" },
                        { key: "p",              desc: "レジスタを上書きしない" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "テキストオブジェクト"
                    entries: [
                        { key: "ci\" / ca\"",    desc: "クォート内/周囲を変更" },
                        { key: "di{ / da{",      desc: "ブレース内/周囲を削除" },
                        { key: "yi( / ya(",      desc: "括弧内/周囲をヤンク" },
                        { key: "viw / vip",      desc: "単語/段落を選択" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "マーク & マクロ"
                    entries: [
                        { key: "m{x}",           desc: "マークをセット" },
                        { key: "`{x}",           desc: "マークへジャンプ" },
                        { key: "q{x}",           desc: "マクロ記録" },
                        { key: "@{x} / @@",      desc: "マクロ実行/最後を再実行" },
                        { key: "* / #",          desc: "カーソル下の単語を検索" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "サラウンド"
                    entries: [
                        { key: "ysiw\"",          desc: "単語をクォートで囲む" },
                        { key: "ds\"",            desc: "クォートを削除" },
                        { key: "cs\"'",           desc: "クォートを変更" },
                        { key: "S{char}",         desc: "選択範囲を囲む" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "コメント"
                    entries: [
                        { key: "gcc / gbc",      desc: "行コメント/ブロック" },
                        { key: "gcO / gco / gcA", desc: "上/下/末尾にコメント" },
                        { key: "gcip / gc3j",    desc: "段落/3行コメント" },
                    ]
                }
            }

            Column {
                width: (parent.width - 32) / 3
                spacing: 8

                KbSection {
                    width: parent.width
                    title: "ファイル / 検索  <leader>f"
                    entries: [
                        { key: "ff / fg",        desc: "ファイル検索 / Grep" },
                        { key: "fr / fb",        desc: "最近 / バッファ" },
                        { key: "fs / fh",        desc: "LSPシンボル / ヘルプ" },
                        { key: "fw",             desc: "カーソル下の単語をGrep" },
                        { key: "fn",             desc: "ファイル名変更" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "バッファ / スプリット"
                    entries: [
                        { key: "Shift+l / h",    desc: "次/前のバッファ" },
                        { key: "leader+bd",      desc: "バッファ削除" },
                        { key: "leader+sv / sh", desc: "垂直/水平分割" },
                        { key: "Ctrl+h/j/k/l",   desc: "ウィンドウ切替" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "LSP  <leader>l"
                    entries: [
                        { key: "la / ln",        desc: "コードアクション / 名前変更" },
                        { key: "lf",             desc: "フォーマット" },
                        { key: "gd / gr",        desc: "定義 / 参照" },
                        { key: "K",              desc: "ホバードキュメント" },
                        { key: "]d / [d",        desc: "次/前の診断" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "Git  <leader>g"
                    entries: [
                        { key: "gs / gc",        desc: "ステータス / コミット" },
                        { key: "ghs / ghr",      desc: "ハンクをステージ/リセット" },
                        { key: "ghb",            desc: "行のBlame" },
                        { key: "]h / [h",        desc: "次/前のハンク" },
                    ]
                }

                KbSection {
                    width: parent.width
                    title: "Flash"
                    entries: [
                        { key: "s",              desc: "ジャンプ (文字入力→ラベル選択)" },
                        { key: "S",              desc: "Treesitterノードジャンプ" },
                        { key: "r",              desc: "リモートFlash (オペレーターモード)" },
                        { key: "Ctrl+s",         desc: "検索でFlash切替" },
                    ]
                }
            }
        }
    }
}
