#!/usr/bin/env python3
"""Display issue details with GitHub sync information."""

import sys
import subprocess
import json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / 'db'))

from helpers import (
    get_db, format_datetime,
    print_error, print_separator
)


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print_error("Please provide an issue number")
        print("Usage: pm issue-show <issue-number>")
        sys.exit(1)

    issue_number = sys.argv[1].lstrip('#')

    # Get task by GitHub issue number
    with get_db() as db:
        tasks = db.query(
            """
            SELECT
                t.id,
                t.name,
                t.description,
                t.status,
                t.estimated_hours,
                t.actual_hours,
                t.parallel,
                t.created_at,
                t.updated_at,
                t.github_issue_number,
                t.github_synced_at,
                e.name as epic_name,
                e.github_issue_number as epic_issue
            FROM ccpm.tasks t
            JOIN ccpm.epics e ON t.epic_id = e.id
            WHERE t.github_issue_number = ?
                AND t.deleted_at IS NULL
            """,
            (int(issue_number),)
        )

        if not tasks:
            print_error(f"No task found for issue #{issue_number}")
            print()
            print("This issue may not be synced to the database yet.")
            print("Try: pm import  or  pm issue-sync")
            sys.exit(1)

        task = tasks[0]
        task_id = task['id']

    # Display header
    print(f"Issue #{issue_number}: {task['name']}")
    print_separator()
    print()

    # Fetch live GitHub data
    try:
        result = subprocess.run(
            ["gh", "issue", "view", issue_number, "--json", "state,labels,assignees"],
            capture_output=True,
            text=True,
            check=False
        )

        if result.returncode == 0:
            gh_data = json.loads(result.stdout)
            print("GitHub Status:")
            print(f"   State: {gh_data.get('state', 'unknown')}")

            labels = gh_data.get('labels', [])
            if labels:
                label_names = ', '.join(l.get('name', '') for l in labels)
                print(f"   Labels: {label_names}")

            assignees = gh_data.get('assignees', [])
            if assignees:
                assignee_name = assignees[0].get('login', '')
                if assignee_name:
                    print(f"   Assignee: @{assignee_name}")
            print()
    except (FileNotFoundError, json.JSONDecodeError):
        pass

    # Local status
    print("Local Status:")
    print(f"   Status: {task['status']}")
    print(f"   Epic: {task['epic_name']}")
    if task['epic_issue']:
        print(f"   Epic Issue: #{task['epic_issue']}")
    if task['parallel']:
        print("   Parallel: Yes (can run in parallel)")
    print()

    # Time tracking
    if task['estimated_hours'] or task['actual_hours']:
        print("Time Tracking:")
        if task['estimated_hours']:
            print(f"   Estimated: {task['estimated_hours']}h")
        if task['actual_hours']:
            print(f"   Actual: {task['actual_hours']}h")

            if task['estimated_hours'] and task['actual_hours']:
                variance = task['actual_hours'] - task['estimated_hours']
                if variance > 0:
                    print(f"   Variance: +{variance}h over estimate")
                elif variance < 0:
                    print(f"   Variance: {variance}h under estimate")
                else:
                    print("   Variance: On estimate")
        print()

    # Description
    if task['description']:
        print("Description:")
        for line in task['description'].split('\n'):
            print(f"   {line}")
        print()

    # Dependencies
    with get_db() as db:
        deps = db.query(
            """
            SELECT
                t.name,
                t.status,
                t.github_issue_number
            FROM ccpm.task_dependencies td
            JOIN ccpm.tasks t ON td.depends_on_task_id = t.id
            WHERE td.task_id = ?
                AND t.deleted_at IS NULL
            """,
            (task_id,)
        )

        if deps:
            print("Dependencies (must complete first):")
            for dep in deps:
                gh_str = f" #{dep['github_issue_number']}" if dep['github_issue_number'] else ""
                print(f"   • {dep['name']} [{dep['status']}]{gh_str}")
            print()

        # Blocked tasks
        blockers = db.query(
            """
            SELECT
                t.name,
                t.status,
                t.github_issue_number
            FROM ccpm.task_dependencies td
            JOIN ccpm.tasks t ON td.task_id = t.id
            WHERE td.depends_on_task_id = ?
                AND t.deleted_at IS NULL
            """,
            (task_id,)
        )

        if blockers:
            print("Blocking (waiting on this task):")
            for blocker in blockers:
                gh_str = f" #{blocker['github_issue_number']}" if blocker['github_issue_number'] else ""
                print(f"   • {blocker['name']} [{blocker['status']}]{gh_str}")
            print()

    # Timestamps
    print("Timeline:")
    print(f"   Created: {format_datetime(task['created_at'])}")
    if task['updated_at']:
        print(f"   Updated: {format_datetime(task['updated_at'])}")
    if task['github_synced_at']:
        print(f"   Last Synced: {format_datetime(task['github_synced_at'])}")
    print()

    # Quick actions
    print("Quick Actions:")
    if task['status'] == 'open':
        print(f"   Start work: pm task-start {task['epic_name']} <task-number>")
    elif task['status'] == 'in_progress':
        print(f"   Complete: pm task-close {task['epic_name']} <task-number>")
    print(f"   Sync to GitHub: pm issue-sync {issue_number}")
    print(f"   View in browser: gh issue view {issue_number} --web")
    print(f"   Add comment: gh issue comment {issue_number} --body 'your comment'")
    print()


if __name__ == "__main__":
    main()
