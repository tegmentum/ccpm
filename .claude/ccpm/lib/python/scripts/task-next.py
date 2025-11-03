#!/usr/bin/env python3
"""Show next available tasks (ready to start)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers import get_ready_tasks, get_epic, print_header, print_info

def main():
    epic_name = sys.argv[1] if len(sys.argv) > 1 else None
    
    if epic_name:
        print_header(f"📋 Ready Tasks: {epic_name}")
        epic = get_epic(epic_name)
        if not epic:
            print(f"❌ Epic not found: {epic_name}")
            sys.exit(1)
        tasks = get_ready_tasks(epic['id'])
    else:
        print_header("📋 Ready Tasks (All Epics)")
        tasks = get_ready_tasks()
    
    if not tasks:
        print_info("No tasks ready to start")
        print()
        return
    
    for task in tasks:
        epic = task.get('epic_name', 'Unknown')
        task_num = task['task_number']
        name = task['name']
        est = task.get('estimated_hours', 0)
        gh_issue = task.get('github_issue_number')
        
        est_str = f" (~{est}h)" if est else ""
        gh_str = f" (GitHub #{gh_issue})" if gh_issue else ""
        print(f"• {epic} / Task #{task_num}: {name}{est_str}{gh_str}")
    
    print()
    if tasks:
        first = tasks[0]
        print(f"Start first: ccpm:task-start {first['epic_name']} {first['task_number']}")
        print()

if __name__ == "__main__":
    main()
