#!/usr/bin/env python3
"""Show overall project status dashboard."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "db"))

from helpers import get_db, print_header, print_separator

def main():
    print_header("📊 Project Status")
    
    with get_db() as db:
        # PRD summary
        prd_counts = db.query("""
            SELECT status, COUNT(*) as count
            FROM ccpm.prds
            WHERE deleted_at IS NULL
            GROUP BY status
        """)
        
        # Epic summary
        epic_counts = db.query("""
            SELECT status, COUNT(*) as count
            FROM ccpm.epics
            WHERE deleted_at IS NULL
            GROUP BY status
        """)
        
        # Task summary
        task_counts = db.query("""
            SELECT status, COUNT(*) as count
            FROM ccpm.tasks
            WHERE deleted_at IS NULL
            GROUP BY status
        """)
    
    print("PRDs:")
    prd_dict = {row['status']: row['count'] for row in prd_counts}
    print(f"  Active: {prd_dict.get('active', 0)}")
    print(f"  Complete: {prd_dict.get('complete', 0)}")
    print(f"  Backlog: {prd_dict.get('backlog', 0)}")
    print()
    
    print("Epics:")
    epic_dict = {row['status']: row['count'] for row in epic_counts}
    print(f"  Active: {epic_dict.get('active', 0)}")
    print(f"  Closed: {epic_dict.get('closed', 0)}")
    print(f"  Backlog: {epic_dict.get('backlog', 0)}")
    print()
    
    print("Tasks:")
    task_dict = {row['status']: row['count'] for row in task_counts}
    print(f"  In Progress: {task_dict.get('in_progress', 0)}")
    print(f"  Open: {task_dict.get('open', 0)}")
    print(f"  Closed: {task_dict.get('closed', 0)}")
    print()
    
    print_separator()
    print("Quick Commands:")
    print("  ccpm:task-next        - See ready tasks")
    print("  ccpm:in-progress - See active work")
    print("  ccpm:epic-list   - View all epics")
    print()

if __name__ == "__main__":
    main()
