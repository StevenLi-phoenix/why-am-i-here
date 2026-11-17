#!/usr/bin/env bash
# Takes the README screenshots on a booted simulator and composes docs/banner.png.
# Usage: scripts/screenshots.sh <simulator-udid> <path-to-WhyAmIHere.app>
set -euo pipefail

SIM="${1:?simulator udid}"
APP="${2:?path to WhyAmIHere.app}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/screenshots"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p "$OUT"

xcrun simctl install "$SIM" "$APP"
xcrun simctl status_bar "$SIM" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3

shot() {
  local name="$1"; shift
  xcrun simctl terminate "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIM" "$BUNDLE_ID" -demoData "$@" >/dev/null
  sleep 4
  xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null
  echo "captured $name"
}

shot today
# -uiTesting asks on every open, so the Intent Check shows regardless of the sample history.
shot intent-check -uiTesting -openURL "whyamihere://ask?app=instagram"
shot reflection -openURL "whyamihere://reflection"
shot settings -openURL "whyamihere://settings"
shot gentle-reminder -openURL "whyamihere://preview-reminder"

xcrun simctl terminate "$SIM" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl status_bar "$SIM" clear

# Compose the banner from four of the screens.
PAGE="$(mktemp -d)/banner.html"
cat > "$PAGE" <<HTML
<!doctype html><meta charset="utf-8">
<style>
  html,body{margin:0;background:#0b0b0d}
  .row{width:1600px;height:800px;display:flex;align-items:center;justify-content:center;gap:44px;
       background:radial-gradient(900px 500px at 50% 0%,#0b3a66 0%,#0b0b0d 70%)}
  img{height:680px;border-radius:44px;box-shadow:0 30px 80px rgba(0,0,0,.6),0 0 0 2px rgba(255,255,255,.10)}
</style>
<div class="row">
  <img src="file://$OUT/intent-check.png"><img src="file://$OUT/gentle-reminder.png">
  <img src="file://$OUT/today.png"><img src="file://$OUT/reflection.png">
</div>
HTML
"$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size=1600,800 \
  --virtual-time-budget=4000 --screenshot="$ROOT/docs/banner.png" "file://$PAGE" >/dev/null 2>&1
echo "wrote docs/banner.png"
