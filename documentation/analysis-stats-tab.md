# Stats Tab

**Goal:** Replace the placeholder `StatsView` with real statistics, prioritized
by value to gym-goers.

**Effort:** Large (7+ files, implement incrementally)

**Framework:** Swift Charts (iOS 16+), matches the project deployment target.

---

## Feature priority

Ordered by motivational value — each feature can ship independently.

### 1. Weight Progression per Exercise (line chart)

The single most motivating stat for strength training. Shows weight lifted over
time for a selected exercise.

- **Data source:** `exerciseLog.weight` joined with `session.date` and
  `workoutExercise.exerciseId`.
- **Chart:** `LineMark` with `PointMark` overlay, X = date, Y = weight (kg).
- **Controls:** Exercise picker (list all exercises that have `hasWeight`).
- **Query:** New `Queries.weightHistory(db:exerciseId:)` returning
  `[(date: String, weight: Double)]`.

### 2. Session Frequency (bar chart)

Shows how often the user trains — weekly and monthly views.

- **Data source:** `session` table, grouped by week or month.
- **Chart:** `BarMark`, X = week/month bucket, Y = session count. Colour by
  `sessionType` (A/B/C).
- **Controls:** Segment picker for weekly vs. monthly granularity.
- **Query:** Existing `Queries.sessionsInDateRange` can be post-processed, or
  add a dedicated `Queries.sessionCountsByPeriod(db:granularity:)`.

### 3. Challenge Heatmap (contribution grid)

GitHub-style 52-week grid showing daily challenge completion.

- **Data source:** `dailyChallenge` table.
- **Chart:** Custom `Grid` or `Canvas` view — Swift Charts doesn't have a
  built-in heatmap. A `LazyVGrid` with 7 rows × 52 columns of small coloured
  squares works well.
- **Colour scale:** Empty (no entry) → light (1 set) → medium (2 sets) →
  full (3 sets).
- **Query:** `Queries.challengeHistory(db:year:)` returning
  `[String: Int]` (date → setsCompleted).

### 4. Personal Bests

Summary cards for milestone achievements.

- **Heaviest weight** per exercise (all-time and recent).
- **Longest streak** (sessions and challenges).
- **Most sessions** in a week/month.
- **Data source:** Computed from `exerciseLog`, `session`, `dailyChallenge`.
- **Display:** Simple `VStack` of labelled values, no charts needed.
- **Query:** `Queries.personalBests(db:)` returning a struct with the above.

### 5. Additional stats (lower priority)

These add depth but are less immediately motivating:

- **Duration trends:** Average session duration over time (`session.durationSeconds`).
- **Failure rate:** Percentage of exercises marked as failed per session.
- **Session type distribution:** Pie/donut chart of A/B/C session counts.
- **Feedback distribution:** How often the user rates sessions easy/ok/hard.

---

## Architecture

### View layer

```
StatsView
├── StatsSummarySection      (personal bests cards)
├── WeightProgressionChart   (line chart + exercise picker)
├── SessionFrequencyChart    (bar chart + granularity picker)
└── ChallengeHeatmap         (contribution grid)
```

`StatsView` becomes a `ScrollView` with sections. Each chart is a standalone
view that takes a `StatsViewModel` (or the specific data it needs).

### ViewModel

Expand `StatsViewModel` (currently empty) to:

```swift
public final class StatsViewModel: ObservableObject {
    @Published var weightHistory: [(date: String, weight: Double)] = []
    @Published var sessionCounts: [SessionCountBucket] = []
    @Published var challengeGrid: [String: Int] = [:]
    @Published var personalBests: PersonalBests?

    private let database: AppDatabase

    func loadWeightHistory(exerciseId: Int64) { ... }
    func loadSessionFrequency(granularity: Granularity) { ... }
    func loadChallengeHeatmap(year: Int) { ... }
    func loadPersonalBests() { ... }
}
```

### Data layer

New queries in `Queries.swift`:

| Query | Returns |
|-------|---------|
| `weightHistory(db:exerciseId:)` | `[(date: String, weight: Double)]` |
| `sessionCountsByPeriod(db:granularity:range:)` | `[SessionCountBucket]` |
| `challengeHistory(db:year:)` | `[String: Int]` |
| `personalBests(db:)` | `PersonalBests` |
| `exercisesWithWeightLogs(db:)` | `[ExerciseRecord]` (for the picker) |

---

## Files

| File | Action |
|------|--------|
| `Views/StatsView.swift` | Replace placeholder with sectioned `ScrollView` |
| `Views/WeightProgressionChart.swift` | New — line chart view |
| `Views/SessionFrequencyChart.swift` | New — bar chart view |
| `Views/ChallengeHeatmap.swift` | New — contribution grid view |
| `Views/StatsSummarySection.swift` | New — personal bests cards |
| `ViewModels/StatsViewModel.swift` | Expand with data loading methods |
| `Data/Queries.swift` | Add stats queries |
| `Views/ContentView.swift` | Pass `database` to `StatsView` |

---

## Implementation order

1. **Weight progression** — highest value, exercises the full
   query→viewmodel→chart pipeline, validates Swift Charts integration.
2. **Session frequency** — reuses the same pipeline pattern with a different
   chart type.
3. **Personal bests** — no charts, just computed values. Quick win.
4. **Challenge heatmap** — custom view (no Swift Charts), can be done
   independently.
5. **Additional stats** — fill in as time allows.

## Notes

- Swift Charts requires `import Charts` and iOS 16+. No new dependencies needed.
- The `exerciseLog` table already stores weight and failure data; no schema
  changes required.
- Consider GRDB observation (`ValueObservation`) for live updates if the user
  finishes a workout and returns to the stats tab. Alternatively, reload on
  `TabView` selection change (simpler, matches existing `homeViewModel.refresh()`
  pattern).

## Open questions

- how to navigate between the different views
