#!/usr/bin/env bash
# Show epic details - Database version

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
    echo "❌ Please provide an epic name"
    echo "Usage: pm epic-show <epic-name>"
    echo ""
    echo "Available epics:"
    "$QUERY_SCRIPT" "
        SELECT name FROM ccpm.epics
        WHERE deleted_at IS NULL
        ORDER BY created_at DESC
    " "csv" | tail -n +2 | while read -r name; do
        echo "  • $name"
    done
    exit 1
fi

# Get epic details
epic_data=$(get_epic "$epic_name" "json")

if [[ -z "$epic_data" ]] || [[ "$epic_data" == "[]" ]]; then
    echo "❌ Epic not found: $epic_name"
    echo ""
    echo "Available epics:"
    "$QUERY_SCRIPT" "
        SELECT name FROM ccpm.epics
        WHERE deleted_at IS NULL
        ORDER BY created_at DESC
    " "csv" | tail -n +2 | while read -r name; do
        echo "  • $name"
    done
    exit 1
fi

# Parse epic details
epic_id=$(echo "$epic_data" | jq -r '.[0].id')
epic_status=$(echo "$epic_data" | jq -r '.[0].status')
epic_progress=$(echo "$epic_data" | jq -r '.[0].progress // 0')
github_issue=$(echo "$epic_data" | jq -r '.[0].github_issue_number // empty')
created_at=$(echo "$epic_data" | jq -r '.[0].created_at')
prd_id=$(echo "$epic_data" | jq -r '.[0].prd_id')

# Get PRD name
prd_name=$("$QUERY_SCRIPT" "
    SELECT name FROM ccpm.prds WHERE id = $prd_id
" "csv" | tail -1)

# Display epic details
echo "📚 Epic: $epic_name"
echo "================================"
echo ""

echo "📊 Metadata:"
echo "  PRD: ${prd_name}"
echo "  Status: ${epic_status}"
echo "  Progress: ${epic_progress}%"
[[ -n "$github_issue" ]] && echo "  GitHub: #${github_issue}"
echo "  Created: ${created_at}"
echo ""

# Get tasks for this epic
tasks_data=$("$QUERY_SCRIPT" "
    SELECT
        task_number,
        name,
        status,
        parallel,
        github_issue_number
    FROM ccpm.tasks
    WHERE epic_id = $epic_id
      AND deleted_at IS NULL
    ORDER BY task_number
" "json")

# Count tasks
if [[ -z "$tasks_data" ]] || [[ "$tasks_data" == "[]" ]]; then
    task_count=0
    open_count=0
    closed_count=0
    in_progress_count=0
else
    task_count=$(echo "$tasks_data" | jq 'length')
    open_count=$(echo "$tasks_data" | jq '[.[] | select(.status == "open")] | length')
    closed_count=$(echo "$tasks_data" | jq '[.[] | select(.status == "closed")] | length')
    in_progress_count=$(echo "$tasks_data" | jq '[.[] | select(.status == "in-progress")] | length')
fi

# Display tasks
echo "📝 Tasks:"
if [[ $task_count -eq 0 ]]; then
    echo "  No tasks created yet"
    echo "  Run: pm epic-decompose $epic_name"
else
    echo "$tasks_data" | jq -c '.[]' | while read -r task; do
        task_num=$(echo "$task" | jq -r '.task_number')
        task_name=$(echo "$task" | jq -r '.name')
        task_status=$(echo "$task" | jq -r '.status')
        task_parallel=$(echo "$task" | jq -r '.parallel')
        task_github=$(echo "$task" | jq -r '.github_issue_number // empty')

        # Choose icon based on status
        case "$task_status" in
            "closed")
                icon="✅"
                ;;
            "in-progress")
                icon="🚀"
                ;;
            "blocked")
                icon="⏸️"
                ;;
            *)
                icon="⬜"
                ;;
        esac

        # Build task line
        task_line="  $icon #$task_num - $task_name"
        [[ "$task_parallel" == "1" ]] && task_line+=" (parallel)"
        [[ -n "$task_github" ]] && task_line+=" [GH #$task_github]"

        echo "$task_line"
    done
fi

# Show statistics
echo ""
echo "📈 Statistics:"
echo "  Total tasks: $task_count"
echo "  Open: $open_count"
echo "  In Progress: $in_progress_count"
echo "  Closed: $closed_count"
[[ $task_count -gt 0 ]] && echo "  Completion: ${epic_progress}%"

# Show dependencies if any
if [[ $task_count -gt 0 ]]; then
    # Check for blocked tasks
    blocked_count=$("$QUERY_SCRIPT" "
        SELECT COUNT(*) FROM ccpm.blocked_tasks
        WHERE epic_id = $epic_id
    " "csv" | tail -1)

    if [[ "$blocked_count" -gt 0 ]]; then
        echo ""
        echo "⚠️  Blocked Tasks: $blocked_count"
        echo "   Run: pm blocked to see details"
    fi

    # Check for ready tasks
    ready_count=$("$QUERY_SCRIPT" "
        SELECT COUNT(*) FROM ccpm.ready_tasks
        WHERE epic_id = $epic_id
    " "csv" | tail -1)

    if [[ "$ready_count" -gt 0 ]]; then
        echo ""
        echo "✨ Ready to Start: $ready_count tasks"
        echo "   Run: pm next to see details"
    fi
fi

# Next actions
echo ""
echo "💡 Actions:"
if [[ $task_count -eq 0 ]]; then
    echo "  • Decompose into tasks: pm epic-decompose $epic_name"
elif [[ -z "$github_issue" ]]; then
    echo "  • Sync to GitHub: pm sync push epic --epic $epic_name"
else
    [[ $ready_count -gt 0 ]] && echo "  • Start ready tasks: pm next"
    [[ $in_progress_count -gt 0 ]] && echo "  • View in-progress: pm in-progress"
    [[ "$epic_status" != "closed" ]] && echo "  • Start epic work: pm epic-start $epic_name"
fi

exit 0
