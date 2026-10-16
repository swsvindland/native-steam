#!/usr/bin/env bash
# Re-shoots docs/screenshots/android/*.png on a running emulator.
#
#   ./scripts/screenshots.sh [serial]      (default serial: emulator-5600)
#
# Installs the debug APK, enables SystemUI demo mode for a clean status bar, launches the app
# with intent extras for each screen, then repeats the tablet shots at 2560x1600 @ 320 dpi.
set -euo pipefail

SERIAL="${1:-emulator-5600}"
ADB=(adb -s "$SERIAL")
PKG=dev.nativesteam.android
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(cd "$ROOT/../.." && pwd)/docs/screenshots/android"
WAIT="${WAIT:-8}"   # seconds for artwork to load (Coil caches it on disk after the first run)
mkdir -p "$OUT"

"$ROOT/gradlew" -p "$ROOT" assembleDebug -q
"${ADB[@]}" install -r "$ROOT/app/build/outputs/apk/debug/app-debug.apk" >/dev/null

demo() {
  "${ADB[@]}" shell settings put global sysui_demo_allowed 1
  "${ADB[@]}" shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null
  "${ADB[@]}" shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
  "${ADB[@]}" shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >/dev/null
  "${ADB[@]}" shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null
  "${ADB[@]}" shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 -e fully true >/dev/null
  "${ADB[@]}" shell am broadcast -a com.android.systemui.demo -e command network -e mobile hide >/dev/null
  "${ADB[@]}" shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null
}

shot() { # shot <name> [am start extras...]
  local name="$1"; shift
  "${ADB[@]}" shell am start -S -W -n "$PKG/.MainActivity" "$@" >/dev/null
  sleep "$WAIT"
  "${ADB[@]}" exec-out screencap -p > "$OUT/$name.png"
  echo "  $OUT/$name.png"
}

echo "Phone"
"${ADB[@]}" shell wm size reset
"${ADB[@]}" shell wm density reset
sleep 2; demo
shot store     --es tab store
shot library   --es tab library
shot community --es tab community
shot profile   --es tab profile
shot game      --ei game 1145350
shot gamepad   --es tab library --es input gamepad

echo "Tablet (landscape)"
"${ADB[@]}" shell wm size 2560x1600
"${ADB[@]}" shell wm density 320
sleep 3; demo
shot tablet-store   --es tab store
shot tablet-library --es tab library

"${ADB[@]}" shell wm size reset
"${ADB[@]}" shell wm density reset
"${ADB[@]}" shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null
echo "Done."
