#!/bin/zsh
# Launches the built macOS app (in the background) with automation arguments,
# captures its window with `screencapture -l`, then quits it.
# Usage: Scripts/screenshot-macos.sh <path/to/NativeSteam.app> <out.png> [wait-seconds] -- <launch args…>
# Example: Scripts/screenshot-macos.sh build/NativeSteam.app ../../docs/screenshots/macos/game.png 8 -- -game 1145350
set -euo pipefail
APP="${1:A}"; OUT="$2"; WAIT="${3:-8}"
shift 3; [[ "${1:-}" == "--" ]] && shift
HERE="${0:A:h}"
WINDOW_ID_BIN="${WINDOW_ID_BIN:-$HERE/.window-id}"
if [[ ! -x "$WINDOW_ID_BIN" ]]; then
  swiftc -O "$HERE/window-id.swift" -o "$WINDOW_ID_BIN"
fi
EXE="$APP/Contents/MacOS/NativeSteam"
pkill -f "$EXE" 2>/dev/null || true
open -n -g "$APP" --args "$@"
sleep "$WAIT"
PID=$(pgrep -nf "$EXE")
trap 'kill $PID 2>/dev/null || true' EXIT
WID=$("$WINDOW_ID_BIN" "$PID")
screencapture -o -x -l "$WID" "$OUT"
echo "captured $OUT (window $WID)"
