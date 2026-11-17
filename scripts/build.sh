#!/usr/bin/env bash
# Build, test, sign and install Why Am I Here?.
#
#   scripts/build.sh test                 unit tests + UI tests on a simulator
#   scripts/build.sh ipa                  signed development build -> build/WhyAmIHere.ipa
#   scripts/build.sh install [udid]       ipa, then install on a connected iPhone
#
# Signing uses the team and bundle id in Config/Signing.local.xcconfig (see the .example file).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
DERIVED="${DERIVED_DATA:-$ROOT/build/DerivedData}"
ARCHIVE="$ROOT/build/WhyAmIHere.xcarchive"
EXPORT="$ROOT/build/export"
SIMULATOR="${SIMULATOR:-iPhone 18 Pro Max}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

generate() {
  command -v xcodegen >/dev/null || { echo "xcodegen is required: brew install xcodegen" >&2; exit 1; }
  log "Generating Xcode project"
  xcodegen generate --quiet
}

setting() {
  # Reads a value from the local signing config without printing the file.
  sed -n "s/^$1[[:space:]]*=[[:space:]]*//p" Config/Signing.local.xcconfig | tail -1
}

require_signing() {
  if [[ ! -f Config/Signing.local.xcconfig ]]; then
    echo "Config/Signing.local.xcconfig is missing. Copy Config/Signing.local.xcconfig.example and fill it in." >&2
    exit 1
  fi
  TEAM="$(setting DEVELOPMENT_TEAM)"
  [[ -n "$TEAM" ]] || { echo "DEVELOPMENT_TEAM is empty in Config/Signing.local.xcconfig" >&2; exit 1; }
}

run_tests() {
  log "Core unit tests"
  swift test --package-path Core
  generate
  log "UI tests on $SIMULATOR"
  xcodebuild -project WhyAmIHere.xcodeproj -scheme WhyAmIHere \
    -destination "platform=iOS Simulator,name=$SIMULATOR" \
    -derivedDataPath "$DERIVED" test
}

build_ipa() {
  require_signing
  generate
  log "Archiving (team $TEAM)"
  rm -rf "$ARCHIVE" "$EXPORT"
  xcodebuild -project WhyAmIHere.xcodeproj -scheme WhyAmIHere -configuration Release \
    -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration archive
  cat > "$ROOT/build/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>debugging</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>$TEAM</string>
  <key>stripSwiftSymbols</key><true/>
</dict>
</plist>
PLIST
  log "Exporting IPA"
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
    -exportOptionsPlist "$ROOT/build/ExportOptions.plist" -allowProvisioningUpdates
  cp "$EXPORT/WhyAmIHere.ipa" "$ROOT/build/WhyAmIHere.ipa"
  log "Signed build: build/WhyAmIHere.ipa"
  codesign -dv "$ARCHIVE/Products/Applications/WhyAmIHere.app" 2>&1 | grep -E '^(Identifier|TeamIdentifier)='
}

install_ipa() {
  local device="${1:-}"
  if [[ -z "$device" ]]; then
    device="$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && /available/ && /physical/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F-]{20,}$/) {print $i; exit}}')"
  fi
  [[ -n "$device" ]] || { echo "No connected iPhone found. Pass its UDID: scripts/build.sh install <udid>" >&2; exit 1; }
  build_ipa
  log "Installing on $device"
  xcrun devicectl device install app --device "$device" "$ROOT/build/WhyAmIHere.ipa"
}

case "${1:-}" in
  test) run_tests ;;
  ipa) build_ipa ;;
  install) install_ipa "${2:-}" ;;
  *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
