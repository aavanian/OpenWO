# Analysis: HealthKit Integration

**Goal:** Start an Apple HealthKit workout session when the user starts a GymTrack workout.

## What This Enables

- Workout appears in Apple Health and the Fitness app
- Heart rate data from Apple Watch is associated with the workout
- Calories/active energy are tracked
- Activity rings get credit for the workout

## Implementation Approach

### Required Setup

1. **Entitlements:** Add HealthKit capability to `GymTrack.entitlements` (currently empty)
2. **Info.plist:** Add usage description strings:
   - `NSHealthShareUsageDescription` — why the app reads health data
   - `NSHealthUpdateUsageDescription` — why the app writes health data
3. **Authorization:** Request permission for `.workoutType()` at minimum

### Core API

```swift
import HealthKit

let healthStore = HKHealthStore()

// Start workout
let config = HKWorkoutConfiguration()
config.activityType = .traditionalStrengthTraining
config.locationType = .indoor

let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())
try await builder.beginCollection(at: startDate)

// End workout
try await builder.endCollection(at: endDate)
try await builder.finishWorkout()
```

### Mapping SessionType to HealthKit Activity Types

| SessionType | Description           | HKWorkoutActivityType              |
|-------------|-----------------------|------------------------------------|
| A           | Upper Strength        | `.traditionalStrengthTraining`     |
| B           | Cardio + Core         | `.mixedCardio` or `.coreTraining`  |
| C           | Mixed / Maintenance   | `.traditionalStrengthTraining`     |

### Key Considerations

- **Platform guard:** HealthKit is iOS-only. Must be guarded with `#if canImport(HealthKit)` for macOS builds and tests.
- **Authorization is optional:** The app must work without HealthKit permission. Authorization is async and can be denied — treat it as graceful degradation.
- **API choice:** `HKWorkoutSession` (available on iPhone since iOS 17) provides a live workout with system UI (Lock Screen indicator, Dynamic Island). It uses `HKLiveWorkoutBuilder` for data collection. Plain `HKWorkoutBuilder` records workouts silently without any system indicator.
- **Aborted workouts:** The HealthKit workout should be ended even if the user aborts — partial workouts still count for activity rings and provide useful data.

### Integration Points in Current Code

All in `ExerciseViewModel` (`GymTrackKit/Sources/GymTrackKit/ViewModels/ExerciseViewModel.swift`):

| Method              | HealthKit Action                                        |
|---------------------|---------------------------------------------------------|
| `startTimer()`      | Call `builder.beginCollection(at:)` to start the workout |
| `finishWorkout()`   | Call `builder.endCollection(at:)` + `finishWorkout()`    |
| `abortWorkout()`    | Still end the HealthKit workout (shorter duration)       |

### Suggested Architecture

A small `HealthKitManager` class wrapping:
- Authorization request (called once, e.g., on first launch or first workout)
- `startWorkout(activityType:date:)` → creates and begins an `HKWorkoutBuilder`
- `endWorkout(at:)` → ends collection and finishes the workout
- Availability check (`HKHealthStore.isHealthDataAvailable()`)

`ExerciseViewModel` would hold an optional reference to this manager. If HealthKit is unavailable or unauthorized, the reference is nil and all calls are no-ops.

## Schema Impact

None. HealthKit integration is purely at the app layer — no database changes needed.

## Recommendation

Straightforward to implement. The main work is:

1. Entitlements + Info.plist setup
2. A `HealthKitManager` class (~50–80 lines) wrapping authorization + workout start/stop
3. Three call sites in `ExerciseViewModel`

Should use graceful degradation: if HealthKit is unavailable or authorization is denied, the app behaves exactly as it does today. No feature flag needed — the nil-manager pattern handles this naturally.
