#!/usr/bin/env bash
# gpu-screen-recorder wrapper — called by RecordingManager
set -euo pipefail

RECORD_DIR="$HOME/Videos/Recordings"
REPLAY_DIR="$HOME/Videos/Replays"
RECORD_PID="/tmp/qs-record.pid"
REPLAY_PID="/tmp/qs-replay.pid"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="$RECORD_DIR/recording_${TIMESTAMP}.mp4"

mkdir -p "$RECORD_DIR" "$REPLAY_DIR"

case "$1" in
    --replay-start)
        gpu-screen-recorder -w screen -f 60 -a default_output -c mp4 -r 180 -replay-storage ram -o "$REPLAY_DIR" &
        echo $! > "$REPLAY_PID"
        notify-send "リプレイ開始" "最後の180秒を録画中" -a "recorder"
        ;;

    --replay-save)
        if [ -f "$REPLAY_PID" ]; then
            kill -SIGUSR1 "$(cat "$REPLAY_PID")" 2>/dev/null || true
        fi
        ICON_HINT=""
        if [ -f "/usr/share/icons/hicolor/256x256/apps/gpu-screen-recorder.png" ]; then
            ICON_HINT="--hint=string:image-path:file:///usr/share/icons/hicolor/256x256/apps/gpu-screen-recorder.png"
        fi
        notify-send "リプレイ保存" "$REPLAY_DIR" $ICON_HINT -a "recorder"
        ;;

    --replay-stop)
        if [ -f "$REPLAY_PID" ]; then
            kill "$(cat "$REPLAY_PID")" 2>/dev/null || true
            rm -f "$REPLAY_PID"
        fi
        ;;

    --fullscreen)
        gpu-screen-recorder -w screen -f 60 -a default_output -c mp4 -o "$OUTFILE" &
        echo $! > "$RECORD_PID"
        ;;

    --region)
        REGION=$(slurp -f "%wx%h+%x+%y") || exit 1
        gpu-screen-recorder -w "$REGION" -f 60 -a default_output -c mp4 -o "$OUTFILE" &
        echo $! > "$RECORD_PID"
        ;;

    --stop)
        if [ -f "$RECORD_PID" ]; then
            kill "$(cat "$RECORD_PID")" 2>/dev/null || true
            rm -f "$RECORD_PID"
        fi
        notify-send "録画完了" "$OUTFILE" -a "recorder"
        ;;
esac
