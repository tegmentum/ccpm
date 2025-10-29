#!/usr/bin/env bash
# Show next available tasks (ready to start) - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

echo "✨ Ready to Start"
echo "================="
echo ""

# Get ready tasks from the view
ready_data=$("$QUERY_SCRIPT" "
    SELECT
        e.name as epic,
        rt.task_number,
        rt.name,
        t.estimated_hours,
        rt.parallel
    FROM ccpm.ready_tasks rt
    JOIN ccpm.epics e ON rt.epic_id = e.id
    JOIN ccpm.tasks t ON rt.id = t.id
    ORDER BY e.name, rt.task_number
" "json")

if [[ -z "$ready_data" ]] || [[ "$ready_data" == "[]" ]]; then
    echo "No tasks ready to start!"
    echo ""

    # Check if there are any open tasks at all
    open_count=$("$QUERY_SCRIPT" "
        SELECT COUNT(*) FROM ccpm.tasks
        WHERE status = 'open' AND deleted_at IS NULL
    " "csv" | tail -1)

    if [[ "$open_count" -gt 0 ]]; then
        echo "📋 All open tasks have unmet dependencies."
        echo ""
        echo "💡 Actions:"
        echo "  • View blocked tasks: pm blocked"
        echo "  • View in-progress: pm in-progress"
        echo "  • Complete in-progress tasks to unblock others"
    else
        echo "🎉 No open tasks - all work is either in-progress or complete!"
        echo ""
        echo "💡 Actions:"
        echo "  • View in-progress: pm in-progress"
        echo "  • View overall status: pm standup"
        echo "  • Create new tasks: pm epic-decompose <epic-name>"
    fi

    exit 0
fi

# Count total ready tasks
ready_count=$(echo "$ready_data" | jq 'length')

# Display ready tasks grouped by epic
current_epic=""

while IFS= read -r task; do
    epic_name=$(echo "$task" | jq -r '.epic')
    task_number=$(echo "$task" | jq -r '.task_number')
    task_name=$(echo "$task" | jq -r '.name')
    estimated_hours=$(echo "$task" | jq -r '.estimated_hours // "?"')
    is_parallel=$(echo "$task" | jq -r '.parallel')

    # Print epic header if changed
    if [[ "$epic_name" != "$current_epic" ]]; then
        [[ -n "$current_epic" ]] && echo ""
        echo "Epic: $epic_name"
        current_epic="$epic_name"
    fi

    # Parallel indicator
    parallel_flag=""
    [[ "$is_parallel" == "1" ]] && parallel_flag=" (parallel)"

    echo "  • #${task_number} - ${task_name} (${estimated_hours}h)${parallel_flag}"
done < <(echo "$ready_data" | jq -c '.[]')

echo ""
echo "📊 Summary:"
echo "  $ready_count task(s) ready to start"

# Calculate total estimated hours
total_hours=$("$QUERY_SCRIPT" "
    SELECT COALESCE(SUM(t.estimated_hours), 0) as total
    FROM ccpm.ready_tasks rt
    JOIN ccpm.tasks t ON rt.id = t.id
" "csv" | tail -1)

if [[ -n "$total_hours" ]] && [[ "$total_hours" != "0" ]]; then
    echo "  Estimated: ${total_hours}h total"
fi

echo ""
echo "💡 Actions:"
echo "  • Start a task: pm task-start <epic-name> <task-number>"
echo "  • View task details: pm task-show <epic-name> <task-number>"
echo "  • View epic details: pm epic-show <epic-name>"

exit 0
