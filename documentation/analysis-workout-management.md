# Analysis: Workout & Exercise Management

**Goal:** Edit workouts (reorder exercises, swap exercises, eventually full CRUD). The phone UI is too constrained for this, so consider alternative interfaces.

## Current State

- Workouts are seeded from `seed-workouts.json` at first migration — no runtime editing
- `SessionType` is a fixed Swift enum (`A`/`B`/`C`) with hardcoded display names and workout lookups
- Adding or removing workouts requires code changes
- No server or networking code exists in the app
- The SQLite DB can be pulled to a computer via `dl_db.sh`

## Options for the Editing Interface

### A. Datasette (read-only browser + manual edits)

[Datasette](https://datasette.io) can serve an existing SQLite DB as a browsable web UI. The `datasette-edit-schema` plugin adds basic editing.

**Pros:**
- Zero custom UI code
- Immediate setup (`datasette openwo-backup.sqlite`)
- Good for browsing and understanding data

**Cons:**
- Generic table editor — not workout-aware
- No drag-and-drop reordering
- User must understand the schema to make correct edits
- No constraint enforcement (e.g., unique positions, valid FKs)

### B. Custom Web UI Served from the App

Embed a lightweight HTTP server (Swift NIO, Vapor) in the app or as a companion macOS process. Serve a single-page app with a workout editor.

**Pros:**
- Tailored UX (drag-and-drop exercises, exercise picker, validation)
- Can enforce domain constraints
- Directly reads/writes the live DB

**Cons:**
- Significant development effort
- Networking code in the app increases complexity
- Security considerations (even on localhost)

### C. Custom Web UI as a Standalone Tool

A separate Python/Node tool that reads/writes the backed-up SQLite DB directly.

**Pros:**
- Decoupled from the app
- Can use any web framework (Flask, FastAPI, etc.)
- Full control over the editing UX

**Cons:**
- DB sync is manual and error-prone (edit on computer, push back to device)
- Risk of data loss if the app writes to the DB between backup and restore

### D. Datasette + Custom Plugin (pragmatic middle ground)

Use datasette for browsing/viewing. Write a small custom plugin or companion script for structured operations (reorder, swap exercise, add workout).

**Pros:**
- Leverages datasette's read UI for free
- Custom logic only where needed
- Scripts can enforce domain constraints

**Cons:**
- Split UX between browsing (datasette) and editing (scripts)
- Requires understanding the datasette plugin API

### E. LLM-Driven Editing via MCP

Expose the DB via MCP (see `analysis-export-log.md`). Let the LLM propose and execute changes.

**Pros:**
- Natural language interface ("swap dumbbell rows for cable rows in A and C")
- No custom UI needed
- Flexible — can handle any operation without pre-building UI for it

**Cons:**
- Depends on MCP infrastructure
- Trust/safety concerns (LLM writing to production DB)
- Needs guardrails (dry-run mode, confirmation prompts, backups)

## Making SessionType Dynamic

Currently `SessionType` is a hardcoded enum. To support user-created workouts:

1. Replace the enum with a dynamic lookup from the `workout` table
2. `session.sessionType` (currently stores `"A"`/`"B"`/`"C"` as text) would become a foreign key to `workout.id` or reference `workout.name`
3. Rotation logic would iterate over all active workouts instead of a fixed list
4. Display names and subtitles would come from the `workout` table instead of hardcoded strings

This is a prerequisite for any editing solution — without it, newly created workouts can't be scheduled.

## Recommendation

**Short term:** Datasette (option A) for read-only browsing + a CLI script for structured edits (reorder, swap). This gives immediate value with minimal effort.

**Medium term:** MCP server (option E) for LLM-driven editing — this aligns with the export analysis and is the most flexible approach. Safety guardrails (transaction wrapping, dry-run, backups) are essential.

**Long term:** If a richer UI is needed, a custom web editor (option B or C) served from a companion process. Only justified if the LLM-driven approach proves insufficient for routine edits.
