#!/usr/bin/env python3
"""Clean up database by removing orphaned records."""

import sys
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers import get_db, print_separator, print_success, print_info


def main():
    """Main entry point."""
    # Parse options
    dry_run = '--dry-run' in sys.argv
    force = '--force' in sys.argv

    print("Database Cleanup")
    print_separator()
    print()

    if dry_run:
        print("DRY RUN MODE - No changes will be made")
        print()

    with get_db() as db:
        # 1. Find orphaned tasks
        print("1. Checking for orphaned tasks...")
        orphaned = db.query(
            """
            SELECT
                t.id,
                t.name,
                t.epic_id
            FROM ccpm.tasks t
            LEFT JOIN ccpm.epics e ON t.epic_id = e.id
            WHERE t.deleted_at IS NULL
                AND (e.id IS NULL OR e.deleted_at IS NOT NULL)
            """
        )

        if orphaned:
            print(f"   Found {len(orphaned)} orphaned tasks")
            for task in orphaned:
                print(f"   • {task['name']} (epic_id: {task['epic_id']})")

            if not dry_run:
                if force:
                    confirm = 'yes'
                else:
                    try:
                        confirm = input("   Delete these tasks? (yes/no): ")
                    except (EOFError, KeyboardInterrupt):
                        confirm = 'no'
                        print()

                if confirm == 'yes':
                    task_ids = [str(t['id']) for t in orphaned]
                    now = datetime.utcnow().isoformat() + "Z"
                    for task_id in task_ids:
                        db.execute(
                            "UPDATE ccpm.tasks SET deleted_at = ? WHERE id = ?",
                            (now, int(task_id))
                        )
                    print_success(f"Deleted {len(orphaned)} orphaned tasks")
                else:
                    print("   Skipped")
        else:
            print("   No orphaned tasks")

        # 2. Find orphaned task dependencies
        print("2. Checking for broken task dependencies...")
        broken_deps = db.query(
            """
            SELECT
                td.task_id,
                td.depends_on_task_id
            FROM ccpm.task_dependencies td
            LEFT JOIN ccpm.tasks t1 ON td.task_id = t1.id
            LEFT JOIN ccpm.tasks t2 ON td.depends_on_task_id = t2.id
            WHERE t1.id IS NULL OR t2.id IS NULL
                OR t1.deleted_at IS NOT NULL OR t2.deleted_at IS NOT NULL
            """
        )

        if broken_deps:
            print(f"   Found {len(broken_deps)} broken dependencies")
            for dep in broken_deps:
                print(f"   • Task {dep['task_id']} depends on {dep['depends_on_task_id']}")

            if not dry_run:
                if force:
                    confirm = 'yes'
                else:
                    try:
                        confirm = input("   Delete these dependencies? (yes/no): ")
                    except (EOFError, KeyboardInterrupt):
                        confirm = 'no'
                        print()

                if confirm == 'yes':
                    for dep in broken_deps:
                        db.execute(
                            """
                            DELETE FROM ccpm.task_dependencies
                            WHERE task_id = ? AND depends_on_task_id = ?
                            """,
                            (dep['task_id'], dep['depends_on_task_id'])
                        )
                    print_success(f"Deleted {len(broken_deps)} broken dependencies")
                else:
                    print("   Skipped")
        else:
            print("   No broken dependencies")

        # 3. Update epic progress if inconsistent
        print("3. Checking epic progress...")
        inconsistent = db.query(
            """
            SELECT
                e.id,
                e.name,
                e.progress as stored_progress,
                CASE
                    WHEN COUNT(t.id) = 0 THEN 0
                    ELSE CAST(SUM(CASE WHEN t.status = 'closed' THEN 1 ELSE 0 END) * 100 / COUNT(t.id) AS INTEGER)
                END as calculated_progress
            FROM ccpm.epics e
            LEFT JOIN ccpm.tasks t ON e.id = t.epic_id AND t.deleted_at IS NULL
            WHERE e.deleted_at IS NULL
            GROUP BY e.id, e.name, e.progress
            HAVING stored_progress != calculated_progress
            """
        )

        if inconsistent:
            print(f"   Found {len(inconsistent)} epics with inconsistent progress")
            for epic in inconsistent:
                print(f"   • {epic['name']}: {epic['stored_progress']}% -> {epic['calculated_progress']}%")

            if not dry_run:
                now = datetime.utcnow().isoformat() + "Z"
                for epic in inconsistent:
                    db.execute(
                        "UPDATE ccpm.epics SET progress = ?, updated_at = ? WHERE id = ?",
                        (epic['calculated_progress'], now, epic['id'])
                    )
                print_success(f"Updated {len(inconsistent)} epic progress values")
        else:
            print("   All epic progress values are consistent")

    print()
    print_separator()
    print_success("Cleanup complete")


if __name__ == "__main__":
    main()
