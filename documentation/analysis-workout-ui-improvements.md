# Workout UI Improvements

Three small, self-contained UI enhancements for the workout and home screens.

---

## 1. Fold/Unfold Exercises

**Goal:** During a workout, show only the current exercise expanded. Completed
and upcoming exercises collapse to a single-line summary, reducing scroll noise.

**Effort:** Small (2 files)

### Design

- Add `@State private var expandedExerciseIds: Set<String>` to `ExerciseView`.
- Pass `isExpanded: Bool` to each `ExerciseStepCard`.
- When collapsed, the card shows only the header row (exercise name +
  checkmark/failed icon). The controls (`exerciseControls`,
  `exerciseLogControls`) render only when expanded.
- Tapping a collapsed card toggles it open; tapping an expanded card's header
  collapses it.
- Use a custom expand/collapse implementation (not `DisclosureGroup`) to keep
  the existing card visual style and background.

### Auto-advance behaviour

- When an exercise completes (`onComplete` fires), collapse it and expand the
  next incomplete exercise via `.onChange(of:)` on the completion state.
- Wrap the `LazyVStack` in a `ScrollViewReader` and call
  `proxy.scrollTo(nextId, anchor: .top)` on auto-advance so the newly expanded
  card is visible.

### Files

| File | Change |
|------|--------|
| `Views/ExerciseView.swift` | Add `expandedExerciseIds` state, `ScrollViewReader`, auto-advance logic |
| `Views/ExerciseStepCard.swift` | Accept `isExpanded: Bool`, conditionally render body |

### Open questions

- Should the first exercise auto-expand on appear, or should all start expanded
  until the user first interacts? Recommend: first incomplete exercise
  auto-expanded, rest collapsed.
- Animate expand/collapse with `withAnimation(.easeInOut(duration: 0.25))`?

---

## 2. Dismiss Numeric Keyboard

**Goal:** Let users dismiss the numeric keyboard (weight input, achieved-value
input) without needing to tap elsewhere or swipe down.

**Effort:** Small (1 file)

### Design

Add a toolbar button above the keyboard and enable interactive scroll dismiss:

```swift
// In ExerciseView's ScrollView:
.scrollDismissesKeyboard(.interactively)

// In ExerciseStepCard, on each TextField:
.toolbar {
    ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") {
            // Dismiss focus
        }
    }
}
```

To support the "Done" button, add a `@FocusState` to `ExerciseStepCard` (or
lift it to `ExerciseView` if shared across cards).

### Files

| File | Change |
|------|--------|
| `Views/ExerciseStepCard.swift` | Add `@FocusState`, `.focused()` modifier on TextFields, keyboard toolbar |

Optionally add `.scrollDismissesKeyboard(.interactively)` to the `ScrollView`
in `ExerciseView.swift` for swipe-to-dismiss as a secondary gesture.

### Notes

- This is a standard iOS pattern. The `.keyboard` toolbar placement is
  iOS 16+, which matches the project minimum.
- Only relevant on iOS; `#if os(iOS)` guard the toolbar if needed for macOS
  compilation.
  
### Open questions

- I'm not clear about the swipe-down thing. It currently doesn't work but 
  if it can be made working, then we don't need the toolbar and button.

---

## 3. Stat Row Alignment

**Goal:** The stats shown in `DailyChallengeCard` (Streak / Past 365d / YTD)
and `QuickStatsRow` (This week / This month / Last session) use independent
`HStack` layouts, so columns don't align vertically. Unify them into a shared
`Grid` for pixel-perfect alignment.

**Effort:** Small (3 files)

### Current layout (in `HomeView`)

```
┌─────────────────────────────┐
│  DailyChallengeCard         │
│  [Streak] [Past 365d] [YTD]│  ← HStack inside DailyChallengeCard
└─────────────────────────────┘
┌─────────────────────────────┐
│  QuickStatsRow              │
│  [Week]  [Month]  [Last]   │  ← HStack inside QuickStatsRow
└─────────────────────────────┘
```

Columns don't align because each row sizes independently.

### Proposed layout

Move the stat rows out of their respective cards and into a single `Grid`
(iOS 16+) in `HomeView`:

```
Grid(alignment: .top) {
    GridRow {  // from DailyChallengeCard
        StatCell(label: "Streak", value: ...)
        StatCell(label: "Past 365d", value: ...)
        StatCell(label: "YTD", value: ...)
    }
    Divider()
    GridRow {  // from QuickStatsRow
        StatCell(label: "This week", value: ...)
        StatCell(label: "This month", value: ...)
        StatCell(label: "Last session", value: ...)
    }
}
```

### Approach options

**Option A — Extract stats into `HomeView`'s Grid:**
Remove the bottom stat rows from `DailyChallengeCard` and `QuickStatsRow`,
and render them directly in `HomeView` inside a `Grid`. The cards themselves
keep their non-stat content (challenge circles, session info).

**Option B — Shared `StatCell` component:**
Create a small `StatCell` view and use it in both cards, but keep each card
self-contained. This doesn't fix alignment across cards unless they share
a parent `Grid`.

Recommend **Option A** — it's the only way to get cross-card column alignment.

### Files

| File | Change |
|------|--------|
| `Views/HomeView.swift` | Add `Grid` with two `GridRow`s for the combined stat rows |
| `Views/DailyChallengeCard.swift` | Remove bottom stat `HStack` |
| `Views/QuickStatsRow.swift` | Remove stat `HStack` (may become unnecessary if all content moves to `HomeView`) |
