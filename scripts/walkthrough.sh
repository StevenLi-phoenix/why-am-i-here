#!/usr/bin/env bash
# Plays the usability-test tasks on a simulator and exports a screenshot of every step.
# Usage: scripts/walkthrough.sh <output-dir> [simulator-name]
#   e.g. scripts/walkthrough.sh docs/design/usability-test/screens/after
set -euo pipefail

OUT="${1:?output directory}"
SIMULATOR="${2:-iPhone 18 Pro}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
DERIVED="${DERIVED_DATA:-$ROOT/build/DerivedData}"
RESULT="$ROOT/build/walkthrough.xcresult"
RAW="$(mktemp -d)"

xcodegen generate --quiet
rm -rf "$RESULT"
echo "==> Walkthrough on $SIMULATOR"
TEST_RUNNER_WAIH_WALKTHROUGH=1 xcodebuild -project WhyAmIHere.xcodeproj -scheme WhyAmIHere \
  -destination "platform=iOS Simulator,name=$SIMULATOR" -derivedDataPath "$DERIVED" \
  -resultBundlePath "$RESULT" -only-testing:WhyAmIHereUITests/WalkthroughUITests test \
  | tail -n 20

xcrun xcresulttool export attachments --path "$RESULT" --output-path "$RAW" >/dev/null
mkdir -p "$OUT"
# The manifest maps exported files to the attachment names given in the test ("T2-1 intent check").
/usr/bin/python3 -I - "$RAW" <<'PY' > "$RAW/names.tsv"
import json, pathlib, sys
raw = pathlib.Path(sys.argv[1])
for test in json.loads((raw / "manifest.json").read_text()):
    for item in test.get("attachments", []):
        name = item.get("suggestedHumanReadableName") or item["exportedFileName"]
        stem = name.split("_")[0].strip().replace(" ", "-").lower()
        print(f"{item['exportedFileName']}\t{stem}")
PY
# Small JPEGs (1000 px tall) keep the screenshots light enough to commit.
count=0
while IFS=$'\t' read -r file stem; do
  sips -s format jpeg -s formatOptions 80 -Z 1000 "$RAW/$file" --out "$OUT/$stem.jpg" >/dev/null
  count=$((count + 1))
done < "$RAW/names.tsv"
echo "exported $count screenshots to $OUT"
