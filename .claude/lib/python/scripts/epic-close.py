#!/usr/bin/env python3
"""Close an epic."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers import (
    get_epic, get_db, update_epic,
    print_error, print_success, print_info
)


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print_error("Usage: ccpm:epic-close <epic-name>")
        print()
        print("Example: ccpm:epic-close user-auth-backend")
        sys.exit(1)

    epic_name = sys.argv[1]

    # Get epic details
    epic = get_epic(epic_name)
    if not epic:
        print_error(f"Epic not found: {epic_name}")
        sys.exit(1)

    epic_id = epic['id']
    current_status = epic['status']

    # Check if already closed
    if current_status == 'closed':
        print_info(f"Epic is already closed: {epic_name}")
        sys.exit(0)

    # Get task statistics
    with get_db() as db:
        task_stats = db.query(
            """
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN status = 'closed' THEN 1 ELSE 0 END) as closed,
                SUM(CASE WHEN status != 'closed' THEN 1 ELSE 0 END) as open
            FROM ccpm.tasks
            WHERE epic_id = ?
              AND deleted_at IS NULL
            """,
            (epic_id,)
        )

        stats = task_stats[0] if task_stats else {'total': 0, 'closed': 0, 'open': 0}
        total_tasks = stats['total'] or 0
        closed_tasks = stats['closed'] or 0
        open_tasks = stats['open'] or 0

        # Warn if not all tasks are closed
        if open_tasks > 0:
            print(f"Warning: Epic has {open_tasks} open task(s)")
            print()

            # Show open tasks
            open_task_list = db.query(
                """
                SELECT task_number, name, status
                FROM ccpm.tasks
                WHERE epic_id = ?
                  AND status != 'closed'
                  AND deleted_at IS NULL
                ORDER BY task_number
                """,
                (epic_id,)
            )

            for task in open_task_list:
                print(f"  • #{task['task_number']} - {task['name']} ({task['status']})")

            print()
            try:
                response = input("Close epic anyway? (y/N) ")
                if response.lower() != 'y':
                    print("Cancelled")
                    sys.exit(0)
            except (EOFError, KeyboardInterrupt):
                print("\nCancelled")
                sys.exit(0)

    # Update epic status
    update_epic(epic_id, status='closed')

    print_success(f"Closed epic: {epic_name}")
    print(f"   Tasks: {closed_tasks}/{total_tasks} completed")
    print()
    print("Next steps:")
    print("  • View PRD status: ccpm:prd-status")
    print("  • View standup: ccpm:standup")


if __name__ == "__main__":
    main()
