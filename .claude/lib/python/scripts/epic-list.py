#!/usr/bin/env python3
"""List all epics."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers import get_db, print_header

def main():
    print_header("📚 Epics")
    
    with get_db() as db:
        epics = db.query("""
            SELECT name, status, progress, github_issue_number
            FROM ccpm.epics
            WHERE deleted_at IS NULL
            ORDER BY 
                CASE status
                    WHEN 'active' THEN 1
                    WHEN 'backlog' THEN 2
                    WHEN 'closed' THEN 3
                END,
                created_at DESC
        """)
    
    if not epics:
        print("No epics found")
        print()
        return
    
    for epic in epics:
        name = epic['name']
        status = epic['status']
        progress = epic.get('progress', 0)
        gh = epic.get('github_issue_number')
        
        status_icons = {
            'active': '🔄',
            'backlog': '📋',
            'closed': '✅'
        }
        icon = status_icons.get(status, '•')
        
        gh_str = f" (#{gh})" if gh else ""
        print(f"{icon} {name} [{status}] {progress}%{gh_str}")
    
    print()

if __name__ == "__main__":
    main()
