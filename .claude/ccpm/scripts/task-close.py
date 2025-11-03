#!/usr/bin/env python3
"""
Close a task - updates task status to 'closed'.

Automatically calculates epic progress and checks for newly unblocked tasks.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "db"))

from helpers import (
    get_epic, get_task, get_db, update_task, calculate_epic_progress,
    print_error, print_success, print_info, print_separator
)


def main():
    """Main entry point."""
    if len(sys.argv) < 3:
        print_error("Usage: ccpm:task-close <epic-name> <task-number>")
        print()
        print("Example: ccpm:task-close user-auth-backend 2")
        sys.exit(1)

    epic_name = sys.argv[1]
    try:
        task_number = int(sys.argv[2])
    except ValueError:
        print_error(f"Invalid task number: {sys.argv[2]}")
        sys.exit(1)

    # Get epic
    epic = get_epic(epic_name)
    if not epic:
        print_error(f"Epic not found: {epic_name}")
        sys.exit(1)

    epic_id = epic['id']
    epic_status = epic['status']

    # Get task
    task = get_task(epic_name, task_number)
    if not task:
        print_error(f"Task #{task_number} not found in epic: {epic_name}")
        sys.exit(1)

    task_id = task['id']
    task_name = task['name']
    current_status = task['status']

    # Check if already closed
    if current_status == 'closed':
        print_info(f"Task #{task_number} is already closed")
        print(f"   {task_name}")
        sys.exit(0)

    # Update status to closed
    update_task(task_id, status='closed')

    # Calculate epic progress
    total, closed, progress = calculate_epic_progress(epic_id)

    print_success(f"Closed task #{task_number}")
    print(f"   Epic: {epic_name}")
    print(f"   Task: {task_name}")
    print()
    print(f"Epic progress: {progress}%")

    # Check if this unblocked any tasks
    with get_db() as db:
        newly_ready = db.query(
            """
            SELECT
                t.task_number,
                t.name
            FROM ccpm.tasks t
            WHERE t.epic_id = ?
              AND t.status = 'open'
              AND t.deleted_at IS NULL
              AND t.id IN (
                SELECT td.task_id
                FROM ccpm.task_dependencies td
                WHERE td.depends_on_task_id = ?
              )
              AND NOT EXISTS (
                SELECT 1
                FROM ccpm.task_dependencies td2
                JOIN ccpm.tasks dep ON td2.depends_on_task_id = dep.id
                WHERE td2.task_id = t.id
                  AND dep.status != 'closed'
                  AND dep.id != ?
              )
            """,
            (epic_id, task_id, task_id)
        )

        if newly_ready:
            print()
            print(f"Unblocked {len(newly_ready)} task(s):")
            for t in newly_ready:
                print(f"   • #{t['task_number']} - {t['name']}")

        # Check if epic is now complete
        all_closed_check = db.query(
            """
            SELECT COUNT(*) = 0 as all_done
            FROM ccpm.tasks
            WHERE epic_id = ?
              AND status != 'closed'
              AND deleted_at IS NULL
            """,
            (epic_id,)
        )

        all_closed = all_closed_check[0]['all_done'] if all_closed_check else False

        if all_closed:
            print()
            print("All tasks complete!")
            if epic_status != 'closed':
                print(f"   Consider closing the epic: ccpm:epic-close {epic_name}")

    print()
    print("Next steps:")
    print("   • View ready tasks: ccpm:task-next")
    print(f"   • View epic status: ccpm:epic-show {epic_name}")
    print("   • Daily standup: ccpm:standup")


if __name__ == "__main__":
    main()
