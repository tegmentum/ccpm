#!/usr/bin/env python3
"""Reopen issue - syncs status to GitHub and updates epic progress."""

import sys
import subprocess
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers import (
    get_db, update_task, calculate_epic_progress,
    print_error, print_success, print_warning, print_info
)


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print_error("Please provide an issue number")
        print("Usage: pm issue-reopen <issue-number> [reason]")
        sys.exit(1)

    issue_number = sys.argv[1].lstrip('#')
    reopen_reason = sys.argv[2] if len(sys.argv) > 2 else "Reopening for additional work"

    # Get task by GitHub issue number
    with get_db() as db:
        tasks = db.query(
            """
            SELECT
                t.id,
                t.name,
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

        # Check if already open
        if current_status == 'open':
            print_warning(f"Issue #{issue_number} is already open")
            sys.exit(0)

        # Update task status in database
        update_task(task_id, status='open')

    print_success(f"Reopened task locally: {task_name}")

    # Reopen on GitHub
    try:
        # Check if issue exists and is closed on GitHub
        result = subprocess.run(
            ["gh", "issue", "view", issue_number, "--json", "state", "-q", ".state"],
            capture_output=True,
            text=True,
            check=False
        )

        if result.returncode == 0:
            gh_state = result.stdout.strip()

            if gh_state == "CLOSED":
                # Add reopen comment
                comment_body = f"Reopening issue\n\n{reopen_reason}\n\n---\nReopened at: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}"
                subprocess.run(
                    ["gh", "issue", "comment", issue_number, "--body", comment_body],
                    capture_output=True,
                    check=False
                )

                # Reopen the issue
                reopen_result = subprocess.run(
                    ["gh", "issue", "reopen", issue_number],
                    capture_output=True,
                    check=False
                )

                if reopen_result.returncode == 0:
                    print_success(f"Reopened GitHub issue #{issue_number}")
                else:
                    print_warning("Failed to reopen GitHub issue (may need manual intervention)")

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
                            f"- [x] #{issue_number}",
                            f"- [ ] #{issue_number}"
                        )

                        if epic_body != updated_body:
                            subprocess.run(
                                ["gh", "issue", "edit", str(epic_issue), "--body", updated_body],
                                capture_output=True,
                                check=False
                            )
                            print_success("Updated epic progress on GitHub")

            elif gh_state == "OPEN":
                print_info(f"GitHub issue #{issue_number} already open")
    except FileNotFoundError:
        print_warning("GitHub CLI not available - only updated local database")

    # Recalculate epic progress
    total, closed, progress = calculate_epic_progress(epic_id)

    print()
    print(f"Epic Progress: {epic_name}")
    print(f"   Status: {closed}/{total} tasks complete ({progress}%)")
    print()
    print(f"Next: Run 'pm task-start {epic_name} <task-number>' to resume work")


if __name__ == "__main__":
    main()
