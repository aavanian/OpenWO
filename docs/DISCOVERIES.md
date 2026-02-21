# Discoveries

Lessons learned and useful findings during development.

## SwiftUI macOS compatibility

When building a Swift Package targeting both iOS and macOS (for `swift test` on Mac):

- `Color(.secondarySystemGroupedBackground)` is UIKit-only. Use a cross-platform `Color` extension (see `PlatformColors.swift`).
- `.fullScreenCover` is iOS-only. Guard with `#if os(iOS)` and fall back to `.sheet` on macOS.
- `.navigationBarTitleDisplayMode` is iOS-only. Guard with `#if os(iOS)`.
- `.foregroundStyle(.accentColor)` doesn't resolve on macOS — use `Color.accentColor` explicitly.

## GRDB records

- `PersistableRecord.insert(_:)` is `mutating` (sets the auto-incremented ID), so the record variable must be `var`.
- When the closure parameter shadows the `AppDatabase` parameter name, rename the closure parameter (e.g. `dbConn`) to avoid confusion.

## XcodeGen

Run `xcodegen generate` from the `GymTrackApp/` directory to regenerate `.xcodeproj`. The generated project is gitignored.

## iOS Simulator platform

Xcode 26 requires separately downloading the iOS platform SDK via `xcodebuild -downloadPlatform iOS` or Xcode > Settings > Components. Without it, `xcodebuild` fails with "iOS 26.x is not installed" even when a simulator runtime exists.
