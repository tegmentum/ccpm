#!/usr/bin/env bash
# Show task details - Database version

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
    echo "❌ Usage: pm task-show <epic-name> <task-number>"
    echo ""
    echo "Example: pm task-show user-auth-backend 3"
    exit 1
fi

# Get epic ID
epic_data=$(get_epic "$epic_name" "json")

if [[ -z "$epic_data" ]] || [[ "$epic_data" == "[]" ]]; then
    echo "❌ Epic not found: $epic_name"
    exit 1
fi

epic_id=$(echo "$epic_data" | jq -r '.[0].id')

# Get task details
task_data=$("$QUERY_SCRIPT" "
    SELECT
        t.id,
        t.name,
        t.status,
        t.content,
        t.estimated_hours,
        t.parallel,
        t.github_issue_number,
        t.created_at,
        t.updated_at
    FROM ccpm.tasks t
    WHERE t.epic_id = $epic_id
      AND t.task_number = $task_number
      AND t.deleted_at IS NULL
" "json")

if [[ -z "$task_data" ]] || [[ "$task_data" == "[]" ]]; then
    echo "❌ Task #$task_number not found in epic: $epic_name"
    exit 1
fi

# Parse task details
task_id=$(echo "$task_data" | jq -r '.[0].id')
task_name=$(echo "$task_data" | jq -r '.[0].name')
task_status=$(echo "$task_data" | jq -r '.[0].status')
task_content=$(echo "$task_data" | jq -r '.[0].content // ""')
estimated_hours=$(echo "$task_data" | jq -r '.[0].estimated_hours // ""')
is_parallel=$(echo "$task_data" | jq -r '.[0].parallel')
github_issue=$(echo "$task_data" | jq -r '.[0].github_issue_number // ""')
created_at=$(echo "$task_data" | jq -r '.[0].created_at')
updated_at=$(echo "$task_data" | jq -r '.[0].updated_at')

# Status icon
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

# Display task header
echo "$icon Task #$task_number: $task_name"
echo "================================"
echo ""

echo "📊 Metadata:"
echo "  Epic: $epic_name"
echo "  Status: $task_status"
[[ -n "$estimated_hours" ]] && echo "  Estimated: ${estimated_hours}h"
[[ "$is_parallel" == "1" ]] && echo "  Parallel: yes (can run with other tasks)"
[[ -n "$github_issue" ]] && echo "  GitHub: #${github_issue}"
echo "  Created: $created_at"
echo "  Updated: $updated_at"
echo ""

# Show content if available
if [[ -n "$task_content" ]]; then
    echo "📝 Description:"
    echo "$task_content" | sed 's/^/  /'
    echo ""
fi

# Get dependencies
dependencies=$("$QUERY_SCRIPT" "
    SELECT
        dep.task_number,
        dep.name,
        dep.status
    FROM ccpm.task_dependencies td
    JOIN ccpm.tasks dep ON td.depends_on_task_id = dep.id
    WHERE td.task_id = $task_id
    ORDER BY dep.task_number
" "json")

if [[ -n "$dependencies" ]] && [[ "$dependencies" != "[]" ]]; then
    echo "🔗 Dependencies:"
    dep_count=$(echo "$dependencies" | jq 'length')
    unmet_count=$(echo "$dependencies" | jq '[.[] | select(.status != "closed")] | length')

    echo "$dependencies" | jq -c '.[]' | while read -r dep; do
        dep_num=$(echo "$dep" | jq -r '.task_number')
        dep_name=$(echo "$dep" | jq -r '.name')
        dep_status=$(echo "$dep" | jq -r '.status')

        if [[ "$dep_status" == "closed" ]]; then
            echo "  ✅ #$dep_num - $dep_name"
        else
            echo "  ⏸️  #$dep_num - $dep_name ($dep_status)"
        fi
    done

    if [[ $unmet_count -gt 0 ]]; then
        echo ""
        echo "  ⚠️  $unmet_count unmet dependencies - task is blocked"
    fi
    echo ""
fi

# Get tasks that depend on this one
dependents=$("$QUERY_SCRIPT" "
    SELECT
        t.task_number,
        t.name,
        t.status
    FROM ccpm.task_dependencies td
    JOIN ccpm.tasks t ON td.task_id = t.id
    WHERE td.depends_on_task_id = $task_id
    ORDER BY t.task_number
" "json")

if [[ -n "$dependents" ]] && [[ "$dependents" != "[]" ]]; then
    echo "🔀 Blocks These Tasks:"
    echo "$dependents" | jq -c '.[]' | while read -r dep; do
        dep_num=$(echo "$dep" | jq -r '.task_number')
        dep_name=$(echo "$dep" | jq -r '.name')
        dep_status=$(echo "$dep" | jq -r '.status')
        echo "  • #$dep_num - $dep_name ($dep_status)"
    done
    echo ""
fi

# Suggested actions
echo "💡 Actions:"
case "$task_status" in
    "open")
        if [[ $unmet_count -eq 0 ]]; then
            echo "  • Start this task: pm task-start $epic_name $task_number"
        else
            echo "  • Cannot start - has unmet dependencies"
            echo "  • View blocked tasks: pm blocked"
        fi
        ;;
    "in-progress")
        echo "  • Mark complete: pm task-close $epic_name $task_number"
        echo "  • View all in-progress: pm in-progress"
        ;;
    "closed")
        echo "  • Task is complete"
        [[ -n "$dependents" ]] && echo "  • Check unblocked tasks: pm next"
        ;;
esac

echo "  • View epic: pm epic-show $epic_name"
[[ -n "$github_issue" ]] && echo "  • View on GitHub: gh issue view $github_issue"

exit 0
