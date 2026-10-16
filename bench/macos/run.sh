#!/bin/zsh
# Head-to-head launch benchmark on macOS: Native Steam (SwiftUI) vs the real
# Steam client vs the Epic Games Launcher (new "EGLv2" preview).
#
#   bench/macos/run.sh [runs]           # default 10 cold starts per app
#
# Needs Screen Recording + Accessibility permission for the terminal running it.
# Don't touch the mouse or keyboard while it runs: it launches, clicks and
# quits the apps and diffs their windows frame by frame.
#
# Steam and Epic must be installed and signed in; both should be set to open on
# their Store page (each restores the last page you had open).
set -euo pipefail
HERE="${0:A:h}"
ROOT="${HERE:h:h}"
RUNS="${1:-10}"
STAMP="$(date +%Y-%m-%d)"
OUT="$ROOT/bench/results/macos-$STAMP.jsonl"
FRAMES="${FRAMES:-${TMPDIR:-/tmp}/native-steam-bench-frames}"
BIN="$HERE/.build/launchbench"
NATIVE="$HERE/.build/derived/Build/Products/Release/NativeSteam.app"

mkdir -p "$HERE/.build" "$ROOT/bench/results"
swiftc -O -parse-as-library "$HERE/launchbench.swift" -o "$BIN"

echo "» building Native Steam (Release)"
xcodebuild -quiet -project "$ROOT/clients/apple/NativeSteam.xcodeproj" -scheme NativeSteam-macOS \
  -configuration Release -derivedDataPath "$HERE/.build/derived" CODE_SIGN_IDENTITY=- build

STEAM_ARGS=(--app /Applications/Steam.app
  --match "$HOME/Library/Application Support/Steam/Steam.AppBundle" --match /Applications/Steam.app
  --quit-url steam://exit --label steam --timeout 60)
EPIC_ARGS=(--app "/Applications/Epic Games Launcher.app" --label epic --timeout 30)
NATIVE_ARGS=(--app "$NATIVE" --label native-steam --timeout 30)
COMMON=(--out "$OUT" --frames "$FRAMES")

echo "» results → $OUT"
echo "» cold starts (×$RUNS each)"
"$BIN" cold "${NATIVE_ARGS[@]}" "${COMMON[@]}" --runs "$RUNS" --cooldown 3 --settle 6 >/dev/null
"$BIN" cold "${EPIC_ARGS[@]}" "${COMMON[@]}" --runs "$RUNS" --cooldown 3 --settle 6 >/dev/null
"$BIN" cold "${STEAM_ARGS[@]}" "${COMMON[@]}" --runs "$RUNS" --cooldown 3 --settle 6 >/dev/null

echo "» reopen from background (×5 each)"
"$BIN" reopen "${NATIVE_ARGS[@]}" "${COMMON[@]}" --runs 5 >/dev/null || true
"$BIN" reopen "${EPIC_ARGS[@]}" "${COMMON[@]}" --runs 5 >/dev/null || true
"$BIN" reopen "${STEAM_ARGS[@]}" "${COMMON[@]}" --runs 5 >/dev/null || true

echo "» tab switches (×5 each)"
# Tab switches: Library then Store, alternating.
"$BIN" click "${NATIVE_ARGS[@]}" "${COMMON[@]}" --runs 5 --click-text LIBRARY --click-text STORE >/dev/null || true
"$BIN" click "${EPIC_ARGS[@]}" "${COMMON[@]}" --runs 5 --click-text Library --click-text Store >/dev/null || true
"$BIN" click "${STEAM_ARGS[@]}" "${COMMON[@]}" --runs 5 --click-text LIBRARY --click-text STORE >/dev/null || true

echo "» done. Summarise with: python3 bench/report.py $OUT"
