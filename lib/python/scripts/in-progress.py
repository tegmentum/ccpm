#!/usr/bin/env python3
"""Show tasks currently in progress."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers import get_db, print_header, print_info

def main():
    print_header("🔄 Tasks In Progress")
    
    with get_db() as db:
        tasks = db.query("""
            SELECT t.*, e.name as epic_name
            FROM ccpm.tasks t
            JOIN ccpm.epics e ON t.epic_id = e.id
            WHERE t.status = 'in_progress'
                AND t.deleted_at IS NULL
            ORDER BY e.name, t.task_number
        """)
    
    if not tasks:
        print_info("No tasks in progress")
        print()
        return
    
    for task in tasks:
        epic_name = task['epic_name']
        task_num = task['task_number']
        name = task['name']
        gh_issue = task.get('github_issue_number')
        
        gh_str = f" (GitHub #{gh_issue})" if gh_issue else ""
        print(f"• {epic_name} / Task #{task_num}: {name}{gh_str}")
    
    print()

if __name__ == "__main__":
    main()
