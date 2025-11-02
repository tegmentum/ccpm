#!/usr/bin/env python3
"""
Start a task - updates task status from 'open' to 'in_progress'.

Checks for unmet dependencies and warns if task is blocked.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "db"))

from helpers import (
    get_epic, get_task, get_db, update_task,
    print_error, print_success, print_warning, print_info
)


def main():
    """Main entry point."""
    if len(sys.argv) < 3:
        print_error("Usage: ccpm:task-start <epic-name> <task-number>")
        print()
        print("Example: ccpm:task-start user-auth-backend 3")
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

    # Get task
    task = get_task(epic_name, task_number)
    if not task:
        print_error(f"Task #{task_number} not found in epic: {epic_name}")
        sys.exit(1)

    task_id = task['id']
    task_name = task['name']
    current_status = task['status']

    # Check current status
    if current_status == 'in_progress':
        print_info(f"Task #{task_number} is already in progress")
        print(f"   {task_name}")
        sys.exit(0)

    if current_status == 'closed':
        print_error(f"Task #{task_number} is already closed")
        print(f"   {task_name}")
        print()
        print("To reopen, update status manually with: ccpm:task-update")
        sys.exit(1)

    # Check if task is blocked (has unmet dependencies)
    with get_db() as db:
        blocked_check = db.query(
            """
            SELECT COUNT(*) > 0 as blocked
            FROM ccpm.tasks t
            WHERE t.id = ?
              AND EXISTS (
                SELECT 1 FROM ccpm.task_dependencies td
                JOIN ccpm.tasks dep ON td.depends_on_task_id = dep.id
                WHERE td.task_id = t.id
                  AND dep.status != 'closed'
              )
            """,
            (task_id,)
        )

        is_blocked = blocked_check[0]['blocked'] if blocked_check else False

        if is_blocked:
            print_warning(f"Warning: Task #{task_number} has unmet dependencies")
            print(f"   {task_name}")
            print()
            print("Blocking tasks:")

            blocking_tasks = db.query(
                """
                SELECT dep.task_number, dep.name, dep.status
                FROM ccpm.task_dependencies td
                JOIN ccpm.tasks dep ON td.depends_on_task_id = dep.id
                WHERE td.task_id = ?
                  AND dep.status != 'closed'
                """,
                (task_id,)
            )

            for dep in blocking_tasks:
                print(f"   • #{dep['task_number']} - {dep['name']} ({dep['status']})")

            print()
            try:
                response = input("Start anyway? (y/N) ")
                if response.lower() != 'y':
                    print("Cancelled")
                    sys.exit(0)
            except (EOFError, KeyboardInterrupt):
                print("\nCancelled")
                sys.exit(0)

    # Update status to in_progress
    update_task(task_id, status='in_progress')

    print_success(f"Started task #{task_number}")
    print(f"   Epic: {epic_name}")
    print(f"   Task: {task_name}")
    print()
    print("Next steps:")
    print(f"   • View task details: ccpm:task-show {epic_name} {task_number}")
    print(f"   • Mark complete: ccpm:task-close {epic_name} {task_number}")
    print("   • View all in-progress: ccpm:in-progress")


if __name__ == "__main__":
    main()
