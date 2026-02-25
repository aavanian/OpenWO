# Analysis: Export Workout Log for LLM Analysis

**Goal:** Let an LLM analyze workout progress from the log over a long-running conversation.

## Current State

- SQLite DB at `Library/Application Support/GymTrack/gymtrack.sqlite` inside the app container
- `dl_db.sh` copies the DB from a connected device to `~/Downloads/gymtrack-backup.sqlite` via `xcrun devicectl`
- All models are `Codable`
- No export functionality exists
- Key tables for analysis: `session`, `exerciseLog`, `workoutExercise`, `exercise`

## Options

### A. Raw SQLite File (already possible)

The `dl_db.sh` script pulls the DB. An LLM with code execution (ChatGPT, Claude with tools) can query it directly.

**Pros:**
- Zero development effort
- Full fidelity — all data accessible
- LLM can write arbitrary queries

**Cons:**
- Requires device connected via USB
- Not self-describing for the LLM (needs schema context)
- LLM must know SQLite and the schema to be useful

### B. JSON Export (lightweight feature)

Add a query that joins `session` + `exerciseLog` + `workoutExercise` + `exercise` and serializes to JSON.

Could be triggered from:
- The app (share sheet)
- A CLI tool (Swift or Python) reading the backed-up SQLite file

A CLI tool reading the backed-up DB is the lowest-effort path — no app changes needed.

**Pros:**
- Human/LLM readable without schema knowledge
- Easy to build (single query + JSON serialization)
- Works with any LLM that accepts text input

**Cons:**
- Static snapshot — LLM can't ask follow-up queries
- Potentially large output for long training histories
- Requires running `dl_db.sh` first (same as option A)

### C. MCP Server

A local MCP server exposing read-only queries over the SQLite DB.

- Could be a small Swift/Python process started alongside the LLM session
- Discovery: local stdio transport (Claude Desktop) or SSE for remote
- Auth: not needed for local-only; for remote, a simple token would suffice

**Pros:**
- LLM can ask dynamic questions, drill into specific exercises/dates
- No need to pre-decide what data to export
- Composable with other MCP tools

**Cons:**
- More infrastructure to build and maintain
- Needs MCP client support in the LLM tool
- Still requires `dl_db.sh` to get a fresh DB copy (unless the server runs on-device)

## Recommendation

Start with **B** (JSON export as a CLI script reading the backed-up SQLite). It's immediately useful and takes minimal effort. A Python script using `sqlite3` + `json` modules would be ~50 lines.

The MCP server (C) is the best long-term path but depends on the LLM tooling ecosystem maturing. It also pairs well with the workout management use case (see `analysis-workout-management.md`).
