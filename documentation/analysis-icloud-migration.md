# Analysis: iCloud Migration

**Goals:**
1. **Data ownership** — give the user control over their data (backup/restore via iCloud Drive)
2. **Desktop editing workflow** — make the SQLite file accessible from a Mac for workout and exercise management (see `analysis-workout-changes.md`, `analysis-workout-management.md`)

This is NOT about multi-device real-time sync or sharing data between users.

## Current State

- **Storage:** GRDB/SQLite database at `~/Library/Application Support/OpenWO/openwo.sqlite`
- **No cloud sync**, no background tasks, no export/import
- **HealthKit integration** is separate and write-only (not affected by this)
- **No App Group** or iCloud container configured
- **6 tables** — all part of the synced database:

| Table | Purpose | Initially seeded? |
|---|---|---|
| `exercise` | Exercise catalog | Yes (from bundled JSON) |
| `workout` | Workout templates | Yes (from bundled JSON) |
| `workoutExercise` | Exercise-to-workout assignments | Yes (from bundled JSON) |
| `session` | Completed workout sessions | No |
| `exerciseLog` | Per-exercise results within a session | No |
| `dailyChallenge` | Daily challenge streak tracking | No |

The entire SQLite database is the sync unit. Exercises and workouts are seeded from bundled JSON on first install, but once created they are user data (editable in the future — see `analysis-workout-changes.md`). The seed JSON files themselves are not synced.

### Schema Relationships

```
workout 1──* workoutExercise *──1 exercise
                │
session 1──* exerciseLog *──1 workoutExercise
dailyChallenge (standalone, keyed by date)
```

All primary keys are `INTEGER PRIMARY KEY AUTOINCREMENT`.

## iCloud Storage Options

| Option | Feasibility | Notes |
|---|---|---|
| **iCloud Documents (file-based)** | High | Copy SQLite file to ubiquity container. Simplest path. |
| **CloudKit + custom sync** | Medium | Keep GRDB, add CloudKit record mapping. Most flexible. |
| **Core Data + CloudKit** | Low | Requires full migration from GRDB to Core Data. |
| **SwiftData + CloudKit** | Low | Requires full migration from GRDB to SwiftData. iOS 17+ only. |
| **NSUbiquitousKeyValueStore** | Not applicable | 1 MB limit, key-value only. |

## Recommended Approaches (Ranked)

### Approach A: File-Level SQLite Sync via iCloud Documents

Store the SQLite database in the app's iCloud Documents container (`FileManager.default.url(forUbiquityContainerIdentifier:)`). iCloud handles file-level upload/download.

**Required changes:**

| Area | Change |
|---|---|
| Entitlements | Add `com.apple.developer.icloud-container-identifiers`, `com.apple.developer.icloud-services: [CloudDocuments]` |
| project.yml | Add iCloud capability with Documents service |
| `OpenWOApp.swift` | Change database path from `applicationSupportDirectory` to ubiquity container URL |
| `Database.swift` | Add startup logic: check iCloud availability, fall back to local if unavailable |

**Conflict resolution:** iCloud Documents uses file-level conflict detection. When two devices edit the same file, iOS presents `NSFileVersion` conflicts. The app must:
1. Register for `NSMetadataQuery` notifications to detect conflicts
2. Pick a winner (e.g., most recent modification date) or merge
3. For a SQLite file, merging is non-trivial — the realistic strategy is **last-writer-wins**

**Data migration for existing users:**
1. On first launch after update, check if old local database exists
2. Copy it to the iCloud container
3. Delete or rename the old local copy
4. If iCloud is unavailable, keep using local path

**Limitations:**
- No concurrent multi-device editing — if the phone and a desktop tool both write at the same time, one overwrites the other. For the intended workflow (edit on Mac, then use on phone), this is acceptable.
- File-level granularity means even a single-row change uploads the entire database (fine for the expected <1 MB database size)
- SQLite WAL mode can leave `-wal` and `-shm` companion files that complicate sync — GRDB should be configured to use `journal_mode=DELETE` instead
- Sync latency (seconds to minutes) between the local file and Apple's servers does NOT affect app performance — GRDB reads/writes the local file at normal SQLite speed. The delay is only in when changes appear on another device or in iCloud Drive on a Mac.
- If iCloud storage is full, sync silently fails
- Must use `NSFileCoordinator` for all file access

**Effort:** **Small** — minimal code changes. Conflict handling is simple given the sequential usage pattern (phone logs workout, Mac edits templates, not both at once).

---

### Approach B: CloudKit Custom Sync with GRDB

Keep GRDB as the local database. Add a CloudKit sync layer that maps GRDB records to `CKRecord` objects and syncs changes bidirectionally.

**Required changes:**

| Area | Change |
|---|---|
| Entitlements | Add `com.apple.developer.icloud-container-identifiers`, `com.apple.developer.icloud-services: [CloudKit]` |
| project.yml | Add iCloud capability with CloudKit service |
| Package.swift | No new dependencies (CloudKit is a system framework) |
| New file | `CloudKitSync.swift` — sync engine: change tracking, push/pull, conflict resolution |
| `Database.swift` | Add change-tracking columns (`cloudKitRecordID`, `lastModified`, `needsSync`) |
| Schema migration | v6: add sync metadata columns to `session`, `exerciseLog`, `dailyChallenge` |
| `OpenWOApp.swift` | Initialize sync engine, subscribe to remote change notifications |

**Conflict resolution:** CloudKit provides per-record conflict detection via `serverRecord` in `CKError.serverRecordChanged`. The sync engine can implement:
- **Last-writer-wins** (simplest): take the record with the latest `lastModified`
- **Field-level merge** (more complex): merge non-conflicting field changes

For OpenWO's data patterns (append-mostly session logs, daily challenge counters), last-writer-wins is likely sufficient.

**CloudKit record design:**

| CKRecord Type | Source Table | Synced Fields |
|---|---|---|
| `OpenWOExercise` | `exercise` | All columns (catalog data, user-editable) |
| `OpenWOWorkout` | `workout` | name, description |
| `OpenWOWorkoutExercise` | `workoutExercise` | All columns (references to workout + exercise) |
| `OpenWOSession` | `session` | sessionType, date, startedAt, durationSeconds, isPartial, feedback |
| `OpenWOExerciseLog` | `exerciseLog` | reference to GymSession, workoutExercise mapping, weight, failed, achievedValue |
| `OpenWODailyChallenge` | `dailyChallenge` | date, setsCompleted |

All 6 tables are synced — exercises and workouts are user-editable data after initial seed.

**ID strategy:** Auto-increment IDs are device-local and will differ across devices. Options:
1. Add a UUID column to synced tables, use UUIDs as the cross-device identifier
2. Map local auto-increment IDs to CloudKit record names
3. For `exerciseLog`, the foreign key to `workoutExercise` must be resolved by matching on (workoutName + exercisePosition) rather than local integer IDs

**Data migration for existing users:**
1. Schema migration adds UUID and sync metadata columns
2. Generate UUIDs for all existing rows
3. Initial sync pushes all local records to CloudKit
4. Subsequent syncs are incremental

**Limitations:**
- Significant implementation effort for a correct sync engine
- Must handle: network failures, partial syncs, retry logic, rate limiting
- CloudKit has per-record size limits (1 MB) and request rate limits
- Background sync requires `BGAppRefreshTask` registration
- Testing CloudKit requires a paid Apple Developer account and real iCloud credentials

**Effort:** **Large** — substantial sync engine code, but most flexible and robust.

---

### Approach C: Migrate to SwiftData + CloudKit

Replace GRDB entirely with SwiftData (or Core Data). Use `ModelConfiguration` with `cloudKitDatabase: .automatic` for built-in iCloud sync.

**Required changes:**

| Area | Change |
|---|---|
| Entitlements | Add iCloud + CloudKit entitlements |
| Package.swift | Remove GRDB dependency |
| All `Data/*.swift` | Rewrite all 6 model files as `@Model` classes |
| `Database.swift` | Replace with SwiftData `ModelContainer` setup |
| `Queries.swift` | Rewrite all queries using `@Query` macros and `ModelContext` |
| All ViewModels | Update to use SwiftData's observation system |
| Seed data | Rewrite seed logic for SwiftData |
| Tests | Rewrite all database tests |

**Conflict resolution:** Handled automatically by `NSPersistentCloudKitContainer` (the underlying Core Data + CloudKit integration). Uses last-writer-wins at the attribute level. No custom conflict code needed.

**ID strategy:** SwiftData uses `PersistentIdentifier` internally and CloudKit record names are auto-managed. No manual UUID handling needed. However, the existing integer-based foreign key relationships would need to be replaced with SwiftData `@Relationship` annotations.

**Data migration for existing users:**
1. On first launch after update, read all data from old GRDB database
2. Insert into new SwiftData store
3. Delete old GRDB database file
4. This is a one-time, one-way migration

**Limitations:**
- SwiftData requires iOS 17+ (current minimum is iOS 16)
- Full rewrite of the data layer — high risk of regressions
- SwiftData + CloudKit sync is opaque (hard to debug when it breaks)
- No control over sync timing or conflict resolution strategy
- Known issues with SwiftData + CloudKit around unique constraints and model evolution
- Core Data variant works on iOS 16+ but still requires full data layer rewrite

**Effort:** **Large** — complete data layer rewrite, but gets "free" sync after migration.

## Comparison Matrix

| Criteria | A: File Sync | B: CloudKit + GRDB | C: SwiftData + CloudKit |
|---|---|---|---|
| Code changes | Minimal | Moderate (new sync layer) | Complete data layer rewrite |
| Keeps GRDB | Yes | Yes | No |
| Conflict handling | File-level, fragile | Record-level, customizable | Attribute-level, automatic |
| Concurrent editing | No (last file wins) | Yes (per-record) | Yes (per-attribute) |
| Sync granularity | Entire database file | Individual records | Individual attributes |
| Offline support | Yes (local file) | Yes (local GRDB + queue) | Yes (local Core Data store) |
| iOS minimum | iOS 16 (no change) | iOS 16 (no change) | iOS 17 (SwiftData) or iOS 16 (Core Data) |
| Effort | **S** | **L** | **L** |
| Robustness | Low | High | Medium (opaque sync) |

## Risks & Considerations

### Conflict Resolution
Given the intended workflow (phone logs workouts, Mac edits templates), simultaneous edits are unlikely. For Approach A, the realistic conflict scenario is: user edits the DB on Mac while the phone is still syncing a recent workout. Last-writer-wins (based on modification date) is acceptable here. Approaches B and C handle conflicts at finer granularity, but this is overkill for the use case.

### Seed Data
Exercise and workout templates are seeded from bundled JSON on first install only. After that, the data lives in the SQLite database and is part of the synced file. The bundled JSON seed files are NOT synced — they only run during the initial GRDB migration on a fresh database.

### Auto-Increment IDs in a Distributed Context
The current schema uses `INTEGER PRIMARY KEY AUTOINCREMENT` everywhere. In a multi-device scenario:
- Two devices will independently generate IDs (session #5 on device A is not session #5 on device B)
- Foreign keys (`exerciseLog.sessionId`, `exerciseLog.workoutExerciseId`) reference local IDs
- Approach A sidesteps this (whole-file sync, only one device's IDs exist at a time)
- Approach B requires adding UUIDs and resolving foreign keys by semantic matching
- Approach C replaces the ID system entirely with SwiftData's managed identifiers

### HealthKit Data
HealthKit data is device-local and managed by Apple Health's own sync. OpenWO's iCloud sync does not need to handle it. The two systems remain decoupled.

### Apple Developer Program
All iCloud features require:
- A paid Apple Developer Program membership ($99/year)
- iCloud container provisioning in the Developer Portal
- CloudKit Dashboard access for Approach B (schema setup, monitoring)

### Database Size and Sync Performance
The current database is small (likely <1 MB for most users). Approach A uploads the entire file on every change. Approaches B and C sync only changed records. For typical usage, database size is not a concern for any approach.

## Recommendation

**Approach A (file-level sync)** is the clear choice for the stated goals. It provides:
- User data backup via iCloud Drive with minimal code changes
- Direct SQLite file access from a Mac for desktop editing workflows (Datasette, CLI tools, MCP — see `analysis-workout-management.md`)
- No architectural disruption to the existing GRDB data layer

The sequential usage pattern (phone logs workouts, Mac edits templates) makes concurrent editing concerns moot. Approaches B and C solve problems that don't exist for this use case and carry disproportionate implementation cost.

### Open questions

- From the target feature of being able to manage workouts and
  exercises, one possibly way is an external app or process to edit
  the sqlite file. On the understanding that concurrent access (by the
  app and this process) will likely to be problematic, should we
  consider a locking mechanism (action in the app to lock it from
  using the db)?
