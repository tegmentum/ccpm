#!/bin/bash

echo "Initializing..."
echo ""
echo ""

echo " ██████╗ ██████╗██████╗ ███╗   ███╗"
echo "██╔════╝██╔════╝██╔══██╗████╗ ████║"
echo "██║     ██║     ██████╔╝██╔████╔██║"
echo "╚██████╗╚██████╗██║     ██║ ╚═╝ ██║"
echo " ╚═════╝ ╚═════╝╚═╝     ╚═╝     ╚═╝"

echo "┌─────────────────────────────────┐"
echo "│ Claude Code Project Management  │"
echo "│ by https://x.com/aroussi        │"
echo "└─────────────────────────────────┘"
echo "https://github.com/automazeio/ccpm"
echo ""
echo ""

echo "🚀 Initializing Claude Code PM System"
echo "======================================"
echo ""

# Detect package manager
detect_package_manager() {
  if command -v brew &> /dev/null; then
    echo "brew"
  elif command -v apt-get &> /dev/null; then
    echo "apt"
  elif command -v dnf &> /dev/null; then
    echo "dnf"
  elif command -v yum &> /dev/null; then
    echo "yum"
  else
    echo "unknown"
  fi
}

# Install package based on detected package manager
install_package() {
  local package_name="$1"
  local brew_name="${2:-$package_name}"
  local apt_name="${3:-$package_name}"
  local dnf_name="${4:-$package_name}"

  local pm=$(detect_package_manager)

  case "$pm" in
    brew)
      brew install "$brew_name"
      ;;
    apt)
      sudo apt-get update && sudo apt-get install -y "$apt_name"
      ;;
    dnf)
      sudo dnf install -y "$dnf_name"
      ;;
    yum)
      sudo yum install -y "$dnf_name"
      ;;
    *)
      return 1
      ;;
  esac
}

# Check for required tools
echo "🔍 Checking dependencies..."

# Check gh CLI
if command -v gh &> /dev/null; then
  echo "  ✅ GitHub CLI (gh) installed"
else
  echo "  ❌ GitHub CLI (gh) not found"
  echo ""
  echo "  Installing gh..."
  if ! install_package "gh" "gh" "gh" "gh"; then
    echo "  Please install GitHub CLI manually: https://cli.github.com/"
    exit 1
  fi
fi

# Check jq
if command -v jq &> /dev/null; then
  echo "  ✅ jq installed"
else
  echo "  ❌ jq not found"
  echo ""
  echo "  Installing jq..."
  if ! install_package "jq" "jq" "jq" "jq"; then
    echo "  Please install jq manually: https://jqlang.github.io/jq/"
    exit 1
  fi
fi

# Check sqlite3
if command -v sqlite3 &> /dev/null; then
  echo "  ✅ SQLite installed"
else
  echo "  ❌ SQLite not found"
  echo ""
  echo "  Installing sqlite3..."
  if ! install_package "sqlite" "sqlite" "sqlite3" "sqlite"; then
    echo "  Please install SQLite manually: https://sqlite.org/"
    exit 1
  fi
fi

# Check duckdb
if command -v duckdb &> /dev/null; then
  echo "  ✅ DuckDB installed"
else
  echo "  ❌ DuckDB not found"
  echo ""
  echo "  Installing duckdb..."

  local pm=$(detect_package_manager)

  if [[ "$pm" == "brew" ]]; then
    brew install duckdb
  elif [[ "$pm" == "apt" ]] || [[ "$pm" == "dnf" ]] || [[ "$pm" == "yum" ]]; then
    # DuckDB requires manual install on Linux
    echo "  Installing DuckDB from GitHub releases..."
    wget -q https://github.com/duckdb/duckdb/releases/latest/download/duckdb_cli-linux-amd64.zip
    unzip -q duckdb_cli-linux-amd64.zip
    sudo mv duckdb /usr/local/bin/
    rm duckdb_cli-linux-amd64.zip
  else
    echo "  Please install DuckDB manually: https://duckdb.org/docs/installation/"
    exit 1
  fi
fi

# Check gh auth status
echo ""
echo "🔐 Checking GitHub authentication..."
if gh auth status &> /dev/null; then
  echo "  ✅ GitHub authenticated"
else
  echo "  ⚠️ GitHub not authenticated"
  echo "  Running: gh auth login"
  gh auth login
fi

# Check for gh-sub-issue extension
echo ""
echo "📦 Checking gh extensions..."
if gh extension list | grep -q "yahsan2/gh-sub-issue"; then
  echo "  ✅ gh-sub-issue extension installed"
else
  echo "  📥 Installing gh-sub-issue extension..."
  gh extension install yahsan2/gh-sub-issue
fi

# Create directory structure
echo ""
echo "📁 Creating directory structure..."
mkdir -p .claude/prds
mkdir -p .claude/epics
mkdir -p .claude/rules
mkdir -p .claude/agents
mkdir -p .claude/scripts/pm
mkdir -p db
echo "  ✅ Directories created"

# Initialize database
echo ""
echo "🗄️  Initializing database..."
if [ -f "db/init.sh" ]; then
  bash db/init.sh
  echo "  ✅ Database initialized"
else
  echo "  ⚠️  Database init script not found (db/init.sh)"
  echo "  Database features will not be available"
fi

# Copy scripts if in main repo
if [ -d "scripts/pm" ] && [ ! "$(pwd)" = *"/.claude"* ]; then
  echo ""
  echo "📝 Copying PM scripts..."
  cp -r scripts/pm/* .claude/scripts/pm/
  chmod +x .claude/scripts/pm/*.sh
  echo "  ✅ Scripts copied and made executable"
fi

# Check for git
echo ""
echo "🔗 Checking Git configuration..."
if git rev-parse --git-dir > /dev/null 2>&1; then
  echo "  ✅ Git repository detected"

  # Check remote
  if git remote -v | grep -q origin; then
    remote_url=$(git remote get-url origin)
    echo "  ✅ Remote configured: $remote_url"
    
    # Check if remote is the CCPM template repository
    if [[ "$remote_url" == *"automazeio/ccpm"* ]] || [[ "$remote_url" == *"automazeio/ccpm.git"* ]]; then
      echo ""
      echo "  ⚠️ WARNING: Your remote origin points to the CCPM template repository!"
      echo "  This means any issues you create will go to the template repo, not your project."
      echo ""
      echo "  To fix this:"
      echo "  1. Fork the repository or create your own on GitHub"
      echo "  2. Update your remote:"
      echo "     git remote set-url origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
      echo ""
    fi
  else
    echo "  ⚠️ No remote configured"
    echo "  Add with: git remote add origin <url>"
  fi
else
  echo "  ⚠️ Not a git repository"
  echo "  Initialize with: git init"
fi

# Create CLAUDE.md if it doesn't exist
if [ ! -f "CLAUDE.md" ]; then
  echo ""
  echo "📄 Creating CLAUDE.md..."
  cat > CLAUDE.md << 'EOF'
# CLAUDE.md

> Think carefully and implement the most concise solution that changes as little code as possible.

## Project-Specific Instructions

Add your project-specific instructions here.

## Testing

Always run tests before committing:
- `npm test` or equivalent for your stack

## Code Style

Follow existing patterns in the codebase.
EOF
  echo "  ✅ CLAUDE.md created"
fi

# Summary
echo ""
echo "✅ Initialization Complete!"
echo "=========================="
echo ""
echo "📊 System Status:"
gh --version | head -1
echo "  Extensions: $(gh extension list | wc -l) installed"
echo "  Auth: $(gh auth status 2>&1 | grep -o 'Logged in to [^ ]*' || echo 'Not authenticated')"
echo ""
echo "🎯 Next Steps:"
echo "  1. Create your first PRD: /pm:prd-new <feature-name>"
echo "  2. View help: /pm:help"
echo "  3. Check status: /pm:status"
echo ""
echo "📚 Documentation: README.md"

exit 0
