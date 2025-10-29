#!/usr/bin/env bash
# Close an epic - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Get epic name from argument
epic_name="${1:-}"

if [[ -z "$epic_name" ]]; then
    echo "❌ Usage: pm epic-close <epic-name>"
    echo ""
    echo "Example: pm epic-close user-auth-backend"
    exit 1
fi

# Get epic details
epic_data=$(get_epic "$epic_name" "json")

if [[ -z "$epic_data" ]] || [[ "$epic_data" == "[]" ]]; then
    echo "❌ Epic not found: $epic_name"
    exit 1
fi

epic_id=$(echo "$epic_data" | jq -r '.[0].id')
current_status=$(echo "$epic_data" | jq -r '.[0].status')

# Check if already closed
if [[ "$current_status" == "closed" ]]; then
    echo "ℹ️  Epic is already closed: $epic_name"
    exit 0
fi

# Get task statistics
task_stats=$("$QUERY_SCRIPT" "
    SELECT
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status = 'closed') as closed,
        COUNT(*) FILTER (WHERE status != 'closed') as open
    FROM ccpm.tasks
    WHERE epic_id = $epic_id
      AND deleted_at IS NULL
" "json")

total_tasks=$(echo "$task_stats" | jq -r '.[0].total // 0')
closed_tasks=$(echo "$task_stats" | jq -r '.[0].closed // 0')
open_tasks=$(echo "$task_stats" | jq -r '.[0].open // 0')

# Warn if not all tasks are closed
if [[ $open_tasks -gt 0 ]]; then
    echo "⚠️  Warning: Epic has $open_tasks open task(s)"
    echo ""
    
    # Show open tasks
    "$QUERY_SCRIPT" "
        SELECT task_number, name, status
        FROM ccpm.tasks
        WHERE epic_id = $epic_id
          AND status != 'closed'
          AND deleted_at IS NULL
        ORDER BY task_number
    " "json" | jq -c '.[]' | while read -r task; do
        task_num=$(echo "$task" | jq -r '.task_number')
        task_name=$(echo "$task" | jq -r '.name')
        task_status=$(echo "$task" | jq -r '.status')
        echo "  • #$task_num - $task_name ($task_status)"
    done
    
    echo ""
    read -p "Close epic anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi
fi

# Update epic status
update_epic "$epic_id" "status" "closed"

echo "✅ Closed epic: $epic_name"
echo "   Tasks: $closed_tasks/$total_tasks completed"
echo ""
echo "💡 Next steps:"
echo "  • View PRD status: pm prd-status"
echo "  • View standup: pm standup"

exit 0
