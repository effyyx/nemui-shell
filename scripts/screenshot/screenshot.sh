#!/bin/bash

screenshot_dir="$HOME/Pictures/Screenshots"
mkdir -p "$screenshot_dir"
screenshot_path="$screenshot_dir/$(date +'%s_grim.png')"

case "$1" in
    --fullscreen)
        grim "$screenshot_path"
        wl-copy < "$screenshot_path"
        notify-send "スクリーンショット" "$screenshot_path" --hint="string:image-path:file://$screenshot_path" -a "screenshot"
        ;;
    --region)
        grim -g "$(slurp)" "$screenshot_path"
        wl-copy < "$screenshot_path"
        notify-send "スクリーンショット" "$screenshot_path" --hint="string:image-path:file://$screenshot_path" -a "screenshot"
        ;;
    --ocr)
        tmp="/tmp/qs-ocr-$(date +'%s').png"
        grim -g "$(slurp)" "$tmp"
        result=$(tesseract "$tmp" stdout -l jpn 2>/dev/null | tr -d ' ')
        rm -f "$tmp"
        if [ -z "$result" ]; then
            notify-send "OCR エラー" "テキストが見つかりません" -a "screenshot"
            exit 1
        fi
        echo -n "$result" | wl-copy
        notify-send "OCR 完了" "$result" -a "screenshot"
        ;;
    *)
        # default: region
        grim -g "$(slurp)" "$screenshot_path"
        wl-copy < "$screenshot_path"
        notify-send "スクリーンショット" "$screenshot_path" --hint="string:image-path:file://$screenshot_path" -a "screenshot"
        ;;
esac
