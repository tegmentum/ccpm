#!/usr/bin/env bash
# Start a task - Database version
# Updates task status from 'open' to 'in-progress'

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
    echo "❌ Usage: pm task-start <epic-name> <task-number>"
    echo ""
    echo "Example: pm task-start user-auth-backend 3"
    exit 1
fi

# Get epic ID
epic_data=$(get_epic "$epic_name" "json")

if [[ -z "$epic_data" ]] || [[ "$epic_data" == "[]" ]]; then
    echo "❌ Epic not found: $epic_name"
    exit 1
fi

epic_id=$(echo "$epic_data" | jq -r '.[0].id')

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
if [[ "$current_status" == "in-progress" ]]; then
    echo "ℹ️  Task #$task_number is already in progress"
    echo "   $task_name"
    exit 0
fi

if [[ "$current_status" == "closed" ]]; then
    echo "❌ Task #$task_number is already closed"
    echo "   $task_name"
    echo ""
    echo "💡 To reopen, update status manually with: pm task-update"
    exit 1
fi

# Check if task is blocked (has unmet dependencies)
is_blocked=$("$QUERY_SCRIPT" "
    SELECT COUNT(*) > 0 as blocked
    FROM ccpm.tasks t
    WHERE t.id = $task_id
      AND EXISTS (
        SELECT 1 FROM ccpm.task_dependencies td
        JOIN ccpm.tasks dep ON td.depends_on_task_id = dep.id
        WHERE td.task_id = t.id
          AND dep.status != 'closed'
      )
" "csv" | tail -1)

if [[ "$is_blocked" == "1" ]] || [[ "$is_blocked" == "true" ]]; then
    echo "⚠️  Warning: Task #$task_number has unmet dependencies"
    echo "   $task_name"
    echo ""
    echo "📋 Blocking tasks:"

    "$QUERY_SCRIPT" "
        SELECT dep.task_number, dep.name, dep.status
        FROM ccpm.task_dependencies td
        JOIN ccpm.tasks dep ON td.depends_on_task_id = dep.id
        WHERE td.task_id = $task_id
          AND dep.status != 'closed'
    " "json" | jq -c '.[]' | while read -r dep; do
        dep_num=$(echo "$dep" | jq -r '.task_number')
        dep_name=$(echo "$dep" | jq -r '.name')
        dep_status=$(echo "$dep" | jq -r '.status')
        echo "   • #$dep_num - $dep_name ($dep_status)"
    done

    echo ""
    read -p "Start anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi
fi

# Update status to in-progress
update_task_status "$task_id" "in-progress"

echo "✅ Started task #$task_number"
echo "   Epic: $epic_name"
echo "   Task: $task_name"
echo ""
echo "💡 Next steps:"
echo "   • View task details: pm task-show $epic_name $task_number"
echo "   • Mark complete: pm task-close $epic_name $task_number"
echo "   • View all in-progress: pm in-progress"

exit 0
