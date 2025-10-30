#!/usr/bin/env python3
"""Search across PRDs, epics, and tasks."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / 'db'))

from helpers import get_db, print_separator


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: pm search <query>")
        print()
        print("Searches across:")
        print("  • PRD names and descriptions")
        print("  • Epic names and content")
        print("  • Task names and descriptions")
        print()
        print("Examples:")
        print("  pm search authentication")
        print("  pm search 'user login'")
        print("  pm search api")
        sys.exit(1)

    query = sys.argv[1]

    print(f"Searching for: '{query}'")
    print_separator()
    print()

    with get_db() as db:
        # Search PRDs
        prd_results = db.query(
            """
            SELECT
                name,
                description,
                status
            FROM ccpm.prds
            WHERE deleted_at IS NULL
                AND (
                    name LIKE ?
                    OR description LIKE ?
                )
            ORDER BY created_at DESC
            """,
            (f'%{query}%', f'%{query}%')
        )

        if prd_results:
            print(f"PRDs ({len(prd_results)} found):")
            for prd in prd_results:
                print(f"  • {prd['name']} [{prd['status']}]")
            print()

        # Search Epics
        epic_results = db.query(
            """
            SELECT
                e.name,
                e.status,
                e.progress,
                p.name as prd_name
            FROM ccpm.epics e
            LEFT JOIN ccpm.prds p ON e.prd_id = p.id
            WHERE e.deleted_at IS NULL
                AND (
                    e.name LIKE ?
                    OR e.content LIKE ?
                )
            ORDER BY e.created_at DESC
            """,
            (f'%{query}%', f'%{query}%')
        )

        if epic_results:
            print(f"Epics ({len(epic_results)} found):")
            for epic in epic_results:
                prd_str = f" (PRD: {epic['prd_name']})" if epic['prd_name'] else ""
                print(f"  • {epic['name']} [{epic['status']}] {epic['progress']}%{prd_str}")
            print()

        # Search Tasks
        task_results = db.query(
            """
            SELECT
                t.task_number,
                t.name,
                t.status,
                e.name as epic_name,
                t.github_issue_number
            FROM ccpm.tasks t
            JOIN ccpm.epics e ON t.epic_id = e.id
            WHERE t.deleted_at IS NULL
                AND (
                    t.name LIKE ?
                    OR t.description LIKE ?
                    OR t.content LIKE ?
                )
            ORDER BY e.name, t.task_number
            """,
            (f'%{query}%', f'%{query}%', f'%{query}%')
        )

        if task_results:
            print(f"Tasks ({len(task_results)} found):")
            for task in task_results:
                gh_str = f" (#{task['github_issue_number']})" if task['github_issue_number'] else ""
                print(f"  • {task['epic_name']} / #{task['task_number']}: {task['name']} [{task['status']}]{gh_str}")
            print()

    # Summary
    total_results = len(prd_results or []) + len(epic_results or []) + len(task_results or [])
    if total_results == 0:
        print("No results found")
    else:
        print(f"Total results: {total_results}")


if __name__ == "__main__":
    main()
