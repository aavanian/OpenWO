# Database Schema

Current migration version: **v6**

## Tables

### session

Workout sessions recorded by the user.

```sql
CREATE TABLE session (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sessionType TEXT NOT NULL,          -- workout type identifier (e.g. "dayA", "dayB")
    date TEXT NOT NULL,                 -- date of the session (ISO format)
    startedAt TEXT NOT NULL,            -- timestamp when the session started
    durationSeconds INTEGER NOT NULL,   -- total duration in seconds
    isPartial BOOLEAN NOT NULL DEFAULT 0, -- whether the session was ended early
    feedback TEXT                       -- optional user feedback (added in v3)
);
```

### dailyChallenge

Tracks daily challenge completions.

```sql
CREATE TABLE dailyChallenge (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL UNIQUE,              -- one entry per day
    setsCompleted INTEGER NOT NULL DEFAULT 0 -- number of challenge sets done
);
```

### exercise

Exercise catalog with metadata.

```sql
CREATE TABLE exercise (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    advice TEXT NOT NULL DEFAULT '',          -- short coaching cue (v1-v2 era)
    counterUnit TEXT NOT NULL,               -- "reps" or "timer"
    defaultValue INTEGER NOT NULL,           -- default reps or seconds
    isDailyChallenge BOOLEAN NOT NULL DEFAULT 0,
    hasWeight BOOLEAN NOT NULL DEFAULT 0,    -- whether exercise uses weights (v3)
    externalId TEXT,                         -- external catalog ID (v4)
    instructions TEXT NOT NULL DEFAULT '',   -- detailed instructions (v4)
    level TEXT,                              -- difficulty level (v4)
    category TEXT,                           -- exercise category (v4)
    force TEXT,                              -- push/pull/static (v4)
    mechanic TEXT,                           -- compound/isolation (v4)
    equipment TEXT,                          -- required equipment (v4)
    primaryMuscles TEXT,                     -- JSON array of muscle names (v4)
    secondaryMuscles TEXT,                   -- JSON array of muscle names (v4)
    tip TEXT NOT NULL DEFAULT ''             -- short coaching tip (v5)
);
```

### workout

Named workout routines.

```sql
CREATE TABLE workout (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT ''
);
```

### workoutExercise

Links exercises to workouts with per-workout programming.

```sql
CREATE TABLE workoutExercise (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    workoutId INTEGER NOT NULL REFERENCES workout(id) ON DELETE CASCADE,
    exerciseId INTEGER NOT NULL REFERENCES exercise(id) ON DELETE CASCADE,
    position INTEGER NOT NULL,               -- ordering within the workout
    counterValue INTEGER,                    -- target reps or seconds
    counterLabel TEXT,                       -- optional display label override
    restSeconds INTEGER NOT NULL DEFAULT 30, -- rest period between sets
    sets INTEGER NOT NULL DEFAULT 1,
    counterUnit TEXT NOT NULL DEFAULT 'reps',          -- (v4) denormalized from exercise
    isDailyChallenge BOOLEAN NOT NULL DEFAULT 0,       -- (v4) denormalized from exercise
    hasWeight BOOLEAN NOT NULL DEFAULT 0,              -- (v4) denormalized from exercise
    isActive BOOLEAN NOT NULL DEFAULT 1,               -- (v6) soft-delete for swap/remove versioning
    UNIQUE(workoutId, position)
);
```

### exerciseLog

Per-exercise results within a session.

```sql
CREATE TABLE exerciseLog (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sessionId INTEGER NOT NULL REFERENCES session(id) ON DELETE CASCADE,
    workoutExerciseId INTEGER NOT NULL REFERENCES workoutExercise(id) ON DELETE CASCADE,
    weight REAL,                             -- weight used (if applicable)
    failed INTEGER NOT NULL DEFAULT 0,       -- number of failed attempts
    achievedValue INTEGER,                   -- actual reps/seconds achieved on failure (partial progress)
    UNIQUE(sessionId, workoutExerciseId)
);
```

## Migration History

| Version | Changes |
|---------|---------|
| v1 | Initial schema: `session`, `dailyChallenge` |
| v2 | Added `exercise`, `workout`, `workoutExercise` with seed data |
| v3 | Added `exercise.hasWeight`, `session.feedback`, `exerciseLog` table |
| v4 | Denormalized programming fields to `workoutExercise`, added catalog columns to `exercise` |
| v5 | Added `exercise.tip`, copied from `instructions` |
| v6 | Added `workoutExercise.isActive` for soft-delete versioning |
