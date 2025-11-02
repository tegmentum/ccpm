#!/bin/bash
# Test CCPM plugin installation in simulated clean environment
# This script validates the full installation process and all 39 commands

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
WARNINGS=0

echo "=========================================="
echo "CCPM Plugin Installation Test Suite"
echo "=========================================="
echo ""

# Test counter
test_count=0

# Function to print test results
print_test() {
    test_count=$((test_count + 1))
    local status=$1
    local message=$2

    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} Test $test_count: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}✗${NC} Test $test_count: $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} Test $test_count: $message"
        WARNINGS=$((WARNINGS + 1))
    fi
}

# ====================
# 1. Pre-Installation Checks
# ====================
echo "1. Pre-Installation Validation"
echo "----------------------------"

# Check Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    print_test "PASS" "Python 3 found: $PYTHON_VERSION"
else
    print_test "FAIL" "Python 3 not found"
fi

# Check git
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | awk '{print $3}')
    print_test "PASS" "Git found: $GIT_VERSION"
else
    print_test "FAIL" "Git not found"
fi

# Check gh CLI (optional)
if command -v gh &> /dev/null; then
    GH_VERSION=$(gh --version | head -n1 | awk '{print $3}')
    print_test "PASS" "GitHub CLI found: $GH_VERSION"
else
    print_test "WARN" "GitHub CLI not found (optional)"
fi

echo ""

# ====================
# 2. Plugin Structure Validation
# ====================
echo "2. Plugin Structure Validation"
echo "----------------------------"

# Check plugin.json
if [ -f "$PROJECT_ROOT/.claude-plugin/plugin.json" ]; then
    print_test "PASS" "plugin.json exists"

    # Validate JSON structure
    if python3 -m json.tool "$PROJECT_ROOT/.claude-plugin/plugin.json" > /dev/null 2>&1; then
        print_test "PASS" "plugin.json is valid JSON"
    else
        print_test "FAIL" "plugin.json is invalid JSON"
    fi
else
    print_test "FAIL" "plugin.json not found"
fi

# Check marketplace.json
if [ -f "$PROJECT_ROOT/.claude-plugin/marketplace.json" ]; then
    print_test "PASS" "marketplace.json exists"

    # Validate JSON structure
    if python3 -m json.tool "$PROJECT_ROOT/.claude-plugin/marketplace.json" > /dev/null 2>&1; then
        print_test "PASS" "marketplace.json is valid JSON"
    else
        print_test "FAIL" "marketplace.json is invalid JSON"
    fi
else
    print_test "FAIL" "marketplace.json not found"
fi

# Check hooks
if [ -f "$PROJECT_ROOT/hooks/hooks.json" ]; then
    print_test "PASS" "hooks.json exists"
else
    print_test "FAIL" "hooks.json not found"
fi

if [ -f "$PROJECT_ROOT/hooks/on_install.sh" ]; then
    print_test "PASS" "on_install.sh exists"

    if [ -x "$PROJECT_ROOT/hooks/on_install.sh" ]; then
        print_test "PASS" "on_install.sh is executable"
    else
        print_test "WARN" "on_install.sh is not executable"
    fi
else
    print_test "FAIL" "on_install.sh not found"
fi

echo ""

# ====================
# 3. Command Files Validation
# ====================
echo "3. Command Files Validation (39 commands)"
echo "----------------------------"

COMMAND_DIR="$PROJECT_ROOT/.claude/commands/pm"
EXPECTED_COMMANDS=39
FOUND_COMMANDS=0

if [ -d "$COMMAND_DIR" ]; then
    FOUND_COMMANDS=$(find "$COMMAND_DIR" -name "*.md" | wc -l | tr -d ' ')

    if [ "$FOUND_COMMANDS" -eq "$EXPECTED_COMMANDS" ]; then
        print_test "PASS" "Found all $EXPECTED_COMMANDS command files"
    else
        print_test "FAIL" "Found $FOUND_COMMANDS commands, expected $EXPECTED_COMMANDS"
    fi
else
    print_test "FAIL" "Command directory not found"
fi

# Validate command file format
INVALID_COMMANDS=0
for cmd_file in "$COMMAND_DIR"/*.md; do
    if [ -f "$cmd_file" ]; then
        # Check for frontmatter
        if ! grep -q "^---$" "$cmd_file"; then
            INVALID_COMMANDS=$((INVALID_COMMANDS + 1))
        fi

        # Check for allowed-tools
        if ! grep -q "allowed-tools:" "$cmd_file"; then
            INVALID_COMMANDS=$((INVALID_COMMANDS + 1))
        fi
    fi
done

if [ "$INVALID_COMMANDS" -eq 0 ]; then
    print_test "PASS" "All command files have valid format"
else
    print_test "FAIL" "$INVALID_COMMANDS command files have invalid format"
fi

echo ""

# ====================
# 4. Agent Definitions Validation
# ====================
echo "4. Agent Definitions Validation (4 agents)"
echo "----------------------------"

AGENT_DIR="$PROJECT_ROOT/.claude/agents"
EXPECTED_AGENTS=4
FOUND_AGENTS=0

if [ -d "$AGENT_DIR" ]; then
    FOUND_AGENTS=$(find "$AGENT_DIR" -name "*.md" | wc -l | tr -d ' ')

    if [ "$FOUND_AGENTS" -eq "$EXPECTED_AGENTS" ]; then
        print_test "PASS" "Found all $EXPECTED_AGENTS agent definitions"
    else
        print_test "FAIL" "Found $FOUND_AGENTS agents, expected $EXPECTED_AGENTS"
    fi
else
    print_test "FAIL" "Agent directory not found"
fi

# Check specific agents
AGENTS=("parallel-worker.md" "test-runner.md" "file-analyzer.md" "code-analyzer.md")
for agent in "${AGENTS[@]}"; do
    if [ -f "$AGENT_DIR/$agent" ]; then
        print_test "PASS" "Agent $agent exists"
    else
        print_test "FAIL" "Agent $agent not found"
    fi
done

echo ""

# ====================
# 5. Library Structure Validation
# ====================
echo "5. Library Structure (lib/) Validation"
echo "----------------------------"

# Check lib directory
if [ -d "$PROJECT_ROOT/lib" ]; then
    print_test "PASS" "lib/ directory exists"
else
    print_test "FAIL" "lib/ directory not found"
fi

# Check lib/python
if [ -d "$PROJECT_ROOT/lib/python" ]; then
    print_test "PASS" "lib/python/ directory exists"
else
    print_test "FAIL" "lib/python/ directory not found"
fi

# Check helpers.py
if [ -f "$PROJECT_ROOT/lib/python/helpers.py" ]; then
    print_test "PASS" "lib/python/helpers.py exists"
else
    print_test "FAIL" "lib/python/helpers.py not found"
fi

# Check router.py
if [ -f "$PROJECT_ROOT/lib/python/scripts/router.py" ]; then
    print_test "PASS" "lib/python/scripts/router.py exists"
else
    print_test "FAIL" "lib/python/scripts/router.py not found"
fi

# Check schema.sql
if [ -f "$PROJECT_ROOT/lib/sql/schema.sql" ]; then
    print_test "PASS" "lib/sql/schema.sql exists"
else
    print_test "FAIL" "lib/sql/schema.sql not found"
fi

# Check rule files
RULE_DIR="$PROJECT_ROOT/lib/docs/rules"
if [ -d "$RULE_DIR" ]; then
    RULE_COUNT=$(find "$RULE_DIR" -name "*.md" | wc -l | tr -d ' ')
    print_test "PASS" "Found $RULE_COUNT rule files in lib/docs/rules/"
else
    print_test "FAIL" "lib/docs/rules/ directory not found"
fi

echo ""

# ====================
# 6. Router Pattern Validation
# ====================
echo "6. Router Pattern Validation"
echo "----------------------------"

ROUTER_FILE="$PROJECT_ROOT/lib/python/scripts/router.py"
if [ -f "$ROUTER_FILE" ]; then
    # Check for dual-mode support
    if grep -q "PLUGIN_DIR" "$ROUTER_FILE"; then
        print_test "PASS" "Router has dual-mode support (PLUGIN_DIR)"
    else
        print_test "FAIL" "Router missing PLUGIN_DIR support"
    fi

    # Check for get_scripts_directory function
    if grep -q "def get_scripts_directory" "$ROUTER_FILE"; then
        print_test "PASS" "Router has get_scripts_directory() function"
    else
        print_test "FAIL" "Router missing get_scripts_directory() function"
    fi

    # Count commands in COMMAND_MAP
    ROUTER_COMMANDS=$(grep -c "'" "$ROUTER_FILE" | head -1 || echo "0")
    if [ "$ROUTER_COMMANDS" -gt 30 ]; then
        print_test "PASS" "Router has command mappings"
    else
        print_test "WARN" "Router may have incomplete command mappings"
    fi
else
    print_test "FAIL" "Router file not found"
fi

echo ""

# ====================
# 7. Documentation Validation
# ====================
echo "7. Documentation Validation"
echo "----------------------------"

# Check PLUGIN.md
if [ -f "$PROJECT_ROOT/docs/PLUGIN.md" ]; then
    LINE_COUNT=$(wc -l < "$PROJECT_ROOT/docs/PLUGIN.md")
    if [ "$LINE_COUNT" -gt 200 ]; then
        print_test "PASS" "docs/PLUGIN.md exists ($LINE_COUNT lines)"
    else
        print_test "WARN" "docs/PLUGIN.md is short ($LINE_COUNT lines)"
    fi
else
    print_test "FAIL" "docs/PLUGIN.md not found"
fi

# Check PLUGIN_README.md
if [ -f "$PROJECT_ROOT/docs/PLUGIN_README.md" ]; then
    print_test "PASS" "docs/PLUGIN_README.md exists"
else
    print_test "FAIL" "docs/PLUGIN_README.md not found"
fi

# Check LICENSE
if [ -f "$PROJECT_ROOT/LICENSE" ]; then
    print_test "PASS" "LICENSE file exists"
else
    print_test "FAIL" "LICENSE file not found"
fi

echo ""

# ====================
# 8. Simulated Installation Test
# ====================
echo "8. Simulated Installation Test"
echo "----------------------------"

# Create temporary test database
TEST_DB="/tmp/ccpm_test_install.db"
export CCPM_DB_PATH="$TEST_DB"

# Clean up any existing test DB
rm -f "$TEST_DB"

# Test database initialization
if [ -f "$PROJECT_ROOT/lib/sql/schema.sql" ]; then
    if sqlite3 "$TEST_DB" < "$PROJECT_ROOT/lib/sql/schema.sql" 2>/dev/null; then
        print_test "PASS" "Database schema initialized successfully"
    else
        print_test "FAIL" "Database schema initialization failed"
    fi
else
    print_test "FAIL" "Schema file not found"
fi

# Verify database structure
if [ -f "$TEST_DB" ]; then
    TABLES=$(sqlite3 "$TEST_DB" ".tables" 2>/dev/null | wc -w)
    if [ "$TABLES" -ge 4 ]; then
        print_test "PASS" "Database has $TABLES tables"
    else
        print_test "FAIL" "Database has insufficient tables ($TABLES)"
    fi
else
    print_test "FAIL" "Test database not created"
fi

# Test Python helpers import
export PLUGIN_DIR="$PROJECT_ROOT"
if python3 -c "import sys; sys.path.insert(0, '$PROJECT_ROOT/lib/python'); from helpers import get_db; db = get_db('$TEST_DB'); print('OK')" 2>&1 | grep -q "OK"; then
    print_test "PASS" "Python helpers import successful"
else
    print_test "FAIL" "Python helpers import failed"
fi

# Clean up test database
rm -f "$TEST_DB"

echo ""

# ====================
# 9. Command Router Test
# ====================
echo "9. Command Router Functionality Test"
echo "----------------------------"

# Test router with a simple command
export PLUGIN_DIR="$PROJECT_ROOT"
if python3 "$PROJECT_ROOT/lib/python/scripts/router.py" help 2>&1 | grep -qi "claude.*code.*pm\|CCPM\|/ccpm:"; then
    print_test "PASS" "Router executes help command"
else
    print_test "FAIL" "Router failed to execute help command"
fi

# Test router path resolution
if python3 -c "import sys; sys.path.insert(0, '$PROJECT_ROOT/lib/python/scripts'); from router import get_scripts_directory; print(get_scripts_directory())" 2>/dev/null | grep -q "/"; then
    print_test "PASS" "Router path resolution works"
else
    print_test "FAIL" "Router path resolution failed"
fi

echo ""

# ====================
# 10. Dependency Check
# ====================
echo "10. Python Dependencies Check"
echo "----------------------------"

# Check if PyGithub is available
if python3 -c "import github; print('OK')" 2>/dev/null | grep -q "OK"; then
    print_test "PASS" "PyGithub is installed"
else
    print_test "WARN" "PyGithub not installed (required for GitHub integration)"
fi

echo ""

# ====================
# Summary
# ====================
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo -e "${GREEN}Passed:${NC}   $TESTS_PASSED"
echo -e "${RED}Failed:${NC}   $TESTS_FAILED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo ""
echo "Total tests: $test_count"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All critical tests passed!${NC}"
    echo ""
    echo "The plugin is ready for installation."
    echo ""
    echo "To install locally:"
    echo "  /plugin install $PROJECT_ROOT"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the output above.${NC}"
    echo ""
    exit 1
fi
