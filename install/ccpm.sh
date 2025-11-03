#!/bin/bash
set -e

REPO="tegmentum/ccpm"
BRANCH="main"
DOWNLOAD_URL="https://github.com/$REPO/archive/refs/heads/$BRANCH.zip"

echo "🚀 Installing Claude Code PM..."
echo ""

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "📦 Downloading CCPM snapshot..."
curl -sL "$DOWNLOAD_URL" -o "$TEMP_DIR/ccpm.zip"

echo "📂 Extracting files..."
unzip -q "$TEMP_DIR/ccpm.zip" -d "$TEMP_DIR"

# Locate extracted directory
EXTRACTED_DIR="$TEMP_DIR/ccpm-$BRANCH"
if [ ! -d "$EXTRACTED_DIR/.claude" ]; then
    echo "❌ Error: Downloaded archive doesn't contain .claude directory"
    exit 1
fi

echo "📁 Installing CCPM files..."
# Create .claude directory if it doesn't exist
mkdir -p .claude

# Copy CCPM plugin files into .claude (overlay method)
cp -r "$EXTRACTED_DIR/.claude/"* .claude/

# Verify critical files were copied
if [ ! -f ".claude/ccpm/CLAUDE.md" ]; then
    echo "❌ Error: CLAUDE.md not found after installation"
    echo "Expected at: .claude/ccpm/CLAUDE.md"
    exit 1
fi

if [ ! -f ".claude/ccpm/scripts/integrate.sh" ]; then
    echo "❌ Error: Integration script not found after installation"
    echo "Expected at: .claude/ccpm/scripts/integrate.sh"
    exit 1
fi

# Create workspace directories
mkdir -p prds epics

echo "🔗 Integrating with existing configuration..."
# Run integration script
bash .claude/ccpm/scripts/integrate.sh

# Verify integration completed
if [ ! -f ".claude/CLAUDE.md" ]; then
    echo "⚠️  Warning: .claude/CLAUDE.md was not created by integration"
    echo "You may need to manually reference .claude/ccpm/CLAUDE.md in your project configuration"
fi

echo ""
echo "✅ CCPM installed successfully!"
echo ""
echo "📁 Installed files:"
echo "  • Plugin: .claude/ccpm/"
echo "  • Configuration: .claude/CLAUDE.md"
echo "  • Workspaces: prds/ and epics/"
echo ""
echo "📋 Next steps:"
echo "  1. Run initialization: /ccpm:init"
echo "  2. Create your first PRD: /ccpm:prd-new"
echo "  3. Get help: /ccpm:help"
echo ""
