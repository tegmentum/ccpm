#!/usr/bin/env python3
"""
Refresh epic progress from task status.

Updates epic progress percentage and status based on completed tasks.
Syncs GitHub issue checklist if epic has a GitHub issue.
"""

import sys
import os
import logging
import tempfile
import subprocess
from pathlib import Path

# Add db directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / 'db'))

from helpers import (
    get_epic, get_db, update_epic, calculate_epic_progress,
    print_header, print_success, print_error, print_separator,
    get_github_client, GITHUB_AVAILABLE
)

logger = logging.getLogger(__name__)


def update_github_checklist(epic_gh_issue: int, epic_id: int) -> bool:
    """Update GitHub issue checklist based on task status."""
    try:
        # Try using gh CLI for simplicity
        result = subprocess.run(
            ["gh", "issue", "view", str(epic_gh_issue), "--json", "body", "-q", ".body"],
            capture_output=True,
            text=True,
            check=True
        )
        epic_body = result.stdout.strip()

        if not epic_body:
            logger.warning("Could not fetch GitHub issue body")
            return False

        # Get tasks with GitHub issues
        with get_db() as db:
            tasks = db.query(
                """
                SELECT
                    task_number,
                    name,
                    status,
                    github_issue_number
                FROM ccpm.tasks
                WHERE epic_id = ?
                    AND github_issue_number IS NOT NULL
                    AND deleted_at IS NULL
                ORDER BY task_number
                """,
                (epic_id,)
            )

        if not tasks:
            return True

        # Update checkboxes in body
        updated_body = epic_body
        for task in tasks:
            task_gh = task['github_issue_number']
            task_status = task['status']

            if task_status == 'closed':
                # Mark as checked
                updated_body = updated_body.replace(
                    f"- [ ] #{task_gh}",
                    f"- [x] #{task_gh}"
                )
            else:
                # Ensure unchecked
                updated_body = updated_body.replace(
                    f"- [x] #{task_gh}",
                    f"- [ ] #{task_gh}"
                )

        # Write to temp file and update
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write(updated_body)
            temp_file = f.name

        try:
            subprocess.run(
                ["gh", "issue", "edit", str(epic_gh_issue), "--body-file", temp_file],
                check=True,
                capture_output=True
            )
            print_success("GitHub task list updated")
            return True
        finally:
            os.unlink(temp_file)

    except subprocess.CalledProcessError:
        logger.warning("Could not update GitHub issue (may not exist or no permissions)")
        return False
    except Exception as e:
        logger.warning(f"Error updating GitHub checklist: {e}")
        return False


def main():
    """Main entry point."""
    # Get epic name from arguments
    if len(sys.argv) < 2:
        print_error("Usage: pm epic-refresh <epic-name>")
        sys.exit(1)

    epic_name = sys.argv[1]

    print_header(f"= Refreshing Epic: {epic_name}")

    # Get epic data
    epic = get_epic(epic_name)
    if not epic:
        print_error(f"Epic not found: {epic_name}")
        sys.exit(1)

    epic_id = epic['id']
    old_status = epic['status']
    old_progress = epic.get('progress', 0)
    epic_gh_issue = epic.get('github_issue_number')

    # Count task statuses
    with get_db() as db:
        task_counts = db.query(
            """
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN status = 'closed' THEN 1 ELSE 0 END) as closed,
                SUM(CASE WHEN status = 'open' THEN 1 ELSE 0 END) as open,
                SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress
            FROM ccpm.tasks
            WHERE epic_id = ?
                AND deleted_at IS NULL
            """,
            (epic_id,)
        )

    counts = task_counts[0]
    total_tasks = counts['total'] or 0
    closed_tasks = counts['closed'] or 0
    open_tasks = counts['open'] or 0
    in_progress_tasks = counts['in_progress'] or 0

    print("Task Status:")
    print(f"  Closed: {closed_tasks}")
    print(f"  In Progress: {in_progress_tasks}")
    print(f"  Open: {open_tasks}")
    print(f"  Total: {total_tasks}")
    print()

    # Calculate progress
    if total_tasks == 0:
        new_progress = 0
    else:
        new_progress = int((closed_tasks / total_tasks) * 100)

    # Determine new status
    if new_progress == 100:
        new_status = "closed"
    elif new_progress > 0:
        new_status = "active"
    else:
        new_status = "backlog"

    # Update epic in database
    update_epic(
        epic_id,
        status=new_status,
        progress=new_progress
    )

    print(f"Progress: {old_progress}% ’ {new_progress}%")
    print(f"Status: {old_status} ’ {new_status}")
    print()

    # Update GitHub issue if it exists
    if epic_gh_issue:
        print(f"Updating GitHub issue #{epic_gh_issue}...")
        update_github_checklist(epic_gh_issue, epic_id)
        print()

    # Summary
    print_separator()
    print_success(f"Epic Refreshed: {epic_name}")
    print()

    if new_status == "closed":
        print("<‰ Epic complete! All tasks done.")
        print()
        print("Next steps:")
        print(f"   Close epic: pm epic-close {epic_name}")
    elif in_progress_tasks > 0:
        print(f"= Work in progress ({in_progress_tasks} task(s))")
        print()
        print("Next steps:")
        print(f"   View progress: pm epic-show {epic_name}")
        print("   See next tasks: pm next")
    else:
        print("=Ë Ready to start work")
        print()
        print("Next steps:")
        print("   See next tasks: pm next")
        print(f"   Start task: pm task-start {epic_name} <num>")
    print()


if __name__ == "__main__":
    main()
