#!/usr/bin/env python3
"""Show task details with dependencies and metadata."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / 'db'))

from helpers import (
    get_epic, get_task, get_db, format_datetime,
    print_error
)


def main():
    """Main entry point."""
    if len(sys.argv) < 3:
        print_error("Usage: pm task-show <epic-name> <task-number>")
        print()
        print("Example: pm task-show user-auth-backend 3")
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

    # Get task
    task = get_task(epic_name, task_number)
    if not task:
        print_error(f"Task #{task_number} not found in epic: {epic_name}")
        sys.exit(1)

    task_id = task['id']
    task_name = task['name']
    task_status = task['status']
    task_content = task.get('content') or task.get('description', '')
    estimated_hours = task.get('estimated_hours')
    is_parallel = task.get('parallel', False)
    github_issue = task.get('github_issue_number')
    created_at = task.get('created_at', '')
    updated_at = task.get('updated_at', '')

    # Status icon
    status_icons = {
        'closed': '',
        'in_progress': '',
        'blocked': '',
    }
    icon = status_icons.get(task_status, '')

    # Display task header
    print(f"{icon} Task #{task_number}: {task_name}")
    print("=" * 62)
    print()

    print("Metadata:")
    print(f"  Epic: {epic_name}")
    print(f"  Status: {task_status}")
    if estimated_hours:
        print(f"  Estimated: {estimated_hours}h")
    if is_parallel:
        print("  Parallel: yes (can run with other tasks)")
    if github_issue:
        print(f"  GitHub: #{github_issue}")
    print(f"  Created: {format_datetime(created_at)}")
    print(f"  Updated: {format_datetime(updated_at)}")
    print()

    # Show content if available
    if task_content:
        print("Description:")
        for line in task_content.split('\n'):
            print(f"  {line}")
        print()

    # Get dependencies
    with get_db() as db:
        dependencies = db.query(
            """
            SELECT
                dep.task_number,
                dep.name,
                dep.status
            FROM ccpm.task_dependencies td
            JOIN ccpm.tasks dep ON td.depends_on_task_id = dep.id
            WHERE td.task_id = ?
            ORDER BY dep.task_number
            """,
            (task_id,)
        )

        if dependencies:
            print("Dependencies:")
            unmet_count = sum(1 for d in dependencies if d['status'] != 'closed')

            for dep in dependencies:
                dep_icon = '' if dep['status'] == 'closed' else ''
                status_str = '' if dep['status'] == 'closed' else f" ({dep['status']})"
                print(f"  {dep_icon} #{dep['task_number']} - {dep['name']}{status_str}")

            if unmet_count > 0:
                print()
                print(f"  {unmet_count} unmet dependencies - task is blocked")
            print()

        # Get tasks that depend on this one
        dependents = db.query(
            """
            SELECT
                t.task_number,
                t.name,
                t.status
            FROM ccpm.task_dependencies td
            JOIN ccpm.tasks t ON td.task_id = t.id
            WHERE td.depends_on_task_id = ?
            ORDER BY t.task_number
            """,
            (task_id,)
        )

        if dependents:
            print("Blocks These Tasks:")
            for dep in dependents:
                print(f"  • #{dep['task_number']} - {dep['name']} ({dep['status']})")
            print()

    # Suggested actions
    print("Actions:")
    if task_status == 'open':
        if not dependencies or all(d['status'] == 'closed' for d in dependencies):
            print(f"  • Start this task: pm task-start {epic_name} {task_number}")
        else:
            print("  • Cannot start - has unmet dependencies")
            print("  • View blocked tasks: pm blocked")
    elif task_status == 'in_progress':
        print(f"  • Mark complete: pm task-close {epic_name} {task_number}")
        print("  • View all in-progress: pm in-progress")
    elif task_status == 'closed':
        print("  • Task is complete")
        if dependents:
            print("  • Check unblocked tasks: pm next")

    print(f"  • View epic: pm epic-show {epic_name}")
    if github_issue:
        print(f"  • View on GitHub: gh issue view {github_issue}")


if __name__ == "__main__":
    main()
