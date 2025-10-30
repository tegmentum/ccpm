#!/usr/bin/env bash
# Show issue status - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Get issue number from argument (optional - if not provided, show all)
issue_number="${1:-}"

if [[ -z "$issue_number" ]]; then
    # Show all issues with their sync status
    echo "📊 All Issues Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    issues=$("$QUERY_SCRIPT" "
        SELECT
            t.github_issue_number,
            t.name,
            t.status,
            e.name as epic_name,
            t.github_synced_at
        FROM ccpm.tasks t
        JOIN ccpm.epics e ON t.epic_id = e.id
        WHERE t.github_issue_number IS NOT NULL
            AND t.deleted_at IS NULL
        ORDER BY t.github_issue_number DESC
    " "json")

    if [[ -z "$issues" ]] || [[ "$issues" == "[]" ]]; then
        echo "No issues synced to GitHub yet"
        echo ""
        echo "Try: pm issue-sync  or  pm import"
        exit 0
    fi

    # Count by status
    open_count=$(echo "$issues" | jq '[.[] | select(.status == "open")] | length')
    in_progress_count=$(echo "$issues" | jq '[.[] | select(.status == "in_progress")] | length')
    closed_count=$(echo "$issues" | jq '[.[] | select(.status == "closed")] | length')

    echo "Summary:"
    echo "  📂 Open: $open_count"
    echo "  🔄 In Progress: $in_progress_count"
    echo "  ✅ Closed: $closed_count"
    echo ""

    # Group by epic
    epics=$(echo "$issues" | jq -r '.[].epic_name' | sort -u)

    while IFS= read -r epic; do
        [[ -z "$epic" ]] && continue

        echo "Epic: $epic"
        echo "$issues" | jq -r --arg epic "$epic" '
            .[] |
            select(.epic_name == $epic) |
            "  #\(.github_issue_number) [\(.status)] \(.name)"
        '
        echo ""
    done <<< "$epics"

    exit 0
fi

# Strip # prefix if provided
issue_number="${issue_number#\#}"

# Get specific issue status
task_data=$("$QUERY_SCRIPT" "
    SELECT
        t.id,
        t.name,
        t.status,
        t.github_issue_number,
        t.github_synced_at,
        t.created_at,
        t.updated_at,
        e.name as epic_name,
        e.status as epic_status
    FROM ccpm.tasks t
    JOIN ccpm.epics e ON t.epic_id = e.id
    WHERE t.github_issue_number = $issue_number
        AND t.deleted_at IS NULL
" "json")

if [[ -z "$task_data" ]] || [[ "$task_data" == "[]" ]]; then
    echo "❌ No task found for issue #$issue_number"
    echo ""
    echo "This issue may not be synced yet. Try:"
    echo "  pm import"
    echo "  pm issue-sync"
    exit 1
fi

# Parse data
name=$(echo "$task_data" | jq -r '.[0].name')
status=$(echo "$task_data" | jq -r '.[0].status')
github_synced=$(echo "$task_data" | jq -r '.[0].github_synced_at')
created_at=$(echo "$task_data" | jq -r '.[0].created_at')
updated_at=$(echo "$task_data" | jq -r '.[0].updated_at')
epic_name=$(echo "$task_data" | jq -r '.[0].epic_name')
epic_status=$(echo "$task_data" | jq -r '.[0].epic_status')

echo "📊 Issue #$issue_number Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Task: $name"
echo "Epic: $epic_name [$epic_status]"
echo ""

# Local status
echo "💾 Local Database:"
echo "  Status: $status"
echo "  Created: $created_at"
[[ "$updated_at" != "null" ]] && echo "  Updated: $updated_at"
echo ""

# GitHub status
if command -v gh &> /dev/null; then
    gh_data=$(gh issue view "$issue_number" --json state,updatedAt 2>/dev/null || echo "")

    if [[ -n "$gh_data" ]]; then
        gh_state=$(echo "$gh_data" | jq -r '.state')
        gh_updated=$(echo "$gh_data" | jq -r '.updatedAt')

        echo "🌐 GitHub:"
        echo "  State: $gh_state"
        echo "  Updated: $gh_updated"
        echo ""

        # Sync status
        echo "🔄 Sync Status:"
        if [[ "$github_synced" != "null" ]]; then
            echo "  Last Synced: $github_synced"

            # Check if GitHub is newer
            if [[ "$gh_updated" > "$github_synced" ]]; then
                echo "  ⚠️  GitHub has newer changes (needs sync)"
            else
                echo "  ✅ In sync"
            fi
        else
            echo "  ⚠️  Never synced"
        fi
        echo ""

        # Status consistency check
        gh_lower=$(echo "$gh_state" | tr '[:upper:]' '[:lower:]')
        if [[ "$status" == "closed" ]] && [[ "$gh_lower" == "open" ]]; then
            echo "⚠️  Status mismatch: Local is closed but GitHub is open"
            echo "   Run: pm issue-sync $issue_number"
        elif [[ "$status" != "closed" ]] && [[ "$gh_lower" == "closed" ]]; then
            echo "⚠️  Status mismatch: GitHub is closed but local is $status"
            echo "   Run: pm issue-sync $issue_number"
        fi
    else
        echo "⚠️  Could not fetch GitHub status"
    fi
else
    echo "⚠️  GitHub CLI not available"
fi
