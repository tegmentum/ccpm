#!/usr/bin/env python3
"""
Edit epic in $EDITOR.

Note: Full edit implementation requires file handling and editor integration.
For now, use the bash version for complete functionality.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))


def main():
    """Main entry point."""
    print("Epic editing requires the bash version for $EDITOR integration.")
    print()
    print("Run: bash .claude/ccpm/scripts/epic-edit-db.sh <epic-name>")
    sys.exit(1)


if __name__ == "__main__":
    main()
