#!/usr/bin/env python3
"""
Import issues from GitHub.

Note: Full import implementation requires complex GitHub API usage.
For now, use the bash version for complete functionality.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))


def main():
    """Main entry point."""
    print("Import from GitHub requires the bash version for complete functionality.")
    print()
    print("Run: bash .claude/scripts/pm/import-db.sh")
    sys.exit(1)


if __name__ == "__main__":
    main()
