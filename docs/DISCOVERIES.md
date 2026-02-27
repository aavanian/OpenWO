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

## iCloud Documents + GRDB

- iCloud Documents syncs files via atomic rename (replace old file with downloaded version). An open GRDB `DatabaseQueue` holds a file descriptor to the old inode and won't see the replacement. A full reload (dealloc old queue, open new one) is required.
- `NSFileCoordinator` should wrap the initial database open to prevent iCloud from replacing the file mid-open.
- `NSMetadataQuery` with `NSMetadataQueryUbiquitousDocumentsScope` detects remote file updates.
- `PRAGMA journal_mode = DELETE` avoids WAL/SHM companion files that break iCloud sync (iCloud treats each file independently; the WAL and main DB can get out of sync).
- The iCloud `Documents/` subdirectory inside the ubiquity container is what Files.app exposes. Files outside it are not user-visible.
- `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` make the app's local Documents directory visible in Files.app under "On My iPhone".
- No locking mechanism exists for concurrent access from multiple devices. Sequential usage (phone, then Mac) is the expected pattern. Last writer wins.
- `NSUbiquitousContainers` in Info.plist is required for the iCloud container to be browseable in Files.app. However, it may only take effect with App Store/TestFlight builds, not development-signed builds. The iCloud container itself works fine in dev (data syncs), but Files.app visibility needs verification via TestFlight.

## HealthKit workout visibility

- `HKWorkoutBuilder` alone records workouts silently — no system UI is shown during the workout. The workout only appears in Health/Fitness after it ends.
- `HKWorkoutSession` on iPhone provides a live workout with system indicators (Lock Screen, Dynamic Island). Despite Apple docs suggesting iOS 17+, both `HKWorkoutSession(healthStore:configuration:)` and `HKLiveWorkoutBuilder` require **iOS 26** in practice. Use `#available(iOS 26, *)` and fall back to `HKWorkoutBuilder` on older versions.
- `HKLiveWorkoutDataSource` auto-collects heart rate, calories, etc. from Apple Watch when set on the builder.
- In the simulator, `HKWorkoutBuilder` appears to "work" visually because the simulator doesn't distinguish live vs background workouts.

## iOS Simulator platform

Xcode 26 requires separately downloading the iOS platform SDK via `xcodebuild -downloadPlatform iOS` or Xcode > Settings > Components. Without it, `xcodebuild` fails with "iOS 26.x is not installed" even when a simulator runtime exists.
