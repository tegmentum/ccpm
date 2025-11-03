#!/usr/bin/env python3
"""
Start epic work.

Note: Full worktree implementation requires git operations.
This is a simplified version that updates epic status.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers import get_epic, update_epic, print_error, print_success, print_separator


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: ccpm:epic-start <epic-name>")
        sys.exit(1)

    epic_name = sys.argv[1]

    print(f"Starting Epic: {epic_name}")
    print_separator()
    print()

    # Validate epic exists
    epic = get_epic(epic_name)
    if not epic:
        print_error(f"Epic not found: {epic_name}")
        sys.exit(1)

    epic_id = epic['id']
    epic_status = epic['status']
    epic_gh_issue = epic.get('github_issue_number')

    print(f"Epic Status: {epic_status}")
    if epic_gh_issue:
        print(f"GitHub Issue: #{epic_gh_issue}")
    print()

    # Update status to active if not already
    if epic_status not in ['active', 'in_progress']:
        update_epic(epic_id, status='active')
        print_success("Updated epic status to 'active'")
    else:
        print("Epic is already active")

    print()
    print("Next steps:")
    print(f"   View tasks: ccpm:epic-show {epic_name}")
    print("   View ready tasks: ccpm:task-next")
    print(f"   Start a task: ccpm:task-start {epic_name} <task-number>")
    print()
    print("Note: Full worktree creation requires the bash version")
    print(f"      Run: bash .claude/ccpm/scripts/epic-start-db.sh {epic_name}")


if __name__ == "__main__":
    main()
