#!/usr/bin/env bash
# Display issue details - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Get issue number from argument
issue_number="${1:-}"

if [[ -z "$issue_number" ]]; then
    echo "❌ Please provide an issue number"
    echo "Usage: pm issue-show <issue-number>"
    exit 1
fi

# Strip # prefix if provided
issue_number="${issue_number#\#}"

# Get task by GitHub issue number
task_data=$("$QUERY_SCRIPT" "
    SELECT
        t.id,
        t.name,
        t.description,
        t.status,
        t.estimated_hours,
        t.actual_hours,
        t.parallel,
        t.created_at,
        t.updated_at,
        t.github_issue_number,
        t.github_synced_at,
        e.name as epic_name,
        e.github_issue_number as epic_issue
    FROM ccpm.tasks t
    JOIN ccpm.epics e ON t.epic_id = e.id
    WHERE t.github_issue_number = $issue_number
        AND t.deleted_at IS NULL
" "json")

if [[ -z "$task_data" ]] || [[ "$task_data" == "[]" ]]; then
    echo "❌ No task found for issue #$issue_number"
    echo ""
    echo "This issue may not be synced to the database yet."
    echo "Try: pm import  or  pm issue-sync"
    exit 1
fi

# Parse task data
name=$(echo "$task_data" | jq -r '.[0].name')
description=$(echo "$task_data" | jq -r '.[0].description')
status=$(echo "$task_data" | jq -r '.[0].status')
estimated_hours=$(echo "$task_data" | jq -r '.[0].estimated_hours')
actual_hours=$(echo "$task_data" | jq -r '.[0].actual_hours')
parallel=$(echo "$task_data" | jq -r '.[0].parallel')
created_at=$(echo "$task_data" | jq -r '.[0].created_at')
updated_at=$(echo "$task_data" | jq -r '.[0].updated_at')
github_synced=$(echo "$task_data" | jq -r '.[0].github_synced_at')
epic_name=$(echo "$task_data" | jq -r '.[0].epic_name')
epic_issue=$(echo "$task_data" | jq -r '.[0].epic_issue')
task_id=$(echo "$task_data" | jq -r '.[0].id')

# Get GitHub data
echo "🎫 Issue #$issue_number: $name"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Fetch live GitHub data
if command -v gh &> /dev/null; then
    gh_data=$(gh issue view "$issue_number" --json state,labels,assignees,createdAt,updatedAt 2>/dev/null || echo "")
    if [[ -n "$gh_data" ]]; then
        gh_state=$(echo "$gh_data" | jq -r '.state')
        gh_labels=$(echo "$gh_data" | jq -r '.labels[]?.name' | tr '\n' ', ' | sed 's/,$//')
        gh_assignee=$(echo "$gh_data" | jq -r '.assignees[]?.login' | head -1)

        echo "📊 GitHub Status:"
        echo "   State: $gh_state"
        [[ -n "$gh_labels" ]] && echo "   Labels: $gh_labels"
        [[ -n "$gh_assignee" ]] && [[ "$gh_assignee" != "null" ]] && echo "   Assignee: @$gh_assignee"
        echo ""
    fi
fi

# Local status
echo "💾 Local Status:"
echo "   Status: $status"
echo "   Epic: $epic_name"
[[ "$epic_issue" != "null" ]] && echo "   Epic Issue: #$epic_issue"
[[ "$parallel" == "1" ]] && echo "   Parallel: Yes (can run in parallel)"
echo ""

# Time tracking
if [[ "$estimated_hours" != "null" ]] || [[ "$actual_hours" != "null" ]]; then
    echo "⏱️  Time Tracking:"
    [[ "$estimated_hours" != "null" ]] && echo "   Estimated: ${estimated_hours}h"
    [[ "$actual_hours" != "null" ]] && echo "   Actual: ${actual_hours}h"

    if [[ "$estimated_hours" != "null" ]] && [[ "$actual_hours" != "null" ]]; then
        variance=$(echo "scale=1; $actual_hours - $estimated_hours" | bc)
        if (( $(echo "$variance > 0" | bc -l) )); then
            echo "   Variance: +${variance}h over estimate"
        elif (( $(echo "$variance < 0" | bc -l) )); then
            echo "   Variance: ${variance}h under estimate"
        else
            echo "   Variance: On estimate"
        fi
    fi
    echo ""
fi

# Description
if [[ -n "$description" ]] && [[ "$description" != "null" ]]; then
    echo "📝 Description:"
    echo "$description" | sed 's/^/   /'
    echo ""
fi

# Dependencies
deps=$("$QUERY_SCRIPT" "
    SELECT
        t.name,
        t.status,
        t.github_issue_number
    FROM ccpm.task_dependencies td
    JOIN ccpm.tasks t ON td.dependency_id = t.id
    WHERE td.task_id = $task_id
        AND t.deleted_at IS NULL
" "json")

if [[ -n "$deps" ]] && [[ "$deps" != "[]" ]]; then
    echo "🔗 Dependencies (must complete first):"
    echo "$deps" | jq -r '.[] | "   • \(.name) [\(.status)]" + (if .github_issue_number then " #\(.github_issue_number)" else "" end)'
    echo ""
fi

# Blocked tasks
blockers=$("$QUERY_SCRIPT" "
    SELECT
        t.name,
        t.status,
        t.github_issue_number
    FROM ccpm.task_dependencies td
    JOIN ccpm.tasks t ON td.task_id = t.id
    WHERE td.dependency_id = $task_id
        AND t.deleted_at IS NULL
" "json")

if [[ -n "$blockers" ]] && [[ "$blockers" != "[]" ]]; then
    echo "⏸️  Blocking (waiting on this task):"
    echo "$blockers" | jq -r '.[] | "   • \(.name) [\(.status)]" + (if .github_issue_number then " #\(.github_issue_number)" else "" end)'
    echo ""
fi

# Timestamps
echo "📅 Timeline:"
echo "   Created: $created_at"
[[ "$updated_at" != "null" ]] && echo "   Updated: $updated_at"
[[ "$github_synced" != "null" ]] && echo "   Last Synced: $github_synced"
echo ""

# Quick actions
echo "🚀 Quick Actions:"
if [[ "$status" == "open" ]]; then
    echo "   Start work: pm task-start $epic_name <task-number>"
elif [[ "$status" == "in_progress" ]]; then
    echo "   Complete: pm task-close $epic_name <task-number>"
fi
echo "   Sync to GitHub: pm issue-sync $issue_number"
echo "   View in browser: gh issue view $issue_number --web"
echo "   Add comment: gh issue comment $issue_number --body 'your comment'"
echo ""
