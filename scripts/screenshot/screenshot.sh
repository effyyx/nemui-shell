#!/bin/bash

screenshot_dir="$HOME/Pictures/Screenshots"
mkdir -p "$screenshot_dir"
screenshot_path="$screenshot_dir/$(date +'%s_grim.png')"

# matugen primary color for slurp border, fallback grey
slurp_color=$(cat ~/.cache/matugen/slurp-color 2>/dev/null | tr -d '\n')
slurp_color="${slurp_color:-808080ff}"

_freeze_slurp() {
    region=$(slurp -c "$slurp_color" -F "TX-02" -d)
}

case "$1" in
    --fullscreen)
        grim "$screenshot_path"
        wl-copy < "$screenshot_path"
        notify-send "スクリーンショット" "$screenshot_path" --hint="string:image-path:file://$screenshot_path" -a "screenshot"
        ;;
    --region)
        _freeze_slurp
        [ -z "$region" ] && exit 0
        grim -g "$region" "$screenshot_path"
        wl-copy < "$screenshot_path"
        notify-send "スクリーンショット" "$screenshot_path" --hint="string:image-path:file://$screenshot_path" -a "screenshot"
        ;;
    --ocr)
        tmp="/tmp/qs-ocr-$(date +'%s').png"
        _freeze_slurp
        [ -z "$region" ] && exit 0
        grim -g "$region" "$tmp"
        result=$(tesseract "$tmp" stdout -l jpn 2>/dev/null | tr -d ' ')
        rm -f "$tmp"
        if [ -z "$result" ]; then
            notify-send "OCR エラー" "テキストが見つかりません" -a "screenshot"
            exit 1
        fi
        echo -n "$result" | wl-copy
        notify-send "OCR 完了" "$result" -a "screenshot"
        ;;
    --annotate)
        _freeze_slurp
        [ -z "$region" ] && exit 0
        grim -g "$region" - | swappy -f - -o "$screenshot_path"
        [ -f "$screenshot_path" ] && notify-send "注釈" "$screenshot_path" --hint="string:image-path:file://$screenshot_path" -a "screenshot"
        ;;
esac
