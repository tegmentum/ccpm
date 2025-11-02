#!/usr/bin/env python3
"""
Sync all issues bidirectionally with GitHub.

Note: Full sync implementation requires complex GitHub API usage.
For now, use the bash version for complete functionality.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "db"))


def main():
    """Main entry point."""
    print("Full sync requires the bash version for complete GitHub integration.")
    print()
    print("Run: bash .claude/scripts/sync-db.sh")
    print()
    print("For single issue sync, use: ccpm:issue-sync <issue-number>")
    sys.exit(1)


if __name__ == "__main__":
    main()
