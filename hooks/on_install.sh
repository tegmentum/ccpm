#!/bin/bash
# CCPM Plugin Install Hook
# Initializes CCPM database and checks dependencies

set -e

echo "🚀 Installing CCPM Plugin..."
echo ""

# Get plugin directory (passed by Claude Code)
PLUGIN_DIR="${PLUGIN_DIR:-$(dirname "$(dirname "$0")")}"

# ============================================================================
# 1. Check Dependencies
# ============================================================================

echo "📋 Checking dependencies..."

# Check Python 3.7+
if command -v python3 &> /dev/null; then
  python_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  python_major=$(echo "$python_version" | cut -d. -f1)
  python_minor=$(echo "$python_version" | cut -d. -f2)

  if [[ "$python_major" -ge 3 ]] && [[ "$python_minor" -ge 7 ]]; then
    echo "  ✅ Python $python_version"
  else
    echo "  ⚠️  Python 3.7+ required (found $python_version)"
    exit 1
  fi
else
  echo "  ❌ Python 3 not found. Please install Python 3.7 or later."
  exit 1
fi

# Check git
if command -v git &> /dev/null; then
  git_version=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  echo "  ✅ git $git_version"
else
  echo "  ❌ git not found. Please install git."
  exit 1
fi

# Check gh CLI (optional but recommended)
if command -v gh &> /dev/null; then
  gh_version=$(gh --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  echo "  ✅ gh CLI $gh_version"
else
  echo "  ⚠️  gh CLI not found (optional - needed for GitHub integration)"
  echo "     Install from: https://cli.github.com/"
fi

echo ""

# ============================================================================
# 2. Install Python Dependencies
# ============================================================================

echo "📦 Installing Python dependencies..."

# Check for uv (fast package installer)
if ! command -v uv &> /dev/null; then
  echo "  Installing uv package manager..."
  if curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null; then
    echo "  ✅ uv installed"
    # Add to PATH for current session
    export PATH="$HOME/.local/bin:$PATH"
  else
    echo "  ⚠️  uv install failed, falling back to pip"
  fi
fi

# Install PyGithub
if command -v uv &> /dev/null; then
  echo "  Installing PyGithub via uv..."
  uv pip install PyGithub --system 2>/dev/null || python3 -m pip install PyGithub
else
  echo "  Installing PyGithub via pip..."
  python3 -m pip install PyGithub
fi

echo "  ✅ PyGithub installed"
echo ""

# ============================================================================
# 3. Initialize Database
# ============================================================================

echo "💾 Initializing CCPM database..."

# Create .claude directory if it doesn't exist
mkdir -p ~/.claude

# Set database path
DB_PATH="${CCPM_DB_PATH:-$HOME/.claude/ccpm.db}"

# Check if database already exists
if [ -f "$DB_PATH" ]; then
  echo "  ℹ️  Database already exists at: $DB_PATH"
  echo "  Skipping initialization (use 'pm:init' to reinitialize)"
else
  # Initialize database with schema
  if [ -f "$PLUGIN_DIR/lib/sql/schema.sql" ]; then
    sqlite3 "$DB_PATH" < "$PLUGIN_DIR/lib/sql/schema.sql"
    echo "  ✅ Database created at: $DB_PATH"
  elif [ -f "$PLUGIN_DIR/db/schema.sql" ]; then
    # Fallback to old location
    sqlite3 "$DB_PATH" < "$PLUGIN_DIR/db/schema.sql"
    echo "  ✅ Database created at: $DB_PATH"
  else
    echo "  ⚠️  Schema file not found, creating empty database"
    touch "$DB_PATH"
  fi
fi

echo ""

# ============================================================================
# 4. Setup Complete
# ============================================================================

echo "✨ CCPM Plugin installed successfully!"
echo ""
echo "Quick Start:"
echo "  pm:status       - View project status"
echo "  pm:help         - Show all commands"
echo "  pm:prd-new      - Create new PRD"
echo ""
echo "Documentation: https://github.com/automazeio/ccpm"
echo ""
echo "Environment Variables:"
echo "  CCPM_DB_PATH    - Custom database location (default: ~/.claude/ccpm.db)"
echo "  PLUGIN_DIR      - Plugin root (set automatically)"
echo ""
