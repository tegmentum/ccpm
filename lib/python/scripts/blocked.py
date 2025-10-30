#!/usr/bin/env python3
"""Show blocked tasks (waiting on dependencies)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / 'db'))

from helpers import get_blocked_tasks, print_header, print_info

def main():
    print_header("⏸️  Blocked Tasks")
    
    blocked = get_blocked_tasks()
    
    if not blocked:
        print_info("No blocked tasks")
        print()
        return
    
    for task in blocked:
        epic_name = task.get('epic_name', 'Unknown')
        task_num = task['task_number']
        name = task['name']
        deps = task.get('unmet_dependencies', 'Unknown')
        
        print(f"• {epic_name} / Task #{task_num}: {name}")
        print(f"  Blocked by: {deps}")
        print()

if __name__ == "__main__":
    main()
