#!/usr/bin/env bash
# Sync epic to GitHub - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Check gh CLI
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found"
    exit 1
fi

# Get epic name
epic_name="${1:-}"

if [[ -z "$epic_name" ]]; then
    echo "Usage: pm epic-sync <epic-name>"
    exit 1
fi

echo "🔄 Syncing Epic: $epic_name"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get epic from database
epic_data=$(get_epic "$epic_name" "json")

if [[ -z "$epic_data" ]] || [[ "$epic_data" == "[]" ]]; then
    echo "❌ Epic not found: $epic_name"
    exit 1
fi

epic_id=$(echo "$epic_data" | jq -r '.[0].id')
epic_status=$(echo "$epic_data" | jq -r '.[0].status')
epic_content=$(echo "$epic_data" | jq -r '.[0].content')
epic_progress=$(echo "$epic_data" | jq -r '.[0].progress')
gh_issue=$(echo "$epic_data" | jq -r '.[0].github_issue_number // "null"')

# Get tasks
tasks=$("$QUERY_SCRIPT" "
    SELECT
        id,
        task_number,
        name,
        status,
        github_issue_number
    FROM ccpm.tasks
    WHERE epic_id = $epic_id
        AND deleted_at IS NULL
    ORDER BY task_number
" "json")

task_count=$(echo "$tasks" | jq 'length')

# Build epic body with task list
epic_body="$epic_content

## Tasks ($task_count total, $epic_progress% complete)

"

if [[ "$task_count" -gt 0 ]]; then
    echo "$tasks" | jq -c '.[]' | while read -r task; do
        task_name=$(echo "$task" | jq -r '.name')
        task_status=$(echo "$task" | jq -r '.status')
        task_gh=$(echo "$task" | jq -r '.github_issue_number // "null"')

        if [[ "$task_status" == "closed" ]]; then
            checkbox="[x]"
        else
            checkbox="[ ]"
        fi

        if [[ "$task_gh" != "null" ]]; then
            echo "- $checkbox #$task_gh - $task_name" >> /tmp/epic_body.txt
        else
            echo "- $checkbox $task_name" >> /tmp/epic_body.txt
        fi
    done

    epic_body="$epic_body$(cat /tmp/epic_body.txt)"
    rm -f /tmp/epic_body.txt
fi

# Check if epic exists on GitHub
if [[ "$gh_issue" != "null" ]]; then
    echo "Updating existing GitHub issue #$gh_issue..."

    # Update the issue
    echo "$epic_body" | gh issue edit "$gh_issue" --title "$epic_name" --body-file - 2>/dev/null

    # Update status
    gh_state=$(gh issue view "$gh_issue" --json state -q .state 2>/dev/null)
    if [[ "$epic_status" == "closed" ]] && [[ "$gh_state" == "OPEN" ]]; then
        gh issue close "$gh_issue" 2>/dev/null
        echo "  ✅ Closed epic on GitHub"
    elif [[ "$epic_status" != "closed" ]] && [[ "$gh_state" == "CLOSED" ]]; then
        gh issue reopen "$gh_issue" 2>/dev/null
        echo "  ✅ Reopened epic on GitHub"
    fi

    echo "  ✅ Updated GitHub issue #$gh_issue"
else
    echo "Creating new GitHub issue..."

    # Create the issue
    new_issue=$(echo "$epic_body" | gh issue create --title "$epic_name" --body-file - --label "epic" 2>/dev/null)

    if [[ -n "$new_issue" ]]; then
        # Extract issue number from URL
        new_number=$(echo "$new_issue" | grep -oE '[0-9]+$')

        # Update database
        "$QUERY_SCRIPT" "
            UPDATE ccpm.epics
            SET
                github_issue_number = $new_number,
                github_synced_at = datetime('now')
            WHERE id = $epic_id
        " > /dev/null

        echo "  ✅ Created GitHub issue #$new_number"
        gh_issue="$new_number"
    else
        echo "  ❌ Failed to create GitHub issue"
        exit 1
    fi
fi

# Update sync timestamp
"$QUERY_SCRIPT" "
    UPDATE ccpm.epics
    SET github_synced_at = datetime('now')
    WHERE id = $epic_id
" > /dev/null

# Sync child tasks
echo ""
echo "Syncing tasks..."
synced=0
created=0

echo "$tasks" | jq -c '.[]' | while read -r task; do
    task_id=$(echo "$task" | jq -r '.id')
    task_number=$(echo "$task" | jq -r '.task_number')
    task_name=$(echo "$task" | jq -r '.name')
    task_gh=$(echo "$task" | jq -r '.github_issue_number // "null"')

    if [[ "$task_gh" == "null" ]]; then
        # Create task on GitHub as sub-issue
        task_body="Part of epic #$gh_issue

Task: $task_name"

        new_task_issue=$(echo "$task_body" | gh issue create --title "$task_name" --body-file - --label "task" 2>/dev/null || echo "")

        if [[ -n "$new_task_issue" ]]; then
            new_task_number=$(echo "$new_task_issue" | grep -oE '[0-9]+$')

            # Update database
            "$QUERY_SCRIPT" "
                UPDATE ccpm.tasks
                SET
                    github_issue_number = $new_task_number,
                    github_synced_at = datetime('now')
                WHERE id = $task_id
            " > /dev/null

            echo "  ✅ Created task #$new_task_number: $task_name"
            ((created++))
        fi
    else
        echo "  ℹ️  Task #$task_gh already synced"
        ((synced++))
    fi
done

echo ""
echo "✅ Epic sync complete"
echo "  Epic: #$gh_issue"
echo "  Tasks created: $created"
echo "  Tasks already synced: $synced"
