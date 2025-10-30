#!/usr/bin/env bash
# Reopen issue - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Get arguments
issue_number="${1:-}"
reopen_reason="${2:-Reopening for additional work}"

if [[ -z "$issue_number" ]]; then
    echo "❌ Please provide an issue number"
    echo "Usage: pm issue-reopen <issue-number> [reason]"
    exit 1
fi

# Strip # prefix if provided
issue_number="${issue_number#\#}"

# Get task by GitHub issue number
task_data=$("$QUERY_SCRIPT" "
    SELECT
        t.id,
        t.name,
        t.status,
        e.id as epic_id,
        e.name as epic_name,
        e.github_issue_number as epic_issue
    FROM ccpm.tasks t
    JOIN ccpm.epics e ON t.epic_id = e.id
    WHERE t.github_issue_number = $issue_number
        AND t.deleted_at IS NULL
" "json")

if [[ -z "$task_data" ]] || [[ "$task_data" == "[]" ]]; then
    echo "❌ No task found for issue #$issue_number"
    exit 1
fi

# Parse task data
task_id=$(echo "$task_data" | jq -r '.[0].id')
task_name=$(echo "$task_data" | jq -r '.[0].name')
current_status=$(echo "$task_data" | jq -r '.[0].status')
epic_id=$(echo "$task_data" | jq -r '.[0].epic_id')
epic_name=$(echo "$task_data" | jq -r '.[0].epic_name')
epic_issue=$(echo "$task_data" | jq -r '.[0].epic_issue')

# Check if already open
if [[ "$current_status" == "open" ]]; then
    echo "⚠️  Issue #$issue_number is already open"
    exit 0
fi

# Update task status in database
"$QUERY_SCRIPT" "
    UPDATE ccpm.tasks
    SET
        status = 'open',
        updated_at = datetime('now')
    WHERE id = $task_id
" > /dev/null

echo "✅ Reopened task locally: $task_name"

# Reopen on GitHub
if command -v gh &> /dev/null; then
    # Check if issue exists and is closed on GitHub
    gh_state=$(gh issue view "$issue_number" --json state -q .state 2>/dev/null || echo "")

    if [[ "$gh_state" == "CLOSED" ]]; then
        # Add reopen comment
        gh issue comment "$issue_number" --body "🔄 Reopening issue

$reopen_reason

---
Reopened at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" 2>/dev/null || true

        # Reopen the issue
        if gh issue reopen "$issue_number" 2>/dev/null; then
            echo "✅ Reopened GitHub issue #$issue_number"
        else
            echo "⚠️  Failed to reopen GitHub issue (may need manual intervention)"
        fi

        # Update epic task list if epic is synced
        if [[ "$epic_issue" != "null" ]]; then
            # Get epic body
            epic_body=$(gh issue view "$epic_issue" --json body -q .body 2>/dev/null || echo "")

            if [[ -n "$epic_body" ]]; then
                # Uncheck task in epic
                updated_body=$(echo "$epic_body" | sed "s/- \[x\] #$issue_number/- [ ] #$issue_number/")

                if [[ "$epic_body" != "$updated_body" ]]; then
                    echo "$updated_body" | gh issue edit "$epic_issue" --body-file - 2>/dev/null && \
                        echo "✅ Updated epic progress on GitHub" || \
                        echo "⚠️  Could not update epic progress"
                fi
            fi
        fi
    elif [[ "$gh_state" == "OPEN" ]]; then
        echo "ℹ️  GitHub issue #$issue_number already open"
    else
        echo "⚠️  Could not verify GitHub issue status"
    fi
else
    echo "⚠️  GitHub CLI not available - only updated local database"
fi

# Recalculate epic progress
epic_stats=$("$QUERY_SCRIPT" "
    SELECT
        COUNT(*) as total,
        SUM(CASE WHEN status = 'closed' THEN 1 ELSE 0 END) as closed
    FROM ccpm.tasks
    WHERE epic_id = $epic_id
        AND deleted_at IS NULL
" "json")

total_tasks=$(echo "$epic_stats" | jq -r '.[0].total')
closed_tasks=$(echo "$epic_stats" | jq -r '.[0].closed')
progress=$(echo "scale=0; ($closed_tasks * 100) / $total_tasks" | bc)

# Update epic progress
"$QUERY_SCRIPT" "
    UPDATE ccpm.epics
    SET
        progress = $progress,
        updated_at = datetime('now')
    WHERE id = $epic_id
" > /dev/null

echo ""
echo "📊 Epic Progress: $epic_name"
echo "   Status: $closed_tasks/$total_tasks tasks complete ($progress%)"
echo ""
echo "🚀 Next: Run 'pm task-start $epic_name <task-number>' to resume work"
