#!/usr/bin/env python3
"""Add task to existing epic."""

import sys
import argparse
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers import (
    get_epic, get_db, update_epic,
    print_error, print_success, print_separator
)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Add task to an epic',
        epilog='Examples:\n  pm task-add "Fix validation bug"\n  pm task-add my-epic "Fix validation bug" --estimate 4',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('epic_or_task', help='Epic name or task name (if no epic, uses backlog)')
    parser.add_argument('task_name', nargs='?', help='Task name (if epic specified)')
    parser.add_argument('--description', help='Task description')
    parser.add_argument('--estimate', type=float, help='Estimated hours')
    parser.add_argument('--depends-on', help='Comma-separated task numbers (e.g., 1,2,3)')
    parser.add_argument('--sync', action='store_true', help='Create GitHub issue immediately')

    args = parser.parse_args()

    # Determine epic and task names
    if args.task_name:
        epic_name = args.epic_or_task
        task_name = args.task_name
    else:
        epic_name = 'backlog'
        task_name = args.epic_or_task

    print("Adding Task to Epic")
    print_separator()
    print()

    # Get or create epic
    epic = get_epic(epic_name)

    if not epic:
        if epic_name == 'backlog':
            print("Creating 'backlog' epic for miscellaneous tasks...")
            with get_db() as db:
                # Check if backlog PRD exists
                prd_result = db.query(
                    "SELECT id FROM ccpm.prds WHERE name = 'backlog' AND deleted_at IS NULL"
                )

                if not prd_result:
                    # Create backlog PRD
                    db.execute(
                        """
                        INSERT INTO ccpm.prds (name, description, status, created_at)
                        VALUES ('backlog', 'Miscellaneous tasks and issues', 'active', ?)
                        """,
                        (datetime.utcnow().isoformat() + "Z",)
                    )
                    prd_id = db.get_last_insert_id()
                    print_success("Created 'backlog' PRD")
                else:
                    prd_id = prd_result[0]['id']

                # Create backlog epic
                now = datetime.utcnow().isoformat() + "Z"
                db.execute(
                    """
                    INSERT INTO ccpm.epics (
                        prd_id, name, content, status, progress, created_at
                    ) VALUES (?, 'backlog', 'Backlog for miscellaneous tasks', 'active', 0, ?)
                    """,
                    (prd_id, now)
                )
                print_success("Created 'backlog' epic")
                epic = get_epic('backlog')
        else:
            print_error(f"Epic not found: {epic_name}")
            sys.exit(1)

    epic_id = epic['id']
    print(f"Epic: {epic_name} [{epic['status']}]")

    # Get next task number
    with get_db() as db:
        result = db.query(
            """
            SELECT COALESCE(MAX(task_number), 0) + 1 as next_num
            FROM ccpm.tasks
            WHERE epic_id = ? AND deleted_at IS NULL
            """,
            (epic_id,)
        )
        next_task_num = result[0]['next_num'] if result else 1

        print(f"Task Number: {next_task_num}")
        print(f"Task Name: {task_name}")
        if args.description:
            print(f"Description: {args.description}")
        if args.estimate:
            print(f"Estimated Hours: {args.estimate}")
        print()

        # Validate dependencies if provided
        dep_ids = []
        if args.depends_on:
            print("Validating dependencies...")
            dep_numbers = [int(n.strip()) for n in args.depends_on.split(',')]

            for dep_num in dep_numbers:
                dep_result = db.query(
                    """
                    SELECT id FROM ccpm.tasks
                    WHERE epic_id = ? AND task_number = ? AND deleted_at IS NULL
                    """,
                    (epic_id, dep_num)
                )

                if not dep_result:
                    print_error(f"Dependency task #{dep_num} not found in epic '{epic_name}'")
                    sys.exit(1)

                dep_ids.append(dep_result[0]['id'])
                print(f"  Task #{dep_num} exists")
            print()

        # Insert task
        now = datetime.utcnow().isoformat() + "Z"
        db.execute(
            """
            INSERT INTO ccpm.tasks (
                epic_id, task_number, name, description, status,
                estimated_hours, created_at, updated_at
            ) VALUES (?, ?, ?, ?, 'open', ?, ?, ?)
            """,
            (epic_id, next_task_num, task_name, args.description,
             args.estimate, now, now)
        )

        task_id = db.get_last_insert_id()

        print_success("Task added to database")
        print(f"   ID: {task_id}")
        print(f"   Epic: {epic_name}")
        print(f"   Task Number: {next_task_num}")
        print()

        # Add dependencies if provided
        if dep_ids:
            print("Adding dependencies...")
            for dep_id in dep_ids:
                db.execute(
                    """
                    INSERT INTO ccpm.task_dependencies (task_id, depends_on_task_id)
                    VALUES (?, ?)
                    """,
                    (task_id, dep_id)
                )
            print_success(f"Added {len(dep_ids)} dependencies")
            print()

    # Summary
    print_separator()
    print_success(f"Task {epic_name}/{next_task_num} added successfully")
    print()
    print("Next steps:")
    print(f"   View epic: pm epic-show {epic_name}")
    print(f"   Start task: pm task-start {epic_name} {next_task_num}")
    if not args.sync:
        print(f"   Sync to GitHub: pm epic-sync {epic_name}")


if __name__ == "__main__":
    main()
