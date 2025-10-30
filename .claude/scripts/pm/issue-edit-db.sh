#!/usr/bin/env bash
# Edit issue/task details - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_DIR")/../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Get issue number
issue_number="${1:-}"

if [[ -z "$issue_number" ]]; then
    echo "Usage: pm issue-edit <issue-number>"
    exit 1
fi

echo "  Editing Issue: #$issue_number"
echo ""
echo ""

# Get task data by GitHub issue number
task_data=$("$QUERY_SCRIPT" "
    SELECT
        t.*,
        e.name as epic_name
    FROM ccpm.tasks t
    JOIN ccpm.epics e ON t.epic_id = e.id
    WHERE t.github_issue_number = $issue_number
        AND t.deleted_at IS NULL
" "json")

if [[ -z "$task_data" ]] || [[ "$task_data" == "[]" ]]; then
    echo "L Issue not found: #$issue_number"
    echo "   Make sure the issue is synced to the database"
    exit 1
fi

task_id=$(echo "$task_data" | jq -r '.[0].id')
epic_name=$(echo "$task_data" | jq -r '.[0].epic_name')
task_number=$(echo "$task_data" | jq -r '.[0].task_number')
current_name=$(echo "$task_data" | jq -r '.[0].name')
current_description=$(echo "$task_data" | jq -r '.[0].description // ""')
current_status=$(echo "$task_data" | jq -r '.[0].status')
estimated_hours=$(echo "$task_data" | jq -r '.[0].estimated_hours // 0')

echo "Current Details:"
echo "  Epic: $epic_name"
echo "  Task: #$task_number"
echo "  Name: $current_name"
echo "  Status: $current_status"
echo "  Estimated: ${estimated_hours}h"
echo ""

# Interactive edit menu
while true; do
    echo "What would you like to edit?"
    echo "  1) Name/Title"
    echo "  2) Description"
    echo "  3) Status"
    echo "  4) Estimated hours"
    echo "  5) Done"
    echo ""
    read -p "Choose (1-5): " choice

    case "$choice" in
        1)
            echo ""
            echo "Current name: $current_name"
            read -p "New name: " new_name
            if [[ -n "$new_name" ]] && [[ "$new_name" != "$current_name" ]]; then
                current_name="$new_name"
                echo " Name updated"
            fi
            echo ""
            ;;
        2)
            echo ""
            echo "Current description:"
            echo "$current_description"
            echo ""
            echo "Enter new description (Ctrl-D when done):"
            new_description=$(cat)
            if [[ -n "$new_description" ]]; then
                current_description="$new_description"
                echo " Description updated"
            fi
            echo ""
            ;;
        3)
            echo ""
            echo "Current status: $current_status"
            echo "Options: open, in_progress, closed"
            read -p "New status: " new_status
            if [[ "$new_status" =~ ^(open|in_progress|closed)$ ]]; then
                current_status="$new_status"
                echo " Status updated"
            else
                echo "Invalid status. Must be: open, in_progress, or closed"
            fi
            echo ""
            ;;
        4)
            echo ""
            echo "Current estimate: ${estimated_hours}h"
            read -p "New estimate (hours): " new_estimate
            if [[ "$new_estimate" =~ ^[0-9]+$ ]]; then
                estimated_hours="$new_estimate"
                echo " Estimate updated"
            else
                echo "Invalid estimate. Must be a number."
            fi
            echo ""
            ;;
        5)
            break
            ;;
        *)
            echo "Invalid choice"
            echo ""
            ;;
    esac
done

# Escape values for SQL
escaped_name=$(escape_sql "$current_name")
escaped_description=$(escape_sql "$current_description")

# Update task in database
"$QUERY_SCRIPT" "
    UPDATE ccpm.tasks
    SET
        name = '$escaped_name',
        description = '$escaped_description',
        status = '$current_status',
        estimated_hours = $estimated_hours,
        updated_at = datetime('now')
    WHERE id = $task_id
" > /dev/null

echo ""
echo " Task Updated: $current_name"
echo ""

# Update GitHub
read -p "Update GitHub issue #$issue_number? (yes/no): " sync_choice
echo ""

if [[ "$sync_choice" == "yes" ]]; then
    if command -v gh &> /dev/null; then
        # Update title
        if gh issue edit "$issue_number" --title "$current_name" 2>/dev/null; then
            echo " GitHub issue title updated"
        else
            echo "   Could not update GitHub issue (may not exist or no permissions)"
        fi

        # Update body if description provided
        if [[ -n "$current_description" ]]; then
            temp_body=$(mktemp)

            # Build body with metadata
            cat > "$temp_body" << EOF
$current_description

---

**Epic:** $epic_name
**Task:** #$task_number
**Estimated:** ${estimated_hours}h
EOF

            if gh issue edit "$issue_number" --body-file "$temp_body" 2>/dev/null; then
                echo " GitHub issue body updated"
            fi
            rm -f "$temp_body"
        fi

        # Update state
        if [[ "$current_status" == "closed" ]]; then
            gh issue close "$issue_number" 2>/dev/null && echo " GitHub issue closed"
        elif gh issue view "$issue_number" --json state -q .state 2>/dev/null | grep -q "CLOSED"; then
            gh issue reopen "$issue_number" 2>/dev/null && echo " GitHub issue reopened"
        fi

        # Update epic's GitHub issue checklist if epic has one
        epic_gh=$("$QUERY_SCRIPT" "
            SELECT e.github_issue_number
            FROM ccpm.epics e
            JOIN ccpm.tasks t ON t.epic_id = e.id
            WHERE t.id = $task_id
                AND e.github_issue_number IS NOT NULL
        " "json")

        epic_gh_num=$(echo "$epic_gh" | jq -r '.[0].github_issue_number // "null"')

        if [[ "$epic_gh_num" != "null" ]]; then
            echo "Updating epic checklist..."
            # Run epic-refresh to update the checklist
            bash "$SCRIPT_DIR/epic-refresh-db.sh" "$epic_name" > /dev/null 2>&1
            echo " Epic checklist updated"
        fi
    else
        echo "   gh CLI not available - GitHub not updated"
    fi
    echo ""
fi

echo "View task: pm task-show $epic_name $task_number"
echo ""
