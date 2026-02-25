# Plan: Store Exercises & Workouts in SQLite

## Current State

- All exercises are **hard-coded** in `WorkoutPlan.swift` as static arrays of `Exercise` structs
- The `Exercise` struct is a flat view-model: `id, name, instruction, sets, reps (String), isDailyChallenge, isTimed`
- The DB only has `session` and `dailyChallenge` tables (migration "v1")
- `ExerciseViewModel` calls `WorkoutPlan.exercises(for: sessionType)` to get the list

## Proposed Database Schema

Three new tables, added via a **"v2" migration**:

### Table: `exercise`

| Column           | Type    | Notes                                     |
|------------------|---------|-------------------------------------------|
| id               | INTEGER | PK AUTOINCREMENT                          |
| name             | TEXT    | NOT NULL — e.g. "Push-ups"               |
| description      | TEXT    | NOT NULL DEFAULT '' — longer explanation |
| advice           | TEXT    | NOT NULL DEFAULT '' — form cue           |
| counterUnit      | TEXT    | NOT NULL — `"reps"` or `"timer"`         |
| defaultValue     | INTEGER | NOT NULL — reps count or seconds         |
| isDailyChallenge | BOOLEAN | NOT NULL DEFAULT 0                        |

### Table: `workout`

| Column      | Type    | Notes                              |
|-------------|---------|------------------------------------|
| id          | INTEGER | PK AUTOINCREMENT                   |
| name        | TEXT    | NOT NULL — e.g. "Day A"           |
| description | TEXT    | NOT NULL DEFAULT ''                |

### Table: `workoutExercise` (join / ordering)

| Column       | Type    | Notes                                                     |
|--------------|---------|-----------------------------------------------------------|
| id           | INTEGER | PK AUTOINCREMENT                                          |
| workoutId    | INTEGER | NOT NULL, FK → workout(id)                               |
| exerciseId   | INTEGER | NOT NULL, FK → exercise(id)                              |
| position     | INTEGER | NOT NULL — ordering within the workout (0-based)         |
| counterValue | INTEGER | NULL — override; NULL means use exercise.defaultValue    |
| counterLabel | TEXT    | NULL — optional display override (e.g. "10 reps / side") |
| restSeconds  | INTEGER | NOT NULL DEFAULT 30 — rest between sets                  |
| sets         | INTEGER | NOT NULL DEFAULT 1 — number of sets                      |

**Why `counterLabel`?** Some current exercises use free-text reps like `"10 + 10 reps"` or `"10 reps / side"` that can't be derived from a bare integer + unit. This nullable field lets us store a display override when needed, while most entries auto-format from `counterUnit + counterValue`.

## Mapping Current Hard-Coded Data

Current `Exercise` struct fields → new schema:

| Current field     | New location                                                        |
|-------------------|---------------------------------------------------------------------|
| `name`            | `exercise.name`                                                     |
| `instruction`     | `exercise.advice` (form cues go here; longer text → `description`) |
| `sets`            | `workoutExercise.sets`                                              |
| `reps` (String)   | Derived from `counterUnit` + `counterValue` (or `counterLabel`)     |
| `isTimed`         | Derived: `exercise.counterUnit == "timer"`                          |
| `isDailyChallenge`| `exercise.isDailyChallenge`                                         |

Example seed data (from the existing `WorkoutPlan`):

```
exercise rows:
  (name: "Cardio warm-up (cycling)", advice: "Easy pace, joints only", counterUnit: "timer", defaultValue: 600)
  (name: "Plank", advice: "Hips level", counterUnit: "timer", defaultValue: 45)
  (name: "Dumbbell rows (pull)", advice: "Elbow back and up, knee on bench", counterUnit: "reps", defaultValue: 10)
  (name: "Daily Challenge — squats + push-ups", advice: "Counts toward daily challenge", counterUnit: "reps", defaultValue: 20, isDailyChallenge: true)
  ...

workout rows:
  (name: "Day A", description: "Upper Strength, 40-45 min")
  (name: "Day B", description: "Cardio + Core, 45-50 min")
  (name: "Day C", description: "Mixed / Maintenance, 35-40 min")

workoutExercise rows (Day A):
  (workoutId: 1, exerciseId: <warm-up>,      position: 0, counterValue: 600,  sets: 1, restSeconds: 0)
  (workoutId: 1, exerciseId: <daily-challenge>, position: 1, counterValue: NULL, counterLabel: "10 + 10 reps", sets: 1, restSeconds: 0)
  (workoutId: 1, exerciseId: <rows>,         position: 2, counterValue: 10,   counterLabel: "10 reps / side", sets: 4, restSeconds: 30)
  (workoutId: 1, exerciseId: <chest-press>,  position: 3, counterValue: 10,   sets: 4, restSeconds: 30)
  ...
```

## Implementation Steps

### Step 1 — New GRDB model structs

Create three new files in `GymTrackKit/Sources/GymTrackKit/Data/`:

- **`ExerciseRecord.swift`** — GRDB `Codable, FetchableRecord, PersistableRecord` for the `exercise` table. Named `ExerciseRecord` to avoid collision with the existing view-facing `Exercise` struct.
- **`Workout.swift`** — Same pattern for `workout` table.
- **`WorkoutExercise.swift`** — Same pattern for `workoutExercise` table.

### Step 2 — Database migration "v2"

In `Database.swift`, register a new migration `"v2"` that:

1. Creates the three tables with foreign keys and indexes
2. **Seeds** them with the current hard-coded data from `WorkoutPlan` — this ensures existing users get the same exercises after the migration, and the hard-coded data becomes the "factory default"

### Step 3 — Query layer

Add new static methods to `Queries.swift`:

- `exercisesForWorkout(_ db, workoutId) -> [(ExerciseRecord, WorkoutExercise)]` — fetches the joined exercise + pivot data, ordered by position
- `allWorkouts(_ db) -> [Workout]`
- `workoutByName(_ db, name) -> Workout?` (useful for mapping current SessionType names)
- Insert/update helpers for exercises, workouts, and the join table (for future editing UI)

### Step 4 — Adapt `WorkoutPlan` to load from DB

Change `WorkoutPlan.exercises(for:)` to:

1. Accept `AppDatabase` as a parameter
2. Look up the `Workout` row matching the session type name (e.g. "Day A")
3. Fetch the joined exercise list
4. Map each `(ExerciseRecord, WorkoutExercise)` pair into the existing `Exercise` view struct

The **`Exercise` view struct stays unchanged** — the views don't need to be touched. The mapping logic:

```swift
Exercise(
    id: "\(workoutExercise.workoutId)-\(workoutExercise.position)",
    name: record.name,
    instruction: record.advice,
    sets: workoutExercise.sets > 1 ? workoutExercise.sets : nil,
    reps: workoutExercise.counterLabel ?? formatDefault(record.counterUnit, workoutExercise.counterValue ?? record.defaultValue),
    isDailyChallenge: record.isDailyChallenge,
    isTimed: record.counterUnit == "timer"
)
```

### Step 5 — Update callers

- **`ExerciseViewModel.init`**: Pass `database` into the updated `WorkoutPlan.exercises(for:database:)` call.
- **`SessionType`**: Consider adding a computed property `workoutName` that returns `"Day A"` / `"Day B"` / `"Day C"` so the lookup is clean. Or store the `workout.id` alongside `SessionType` — but for now a name-based lookup keeps the change minimal.

### Step 6 — Delete hard-coded data

Once the DB-backed path is working and tested, remove the static `dayA`, `dayB`, `dayC` arrays from `WorkoutPlan.swift`. The seed data in the migration is now the source of truth.

### Step 7 — Tests

- Add migration tests: verify tables exist and seed data is correct
- Add query tests: fetch exercises for a workout, verify ordering and field mapping
- Update `ExerciseViewModelTests` if they relied on the hard-coded data
- Verify existing `DatabaseTests` and `QueriesTests` still pass

## What Does NOT Change

- **Views**: `ExerciseView`, `ExerciseStepCard`, `TimerView`, `SetTracker` — all consume the same `Exercise` struct, untouched.
- **`Session` table & model**: Session logging stays the same.
- **`DailyChallenge` table & model**: No changes.
- **`HomeViewModel`**: Still uses `SessionType` for rotation, no changes needed.
- **Business logic**: `RotationLogic`, `StreakLogic` unaffected.

## Future Considerations (out of scope for this task)

- UI for creating/editing exercises and workouts
- Replacing `SessionType` enum with dynamic workout selection (workout ID stored in session)
- Workout templates / duplication
- Exercise tags/categories for filtering
