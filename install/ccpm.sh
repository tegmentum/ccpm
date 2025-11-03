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

# Create workspace directories
mkdir -p prds epics

echo "🔗 Integrating with existing configuration..."
# Run integration script if it exists
if [ -f ".claude/ccpm/scripts/integrate.sh" ]; then
    bash .claude/ccpm/scripts/integrate.sh
else
    echo "⚠️  Warning: Integration script not found, skipping configuration merge"
fi

echo ""
echo "✅ CCPM installed successfully!"
echo ""
echo "📋 Next steps:"
echo "  1. Run initialization: /ccpm:init"
echo "  2. Create your first PRD: /ccpm:prd-new"
echo "  3. Get help: /ccpm:help"
echo ""
