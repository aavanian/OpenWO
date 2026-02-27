#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

run_swift() {
    echo "=== Running GymTrackKit tests ==="
    cd "$ROOT/GymTrackKit"
    swift test
}

run_xcode() {
    echo "=== Building Xcode project ==="
    cd "$ROOT/GymTrackApp"

    if [ ! -d GymTrack.xcodeproj ]; then
        echo "Generating Xcode project..."
        xcodegen generate
    fi

    xcodebuild build \
        -project GymTrack.xcodeproj \
        -scheme GymTrack \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
        -quiet
}

run_python() {
    echo "=== Running Python tests ==="
    cd "$ROOT"
    uv run --with pytest pytest test_gymtrack.py -v
}

case "${1:-all}" in
    swift)  run_swift ;;
    xcode)  run_xcode ;;
    python) run_python ;;
    all)
        run_swift
        echo ""
        run_python
        echo ""
        run_xcode
        echo ""
        echo "=== All checks passed ==="
        ;;
    *)
        echo "Usage: $0 [swift|xcode|python|all]"
        exit 1
        ;;
esac
