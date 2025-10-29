#!/usr/bin/env bash
# Daily standup report - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

echo "📅 Daily Standup - $(date '+%Y-%m-%d')"
echo "==============================="
echo ""

# Get all in-progress tasks
in_progress_data=$("$QUERY_SCRIPT" "
    SELECT
        e.name as epic,
        t.task_number,
        t.name,
        t.estimated_hours
    FROM ccpm.tasks t
    JOIN ccpm.epics e ON t.epic_id = e.id
    WHERE t.status = 'in-progress'
      AND t.deleted_at IS NULL
    ORDER BY e.name, t.task_number
" "json")

# Get blocked tasks count
blocked_count=$("$QUERY_SCRIPT" "
    SELECT COUNT(*) FROM ccpm.blocked_tasks
" "csv" | tail -1)

# Get ready tasks
ready_data=$("$QUERY_SCRIPT" "
    SELECT
        e.name as epic,
        rt.task_number,
        rt.name,
        t.estimated_hours
    FROM ccpm.ready_tasks rt
    JOIN ccpm.epics e ON rt.epic_id = e.id
    JOIN ccpm.tasks t ON rt.id = t.id
    ORDER BY e.name, rt.task_number
    LIMIT 5
" "json")

# Get overall statistics
stats=$("$QUERY_SCRIPT" "
    SELECT
        COUNT(*) FILTER (WHERE status = 'open') as open_count,
        COUNT(*) FILTER (WHERE status = 'in-progress') as in_progress_count,
        COUNT(*) FILTER (WHERE status = 'closed') as closed_count,
        COUNT(*) as total_count
    FROM ccpm.tasks
    WHERE deleted_at IS NULL
" "json")

# Parse stats
open_count=$(echo "$stats" | jq -r '.[0].open_count // 0')
in_progress_count=$(echo "$stats" | jq -r '.[0].in_progress_count // 0')
closed_count=$(echo "$stats" | jq -r '.[0].closed_count // 0')
total_count=$(echo "$stats" | jq -r '.[0].total_count // 0')

# Display in-progress tasks
echo "🚀 Currently In Progress:"
echo "========================"
if [[ -z "$in_progress_data" ]] || [[ "$in_progress_data" == "[]" ]]; then
    echo "  No tasks in progress"
else
    current_epic=""
    echo "$in_progress_data" | jq -c '.[]' | while read -r task; do
        epic_name=$(echo "$task" | jq -r '.epic')
        task_number=$(echo "$task" | jq -r '.task_number')
        task_name=$(echo "$task" | jq -r '.name')
        estimated_hours=$(echo "$task" | jq -r '.estimated_hours // "?"')

        if [[ "$epic_name" != "$current_epic" ]]; then
            [[ -n "$current_epic" ]] && echo ""
            echo "  Epic: $epic_name"
            current_epic="$epic_name"
        fi

        echo "    • #${task_number} - ${task_name} (${estimated_hours}h est.)"
    done
fi

echo ""
echo "⏸️  Blocked Tasks:"
echo "================="
if [[ "$blocked_count" -eq 0 ]]; then
    echo "  None - great!"
else
    echo "  ⚠️  $blocked_count task(s) blocked"
    echo "  Run: pm blocked for details"
fi

echo ""
echo "✨ Ready to Start:"
echo "================="
if [[ -z "$ready_data" ]] || [[ "$ready_data" == "[]" ]]; then
    echo "  No tasks ready (all have unmet dependencies)"
else
    ready_count=$(echo "$ready_data" | jq 'length')
    current_epic=""
    echo "$ready_data" | jq -c '.[]' | while read -r task; do
        epic_name=$(echo "$task" | jq -r '.epic')
        task_number=$(echo "$task" | jq -r '.task_number')
        task_name=$(echo "$task" | jq -r '.name')
        estimated_hours=$(echo "$task" | jq -r '.estimated_hours // "?"')

        if [[ "$epic_name" != "$current_epic" ]]; then
            [[ -n "$current_epic" ]] && echo ""
            echo "  Epic: $epic_name"
            current_epic="$epic_name"
        fi

        echo "    • #${task_number} - ${task_name} (${estimated_hours}h est.)"
    done
fi

echo ""
echo "📊 Overall Progress:"
echo "==================="
echo "  Open: $open_count tasks"
echo "  In Progress: $in_progress_count tasks"
echo "  Closed: $closed_count tasks"
echo "  Total: $total_count tasks"

if [[ $total_count -gt 0 ]]; then
    completion=$((closed_count * 100 / total_count))
    echo "  Completion: ${completion}%"
fi

# Show active epics
echo ""
echo "📚 Active Epics:"
echo "==============="
active_epics=$("$QUERY_SCRIPT" "
    SELECT
        e.name,
        e.status,
        e.progress
    FROM ccpm.epics e
    WHERE e.status IN ('active', 'in-progress')
      AND e.deleted_at IS NULL
    ORDER BY e.created_at DESC
" "json")

if [[ -z "$active_epics" ]] || [[ "$active_epics" == "[]" ]]; then
    echo "  No active epics"
else
    echo "$active_epics" | jq -c '.[]' | while read -r epic; do
        epic_name=$(echo "$epic" | jq -r '.name')
        epic_status=$(echo "$epic" | jq -r '.status')
        epic_progress=$(echo "$epic" | jq -r '.progress // 0')

        echo "  • $epic_name (${epic_status}) - ${epic_progress}% complete"
    done
fi

echo ""
echo "💡 Suggested Actions:"
echo "===================="
if [[ $in_progress_count -eq 0 ]] && [[ ! -z "$ready_data" ]] && [[ "$ready_data" != "[]" ]]; then
    echo "  • Start working on ready tasks: pm next"
elif [[ $in_progress_count -gt 0 ]]; then
    echo "  • Continue in-progress tasks: pm in-progress"
fi

if [[ $blocked_count -gt 0 ]]; then
    echo "  • Review blocked tasks: pm blocked"
fi

echo "  • View epic details: pm epic-show <epic-name>"
echo "  • Update task status: pm task-start/task-close"

exit 0
