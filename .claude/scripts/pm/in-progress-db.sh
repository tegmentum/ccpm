#!/usr/bin/env bash
# Show in-progress tasks - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

echo "🚀 In Progress Tasks"
echo "===================="
echo ""

# Get in-progress tasks directly
in_progress_data=$("$PROJECT_ROOT/db/query.sh" "
    SELECT
        e.name as epic,
        t.task_number,
        t.name
    FROM ccpm.tasks t
    JOIN ccpm.epics e ON t.epic_id = e.id
    WHERE t.status = 'in-progress'
      AND t.deleted_at IS NULL
    ORDER BY e.name, t.task_number
" "json")

if [[ -z "$in_progress_data" ]] || [[ "$in_progress_data" == "[]" ]]; then
    echo "No tasks currently in progress!"
    echo ""
    echo "💡 Use 'pm next' to see what's available to start."
    exit 0
fi

# Count total
count=$(echo "$in_progress_data" | jq 'length')

# Group by epic
current_epic=""
echo "$in_progress_data" | jq -c '.[]' | while read -r task; do
    epic_name=$(echo "$task" | jq -r '.epic')
    task_number=$(echo "$task" | jq -r '.task_number')
    task_name=$(echo "$task" | jq -r '.name')

    # Print epic header if changed
    if [[ "$epic_name" != "$current_epic" ]]; then
        [[ -n "$current_epic" ]] && echo ""
        echo "Epic: $epic_name"
        current_epic="$epic_name"
    fi

    echo "  ⚙️  #${task_number} - ${task_name}"
done

echo ""
echo "📊 Total in progress: $count tasks"

exit 0
