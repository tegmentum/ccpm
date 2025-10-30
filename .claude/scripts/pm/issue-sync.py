#!/usr/bin/env python3
"""Sync single issue bidirectionally with GitHub."""

import sys
import subprocess
import json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / 'db'))

from helpers import get_db, print_error, print_success, print_separator


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: pm issue-sync <issue-number>")
        sys.exit(1)

    issue_number = sys.argv[1].lstrip('#')

    print(f"Syncing Issue #{issue_number}")
    print_separator()
    print()

    # Check gh CLI
    try:
        subprocess.run(["gh", "--version"], capture_output=True, check=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        print_error("GitHub CLI (gh) not found")
        sys.exit(1)

    # Get GitHub data
    print("Fetching from GitHub...")
    try:
        result = subprocess.run(
            ["gh", "issue", "view", issue_number, "--json", "number,title,body,state,updatedAt"],
            capture_output=True,
            text=True,
            check=True
        )
        gh_data = json.loads(result.stdout)
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        print_error(f"Issue #{issue_number} not found on GitHub")
        sys.exit(1)

    gh_title = gh_data.get('title', '')
    gh_state = gh_data.get('state', '').lower()
    print(f"  Title: {gh_title}")
    print(f"  State: {gh_state}")
    print()

    # Check local database
    print("Checking local database...")
    with get_db() as db:
        tasks = db.query(
            """
            SELECT
                t.id,
                t.name,
                t.status,
                e.name as epic_name
            FROM ccpm.tasks t
            JOIN ccpm.epics e ON t.epic_id = e.id
            WHERE t.github_issue_number = ?
                AND t.deleted_at IS NULL
            """,
            (int(issue_number),)
        )

        if not tasks:
            print("  No local task found - import functionality not yet implemented")
            print("  Use 'pm import' to import from GitHub")
            sys.exit(1)

        task = tasks[0]
        print(f"  Local task: {task['epic_name']} - {task['name']}")
        print(f"  Local status: {task['status']}")
        print()

        # Simple sync: update local status to match GitHub
        local_status = 'closed' if gh_state == 'closed' else 'open'
        if task['status'] != local_status:
            from datetime import datetime
            now = datetime.utcnow().isoformat() + "Z"
            db.execute(
                "UPDATE ccpm.tasks SET status = ?, updated_at = ? WHERE id = ?",
                (local_status, now, task['id'])
            )
            print_success(f"Updated local status to '{local_status}'")
        else:
            print("  Status already in sync")

    print()
    print_separator()
    print_success(f"Issue #{issue_number} synced")


if __name__ == "__main__":
    main()
