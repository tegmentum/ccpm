#!/usr/bin/env bash
# Create a new epic - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Get PRD name and epic name from arguments
prd_name="${1:-}"
epic_name="${2:-}"

if [[ -z "$prd_name" ]] || [[ -z "$epic_name" ]]; then
    echo "❌ Usage: pm epic-new <prd-name> <epic-name>"
    echo ""
    echo "Example: pm epic-new user-auth user-auth-frontend"
    echo ""
    echo "Available PRDs:"
    "$QUERY_SCRIPT" "
        SELECT name FROM ccpm.prds
        WHERE deleted_at IS NULL
        ORDER BY created_at DESC
    " "csv" | tail -n +2 | while read -r name; do
        echo "  • $name"
    done
    exit 1
fi

# Get PRD ID
prd_data=$(get_prd "$prd_name" "json")

if [[ -z "$prd_data" ]] || [[ "$prd_data" == "[]" ]]; then
    echo "❌ PRD not found: $prd_name"
    exit 1
fi

prd_id=$(echo "$prd_data" | jq -r '.[0].id')

# Check if epic already exists
existing=$(get_epic "$epic_name" "json")
if [[ -n "$existing" ]] && [[ "$existing" != "[]" ]]; then
    echo "❌ Epic already exists: $epic_name"
    exit 1
fi

# Get epic description
echo "📋 Creating new epic: $epic_name"
echo "PRD: $prd_name"
echo ""
echo "Enter epic description (press Ctrl+D when done):"
content=$(cat)

# Create epic
epic_id=$(create_epic "$prd_id" "$epic_name" "$content" "backlog")

if [[ -z "$epic_id" ]]; then
    echo "❌ Failed to create epic"
    exit 1
fi

echo ""
echo "✅ Created epic: $epic_name (ID: $epic_id)"
echo "   PRD: $prd_name"
echo "   Status: backlog"
echo ""
echo "💡 Next steps:"
echo "  • Decompose into tasks: pm epic-decompose $epic_name"
echo "  • View epic details: pm epic-show $epic_name"
echo "  • Sync to GitHub: pm sync push epic --epic $epic_name"

exit 0
