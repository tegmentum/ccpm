#!/usr/bin/env bash
# Show blocked tasks - Database version
# Tasks that are open but have unmet dependencies

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

echo "🚫 Blocked Tasks"
echo "================"
echo ""

# Get blocked tasks from the view
blocked_data=$(get_blocked_tasks "json")

if [[ -z "$blocked_data" ]] || [[ "$blocked_data" == "[]" ]]; then
    echo "No blocked tasks found!"
    echo ""
    echo "💡 All tasks with dependencies are either completed or in progress."
    exit 0
fi

# Count total
count=$(echo "$blocked_data" | jq 'length')

# Display each blocked task
echo "$blocked_data" | jq -c '.[]' | while read -r task; do
    task_id=$(echo "$task" | jq -r '.id')
    task_number=$(echo "$task" | jq -r '.task_number')
    task_name=$(echo "$task" | jq -r '.name')
    epic_name=$(echo "$task" | jq -r '.epic')
    blocking_tasks=$(echo "$task" | jq -r '.blocking_tasks // empty')

    echo "⏸️  Task #${task_number} - ${task_name}"
    echo "   Epic: ${epic_name}"

    # Parse blocking tasks (format: "2:open,3:in-progress")
    if [[ -n "$blocking_tasks" ]] && [[ "$blocking_tasks" != "null" ]]; then
        echo "   Waiting for:"

        IFS=',' read -ra blocking_array <<< "$blocking_tasks"
        for blocking in "${blocking_array[@]}"; do
            if [[ "$blocking" =~ ^([0-9]+):(.+)$ ]]; then
                dep_num="${BASH_REMATCH[1]}"
                dep_status="${BASH_REMATCH[2]}"

                # Get task name
                dep_name=$("$PROJECT_ROOT/db/query.sh" "
                    SELECT name FROM ccpm.tasks
                    WHERE task_number = ${dep_num} AND epic_id = (
                        SELECT epic_id FROM ccpm.tasks WHERE id = ${task_id}
                    )
                " "csv" | tail -1)

                echo "      #${dep_num} ${dep_name} (${dep_status})"
            fi
        done
    fi

    echo ""
done

echo "📊 Total blocked: $count tasks"

exit 0
