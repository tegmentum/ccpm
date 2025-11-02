#!/bin/bash
set -e

REPO="tegmentum/ccpm"
BRANCH="main"
DOWNLOAD_URL="https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz"

echo "🚀 Installing Claude Code PM..."
echo ""

# Check if .claude directory already exists
if [ -d ".claude" ]; then
    echo "❌ Error: .claude directory already exists in this project"
    echo ""
    echo "This project may already have CCPM or another Claude Code configuration."
    echo "To avoid conflicts, CCPM will not overwrite existing .claude directories."
    echo ""
    echo "Options:"
    echo "  1. Remove .claude directory: rm -rf .claude"
    echo "  2. Install in a new project directory"
    echo ""
    exit 1
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "📦 Downloading CCPM snapshot..."
curl -sL "$DOWNLOAD_URL" -o "$TEMP_DIR/ccpm.tar.gz"

echo "📂 Extracting files..."
tar -xzf "$TEMP_DIR/ccpm.tar.gz" -C "$TEMP_DIR"

# Move .claude directory to current directory
EXTRACTED_DIR="$TEMP_DIR/ccpm-$BRANCH"
if [ ! -d "$EXTRACTED_DIR/.claude" ]; then
    echo "❌ Error: Downloaded archive doesn't contain .claude directory"
    exit 1
fi

echo "📁 Installing CCPM files..."
mv "$EXTRACTED_DIR/.claude" .

# Create workspace directories
mkdir -p prds epics

echo ""
echo "✅ CCPM installed successfully!"
echo ""
echo "📋 Next steps:"
echo "  1. Run initialization: /ccpm:init"
echo "  2. Create your first PRD: /ccpm:prd-new"
echo "  3. Get help: /ccpm:help"
echo ""
