#!/usr/bin/env -S uv run --script
"""CLI for GymTrack workout management.

Operates directly on the iCloud-synced SQLite database.
All mutations are dry-run by default — pass --execute to apply.
"""

import argparse
import difflib
import json
import shutil
import sqlite3
import sys
from datetime import datetime
from pathlib import Path
from typing import NoReturn

# ── DB Discovery ──────────────────────────────────────────────────────

DEFAULT_DB_PATH = Path.home() / (
    "Library/Mobile Documents/"
    "iCloud~com~avanian~gymtrack/Documents/gymtrack.sqlite"
)


def discover_db(explicit: str | None) -> Path:
    if explicit:
        p = Path(explicit)
        if not p.exists():
            die(f"Database not found: {p}")
        return p
    if DEFAULT_DB_PATH.exists():
        return DEFAULT_DB_PATH
    die(
        f"Database not found at default location:\n  {DEFAULT_DB_PATH}\n"
        "Use --db PATH to specify an explicit path."
    )


def connect(path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode = DELETE")
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


# ── Migration ─────────────────────────────────────────────────────────

def ensure_is_active_column(conn: sqlite3.Connection) -> None:
    cols = [r["name"] for r in conn.execute("PRAGMA table_info(workoutExercise)")]
    if "isActive" not in cols:
        conn.execute(
            "ALTER TABLE workoutExercise ADD COLUMN isActive BOOLEAN NOT NULL DEFAULT 1"
        )
        conn.commit()


# ── Backup ────────────────────────────────────────────────────────────

_backup_done = False


def backup_db(db_path: Path) -> Path:
    global _backup_done
    if _backup_done:
        return db_path
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    bak = db_path.with_suffix(f".sqlite.bak.{stamp}")
    shutil.copy2(db_path, bak)
    print(f"Backup: {bak}")
    _backup_done = True
    return bak


# ── Exercise Resolution ──────────────────────────────────────────────

def resolve_exercise(conn: sqlite3.Connection, query: str) -> sqlite3.Row:
    """Resolve a query string to exactly one exercise row."""
    rows = conn.execute("SELECT * FROM exercise").fetchall()
    q = query.lower()

    # Exact match (case-insensitive)
    exact = [r for r in rows if r["name"].lower() == q]
    if len(exact) == 1:
        return exact[0]

    # Substring match
    subs = [r for r in rows if q in r["name"].lower()]
    if len(subs) == 1:
        return subs[0]
    if len(subs) > 1:
        die(
            f"Ambiguous exercise \"{query}\" — matches:\n"
            + "\n".join(f"  - {r['name']}" for r in subs)
        )

    # No match — suggest closest
    names = [r["name"] for r in rows]
    close = difflib.get_close_matches(query, names, n=3, cutoff=0.4)
    msg = f"No exercise matching \"{query}\"."
    if close:
        msg += "\nDid you mean:\n" + "\n".join(f"  - {n}" for n in close)
    die(msg)


def resolve_workout(conn: sqlite3.Connection, query: str) -> sqlite3.Row:
    """Resolve a query string to exactly one workout row."""
    rows = conn.execute("SELECT * FROM workout").fetchall()
    q = query.lower()

    exact = [r for r in rows if r["name"].lower() == q]
    if len(exact) == 1:
        return exact[0]

    subs = [r for r in rows if q in r["name"].lower()]
    if len(subs) == 1:
        return subs[0]
    if len(subs) > 1:
        die(
            f"Ambiguous workout \"{query}\" — matches:\n"
            + "\n".join(f"  - {r['name']}" for r in subs)
        )

    names = [r["name"] for r in rows]
    close = difflib.get_close_matches(query, names, n=3, cutoff=0.4)
    msg = f"No workout matching \"{query}\"."
    if close:
        msg += "\nDid you mean:\n" + "\n".join(f"  - {n}" for n in close)
    die(msg)


# ── Helpers ───────────────────────────────────────────────────────────

def die(msg: str) -> NoReturn:
    print(f"Error: {msg}", file=sys.stderr)
    sys.exit(1)


def format_counter(unit: str, value: int) -> str:
    if unit == "timer":
        m, s = divmod(value, 60)
        return f"{m}:{s:02d}"
    return str(value)


# ── Commands ──────────────────────────────────────────────────────────

def cmd_show(conn: sqlite3.Connection, args: argparse.Namespace) -> None:
    if args.workout:
        workout = resolve_workout(conn, args.workout)
        workouts = [workout]
    else:
        workouts = conn.execute("SELECT * FROM workout ORDER BY id").fetchall()

    for w in workouts:
        active_filter = "" if args.all else "AND we.isActive = 1"
        rows = conn.execute(
            f"""
            SELECT e.name, we.position, we.sets, we.counterUnit, we.counterValue,
                   we.counterLabel, we.restSeconds, we.hasWeight, we.isActive
            FROM workoutExercise we
            JOIN exercise e ON e.id = we.exerciseId
            WHERE we.workoutId = ? {active_filter}
            ORDER BY we.position
            """,
            (w["id"],),
        ).fetchall()

        print(f"\n{'='*60}")
        print(f"  {w['name']}")
        print(f"{'='*60}")
        if not rows:
            print("  (no exercises)")
            continue

        # Header
        print(f"  {'#':<4} {'Exercise':<32} {'Sets':>4} {'Reps/Time':>10} {'Rest':>5} {'Wt':>3}")
        print(f"  {'─'*4} {'─'*32} {'─'*4} {'─'*10} {'─'*5} {'─'*3}")
        for r in rows:
            active_mark = "" if r["isActive"] else " [inactive]"
            counter_str = format_counter(r["counterUnit"], r["counterValue"])
            if r["counterLabel"]:
                counter_str = r["counterLabel"]
            wt = "Y" if r["hasWeight"] else ""
            print(
                f"  {r['position']:<4} {r['name'] + active_mark:<32} "
                f"{r['sets']:>4} {counter_str:>10} "
                f"{r['restSeconds']:>4}s {wt:>3}"
            )
    print()


def cmd_exercises(conn: sqlite3.Connection, args: argparse.Namespace) -> None:
    conditions = ["1=1"]
    params: list = []

    if args.query:
        conditions.append("LOWER(e.name) LIKE ?")
        params.append(f"%{args.query.lower()}%")
    if args.muscle:
        conditions.append(
            "(LOWER(e.primaryMuscles) LIKE ? OR LOWER(e.secondaryMuscles) LIKE ?)"
        )
        params.extend([f"%{args.muscle.lower()}%"] * 2)
    if args.equipment:
        conditions.append("LOWER(e.equipment) LIKE ?")
        params.append(f"%{args.equipment.lower()}%")

    where = " AND ".join(conditions)
    rows = conn.execute(
        f"""
        SELECT e.id, e.name, e.equipment, e.primaryMuscles, e.secondaryMuscles,
               e.level, e.category, e.force, e.mechanic
        FROM exercise e
        WHERE {where}
        ORDER BY e.name
        """,
        params,
    ).fetchall()

    if not rows:
        print("No exercises found.")
        return

    print(f"\n{'ID':>4}  {'Name':<35} {'Equipment':<15} {'Muscles':<25} {'Level':<12}")
    print(f"{'─'*4}  {'─'*35} {'─'*15} {'─'*25} {'─'*12}")
    for r in rows:
        muscles = r["primaryMuscles"] or ""
        print(
            f"{r['id']:>4}  {r['name']:<35} {(r['equipment'] or '')::<15} "
            f"{muscles:<25} {(r['level'] or ''):<12}"
        )
    print(f"\n{len(rows)} exercise(s) found.")


def cmd_swap(conn: sqlite3.Connection, args: argparse.Namespace, db_path: Path) -> None:
    workout = resolve_workout(conn, args.workout)
    old_ex = resolve_exercise(conn, args.old)
    new_ex = resolve_exercise(conn, args.new)

    # Find the active workoutExercise row for the old exercise
    we_row = conn.execute(
        """
        SELECT * FROM workoutExercise
        WHERE workoutId = ? AND exerciseId = ? AND isActive = 1
        """,
        (workout["id"], old_ex["id"]),
    ).fetchone()

    if not we_row:
        die(
            f"\"{old_ex['name']}\" is not an active exercise in "
            f"\"{workout['name']}\"."
        )

    # Determine programming for the new row
    sets = args.sets if args.sets is not None else we_row["sets"]
    reps = args.reps if args.reps is not None else we_row["counterValue"]
    rest = args.rest if args.rest is not None else we_row["restSeconds"]

    print(f"\nSwap in \"{workout['name']}\":")
    print(f"  Position {we_row['position']}: {old_ex['name']} → {new_ex['name']}")
    print(f"  Sets: {sets}, Reps/Value: {reps}, Rest: {rest}s")

    if not args.execute:
        print("\nDry run — pass --execute to apply.")
        return

    backup_db(db_path)
    conn.execute("BEGIN")
    try:
        # Mark old row inactive; park position at -id to free the unique constraint
        conn.execute(
            "UPDATE workoutExercise SET isActive = 0, position = -id WHERE id = ?",
            (we_row["id"],),
        )
        # Insert new row at same position
        conn.execute(
            """
            INSERT INTO workoutExercise
              (workoutId, exerciseId, position, counterUnit, counterValue,
               counterLabel, restSeconds, sets, isDailyChallenge, hasWeight, isActive)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
            """,
            (
                workout["id"],
                new_ex["id"],
                we_row["position"],
                we_row["counterUnit"],
                reps,
                we_row["counterLabel"],
                rest,
                sets,
                we_row["isDailyChallenge"],
                1 if new_ex["hasWeight"] else 0,
            ),
        )
        conn.commit()
        print("Done.")
    except Exception:
        conn.rollback()
        raise


def cmd_add(conn: sqlite3.Connection, args: argparse.Namespace, db_path: Path) -> None:
    workout = resolve_workout(conn, args.workout)
    exercise = resolve_exercise(conn, args.exercise)

    # Determine position
    max_pos_row = conn.execute(
        "SELECT MAX(position) AS mp FROM workoutExercise WHERE workoutId = ? AND isActive = 1",
        (workout["id"],),
    ).fetchone()
    max_pos = max_pos_row["mp"] if max_pos_row and max_pos_row["mp"] is not None else 0

    if args.position is not None:
        position = args.position
        if position < 1 or position > max_pos + 1:
            die(f"Position must be between 1 and {max_pos + 1}.")
    else:
        position = max_pos + 1

    sets = args.sets if args.sets is not None else 3
    counter_unit = "timer" if args.timed else "reps"
    reps = args.reps if args.reps is not None else (60 if args.timed else 10)
    rest = args.rest if args.rest is not None else 30
    has_weight = args.weight if args.weight else bool(exercise["hasWeight"])

    print(f"\nAdd to \"{workout['name']}\":")
    print(f"  Position {position}: {exercise['name']}")
    print(f"  Sets: {sets}, {'Time' if args.timed else 'Reps'}: {reps}, Rest: {rest}s, Weight: {'Y' if has_weight else 'N'}")

    if position <= max_pos:
        print(f"  (exercises at position {position}+ will shift down)")

    if not args.execute:
        print("\nDry run — pass --execute to apply.")
        return

    backup_db(db_path)
    conn.execute("BEGIN")
    try:
        if position <= max_pos:
            # Fetch all active rows at or after the insertion point
            affected = conn.execute(
                """
                SELECT id, position FROM workoutExercise
                WHERE workoutId = ? AND isActive = 1 AND position >= ?
                ORDER BY position
                """,
                (workout["id"], position),
            ).fetchall()
            # Phase 1: move to temporary positions
            offset = max_pos + 100
            for r in affected:
                conn.execute(
                    "UPDATE workoutExercise SET position = ? WHERE id = ?",
                    (offset + r["position"], r["id"]),
                )
            # Phase 2: set final positions (+1 from original)
            for r in affected:
                conn.execute(
                    "UPDATE workoutExercise SET position = ? WHERE id = ?",
                    (r["position"] + 1, r["id"]),
                )
        conn.execute(
            """
            INSERT INTO workoutExercise
              (workoutId, exerciseId, position, counterUnit, counterValue,
               counterLabel, restSeconds, sets, isDailyChallenge, hasWeight, isActive)
            VALUES (?, ?, ?, ?, ?, NULL, ?, ?, 0, ?, 1)
            """,
            (
                workout["id"],
                exercise["id"],
                position,
                counter_unit,
                reps,
                rest,
                sets,
                1 if has_weight else 0,
            ),
        )
        conn.commit()
        print("Done.")
    except Exception:
        conn.rollback()
        raise


def cmd_remove(conn: sqlite3.Connection, args: argparse.Namespace, db_path: Path) -> None:
    workout = resolve_workout(conn, args.workout)
    exercise = resolve_exercise(conn, args.exercise)

    we_row = conn.execute(
        """
        SELECT * FROM workoutExercise
        WHERE workoutId = ? AND exerciseId = ? AND isActive = 1
        """,
        (workout["id"], exercise["id"]),
    ).fetchone()

    if not we_row:
        die(
            f"\"{exercise['name']}\" is not an active exercise in "
            f"\"{workout['name']}\"."
        )

    print(f"\nRemove from \"{workout['name']}\":")
    print(f"  Position {we_row['position']}: {exercise['name']}")

    if not args.execute:
        print("\nDry run — pass --execute to apply.")
        return

    backup_db(db_path)
    conn.execute("BEGIN")
    try:
        # Mark inactive; park position at -id to free the unique constraint
        conn.execute(
            "UPDATE workoutExercise SET isActive = 0, position = -id WHERE id = ?",
            (we_row["id"],),
        )
        # Shift positions up for remaining exercises
        affected = conn.execute(
            """
            SELECT id, position FROM workoutExercise
            WHERE workoutId = ? AND isActive = 1 AND position > ?
            ORDER BY position
            """,
            (workout["id"], we_row["position"]),
        ).fetchall()
        # Phase 1: move to temporary positions
        offset = we_row["position"] + 100
        for r in affected:
            conn.execute(
                "UPDATE workoutExercise SET position = ? WHERE id = ?",
                (offset + r["position"], r["id"]),
            )
        # Phase 2: set final positions (-1 from original)
        for r in affected:
            conn.execute(
                "UPDATE workoutExercise SET position = ? WHERE id = ?",
                (r["position"] - 1, r["id"]),
            )
        conn.commit()
        print("Done.")
    except Exception:
        conn.rollback()
        raise


def cmd_reorder(conn: sqlite3.Connection, args: argparse.Namespace, db_path: Path) -> None:
    workout = resolve_workout(conn, args.workout)
    from_pos = args.move
    to_pos = args.to

    # Fetch active exercises
    rows = conn.execute(
        """
        SELECT we.id, we.position, e.name
        FROM workoutExercise we
        JOIN exercise e ON e.id = we.exerciseId
        WHERE we.workoutId = ? AND we.isActive = 1
        ORDER BY we.position
        """,
        (workout["id"],),
    ).fetchall()

    positions = [r["position"] for r in rows]
    if from_pos not in positions:
        die(f"No active exercise at position {from_pos}.")
    if to_pos < 1 or to_pos > max(positions):
        die(f"Target position must be between 1 and {max(positions)}.")
    if from_pos == to_pos:
        die("Source and target positions are the same.")

    moving = next(r for r in rows if r["position"] == from_pos)
    print(f"\nReorder in \"{workout['name']}\":")
    print(f"  Move \"{moving['name']}\" from position {from_pos} to {to_pos}")

    if not args.execute:
        print("\nDry run — pass --execute to apply.")
        return

    backup_db(db_path)
    conn.execute("BEGIN")
    try:
        # Build the reordered list in Python to avoid unique constraint
        # collisions from bulk UPDATE position arithmetic
        ordered = list(rows)
        from_idx = next(i for i, r in enumerate(ordered) if r["position"] == from_pos)
        to_idx = next(i for i, r in enumerate(ordered) if r["position"] == to_pos)
        item = ordered.pop(from_idx)
        ordered.insert(to_idx, item)

        # Phase 1: move all affected rows to temporary positions
        offset = max(positions) + 100
        for i, r in enumerate(ordered):
            conn.execute(
                "UPDATE workoutExercise SET position = ? WHERE id = ?",
                (offset + i, r["id"]),
            )
        # Phase 2: set final positions
        for i, r in enumerate(ordered):
            conn.execute(
                "UPDATE workoutExercise SET position = ? WHERE id = ?",
                (i + 1, r["id"]),
            )

        conn.commit()
        print("Done.")
    except Exception:
        conn.rollback()
        raise


def cmd_import_exercises(conn: sqlite3.Connection, args: argparse.Namespace, db_path: Path) -> None:
    file_path = Path(args.file)
    if not file_path.exists():
        die(f"File not found: {file_path}")

    with open(file_path) as f:
        data = json.load(f)

    if not isinstance(data, list):
        die("Expected a JSON array of exercise objects.")

    # Get existing exercise names (case-insensitive)
    existing = {
        r["name"].lower()
        for r in conn.execute("SELECT name FROM exercise").fetchall()
    }

    to_import = []
    skipped = []
    for entry in data:
        name = entry.get("name", "")
        if name.lower() in existing:
            skipped.append(name)
        else:
            to_import.append(entry)

    if skipped:
        print(f"\nSkipping {len(skipped)} existing exercise(s):")
        for name in skipped:
            print(f"  - {name}")

    if to_import:
        print(f"\nWould import {len(to_import)} exercise(s):")
        for entry in to_import:
            print(f"  + {entry['name']}")
    else:
        print("\nNothing to import.")
        return

    if not args.execute:
        print("\nDry run — pass --execute to apply.")
        return

    backup_db(db_path)
    conn.execute("BEGIN")
    try:
        for e in to_import:
            primary = json.dumps(e.get("primaryMuscles", [])) if e.get("primaryMuscles") else None
            secondary = json.dumps(e.get("secondaryMuscles", [])) if e.get("secondaryMuscles") else None
            conn.execute(
                """
                INSERT INTO exercise
                  (name, description, instructions, tip, externalId, hasWeight,
                   level, category, force, mechanic, equipment,
                   primaryMuscles, secondaryMuscles, counterUnit, defaultValue, isDailyChallenge)
                VALUES (?, '', '', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'reps', 10, 0)
                """,
                (
                    e["name"],
                    e.get("tip", ""),
                    e.get("id"),
                    1 if e.get("hasWeight") else 0,
                    e.get("level"),
                    e.get("category"),
                    e.get("force"),
                    e.get("mechanic"),
                    e.get("equipment"),
                    primary,
                    secondary,
                ),
            )
        conn.commit()
        print(f"\nImported {len(to_import)} exercise(s).")
    except Exception:
        conn.rollback()
        raise


# ── Argument Parsing ──────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="gymtrack",
        description="CLI for GymTrack workout management",
    )
    parser.add_argument("--db", help="Path to SQLite database")
    sub = parser.add_subparsers(dest="command")

    # show
    p_show = sub.add_parser("show", help="List workouts and exercises")
    p_show.add_argument("workout", nargs="?", help="Workout name/substring")
    p_show.add_argument("--all", action="store_true", help="Include inactive exercises")

    # exercises
    p_ex = sub.add_parser("exercises", help="Browse exercise catalog")
    p_ex.add_argument("query", nargs="?", help="Name substring")
    p_ex.add_argument("--muscle", "-m", help="Filter by muscle")
    p_ex.add_argument("--equipment", "-e", help="Filter by equipment")

    # swap
    p_swap = sub.add_parser("swap", help="Replace an exercise in a workout")
    p_swap.add_argument("workout", help="Workout name")
    p_swap.add_argument("old", help="Exercise to replace")
    p_swap.add_argument("new", help="Replacement exercise")
    p_swap.add_argument("--sets", type=int)
    p_swap.add_argument("--reps", type=int)
    p_swap.add_argument("--rest", type=int)
    p_swap.add_argument("--execute", action="store_true", help="Apply changes")

    # add
    p_add = sub.add_parser("add", help="Add an exercise to a workout")
    p_add.add_argument("workout", help="Workout name")
    p_add.add_argument("exercise", help="Exercise name")
    p_add.add_argument("--position", type=int, help="Insert position (default: append)")
    p_add.add_argument("--sets", type=int)
    p_add.add_argument("--reps", type=int)
    p_add.add_argument("--rest", type=int)
    p_add.add_argument("--timed", action="store_true", help="Use timer instead of reps")
    p_add.add_argument("--weight", action="store_true", help="Exercise uses weight")
    p_add.add_argument("--execute", action="store_true", help="Apply changes")

    # remove
    p_rm = sub.add_parser("remove", help="Remove an exercise from a workout")
    p_rm.add_argument("workout", help="Workout name")
    p_rm.add_argument("exercise", help="Exercise name")
    p_rm.add_argument("--execute", action="store_true", help="Apply changes")

    # reorder
    p_ro = sub.add_parser("reorder", help="Move an exercise to a different position")
    p_ro.add_argument("workout", help="Workout name")
    p_ro.add_argument("--move", type=int, required=True, help="Position to move from")
    p_ro.add_argument("--to", type=int, required=True, help="Position to move to")
    p_ro.add_argument("--execute", action="store_true", help="Apply changes")

    # import-exercises
    p_imp = sub.add_parser("import-exercises", help="Import exercises from JSON")
    p_imp.add_argument("file", help="JSON file path")
    p_imp.add_argument("--execute", action="store_true", help="Apply changes")

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    db_path = discover_db(args.db)
    conn = connect(db_path)
    ensure_is_active_column(conn)

    if args.command == "show":
        cmd_show(conn, args)
    elif args.command == "exercises":
        cmd_exercises(conn, args)
    elif args.command == "swap":
        cmd_swap(conn, args, db_path)
    elif args.command == "add":
        cmd_add(conn, args, db_path)
    elif args.command == "remove":
        cmd_remove(conn, args, db_path)
    elif args.command == "reorder":
        cmd_reorder(conn, args, db_path)
    elif args.command == "import-exercises":
        cmd_import_exercises(conn, args, db_path)

    conn.close()


if __name__ == "__main__":
    main()
