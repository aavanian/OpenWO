# GymTrack — iOS App Specification
**v1.0 Draft for Development**

---

## 1. Overview

GymTrack is a minimal, no-account iOS app to track a personal gym routine built around 3 rotating workout types (A, B, C), a daily bodyweight challenge, and long-term habit streaks. All data is stored locally in a SQLite database synced to iCloud Drive. There is no backend, no authentication, and no network dependency.

| | |
|---|---|
| **Platform** | iOS 16+ |
| **Language** | Swift / SwiftUI |
| **Storage** | SQLite (via GRDB or SQLite.swift), file stored in iCloud Drive container |
| **No account** | No sign-in, no server, no analytics SDK |
| **iCloud sync** | NSUbiquitousContainer — database file in iCloud Drive, accessible across user's own devices |

---

## 2. Screen Map

- Main Screen (Home)
- Exercise Screen (active workout)
- Stats Screen (placeholder for v1.1)

---

## 3. Main Screen

### 3.1 Workout Streak

Displayed prominently at the top. A streak counts consecutive calendar days on which at least one gym session (A, B, or C) was completed.

- Large number: current streak in days
- Subtext: e.g. "12-day streak" or "Start your streak today!" if 0
- Visual: a simple flame icon or ring indicator (design choice, keep minimal)

### 3.2 Workout Buttons (A / B / C)

Three large tappable cards or buttons, one per workout type.

- The next workout in rotation is highlighted (accent color, slightly larger or elevated)
- Rotation logic: A → B → C → A → …, inferred from the last completed session stored in the database
- Each button shows the workout label (A, B, or C) and a short subtitle:
  - A → "Upper Strength"
  - B → "Cardio + Core"
  - C → "Mixed / Maintenance"
- Tapping any button triggers a confirmation pop-up (see 3.3), not immediate navigation

### 3.3 Confirmation Pop-up

A modal sheet or alert presented after tapping a workout button.

- Title: e.g. "Start Day A — Upper Strength?"
- Body: brief one-line description of the session
- Two actions: **"Let's go"** (confirms, navigates to Exercise Screen) and **"Not now"** (dismisses)

### 3.4 Daily Challenge Stats

A card below the workout buttons showing the bodyweight challenge status. The challenge is 30 squats + 30 push-ups per day, done as 3 sets of 10.

| Field | Detail |
|---|---|
| **Sets done today** | 0 / 3 — tappable, each tap logs one completed set |
| **Today's status** | Visual indicator: empty / partial / complete |
| **Current streak** | Consecutive days with all 3 sets completed |
| **Past 365 days** | Count of days with full challenge completion |
| **Year to date** | Count of days with full challenge completion in current calendar year |

The "Sets done today" counter should be the most prominent interactive element in this card. A single tap increments it (max 3). A long-press allows manual correction (set to 0, 1, 2, or 3).

### 3.5 Quick Stats Summary

A compact row or small card showing at-a-glance numbers:

- Sessions this week
- Sessions this month
- Last session: type and date

Full stats and graphs are deferred to the Stats Screen (v1.1).

---

## 4. Exercise Screen

Displayed when the user confirms starting a workout. Shows the full session plan with steps, timers, and set tracking.

### 4.1 Layout

- Header: workout name (e.g. "Day A — Upper Strength") + elapsed time counter
- Scrollable list of steps/exercises in order
- Each step has: title, instruction text, set/rep counter (where applicable), and an optional timer
- A "Finish workout" button fixed at the bottom, which logs the session and returns to Main Screen

### 4.2 Step / Exercise Cards

- Each card shows the exercise name as the card header
- Instruction text below (from session definitions in section 5)
- For timed steps: a start/pause timer button with countdown display
- For set-based steps: a tap-to-complete set tracker (e.g. ○ ○ ○ → tap fills circles ● ● ○)
- Completed steps are visually dimmed or checked off but remain visible for reference

### 4.3 Daily Challenge Integration

The first exercise step in every session is the Daily Challenge set (10 squats + 10 push-ups). Completing this step automatically increments the daily challenge counter on the Main Screen by 1.

### 4.4 Finishing

- Tapping "Finish workout" logs: session type (A/B/C), date, time started, duration
- If fewer than 50% of steps were checked, show a brief confirmation: "Log as partial session?" with Yes / No
- After logging, return to Main Screen with streak updated

---

## 5. Session Definitions

These are the exercise plans for each session type. All set/rep counts are defaults; a future settings screen may allow customisation.

### 5.1 Day A — Upper Strength

Focus: push/pull balance, arm strength rebuilding. Target duration: 40–45 min.

| Exercise | Sets | Reps / Duration | Notes |
|---|---|---|---|
| Cardio warm-up (cycling) | — | 10 min | Easy pace, joints only |
| Daily Challenge — squats + push-ups | 1 of 3 | 10 + 10 reps | Counts toward daily challenge |
| Dumbbell rows (pull) | 1 warm-up + 3 working | 10 reps / side | Elbow back and up, knee on bench |
| Dumbbell chest press (push) | 1 warm-up + 3 working | 10 reps | 2–3 sec descent, slow is the work |
| Shoulder press (push) | 3 | 10 reps | Go light — easy to strain when returning |
| Bicep curls (pull) | 3 | 10 reps | No swinging, controlled |
| Plank | 2 | 30–45 sec hold | Hips level |
| Dead bugs | 2 | 10 reps | Lower back pressed into mat |
| Stretch | — | 5 min | Chest opener, lat, shoulder cross-body |

### 5.2 Day B — Cardio + Core + Flexibility

Focus: aerobic base, core, mobility. Target duration: 45–50 min. Good for lower-energy mornings.

| Exercise | Sets | Reps / Duration | Notes |
|---|---|---|---|
| Cardio warm-up (cycling) | — | 5 min | Easy pace |
| Daily Challenge — squats + push-ups | 1 of 3 | 10 + 10 reps | Counts toward daily challenge |
| Main cardio block (cycling) | — | 20 min | 6–7/10 effort, steady pace |
| Plank | 3 | 30–45 sec hold | Quality over duration |
| Dead bugs | 3 | 10 reps / side | Deliberate, back flat |
| Leg raises | 3 | 10 reps | Bend knees if lower back lifts |
| Flexibility & mobility | — | 10 min | Hip flexors, hamstrings, chest opener, glutes |

**Flexibility block detail:** hip flexor lunge stretch (2 min/side), seated hamstring stretch (2 min), chest opener on mat (2 min), figure-4 glute stretch (2 min/side).

### 5.3 Day C — Mixed / Maintenance

Focus: lighter full-body session. Target duration: 35–40 min. Designed for charging days or low-energy mornings. A completed Day C beats a skipped Day A.

| Exercise | Sets | Reps / Duration | Notes |
|---|---|---|---|
| Cardio — cycling or stepper | — | 15 min | Comfortable to moderate effort |
| Daily Challenge — squats + push-ups | 1 of 3 | 10 + 10 reps | Counts toward daily challenge |
| Dumbbell rows (pull) | 2 | 10 reps / side | Lighter than Day A, maintenance pace |
| Chest press or push-ups (push) | 2 | 10 reps | Dumbbells or bodyweight |
| Plank | 1 | 30–40 sec | — |
| Dead bugs | 1 | 10 reps / side | — |
| Stretch | — | 7 min | Chest opener, hip flexors, hamstrings |

---

## 6. Data Model (SQLite)

All data lives in a single SQLite file stored in the app's iCloud Drive container. No external dependencies.

### 6.1 Tables

**`sessions`**

| Column | Type | Description |
|---|---|---|
| id | INTEGER PK | Auto-increment |
| session_type | TEXT | 'A', 'B', or 'C' |
| date | TEXT | ISO date string YYYY-MM-DD |
| started_at | TEXT | ISO datetime |
| duration_seconds | INTEGER | Total session duration |
| is_partial | INTEGER | 0 or 1 |

**`daily_challenge`**

| Column | Type | Description |
|---|---|---|
| id | INTEGER PK | Auto-increment |
| date | TEXT | ISO date string YYYY-MM-DD, unique |
| sets_completed | INTEGER | 0, 1, 2, or 3 |

### 6.2 iCloud Storage Path

```
<iCloud Container>/Documents/gymtrack.sqlite
```

Use `NSFileCoordinator` for all reads/writes to avoid iCloud sync conflicts. Enable the iCloud Documents entitlement in the app target.

---

## 7. Rotation Logic

- On app launch, query the most recent row in the `sessions` table
- Next session = (last_session_type + 1) mod 3, mapped to A/B/C
- If no sessions exist, default to A
- If the last session was today (same date), next defaults to the following type in rotation — do not offer the same type twice in one day
- The highlighted button on the Main Screen reflects this computed next type

---

## 8. Streak Logic

### 8.1 Gym Session Streak

- A day "counts" if at least one non-partial session was completed on that calendar date
- Streak = number of consecutive days ending today (or yesterday if today has no session yet)
- A gap of more than one day resets the streak to 0

### 8.2 Daily Challenge Streak

- A day "counts" if `sets_completed = 3` for that date in `daily_challenge`
- Same consecutive-day logic as above

---

## 9. Stats Screen (v1.1 — Placeholder)

Out of scope for v1.0 but should be architecturally anticipated. A bottom tab or nav item labelled "Stats" should exist in v1.0 and show a "Coming soon" placeholder.

**Planned v1.1 content:**

- Weekly/monthly session frequency bar chart
- Session type distribution (A vs B vs C)
- Challenge completion heatmap (GitHub-style, 52 weeks)
- Personal bests (longest gym streak, longest challenge streak)

---

## 10. UX & Design Notes

- Keep the UI minimal and fast to open — the app should feel instant
- Dark mode support required from day one
- No onboarding flow — Main Screen is the first thing seen
- No notifications in v1.0 (deferred), but structure the codebase so they can be added cleanly
- Haptic feedback on: completing a set, finishing a workout, incrementing the daily challenge counter
- Accessibility: support Dynamic Type for all text

---

## 11. Out of Scope for v1.0

- User accounts or cloud backend
- Social or sharing features
- Custom workout editor
- Notifications / reminders (architecture should allow future addition)
- Apple Watch companion app
- HealthKit integration
- Stats screen content (placeholder only)

---

*End of specification — v1.0 draft*
