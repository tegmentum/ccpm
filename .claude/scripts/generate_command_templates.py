#!/usr/bin/env python3
"""
Generate minimal command template files for router-based commands.

This script creates standardized command files that route through router.py,
reducing token usage while maintaining functionality.
"""

import sys
from pathlib import Path

# Import the command map from router
sys.path.insert(0, str(Path(__file__).parent))
from router import COMMAND_MAP, BASH_COMMANDS

# Commands that should NOT use router (LLM-based commands)
SKIP_COMMANDS = {
    'prd-new',       # LLM-based PRD creation
    'prd-edit',      # LLM-based PRD editing
    'prd-parse',     # LLM-based PRD parsing
    'epic-decompose', # LLM-based epic decomposition
    'issue-analyze',  # LLM-based issue analysis
    'epic-oneshot',   # LLM-based single-shot epic
}

# Commands that already converted in Phase 2
ALREADY_CONVERTED = {
    'status',
    'task-next',
    'blocked',
    'epic-list',
    'task-add',
}

def generate_template(command_name: str) -> str:
    """Generate minimal router template for a command."""
    return f"""---
allowed-tools: Bash
---

Run: `python3 .claude/scripts/router.py {command_name} $ARGUMENTS`
"""

def main():
    """Generate command template files."""
    commands_dir = Path(__file__).parent.parent.parent / 'commands' / 'pm'

    if not commands_dir.exists():
        print(f"Error: Commands directory not found: {commands_dir}")
        sys.exit(1)

    print("Generating command template files...")
    print("=" * 60)

    # Combine Python and bash commands
    all_commands = set(COMMAND_MAP.keys()) | set(BASH_COMMANDS.keys())

    # Filter out commands to skip
    commands_to_convert = all_commands - SKIP_COMMANDS - ALREADY_CONVERTED

    generated = []
    skipped = []

    for command in sorted(commands_to_convert):
        command_file = commands_dir / f"{command}.md"

        # Generate template
        template = generate_template(command)

        # Write file
        with open(command_file, 'w') as f:
            f.write(template)

        generated.append(command)
        print(f"✅ Generated: {command}.md")

    print()
    print("=" * 60)
    print(f"Generated: {len(generated)} command files")
    print()

    if SKIP_COMMANDS:
        print("Skipped (LLM-based commands):")
        for cmd in sorted(SKIP_COMMANDS):
            print(f"  - {cmd}")
        print()

    if ALREADY_CONVERTED:
        print("Already converted (Phase 2):")
        for cmd in sorted(ALREADY_CONVERTED):
            print(f"  - {cmd}")
        print()

    print("Commands generated:")
    for cmd in sorted(generated):
        print(f"  - {cmd}")

if __name__ == "__main__":
    main()
