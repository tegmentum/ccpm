#!/usr/bin/env python3
"""Daily standup report showing in-progress, blocked, and ready tasks."""

import sys
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / 'db'))

from helpers import get_db, print_separator


def main():
    """Main entry point."""
    print(f"Daily Standup - {datetime.now().strftime('%Y-%m-%d')}")
    print("=" * 62)
    print()

    with get_db() as db:
        # Get all in-progress tasks
        in_progress_data = db.query(
            """
            SELECT
                e.name as epic,
                t.task_number,
                t.name,
                t.estimated_hours
            FROM ccpm.tasks t
            JOIN ccpm.epics e ON t.epic_id = e.id
            WHERE t.status = 'in_progress'
              AND t.deleted_at IS NULL
            ORDER BY e.name, t.task_number
            """
        )

        # Get blocked tasks count
        blocked_count_result = db.query(
            "SELECT COUNT(*) as count FROM ccpm.blocked_tasks"
        )
        blocked_count = blocked_count_result[0]['count'] if blocked_count_result else 0

        # Get ready tasks (limit to 5)
        ready_data = db.query(
            """
            SELECT
                e.name as epic,
                rt.task_number,
                rt.name,
                t.estimated_hours
            FROM ccpm.ready_tasks rt
            JOIN ccpm.epics e ON rt.epic_id = e.id
            JOIN ccpm.tasks t ON rt.id = t.id
            ORDER BY e.name, rt.task_number
            LIMIT 5
            """
        )

        # Get overall statistics
        stats = db.query(
            """
            SELECT
                SUM(CASE WHEN status = 'open' THEN 1 ELSE 0 END) as open_count,
                SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress_count,
                SUM(CASE WHEN status = 'closed' THEN 1 ELSE 0 END) as closed_count,
                COUNT(*) as total_count
            FROM ccpm.tasks
            WHERE deleted_at IS NULL
            """
        )

        stat = stats[0] if stats else {}
        open_count = stat.get('open_count', 0) or 0
        in_progress_count = stat.get('in_progress_count', 0) or 0
        closed_count = stat.get('closed_count', 0) or 0
        total_count = stat.get('total_count', 0) or 0

    # Display in-progress tasks
    print("Currently In Progress:")
    print("=" * 62)
    if not in_progress_data:
        print("  No tasks in progress")
    else:
        current_epic = ""
        for task in in_progress_data:
            epic_name = task['epic']
            task_number = task['task_number']
            task_name = task['name']
            estimated_hours = task['estimated_hours'] or '?'

            if epic_name != current_epic:
                if current_epic:
                    print()
                print(f"  Epic: {epic_name}")
                current_epic = epic_name

            print(f"    • #{task_number} - {task_name} ({estimated_hours}h est.)")

    print()
    print("Blocked Tasks:")
    print("=" * 62)
    if blocked_count == 0:
        print("  None - great!")
    else:
        print(f"  {blocked_count} task(s) blocked")
        print("  Run 'pm blocked' for details")

    print()
    print("Next Up (Ready to Start):")
    print("=" * 62)
    if not ready_data:
        print("  No tasks ready")
    else:
        current_epic = ""
        for task in ready_data:
            epic_name = task['epic']
            task_number = task['task_number']
            task_name = task['name']
            estimated_hours = task['estimated_hours'] or '?'

            if epic_name != current_epic:
                if current_epic:
                    print()
                print(f"  Epic: {epic_name}")
                current_epic = epic_name

            print(f"    • #{task_number} - {task_name} ({estimated_hours}h est.)")

    # Overall statistics
    print()
    print("Overall Progress:")
    print("=" * 62)
    if total_count > 0:
        progress_pct = int((closed_count / total_count) * 100)
        print(f"  Open: {open_count}")
        print(f"  In Progress: {in_progress_count}")
        print(f"  Closed: {closed_count}")
        print(f"  Total: {total_count}")
        print(f"  Progress: {progress_pct}%")
    else:
        print("  No tasks tracked yet")

    print()
    print("Quick Actions:")
    print("  • View ready tasks: pm next")
    print("  • View blocked tasks: pm blocked")
    print("  • View in-progress: pm in-progress")
    print()


if __name__ == "__main__":
    main()
