#!/usr/bin/env python3
"""Close issue - syncs status to GitHub and updates epic progress."""

import sys
import subprocess
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent.parent / "db"))

from helpers import (
    get_db, update_task, calculate_epic_progress,
    print_error, print_success, print_warning, print_info
)


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print_error("Please provide an issue number")
        print("Usage: ccpm:issue-close <issue-number> [completion-notes]")
        sys.exit(1)

    issue_number = sys.argv[1].lstrip('#')
    completion_notes = sys.argv[2] if len(sys.argv) > 2 else "Task completed"

    # Get task by GitHub issue number
    with get_db() as db:
        tasks = db.query(
            """
            SELECT
                t.id,
                t.name,
                t.task_number,
                t.status,
                e.id as epic_id,
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
            sys.exit(1)

        task = tasks[0]
        task_id = task['id']
        task_name = task['name']
        current_status = task['status']
        epic_id = task['epic_id']
        epic_name = task['epic_name']
        epic_issue = task['epic_issue']

        # Check if already closed
        if current_status == 'closed':
            print_warning(f"Issue #{issue_number} is already closed")
            sys.exit(0)

        # Update task status in database
        update_task(task_id, status='closed')

    print_success(f"Closed task locally: {task_name}")

    # Close on GitHub
    try:
        # Check if issue exists and is open on GitHub
        result = subprocess.run(
            ["gh", "issue", "view", issue_number, "--json", "state", "-q", ".state"],
            capture_output=True,
            text=True,
            check=False
        )

        if result.returncode == 0:
            gh_state = result.stdout.strip()

            if gh_state == "OPEN":
                # Add completion comment
                comment_body = f"Task completed\n\n{completion_notes}\n\n---\nClosed at: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}"
                subprocess.run(
                    ["gh", "issue", "comment", issue_number, "--body", comment_body],
                    capture_output=True,
                    check=False
                )

                # Close the issue
                close_result = subprocess.run(
                    ["gh", "issue", "close", issue_number],
                    capture_output=True,
                    check=False
                )

                if close_result.returncode == 0:
                    print_success(f"Closed GitHub issue #{issue_number}")
                else:
                    print_warning("Failed to close GitHub issue (may need manual intervention)")

                # Update epic task list if epic is synced
                if epic_issue:
                    epic_result = subprocess.run(
                        ["gh", "issue", "view", str(epic_issue), "--json", "body", "-q", ".body"],
                        capture_output=True,
                        text=True,
                        check=False
                    )

                    if epic_result.returncode == 0:
                        epic_body = epic_result.stdout.strip()
                        updated_body = epic_body.replace(
                            f"- [ ] #{issue_number}",
                            f"- [x] #{issue_number}"
                        )

                        if epic_body != updated_body:
                            subprocess.run(
                                ["gh", "issue", "edit", str(epic_issue), "--body", updated_body],
                                capture_output=True,
                                check=False
                            )
                            print_success("Updated epic progress on GitHub")

            elif gh_state == "CLOSED":
                print_info(f"GitHub issue #{issue_number} already closed")
    except FileNotFoundError:
        print_warning("GitHub CLI not available - only updated local database")

    # Calculate epic progress
    total, closed, progress = calculate_epic_progress(epic_id)

    print()
    print(f"Epic Progress: {epic_name}")
    print(f"   Status: {closed}/{total} tasks complete ({progress}%)")
    print()
    print("Next: Run 'ccpm:task-next' to see next priority task")


if __name__ == "__main__":
    main()
