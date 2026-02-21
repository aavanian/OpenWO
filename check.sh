#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "=== Running GymTrackKit tests ==="
cd "$ROOT/GymTrackKit"
swift test

echo ""
echo "=== Building Xcode project ==="
cd "$ROOT/GymTrackApp"

if [ ! -d GymTrack.xcodeproj ]; then
    echo "Generating Xcode project..."
    xcodegen generate
fi

xcodebuild build \
    -project GymTrack.xcodeproj \
    -scheme GymTrack \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -quiet

echo ""
echo "=== All checks passed ==="
