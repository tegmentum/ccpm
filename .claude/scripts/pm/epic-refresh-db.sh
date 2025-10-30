#!/usr/bin/env bash
# Refresh epic progress from task status - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_DIR")/../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Get epic name
epic_name="${1:-}"

if [[ -z "$epic_name" ]]; then
    echo "Usage: pm epic-refresh <epic-name>"
    exit 1
fi

echo "= Refreshing Epic: $epic_name"
echo ""
echo ""

# Get epic data
epic_data=$(get_epic "$epic_name" "json")

if [[ -z "$epic_data" ]] || [[ "$epic_data" == "[]" ]]; then
    echo "L Epic not found: $epic_name"
    exit 1
fi

epic_id=$(echo "$epic_data" | jq -r '.[0].id')
old_status=$(echo "$epic_data" | jq -r '.[0].status')
old_progress=$(echo "$epic_data" | jq -r '.[0].progress // 0')
epic_gh_issue=$(echo "$epic_data" | jq -r '.[0].github_issue_number // "null"')

# Count task statuses
task_counts=$("$QUERY_SCRIPT" "
    SELECT
        COUNT(*) as total,
        SUM(CASE WHEN status = 'closed' THEN 1 ELSE 0 END) as closed,
        SUM(CASE WHEN status = 'open' THEN 1 ELSE 0 END) as open,
        SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress
    FROM ccpm.tasks
    WHERE epic_id = $epic_id
        AND deleted_at IS NULL
" "json")

total_tasks=$(echo "$task_counts" | jq -r '.[0].total // 0')
closed_tasks=$(echo "$task_counts" | jq -r '.[0].closed // 0')
open_tasks=$(echo "$task_counts" | jq -r '.[0].open // 0')
in_progress_tasks=$(echo "$task_counts" | jq -r '.[0].in_progress // 0')

echo "Task Status:"
echo "  Closed: $closed_tasks"
echo "  In Progress: $in_progress_tasks"
echo "  Open: $open_tasks"
echo "  Total: $total_tasks"
echo ""

# Calculate progress
if [[ "$total_tasks" -eq 0 ]]; then
    new_progress=0
else
    new_progress=$(echo "scale=0; ($closed_tasks * 100) / $total_tasks" | bc)
fi

# Determine new status
if [[ "$new_progress" -eq 100 ]]; then
    new_status="closed"
elif [[ "$new_progress" -gt 0 ]]; then
    new_status="active"
else
    new_status="backlog"
fi

# Update epic in database
"$QUERY_SCRIPT" "
    UPDATE ccpm.epics
    SET
        status = '$new_status',
        progress = $new_progress,
        updated_at = datetime('now')
    WHERE id = $epic_id
" > /dev/null

echo "Progress: $old_progress% ’ $new_progress%"
echo "Status: $old_status ’ $new_status"
echo ""

# Update GitHub issue if it exists
if [[ "$epic_gh_issue" != "null" ]] && command -v gh &> /dev/null; then
    echo "Updating GitHub issue #$epic_gh_issue..."

    # Get current epic body
    epic_body=$(gh issue view "$epic_gh_issue" --json body -q .body 2>/dev/null || echo "")

    if [[ -n "$epic_body" ]]; then
        # Get all tasks with GitHub issues
        tasks_with_gh=$("$QUERY_SCRIPT" "
            SELECT
                task_number,
                name,
                status,
                github_issue_number
            FROM ccpm.tasks
            WHERE epic_id = $epic_id
                AND github_issue_number IS NOT NULL
                AND deleted_at IS NULL
            ORDER BY task_number
        " "json")

        # Create temp file with updated body
        temp_body=$(mktemp)
        echo "$epic_body" > "$temp_body"

        # Update each task's checkbox
        if [[ -n "$tasks_with_gh" ]] && [[ "$tasks_with_gh" != "[]" ]]; then
            echo "$tasks_with_gh" | jq -c '.[]' | while read -r task; do
                task_gh=$(echo "$task" | jq -r '.github_issue_number')
                task_status=$(echo "$task" | jq -r '.status')

                if [[ "$task_status" == "closed" ]]; then
                    # Mark as checked
                    sed -i.bak "s/- \[ \] #$task_gh/- [x] #$task_gh/" "$temp_body"
                else
                    # Ensure unchecked
                    sed -i.bak "s/- \[x\] #$task_gh/- [ ] #$task_gh/" "$temp_body"
                fi
            done
            rm -f "${temp_body}.bak"
        fi

        # Update GitHub issue
        if gh issue edit "$epic_gh_issue" --body-file "$temp_body" 2>/dev/null; then
            echo " GitHub task list updated"
        else
            echo "   Could not update GitHub issue (may not exist or no permissions)"
        fi

        rm -f "$temp_body"
    else
        echo "   Could not fetch GitHub issue body"
    fi
    echo ""
fi

# Summary
echo ""
echo " Epic Refreshed: $epic_name"
echo ""

if [[ "$new_status" == "closed" ]]; then
    echo "<‰ Epic complete! All tasks done."
    echo ""
    echo "Next steps:"
    echo "   Close epic: pm epic-close $epic_name"
elif [[ "$in_progress_tasks" -gt 0 ]]; then
    echo "= Work in progress ($in_progress_tasks task(s))"
    echo ""
    echo "Next steps:"
    echo "   View progress: pm epic-show $epic_name"
    echo "   See next tasks: pm next"
else
    echo "=Ë Ready to start work"
    echo ""
    echo "Next steps:"
    echo "   See next tasks: pm next"
    echo "   Start task: pm task-start $epic_name <num>"
fi
echo ""
