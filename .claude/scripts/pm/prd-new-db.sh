#!/usr/bin/env bash
# Create a new PRD - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Get PRD name from argument
prd_name="${1:-}"

if [[ -z "$prd_name" ]]; then
    echo "❌ Usage: pm prd-new <prd-name>"
    echo ""
    echo "Example: pm prd-new user-auth"
    exit 1
fi

# Check if PRD already exists
existing=$(get_prd "$prd_name" "json")
if [[ -n "$existing" ]] && [[ "$existing" != "[]" ]]; then
    echo "❌ PRD already exists: $prd_name"
    exit 1
fi

echo "📋 Creating new PRD: $prd_name"
echo ""

# Get description
echo "Enter brief description:"
read -r description

echo ""
echo "Enter detailed content (press Ctrl+D when done):"
content=$(cat)

# Create PRD
prd_id=$(create_prd "$prd_name" "$description" "backlog" "$content")

if [[ -z "$prd_id" ]]; then
    echo "❌ Failed to create PRD"
    exit 1
fi

echo ""
echo "✅ Created PRD: $prd_name (ID: $prd_id)"
echo "   Status: backlog"
echo ""
echo "💡 Next steps:"
echo "  • Create epics: pm epic-new $prd_name <epic-name>"
echo "  • View PRD: pm prd-status $prd_name"
echo "  • Sync to GitHub: pm sync push prd --prd $prd_name"

exit 0
