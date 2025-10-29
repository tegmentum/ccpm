#!/usr/bin/env bash
# Close a task - Database version
# Updates task status to 'closed'

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Get epic and task number from arguments
epic_name="${1:-}"
task_number="${2:-}"

if [[ -z "$epic_name" ]] || [[ -z "$task_number" ]]; then
    echo "❌ Usage: pm task-close <epic-name> <task-number>"
    echo ""
    echo "Example: pm task-close user-auth-backend 2"
    exit 1
fi

# Get epic ID
epic_data=$(get_epic "$epic_name" "json")

if [[ -z "$epic_data" ]] || [[ "$epic_data" == "[]" ]]; then
    echo "❌ Epic not found: $epic_name"
    exit 1
fi

epic_id=$(echo "$epic_data" | jq -r '.[0].id')
epic_status=$(echo "$epic_data" | jq -r '.[0].status')

# Get task by epic_id and task_number
task_data=$("$QUERY_SCRIPT" "
    SELECT id, name, status
    FROM ccpm.tasks
    WHERE epic_id = $epic_id
      AND task_number = $task_number
      AND deleted_at IS NULL
" "json")

if [[ -z "$task_data" ]] || [[ "$task_data" == "[]" ]]; then
    echo "❌ Task #$task_number not found in epic: $epic_name"
    exit 1
fi

task_id=$(echo "$task_data" | jq -r '.[0].id')
task_name=$(echo "$task_data" | jq -r '.[0].name')
current_status=$(echo "$task_data" | jq -r '.[0].status')

# Check current status
if [[ "$current_status" == "closed" ]]; then
    echo "ℹ️  Task #$task_number is already closed"
    echo "   $task_name"
    exit 0
fi

# Update status to closed
update_task_status "$task_id" "closed"

# Get updated epic progress
epic_progress=$("$QUERY_SCRIPT" "
    SELECT calculated_progress FROM ccpm.epic_progress
    WHERE id = $epic_id
" "csv" | tail -1)

echo "✅ Closed task #$task_number"
echo "   Epic: $epic_name"
echo "   Task: $task_name"
echo ""
echo "📊 Epic progress: ${epic_progress}%"

# Check if this unblocked any tasks
newly_ready=$("$QUERY_SCRIPT" "
    SELECT
        t.task_number,
        t.name
    FROM ccpm.tasks t
    WHERE t.epic_id = $epic_id
      AND t.status = 'open'
      AND t.deleted_at IS NULL
      AND t.id IN (
        SELECT td.task_id
        FROM ccpm.task_dependencies td
        WHERE td.depends_on_task_id = $task_id
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ccpm.task_dependencies td2
        JOIN ccpm.tasks dep ON td2.depends_on_task_id = dep.id
        WHERE td2.task_id = t.id
          AND dep.status != 'closed'
          AND dep.id != $task_id
      )
" "json")

if [[ -n "$newly_ready" ]] && [[ "$newly_ready" != "[]" ]]; then
    ready_count=$(echo "$newly_ready" | jq 'length')
    echo ""
    echo "✨ Unblocked $ready_count task(s):"
    echo "$newly_ready" | jq -c '.[]' | while read -r task; do
        task_num=$(echo "$task" | jq -r '.task_number')
        task_name=$(echo "$task" | jq -r '.name')
        echo "   • #$task_num - $task_name"
    done
fi

# Check if epic is now complete
all_closed=$("$QUERY_SCRIPT" "
    SELECT COUNT(*) = 0 as all_done
    FROM ccpm.tasks
    WHERE epic_id = $epic_id
      AND status != 'closed'
      AND deleted_at IS NULL
" "csv" | tail -1)

if [[ "$all_closed" == "1" ]] || [[ "$all_closed" == "true" ]]; then
    echo ""
    echo "🎉 All tasks complete!"
    if [[ "$epic_status" != "closed" ]]; then
        echo "   Consider closing the epic: pm epic-close $epic_name"
    fi
fi

echo ""
echo "💡 Next steps:"
echo "   • View ready tasks: pm next"
echo "   • View epic status: pm epic-show $epic_name"
echo "   • Daily standup: pm standup"

exit 0
