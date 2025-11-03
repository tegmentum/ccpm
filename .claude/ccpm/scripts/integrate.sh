#!/bin/bash

# CCPM Integration Script
# Integrates CCPM configuration files into existing Claude Code project

set -e

echo "🔧 CCPM Configuration Integration"
echo "=================================="
echo ""

# Function to merge JSON files
merge_json() {
  local source="$1"
  local target="$2"

  if [ ! -f "$target" ]; then
    # Target doesn't exist, just copy
    cp "$source" "$target"
    echo "  ✅ Created $target"
  else
    # Target exists, need to merge
    echo "  📋 Merging into existing $target"

    # Use Python to merge JSON
    python3 <<EOF
import json
import sys

try:
    with open('$source', 'r') as f:
        source_data = json.load(f)

    with open('$target', 'r') as f:
        target_data = json.load(f)

    # Merge permissions.allow arrays
    if 'permissions' in source_data and 'allow' in source_data['permissions']:
        if 'permissions' not in target_data:
            target_data['permissions'] = {}
        if 'allow' not in target_data['permissions']:
            target_data['permissions']['allow'] = []

        # Add new permissions that don't already exist
        existing = set(target_data['permissions']['allow'])
        for perm in source_data['permissions']['allow']:
            if perm not in existing:
                target_data['permissions']['allow'].append(perm)

    with open('$target', 'w') as f:
        json.dump(target_data, f, indent=2)

    print("  ✅ Merged permissions into $target")
except Exception as e:
    print(f"  ❌ Error merging JSON: {e}")
    sys.exit(1)
EOF
  fi
}

# Function to merge CLAUDE.md files
merge_claude_md() {
  local source="$1"
  local target="$2"

  if [ ! -f "$target" ]; then
    # Target doesn't exist, just copy
    cp "$source" "$target"
    echo "  ✅ Created $target"
  else
    # Target exists, append CCPM section
    echo "  📋 Appending CCPM configuration to existing $target"

    # Check if CCPM section already exists
    if grep -q "## CCPM Project Management" "$target" 2>/dev/null; then
      echo "  ℹ️  CCPM section already exists in $target, skipping"
    else
      # Append CCPM section
      cat >> "$target" <<'CCPM_EOF'

# ============================================================================
## CCPM Project Management

This project uses the CCPM (Claude Code Project Management) plugin.

### Project Context

@.claude/ccpm/context/project-overview.md
@.claude/ccpm/context/progress.md
@.claude/ccpm/context/tech-context.md
@.claude/ccpm/context/system-patterns.md
@.claude/ccpm/context/product-context.md
@.claude/ccpm/context/project-brief.md
@.claude/ccpm/context/project-vision.md
@.claude/ccpm/context/project-style-guide.md
@.claude/ccpm/context/project-structure.md

### Common Commands

- `/ccpm:status` - Project status dashboard
- `/ccpm:task-next` - Show next available tasks
- `/ccpm:epic-list` - List all epics
- `/ccpm:issue-start <number>` - Start working on an issue
- `/ccpm:help` - Show all available commands

For full documentation, see `.claude/ccpm/CLAUDE.md`

CCPM_EOF
      echo "  ✅ Appended CCPM section to $target"
    fi
  fi
}

# Integrate settings.local.json
echo "📝 Integrating settings.local.json..."
if [ -f ".claude/ccpm/settings.local.json" ]; then
  merge_json ".claude/ccpm/settings.local.json" ".claude/settings.local.json"
else
  echo "  ⚠️  Source file not found: .claude/ccpm/settings.local.json"
fi

echo ""

# Integrate CLAUDE.md
echo "📝 Integrating CLAUDE.md..."
if [ -f ".claude/ccpm/CLAUDE.md" ]; then
  merge_claude_md ".claude/ccpm/CLAUDE.md" ".claude/CLAUDE.md"
else
  echo "  ⚠️  Source file not found: .claude/ccpm/CLAUDE.md"
fi

echo ""
echo "✅ Integration Complete!"
echo ""
echo "📋 Next Steps:"
echo "  1. Review merged configuration files:"
echo "     - .claude/CLAUDE.md"
echo "     - .claude/settings.local.json"
echo "  2. Run: /ccpm:init to initialize the system"
echo "  3. Run: /ccpm:help to see all available commands"
echo ""
