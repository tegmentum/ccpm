#!/usr/bin/env python3
"""
Merge tasks from one epic to another.

Note: Full merge implementation requires complex validation.
For now, use the bash version for complete functionality.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / 'db'))


def main():
    """Main entry point."""
    print("Epic merge requires the bash version for complete functionality.")
    print()
    print("Run: bash .claude/scripts/pm/epic-merge-db.sh <source-epic> <target-epic>")
    sys.exit(1)


if __name__ == "__main__":
    main()
