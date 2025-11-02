#!/usr/bin/env python3
"""Show PRD implementation status."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers import get_prd, get_db, format_datetime, print_error


def main():
    """Main entry point."""
    prd_name = sys.argv[1] if len(sys.argv) > 1 else None

    if not prd_name:
        # Show all PRDs
        print("PRD Implementation Status")
        print("=" * 62)
        print()

        with get_db() as db:
            prds_data = db.query(
                """
                SELECT
                    p.id,
                    p.name,
                    p.status,
                    p.created_at,
                    COUNT(DISTINCT e.id) as epic_count,
                    SUM(CASE WHEN e.status IN ('active', 'in_progress') THEN 1 ELSE 0 END) as active_epics,
                    SUM(CASE WHEN e.status = 'closed' THEN 1 ELSE 0 END) as closed_epics
                FROM ccpm.prds p
                LEFT JOIN ccpm.epics e ON p.id = e.prd_id AND e.deleted_at IS NULL
                WHERE p.deleted_at IS NULL
                GROUP BY p.id, p.name, p.status, p.created_at
                ORDER BY p.created_at DESC
                """
            )

            if not prds_data:
                print("No PRDs found")
                print()
                print("Create a new PRD with: ccpm:prd-new")
                sys.exit(0)

            for prd in prds_data:
                prd_name = prd['name']
                prd_status = prd['status']
                epic_count = prd['epic_count'] or 0
                active_epics = prd['active_epics'] or 0
                closed_epics = prd['closed_epics'] or 0

                # Status icon
                icon_map = {
                    'complete': '',
                    'in_progress': '',
                }
                icon = icon_map.get(prd_status, '')

                print(f"{icon} {prd_name} ({prd_status})")
                print(f"   Epics: {epic_count} total, {active_epics} active, {closed_epics} closed")

        print()
        print("View details: ccpm:prd-status <prd-name>")
        sys.exit(0)

    # Show specific PRD details
    prd = get_prd(prd_name)
    if not prd:
        print_error(f"PRD not found: {prd_name}")
        print()
        print("Available PRDs:")
        with get_db() as db:
            prds = db.query(
                """
                SELECT name FROM ccpm.prds
                WHERE deleted_at IS NULL
                ORDER BY created_at DESC
                """
            )
            for p in prds:
                print(f"  • {p['name']}")
        sys.exit(1)

    # Display PRD details
    print(f"PRD: {prd['name']}")
    print("=" * 62)
    print()
    print(f"Status: {prd['status']}")
    print(f"Created: {format_datetime(prd['created_at'])}")
    if prd.get('description'):
        print()
        print("Description:")
        print(f"  {prd['description']}")
    print()

    # Get epics for this PRD
    with get_db() as db:
        epics = db.query(
            """
            SELECT
                e.name,
                e.status,
                e.progress,
                COUNT(DISTINCT t.id) as total_tasks,
                SUM(CASE WHEN t.status = 'closed' THEN 1 ELSE 0 END) as closed_tasks
            FROM ccpm.epics e
            LEFT JOIN ccpm.tasks t ON e.id = t.epic_id AND t.deleted_at IS NULL
            WHERE e.prd_id = ?
              AND e.deleted_at IS NULL
            GROUP BY e.id, e.name, e.status, e.progress
            ORDER BY e.created_at
            """,
            (prd['id'],)
        )

        if epics:
            print("Epics:")
            for epic in epics:
                status_icon_map = {
                    'closed': '',
                    'active': '',
                    'in_progress': '',
                }
                icon = status_icon_map.get(epic['status'], '')
                total = epic['total_tasks'] or 0
                closed = epic['closed_tasks'] or 0
                progress = epic['progress'] or 0

                print(f"  {icon} {epic['name']} ({epic['status']})")
                print(f"     Progress: {progress}% ({closed}/{total} tasks)")
        else:
            print("No epics for this PRD yet")
            print("Create an epic with: ccpm:epic-new")

    print()


if __name__ == "__main__":
    main()
