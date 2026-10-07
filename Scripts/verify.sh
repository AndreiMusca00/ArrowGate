#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
verification_dir=$(mktemp -d /tmp/ArrowGateVerification.XXXXXX)
export ARROWGATE_FIXTURES="$PWD/ArrowGateUITests/levels.json"
xcrun swift test --scratch-path "$verification_dir/Rules"
xcodebuild -project ArrowGate.xcodeproj -scheme ArrowGate \
  -destination "${UI_DESTINATION:-platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0}" \
  -derivedDataPath "$verification_dir/Build" \
  -resultBundlePath "$verification_dir/UI.xcresult" CODE_SIGNING_ALLOWED=NO test
printf 'Rezultatele verificării: %s\n' "$verification_dir"
