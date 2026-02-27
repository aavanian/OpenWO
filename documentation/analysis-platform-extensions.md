# Platform Extensions

Overview of three larger platform features: Apple Watch companion, voiceover
coaching, and Apple Intelligence integration.

---

## 1. Apple Watch Companion App

**Goal:** A lightweight watch app that lets users follow a workout hands-free at
the gym, without pulling out their phone.

**Effort:** Large

### Architecture

- **Dependent watch app** bundled inside the iOS app (not standalone).
- Communication via `WatchConnectivity` (`WCSession`): the phone sends the
  exercise list for the selected session; the watch displays it.
- **No GRDB on the watch.** The watch receives a JSON-encoded array of exercise
  structs and renders them. All persistence stays on the phone.

### Watch UI

One exercise at a time, swipe-to-advance:

```
┌─────────────────────┐
│  Bench Press   2/6  │  ← exercise name + position
│                     │
│  3 × 12 reps       │  ← sets × reps/time
│  ○ ○ ○              │  ← set tracker (tap to complete)
│                     │
│  ▶ 1:30             │  ← timer (for timed exercises)
└─────────────────────┘
```

- `SetTracker` reuse: the existing `SetTracker` view is pure SwiftUI with no
  platform-specific code, so it can compile for watchOS as-is.
- `TimerView` similarly portable; verify that haptics (`Haptics.swift`) degrade
  gracefully on watchOS or guard with `#if os(watchOS)`.

### Data flow

```
Phone (HomeView)                    Watch
     │                                │
     ├── User taps "Start Day A" ────►│
     │   WCSession.transferUserInfo   │
     │   payload: [Exercise] as JSON  │
     │                                ├── Decode, display exercise list
     │                                │
     │◄── Set completed ─────────────┤
     │   WCSession.sendMessage        │
     │                                │
     ├── Session finished ───────────►│
     │   Mark complete, save to DB    │
```

### HealthKit on watch

The watch should own the `HKWorkoutSession` — this gives full sensor access
(high-frequency heart rate every few seconds, active calories with workout-
specific algorithms, wrist detection).

**Recommended approach: watch-owned workout, not mirroring.**

- The watch starts its own `HKWorkoutSession` + `HKLiveWorkoutBuilder` when
  notified by the phone that a workout has started.
- The phone drops its own `HKWorkoutSession` when the watch is paired and
  reachable, to avoid duplicate workouts in HealthKit.
- On iOS 26+, the phone currently uses `HKWorkoutSession` for a Live Activity
  indicator. When the watch companion is active, the phone should fall back to
  silent `HKWorkoutBuilder` (or skip HealthKit entirely) and let the watch
  handle it.

**Why not mirroring (`HKWorkoutSession.mirror(to:)`)?**

- Mirroring is for controlling a single shared session across devices (e.g.,
  start on phone, mirror to watch). It adds complexity.
- Since OpenWO's primary UI is phone-based (exercise steps, weight logging),
  and the watch is a follow-along companion, two coordinated sessions via
  `WatchConnectivity` is simpler and gives the same end result.
- If mirroring becomes desirable later (e.g., seamless handoff mid-workout),
  it can be added incrementally.

**Without a watch companion:** the phone's `HKWorkoutSession` (iOS 26+) does
show a Dynamic Island indicator, but the watch won't display anything and heart
rate sampling stays at background rate (~every 10 minutes). HealthKit associates
any samples that overlap the workout time window, but data quality is low.

### Project setup

- Add a watchOS target in `project.yml` (XcodeGen supports
  `type: application.watchapp2`).
- Minimum watchOS 12 (aligns with iOS 26 pairing and `HKWorkoutSession` APIs).
- New SPM target or shared source set for the watch views.

### Risks

- `WatchConnectivity` is unreliable when the phone is locked or the app is
  backgrounded. Need robust error handling and a "waiting for phone" state.
- Watch screen real estate is very limited; complex exercises with many fields
  will need careful layout.
- Coordinating workout start/stop between phone and watch requires careful
  state management to avoid duplicate or orphaned HealthKit workouts.

---

## 2. Voiceover Coaching

**Goal:** Announce exercise transitions, set completions, and timer milestones
audibly so the user doesn't need to look at the screen during a workout.

**Effort:** Medium

**Depends on:** Topic 1 (Fold/Unfold) — the "current exercise" concept provides
the trigger points for announcements.

### Implementation

Use `AVSpeechSynthesizer` with an `.duckOthers` audio session so speech mixes
with the user's music without pausing it:

```swift
import AVFoundation

let synthesizer = AVSpeechSynthesizer()

func announce(_ text: String) {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, options: .duckOthers)
    try? session.setActive(true)

    let utterance = AVSpeechUtterance(string: text)
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate
    synthesizer.speak(utterance)
}
```

### Announcement triggers

| Event | Example announcement |
|-------|---------------------|
| Exercise transition (auto-advance) | "Next: Bench Press, 3 sets of 12 reps" |
| Set completed | "Set 2 of 3 complete" |
| All sets completed | "Bench Press done" |
| Timer milestone (halfway, 10s left) | "30 seconds remaining" |
| Workout finished | "Workout complete. 45 minutes." |

### Integration points

| File | Change |
|------|--------|
| `Views/ExerciseView.swift` | Call `announce()` on auto-advance (from Topic 1) |
| `Views/SetTracker.swift` | Call `announce()` when a set circle is tapped |
| `Views/TimerView.swift` | Call `announce()` at configurable milestones |
| New: `Utilities/VoiceCoach.swift` | Encapsulate `AVSpeechSynthesizer` + audio session |

### User control

- Add a toggle in the workout toolbar or a per-session setting to
  enable/disable voice coaching.
- Store preference in `UserDefaults` (no schema change needed).

### Notes

- `AVSpeechSynthesizer` is iOS-only; guard with `#if os(iOS)`.
- The `.duckOthers` option lowers music volume during speech, then restores it.
  This is the standard approach for mixing speech over media playback.
- Test with AirPods — speech routing should follow the active audio output
  automatically.

---

## 3. Apple Intelligence / AI Features

**Goal:** Help users gain insights from their workout data using AI, and
explore Siri integration.

**Effort:** Small (data export), Small-Medium (AI features)

### Foundation Models framework (iOS 26+)

Apple's on-device Foundation Models framework (`FoundationModels.framework`)
requires iOS 26. The project's minimum target is iOS 18, so this needs an
`#available(iOS 26, *)` guard.

**Recommendation:** Do not adopt Foundation Models as a primary feature. Instead:

1. **Ship data export first** (works on iOS 18+).
2. **Optionally add Foundation Models** behind `#available(iOS 26, *)` as a
   progressive enhancement for users on the latest OS.

### Data export via ShareLink (iOS 16+)

Provide a "Share workout data" action that exports structured JSON for use with
any external LLM (ChatGPT, Claude, etc.):

```swift
struct WorkoutExport: Codable {
    let exportDate: String
    let sessions: [SessionExport]
    let exercises: [ExerciseExport]
    let personalBests: PersonalBestsExport
}

// In StatsView or a dedicated export section:
ShareLink(
    item: exportJSON,
    preview: SharePreview("OpenWO Data", image: Image(systemName: "chart.bar"))
)
```

This gives users immediate AI value with zero platform constraints:
- "Analyse my workout trends"
- "Suggest a progression plan based on my data"
- "What muscles am I undertaining?"

### Optional: Foundation Models (iOS 26+)

If adding on-device AI as a progressive enhancement:

```swift
if #available(iOS 26, *) {
    import FoundationModels

    let session = LanguageModelSession()
    let response = try await session.respond(to: prompt)
}
```

Possible features:
- Natural-language workout summaries ("You trained 4 times this week, up from 3
  last week. Your bench press is trending up.")
- Exercise recommendations based on recent history.

Guard all Foundation Models code behind `#available(iOS 26, *)` and provide
a fallback (the JSON export) for older OS versions.

### App Intents / Siri integration (iOS 16+)

A lighter-weight alternative to full AI features. App Intents let users interact
with the app via Siri and Shortcuts:

```swift
struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Workout"

    @Parameter(title: "Session Type")
    var sessionType: SessionTypeEntity

    func perform() async throws -> some IntentResult {
        // Launch workout for the given session type
    }
}

struct LogChallengeIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Challenge Set"

    func perform() async throws -> some IntentResult {
        // Increment today's challenge count
    }
}
```

Use cases:
- "Hey Siri, start my workout" → opens the app to the next session.
- "Hey Siri, log a challenge set" → increments today's challenge count.
- Shortcut automations (e.g., auto-log challenge at a scheduled time).

### Implementation order

1. **JSON data export** — immediate value, no new frameworks, iOS 16+.
2. **App Intents** — lightweight Siri integration, iOS 16+.
3. **Foundation Models** — optional progressive enhancement, iOS 26+ only.

### Files

| File | Action |
|------|--------|
| New: `Domain/WorkoutExport.swift` | `Codable` export structs |
| `Data/Queries.swift` | Add `exportData(db:)` query |
| `Views/StatsView.swift` (or new export view) | `ShareLink` for JSON export |
| New: `Intents/StartWorkoutIntent.swift` | App Intent for starting workouts |
| New: `Intents/LogChallengeIntent.swift` | App Intent for challenge logging |
