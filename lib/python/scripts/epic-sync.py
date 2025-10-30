#!/usr/bin/env python3
"""
Sync epic to GitHub.

Note: Full GitHub sync implementation is complex.
For now, use the bash version for complete functionality.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / 'db'))

from helpers import get_epic, print_error


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: pm epic-sync <epic-name>")
        sys.exit(1)

    epic_name = sys.argv[1]

    epic = get_epic(epic_name)
    if not epic:
        print_error(f"Epic not found: {epic_name}")
        sys.exit(1)

    print(f"Epic sync for '{epic_name}' requires the bash version for full GitHub integration.")
    print()
    print(f"Run: bash .claude/scripts/pm/epic-sync-db.sh {epic_name}")
    sys.exit(1)


if __name__ == "__main__":
    main()
