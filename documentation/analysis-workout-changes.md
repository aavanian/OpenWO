# Analysis: Swapping Exercises in a Workout

**Goal:** Swap an exercise in a workout (e.g., dumbbell rows → standing cable rows in Day A & C) without losing history.

## The Core Problem

`exerciseLog.workoutExerciseId` is a foreign key to `workoutExercise(id)`. If you change the `exerciseId` on an existing `workoutExercise` row, past logs now point to the wrong exercise. The log would say "I did standing cable rows on Jan 15" when the user actually did dumbbell rows.

Additionally, `lastWeights` cross-joins on `exerciseId` — changing the exercise retroactively would mix weight history from two different movements.

## Options

### A. Modify in Place (destructive)

Change `workoutExercise.exerciseId` from the old exercise to the new one.

**Pros:**
- Simplest implementation (single UPDATE)

**Cons:**
- History is retroactively wrong
- Weight carry-over (`lastWeights` query) mixes two different exercises
- **Not recommended**

### B. Duplicate Workouts (A → A', C → C')

Create new workout rows with the updated exercise list. Old sessions still reference the old workout versions.

**Pros:**
- History is perfectly preserved
- Clean separation between old and new configurations

**Cons:**
- Requires changing `SessionType` from a fixed enum to something dynamic, or adding a "current version" concept
- Leads to proliferation of workout variants over time
- Rotation logic becomes more complex (which version of "Day A" is current?)
- Architecturally heavy for a simple swap

### C. Version workoutExercise Rows (recommended)

When swapping an exercise:
1. Mark the old `workoutExercise` row as inactive (`isActive = 0`)
2. Create a new `workoutExercise` row for the replacement at the same position

The workout itself stays the same — "Day A" is always "Day A". Old `exerciseLog` entries still point to the old `workoutExercise` row (correct history). New sessions use only the active rows.

**Schema change (migration v6):**
```sql
ALTER TABLE workoutExercise ADD COLUMN isActive BOOLEAN NOT NULL DEFAULT 1;
```

**Query changes:**
- `exercisesForWorkout`: add `WHERE we.isActive = 1`
- `lastWeights`: already cross-joins on `exerciseId`, so it naturally finds weights for the new exercise if it was used elsewhere. No change needed unless we want to carry over weights from the retired row (manual opt-in).

**Pros:**
- History is perfectly preserved
- Workout identity stays stable (no proliferation)
- Minimal schema and query changes
- Easy to understand and debug

**Cons:**
- Retired rows accumulate in the table (negligible for this scale)
- No concept of "when" a swap happened (only that it did)

### D. Temporal/Effective-Date Model

Add `effectiveFrom` date to `workoutExercise`. When loading a workout for a session, pick rows effective at that date.

**Pros:**
- Most correct for historical replay ("what did Day A look like on March 1?")
- Supports multiple changes over time with precise dating

**Cons:**
- Significantly more complex queries (date range filtering, gap handling)
- Over-engineering for current needs
- Makes the common case (loading today's workout) slower and harder to reason about

## Recommendation

**Option C** (version workoutExercise rows with `isActive` flag). It preserves history, keeps workout identity stable, and requires minimal schema/query changes. Option D is the "right" answer for a production fitness platform but YAGNI for now.

If a need for temporal queries emerges later, option C can be migrated to option D by adding an `effectiveFrom` column and backfilling dates from the earliest `exerciseLog` referencing each row.
