#!/usr/bin/env bash
# Cold-start benchmark for the Android client using the platform's own launch
# timer (`am start -W`): TotalTime = process fork → first frame drawn.
#
#   scripts/coldstart.sh <adb-serial> [runs=10] [out=../../bench/results/android-<date>.jsonl]
#
# Builds and installs a release-like (minified, non-debuggable) APK so ART/JIT
# behaviour matches what users get, then force-stops the app before every run.
set -euo pipefail
SERIAL="${1:?usage: coldstart.sh <adb-serial> [runs] [out]}"
RUNS="${2:-10}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
OUT="${3:-$ROOT/bench/results/android-$(date +%Y-%m-%d).jsonl}"
PKG=dev.nativesteam.android
ADB=(adb -s "$SERIAL")

cd "$HERE/.."
./gradlew -q :app:assembleBenchmark
"${ADB[@]}" install -r -t app/build/outputs/apk/benchmark/app-benchmark.apk >/dev/null
# Compile ahead of time like a Play Store install with a baseline profile would.
"${ADB[@]}" shell cmd package compile -m speed -f "$PKG" >/dev/null

mkdir -p "$(dirname "$OUT")"
: > "$OUT"
DEVICE="$("${ADB[@]}" shell getprop ro.product.model | tr -d '\r')"
for run in $(seq 1 "$RUNS"); do
  "${ADB[@]}" shell am force-stop "$PKG"
  sleep 2
  res="$("${ADB[@]}" shell am start -W -n "$PKG/.MainActivity" | tr -d '\r')"
  total="$(sed -n 's/^TotalTime: //p' <<<"$res")"
  sleep 6
  pss="$("${ADB[@]}" shell dumpsys meminfo "$PKG" | tr -d '\r' | awk '/TOTAL PSS:/ {print $3; exit} /^ *TOTAL / {print $2; exit}')"
  printf '{"app":"native-steam-android","mode":"cold","run":%d,"ttfd_ms":%s,"pss_mib":%.1f,"device":"%s"}\n' \
    "$run" "${total:-null}" "$(bc -l <<<"${pss:-0}/1024")" "$DEVICE" | tee -a "$OUT"
done
