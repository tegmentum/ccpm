#!/usr/bin/env python3
"""Show epic details and all tasks."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers import get_epic, get_tasks_for_epic, print_header, print_error, print_separator

def main():
    if len(sys.argv) < 2:
        print_error("Usage: ccpm:epic-show <epic-name>")
        sys.exit(1)
    
    epic_name = sys.argv[1]
    
    epic = get_epic(epic_name)
    if not epic:
        print_error(f"Epic not found: {epic_name}")
        sys.exit(1)
    
    print_header(f"📊 Epic: {epic_name}")
    
    print(f"Status: {epic['status']}")
    print(f"Progress: {epic.get('progress', 0)}%")
    if epic.get('prd_name'):
        print(f"PRD: {epic['prd_name']}")
    if epic.get('github_issue_number'):
        print(f"GitHub: #{epic['github_issue_number']}")
    
    if epic.get('description'):
        print(f"\nDescription:\n{epic['description']}")
    
    print()
    print_separator()
    print("Tasks:")
    print_separator()
    print()
    
    tasks = get_tasks_for_epic(epic['id'])
    
    if not tasks:
        print("No tasks found")
        print()
        return
    
    for task in tasks:
        status_icon = {
            'closed': '✅',
            'in_progress': '🔄',
            'open': '📋'
        }.get(task['status'], '•')
        
        num = task['task_number']
        name = task['name']
        status = task['status']
        est = task.get('estimated_hours', 0)
        gh = task.get('github_issue_number')
        
        est_str = f" ~{est}h" if est else ""
        gh_str = f" #{gh}" if gh else ""
        
        print(f"{status_icon} Task #{num}: {name} [{status}]{est_str}{gh_str}")
    
    print()

if __name__ == "__main__":
    main()
