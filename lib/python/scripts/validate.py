#!/usr/bin/env python3
"""Validate database integrity."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers import get_db, print_separator


def main():
    """Main entry point."""
    print("Validating Database Integrity")
    print_separator()
    print()

    errors = 0
    warnings = 0

    with get_db() as db:
        # 1. Check for orphaned tasks (epic deleted but tasks remain)
        print("1. Checking for orphaned tasks...")
        orphaned = db.query(
            """
            SELECT COUNT(*) as count
            FROM ccpm.tasks t
            LEFT JOIN ccpm.epics e ON t.epic_id = e.id
            WHERE t.deleted_at IS NULL
                AND (e.id IS NULL OR e.deleted_at IS NOT NULL)
            """
        )
        orphaned_count = orphaned[0]['count'] if orphaned else 0

        if orphaned_count > 0:
            print(f"   Found {orphaned_count} orphaned tasks (epic deleted but tasks remain)")
            errors += 1
        else:
            print("   No orphaned tasks")

        # 2. Check for orphaned epics (PRD deleted but epic remains)
        print("2. Checking for orphaned epics...")
        orphaned_epics = db.query(
            """
            SELECT COUNT(*) as count
            FROM ccpm.epics e
            LEFT JOIN ccpm.prds p ON e.prd_id = p.id
            WHERE e.deleted_at IS NULL
                AND e.prd_id IS NOT NULL
                AND (p.id IS NULL OR p.deleted_at IS NOT NULL)
            """
        )
        orphaned_epics_count = orphaned_epics[0]['count'] if orphaned_epics else 0

        if orphaned_epics_count > 0:
            print(f"   Found {orphaned_epics_count} epics with deleted PRDs")
            warnings += 1
        else:
            print("   No orphaned epics")

        # 3. Check for broken task dependencies
        print("3. Checking for broken task dependencies...")
        broken_deps = db.query(
            """
            SELECT COUNT(*) as count
            FROM ccpm.task_dependencies td
            LEFT JOIN ccpm.tasks t1 ON td.task_id = t1.id
            LEFT JOIN ccpm.tasks t2 ON td.depends_on_task_id = t2.id
            WHERE t1.id IS NULL OR t2.id IS NULL
                OR t1.deleted_at IS NOT NULL OR t2.deleted_at IS NOT NULL
            """
        )
        broken_count = broken_deps[0]['count'] if broken_deps else 0

        if broken_count > 0:
            print(f"   Found {broken_count} broken dependencies")
            errors += 1
        else:
            print("   No broken dependencies")

        # 4. Check for duplicate GitHub issue numbers
        print("4. Checking for duplicate GitHub issue numbers...")
        duplicates = db.query(
            """
            SELECT github_issue_number, COUNT(*) as count
            FROM ccpm.tasks
            WHERE github_issue_number IS NOT NULL
                AND deleted_at IS NULL
            GROUP BY github_issue_number
            HAVING COUNT(*) > 1
            """
        )

        if duplicates:
            print(f"   Found {len(duplicates)} duplicate GitHub issue numbers")
            for dup in duplicates:
                print(f"     • Issue #{dup['github_issue_number']}: {dup['count']} tasks")
            errors += 1
        else:
            print("   No duplicate GitHub issues")

        # 5. Check epic progress consistency
        print("5. Checking epic progress consistency...")
        inconsistent = db.query(
            """
            SELECT
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
                print(f"     • {epic['name']}: stored {epic['stored_progress']}%, calculated {epic['calculated_progress']}%")
            warnings += 1
        else:
            print("   All epic progress values consistent")

    # Summary
    print()
    print_separator()
    if errors == 0 and warnings == 0:
        print("Database validation passed!")
        print()
    else:
        if errors > 0:
            print(f" {errors} error(s) found")
        if warnings > 0:
            print(f" {warnings} warning(s) found")
        print()
        print("Run 'pm clean' to fix issues")


if __name__ == "__main__":
    main()
