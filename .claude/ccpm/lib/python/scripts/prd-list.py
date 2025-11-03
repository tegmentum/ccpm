#!/usr/bin/env python3
"""List all PRDs."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers import get_db, print_header

def main():
    print_header("📄 PRDs")
    
    with get_db() as db:
        prds = db.query("""
            SELECT name, description, status
            FROM ccpm.prds
            WHERE deleted_at IS NULL
            ORDER BY created_at DESC
        """)
    
    if not prds:
        print("No PRDs found")
        print()
        return
    
    for prd in prds:
        name = prd['name']
        desc = prd.get('description', '')[:60]
        status = prd['status']
        
        status_icon = {
            'active': '🔄',
            'backlog': '📋',
            'complete': '✅'
        }.get(status, '•')
        
        print(f"{status_icon} {name} [{status}]")
        if desc:
            print(f"   {desc}...")
    
    print()

if __name__ == "__main__":
    main()
