#!/usr/bin/env bash
# Edit epic details - Database version

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
    echo "Usage: pm epic-edit <epic-name>"
    exit 1
fi

echo "  Editing Epic: $epic_name"
echo ""
echo ""

# Get epic data
epic_data=$(get_epic "$epic_name" "json")

if [[ -z "$epic_data" ]] || [[ "$epic_data" == "[]" ]]; then
    echo "L Epic not found: $epic_name"
    exit 1
fi

epic_id=$(echo "$epic_data" | jq -r '.[0].id')
current_name=$(echo "$epic_data" | jq -r '.[0].name')
current_description=$(echo "$epic_data" | jq -r '.[0].description // ""')
current_status=$(echo "$epic_data" | jq -r '.[0].status')
prd_name=$(echo "$epic_data" | jq -r '.[0].prd_name // "null"')
epic_gh_issue=$(echo "$epic_data" | jq -r '.[0].github_issue_number // "null"')

echo "Current Details:"
echo "  Name: $current_name"
echo "  Status: $current_status"
[[ "$prd_name" != "null" ]] && echo "  PRD: $prd_name"
[[ "$epic_gh_issue" != "null" ]] && echo "  GitHub: #$epic_gh_issue"
echo ""

# Interactive edit menu
while true; do
    echo "What would you like to edit?"
    echo "  1) Name"
    echo "  2) Description"
    echo "  3) Status"
    echo "  4) Done"
    echo ""
    read -p "Choose (1-4): " choice

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
            echo "Options: backlog, active, closed"
            read -p "New status: " new_status
            if [[ "$new_status" =~ ^(backlog|active|closed)$ ]]; then
                current_status="$new_status"
                echo " Status updated"
            else
                echo "Invalid status. Must be: backlog, active, or closed"
            fi
            echo ""
            ;;
        4)
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

# Update epic in database
"$QUERY_SCRIPT" "
    UPDATE ccpm.epics
    SET
        name = '$escaped_name',
        description = '$escaped_description',
        status = '$current_status',
        updated_at = datetime('now')
    WHERE id = $epic_id
" > /dev/null

echo ""
echo " Epic Updated: $current_name"
echo ""

# Update GitHub if it exists
if [[ "$epic_gh_issue" != "null" ]]; then
    read -p "Update GitHub issue #$epic_gh_issue? (yes/no): " sync_choice
    echo ""

    if [[ "$sync_choice" == "yes" ]]; then
        if command -v gh &> /dev/null; then
            # Update title
            if gh issue edit "$epic_gh_issue" --title "$current_name" 2>/dev/null; then
                echo " GitHub issue title updated"
            else
                echo "   Could not update GitHub issue (may not exist or no permissions)"
            fi

            # Update body if description provided
            if [[ -n "$current_description" ]]; then
                temp_body=$(mktemp)
                echo "$current_description" > "$temp_body"
                if gh issue edit "$epic_gh_issue" --body-file "$temp_body" 2>/dev/null; then
                    echo " GitHub issue body updated"
                fi
                rm -f "$temp_body"
            fi

            # Update state if closed
            if [[ "$current_status" == "closed" ]]; then
                gh issue close "$epic_gh_issue" 2>/dev/null && echo " GitHub issue closed"
            elif gh issue view "$epic_gh_issue" --json state -q .state 2>/dev/null | grep -q "CLOSED"; then
                gh issue reopen "$epic_gh_issue" 2>/dev/null && echo " GitHub issue reopened"
            fi
        else
            echo "   gh CLI not available - GitHub not updated"
        fi
        echo ""
    fi
fi

echo "View epic: pm epic-show $current_name"
echo ""
