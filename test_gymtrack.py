"""Tests for gymtrack.py CLI operations."""

import argparse
import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

import gymtrack


def create_test_db() -> sqlite3.Connection:
    """Create an in-memory DB with the app schema and seed data."""
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")

    conn.executescript("""
        CREATE TABLE exercise (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            instructions TEXT NOT NULL DEFAULT '',
            tip TEXT NOT NULL DEFAULT '',
            externalId TEXT,
            hasWeight BOOLEAN NOT NULL DEFAULT 0,
            counterUnit TEXT NOT NULL DEFAULT 'reps',
            defaultValue INTEGER NOT NULL DEFAULT 10,
            isDailyChallenge BOOLEAN NOT NULL DEFAULT 0,
            level TEXT,
            category TEXT,
            force TEXT,
            mechanic TEXT,
            equipment TEXT,
            primaryMuscles TEXT,
            secondaryMuscles TEXT
        );

        CREATE TABLE workout (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT ''
        );

        CREATE TABLE workoutExercise (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workoutId INTEGER NOT NULL REFERENCES workout(id) ON DELETE CASCADE,
            exerciseId INTEGER NOT NULL REFERENCES exercise(id) ON DELETE CASCADE,
            position INTEGER NOT NULL,
            counterUnit TEXT NOT NULL DEFAULT 'reps',
            counterValue INTEGER,
            counterLabel TEXT,
            restSeconds INTEGER NOT NULL DEFAULT 30,
            sets INTEGER NOT NULL DEFAULT 1,
            isDailyChallenge BOOLEAN NOT NULL DEFAULT 0,
            hasWeight BOOLEAN NOT NULL DEFAULT 0,
            isActive BOOLEAN NOT NULL DEFAULT 1,
            UNIQUE(workoutId, position)
        );

        CREATE TABLE session (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sessionType TEXT NOT NULL,
            date TEXT NOT NULL,
            startedAt TEXT NOT NULL,
            durationSeconds INTEGER NOT NULL,
            isPartial BOOLEAN NOT NULL DEFAULT 0,
            feedback TEXT
        );

        CREATE TABLE exerciseLog (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sessionId INTEGER NOT NULL REFERENCES session(id) ON DELETE CASCADE,
            workoutExerciseId INTEGER NOT NULL REFERENCES workoutExercise(id) ON DELETE CASCADE,
            weight REAL,
            failed INTEGER NOT NULL DEFAULT 0,
            achievedValue INTEGER,
            UNIQUE(sessionId, workoutExerciseId)
        );

        INSERT INTO exercise (id, name, hasWeight, equipment, primaryMuscles)
        VALUES
            (1, 'Bench Press', 1, 'barbell', '["chest"]'),
            (2, 'Squat', 1, 'barbell', '["quadriceps"]'),
            (3, 'Deadlift', 1, 'barbell', '["lower back"]'),
            (4, 'Pull-ups', 0, 'body only', '["lats"]'),
            (5, 'Plank', 0, 'body only', '["abdominals"]'),
            (6, 'Dumbbell Rows', 1, 'dumbbell', '["middle back"]'),
            (7, 'Cable Rows', 1, 'cable', '["middle back"]');

        INSERT INTO workout (id, name) VALUES (1, 'Day A'), (2, 'Day B');

        INSERT INTO workoutExercise
            (workoutId, exerciseId, position, counterValue, sets, hasWeight)
        VALUES
            (1, 1, 1, 10, 3, 1),
            (1, 2, 2, 10, 3, 1),
            (1, 3, 3, 10, 3, 1),
            (1, 4, 4, 10, 3, 0),
            (1, 5, 5, 60, 3, 0),
            (2, 6, 1, 10, 3, 1),
            (2, 5, 2, 60, 3, 0);
    """)
    return conn


def get_active_positions(conn: sqlite3.Connection, workout_id: int) -> list[tuple[int, str]]:
    """Return [(position, exercise_name), ...] for active rows, ordered by position."""
    rows = conn.execute(
        """
        SELECT we.position, e.name
        FROM workoutExercise we
        JOIN exercise e ON e.id = we.exerciseId
        WHERE we.workoutId = ? AND we.isActive = 1
        ORDER BY we.position
        """,
        (workout_id,),
    ).fetchall()
    return [(r["position"], r["name"]) for r in rows]


# ── Resolution Tests ──────────────────────────────────────────────────


class TestResolveExercise(unittest.TestCase):
    def setUp(self):
        self.conn = create_test_db()

    def test_exact_match_case_insensitive(self):
        row = gymtrack.resolve_exercise(self.conn, "bench press")
        self.assertEqual(row["name"], "Bench Press")

    def test_substring_unique(self):
        row = gymtrack.resolve_exercise(self.conn, "pull")
        self.assertEqual(row["name"], "Pull-ups")

    def test_substring_ambiguous_exits(self):
        with self.assertRaises(SystemExit):
            gymtrack.resolve_exercise(self.conn, "rows")

    def test_no_match_exits(self):
        with self.assertRaises(SystemExit):
            gymtrack.resolve_exercise(self.conn, "zzzzz")


class TestResolveWorkout(unittest.TestCase):
    def setUp(self):
        self.conn = create_test_db()

    def test_exact_match(self):
        row = gymtrack.resolve_workout(self.conn, "Day A")
        self.assertEqual(row["name"], "Day A")

    def test_substring_unique(self):
        row = gymtrack.resolve_workout(self.conn, "y A")
        self.assertEqual(row["name"], "Day A")

    def test_substring_ambiguous_exits(self):
        with self.assertRaises(SystemExit):
            gymtrack.resolve_workout(self.conn, "Day")


# ── Swap Tests ────────────────────────────────────────────────────────


class TestSwap(unittest.TestCase):
    def setUp(self):
        self.conn = create_test_db()
        self.db_file = tempfile.NamedTemporaryFile(suffix=".sqlite", delete=False)
        self.db_path = Path(self.db_file.name)
        self.db_file.close()
        # Reset backup state
        gymtrack._backup_done = True  # skip backup for tests

    def test_swap_marks_old_inactive_and_inserts_new(self):
        args = argparse.Namespace(
            workout="Day A", old="Bench Press", new="Cable Rows",
            sets=None, reps=None, rest=None, execute=True,
        )
        gymtrack.cmd_swap(self.conn, args, self.db_path)

        active = get_active_positions(self.conn, 1)
        names = [name for _, name in active]
        self.assertNotIn("Bench Press", names)
        self.assertIn("Cable Rows", names)
        # Position preserved
        self.assertEqual(active[0], (1, "Cable Rows"))

    def test_swap_preserves_old_row(self):
        args = argparse.Namespace(
            workout="Day A", old="Bench Press", new="Cable Rows",
            sets=None, reps=None, rest=None, execute=True,
        )
        gymtrack.cmd_swap(self.conn, args, self.db_path)

        old = self.conn.execute(
            "SELECT * FROM workoutExercise WHERE exerciseId = 1 AND workoutId = 1"
        ).fetchone()
        self.assertEqual(old["isActive"], 0)

    def test_swap_copies_programming(self):
        args = argparse.Namespace(
            workout="Day A", old="Bench Press", new="Cable Rows",
            sets=None, reps=None, rest=None, execute=True,
        )
        gymtrack.cmd_swap(self.conn, args, self.db_path)

        new_we = self.conn.execute(
            "SELECT * FROM workoutExercise WHERE exerciseId = 7 AND workoutId = 1 AND isActive = 1"
        ).fetchone()
        self.assertEqual(new_we["sets"], 3)
        self.assertEqual(new_we["counterValue"], 10)
        self.assertEqual(new_we["restSeconds"], 30)

    def test_swap_with_overrides(self):
        args = argparse.Namespace(
            workout="Day A", old="Bench Press", new="Cable Rows",
            sets=5, reps=12, rest=60, execute=True,
        )
        gymtrack.cmd_swap(self.conn, args, self.db_path)

        new_we = self.conn.execute(
            "SELECT * FROM workoutExercise WHERE exerciseId = 7 AND workoutId = 1 AND isActive = 1"
        ).fetchone()
        self.assertEqual(new_we["sets"], 5)
        self.assertEqual(new_we["counterValue"], 12)
        self.assertEqual(new_we["restSeconds"], 60)

    def test_swap_nonexistent_exercise_exits(self):
        args = argparse.Namespace(
            workout="Day A", old="Cable Rows", new="Bench Press",
            sets=None, reps=None, rest=None, execute=True,
        )
        with self.assertRaises(SystemExit):
            gymtrack.cmd_swap(self.conn, args, self.db_path)


# ── Reorder Tests ─────────────────────────────────────────────────────


class TestReorder(unittest.TestCase):
    def setUp(self):
        self.conn = create_test_db()
        self.db_file = tempfile.NamedTemporaryFile(suffix=".sqlite", delete=False)
        self.db_path = Path(self.db_file.name)
        self.db_file.close()
        gymtrack._backup_done = True

    def _reorder(self, move: int, to: int):
        args = argparse.Namespace(workout="Day A", move=move, to=to, execute=True)
        gymtrack.cmd_reorder(self.conn, args, self.db_path)

    def test_move_last_to_first(self):
        self._reorder(5, 1)
        active = get_active_positions(self.conn, 1)
        self.assertEqual(active[0], (1, "Plank"))
        self.assertEqual(active[1], (2, "Bench Press"))
        self.assertEqual(len(active), 5)

    def test_move_first_to_last(self):
        self._reorder(1, 5)
        active = get_active_positions(self.conn, 1)
        self.assertEqual(active[0], (1, "Squat"))
        self.assertEqual(active[-1], (5, "Bench Press"))

    def test_move_middle_up(self):
        self._reorder(3, 1)
        active = get_active_positions(self.conn, 1)
        self.assertEqual(active[0], (1, "Deadlift"))
        self.assertEqual(active[1], (2, "Bench Press"))
        self.assertEqual(active[2], (3, "Squat"))

    def test_move_middle_down(self):
        self._reorder(2, 4)
        active = get_active_positions(self.conn, 1)
        self.assertEqual(active[0], (1, "Bench Press"))
        self.assertEqual(active[1], (2, "Deadlift"))
        self.assertEqual(active[2], (3, "Pull-ups"))
        self.assertEqual(active[3], (4, "Squat"))

    def test_consecutive_reorders(self):
        """The bug that triggered the fix: two reorders in sequence."""
        self._reorder(1, 5)
        self._reorder(5, 1)
        active = get_active_positions(self.conn, 1)
        # Position 5 after first reorder is Bench Press, moving it back to 1
        self.assertEqual(active[0][0], 1)
        self.assertEqual(len(active), 5)
        # Positions should be contiguous 1-5
        positions = [p for p, _ in active]
        self.assertEqual(positions, [1, 2, 3, 4, 5])

    def test_reorder_same_position_exits(self):
        with self.assertRaises(SystemExit):
            self._reorder(3, 3)

    def test_reorder_invalid_position_exits(self):
        with self.assertRaises(SystemExit):
            self._reorder(99, 1)


# ── Add Tests ─────────────────────────────────────────────────────────


class TestAdd(unittest.TestCase):
    def setUp(self):
        self.conn = create_test_db()
        self.db_file = tempfile.NamedTemporaryFile(suffix=".sqlite", delete=False)
        self.db_path = Path(self.db_file.name)
        self.db_file.close()
        gymtrack._backup_done = True

    def test_add_appends_at_end(self):
        args = argparse.Namespace(
            workout="Day A", exercise="Cable Rows", position=None,
            sets=None, reps=None, rest=None, timed=False, weight=False,
            execute=True,
        )
        gymtrack.cmd_add(self.conn, args, self.db_path)

        active = get_active_positions(self.conn, 1)
        self.assertEqual(len(active), 6)
        self.assertEqual(active[-1], (6, "Cable Rows"))

    def test_add_at_position_shifts_others(self):
        args = argparse.Namespace(
            workout="Day A", exercise="Cable Rows", position=2,
            sets=None, reps=None, rest=None, timed=False, weight=False,
            execute=True,
        )
        gymtrack.cmd_add(self.conn, args, self.db_path)

        active = get_active_positions(self.conn, 1)
        self.assertEqual(len(active), 6)
        self.assertEqual(active[0], (1, "Bench Press"))
        self.assertEqual(active[1], (2, "Cable Rows"))
        self.assertEqual(active[2], (3, "Squat"))

    def test_add_at_position_1(self):
        args = argparse.Namespace(
            workout="Day A", exercise="Cable Rows", position=1,
            sets=None, reps=None, rest=None, timed=False, weight=False,
            execute=True,
        )
        gymtrack.cmd_add(self.conn, args, self.db_path)

        active = get_active_positions(self.conn, 1)
        self.assertEqual(len(active), 6)
        self.assertEqual(active[0], (1, "Cable Rows"))
        self.assertEqual(active[1], (2, "Bench Press"))
        positions = [p for p, _ in active]
        self.assertEqual(positions, [1, 2, 3, 4, 5, 6])


# ── Remove Tests ──────────────────────────────────────────────────────


class TestRemove(unittest.TestCase):
    def setUp(self):
        self.conn = create_test_db()
        self.db_file = tempfile.NamedTemporaryFile(suffix=".sqlite", delete=False)
        self.db_path = Path(self.db_file.name)
        self.db_file.close()
        gymtrack._backup_done = True

    def test_remove_marks_inactive_and_shifts(self):
        args = argparse.Namespace(workout="Day A", exercise="Squat", execute=True)
        gymtrack.cmd_remove(self.conn, args, self.db_path)

        active = get_active_positions(self.conn, 1)
        names = [name for _, name in active]
        self.assertNotIn("Squat", names)
        self.assertEqual(len(active), 4)
        positions = [p for p, _ in active]
        self.assertEqual(positions, [1, 2, 3, 4])

    def test_remove_first(self):
        args = argparse.Namespace(workout="Day A", exercise="Bench Press", execute=True)
        gymtrack.cmd_remove(self.conn, args, self.db_path)

        active = get_active_positions(self.conn, 1)
        self.assertEqual(len(active), 4)
        self.assertEqual(active[0], (1, "Squat"))
        positions = [p for p, _ in active]
        self.assertEqual(positions, [1, 2, 3, 4])

    def test_remove_last(self):
        args = argparse.Namespace(workout="Day A", exercise="Plank", execute=True)
        gymtrack.cmd_remove(self.conn, args, self.db_path)

        active = get_active_positions(self.conn, 1)
        self.assertEqual(len(active), 4)
        positions = [p for p, _ in active]
        self.assertEqual(positions, [1, 2, 3, 4])

    def test_remove_preserves_old_row_for_history(self):
        args = argparse.Namespace(workout="Day A", exercise="Squat", execute=True)
        gymtrack.cmd_remove(self.conn, args, self.db_path)

        old = self.conn.execute(
            "SELECT * FROM workoutExercise WHERE exerciseId = 2 AND workoutId = 1"
        ).fetchone()
        self.assertIsNotNone(old)
        self.assertEqual(old["isActive"], 0)

    def test_remove_nonexistent_exercise_exits(self):
        args = argparse.Namespace(workout="Day A", exercise="Cable Rows", execute=True)
        with self.assertRaises(SystemExit):
            gymtrack.cmd_remove(self.conn, args, self.db_path)


# ── Import Tests ──────────────────────────────────────────────────────


class TestImportExercises(unittest.TestCase):
    def setUp(self):
        self.conn = create_test_db()
        self.db_file = tempfile.NamedTemporaryFile(suffix=".sqlite", delete=False)
        self.db_path = Path(self.db_file.name)
        self.db_file.close()
        gymtrack._backup_done = True

    def test_imports_new_exercises(self):
        data = [
            {"id": "lunges", "name": "Lunges", "tip": "Keep knee over ankle",
             "hasWeight": False, "primaryMuscles": ["quadriceps"]},
        ]
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(data, f)
            f.flush()
            args = argparse.Namespace(file=f.name, execute=True)
            gymtrack.cmd_import_exercises(self.conn, args, self.db_path)

        row = self.conn.execute("SELECT * FROM exercise WHERE name = 'Lunges'").fetchone()
        self.assertIsNotNone(row)
        self.assertEqual(row["tip"], "Keep knee over ankle")

    def test_skips_existing_exercises(self):
        data = [
            {"id": "bench", "name": "Bench Press", "tip": "x", "hasWeight": True},
            {"id": "lunges", "name": "Lunges", "tip": "y", "hasWeight": False},
        ]
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(data, f)
            f.flush()
            args = argparse.Namespace(file=f.name, execute=True)
            gymtrack.cmd_import_exercises(self.conn, args, self.db_path)

        count = self.conn.execute("SELECT COUNT(*) AS c FROM exercise WHERE name = 'Bench Press'").fetchone()["c"]
        self.assertEqual(count, 1)  # not duplicated


# ── Combined Operations ──────────────────────────────────────────────


class TestCombinedOperations(unittest.TestCase):
    """Test sequences of operations that could trigger constraint issues."""

    def setUp(self):
        self.conn = create_test_db()
        self.db_file = tempfile.NamedTemporaryFile(suffix=".sqlite", delete=False)
        self.db_path = Path(self.db_file.name)
        self.db_file.close()
        gymtrack._backup_done = True

    def test_swap_then_reorder(self):
        # Swap creates an inactive row at the same position
        args = argparse.Namespace(
            workout="Day A", old="Bench Press", new="Cable Rows",
            sets=None, reps=None, rest=None, execute=True,
        )
        gymtrack.cmd_swap(self.conn, args, self.db_path)

        # Reorder should still work despite inactive row at position 1
        args = argparse.Namespace(workout="Day A", move=5, to=1, execute=True)
        gymtrack.cmd_reorder(self.conn, args, self.db_path)

        active = get_active_positions(self.conn, 1)
        positions = [p for p, _ in active]
        self.assertEqual(positions, [1, 2, 3, 4, 5])

    def test_remove_then_add_at_same_position(self):
        args = argparse.Namespace(workout="Day A", exercise="Squat", execute=True)
        gymtrack.cmd_remove(self.conn, args, self.db_path)

        args = argparse.Namespace(
            workout="Day A", exercise="Cable Rows", position=2,
            sets=None, reps=None, rest=None, timed=False, weight=False,
            execute=True,
        )
        gymtrack.cmd_add(self.conn, args, self.db_path)

        active = get_active_positions(self.conn, 1)
        self.assertEqual(active[1], (2, "Cable Rows"))
        self.assertEqual(len(active), 5)
        positions = [p for p, _ in active]
        self.assertEqual(positions, [1, 2, 3, 4, 5])

    def test_multiple_reorders(self):
        """Repeated reorders should keep positions contiguous."""
        for move, to in [(5, 1), (3, 5), (2, 4), (4, 1)]:
            args = argparse.Namespace(workout="Day A", move=move, to=to, execute=True)
            gymtrack.cmd_reorder(self.conn, args, self.db_path)

        active = get_active_positions(self.conn, 1)
        positions = [p for p, _ in active]
        self.assertEqual(positions, [1, 2, 3, 4, 5])


if __name__ == "__main__":
    unittest.main()
