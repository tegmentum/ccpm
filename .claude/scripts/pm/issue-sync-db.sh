#!/usr/bin/env bash
# Sync single issue bidirectionally - Database version

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

# Get issue number
issue_number="${1:-}"

if [[ -z "$issue_number" ]]; then
    echo "Usage: pm issue-sync <issue-number>"
    exit 1
fi

# Strip # prefix
issue_number="${issue_number#\#}"

echo "🔄 Syncing Issue #$issue_number"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get GitHub data
echo "Fetching from GitHub..."
gh_data=$(gh issue view "$issue_number" --json number,title,body,state,updatedAt 2>/dev/null || echo "")

if [[ -z "$gh_data" ]]; then
    echo "❌ Issue #$issue_number not found on GitHub"
    exit 1
fi

gh_title=$(echo "$gh_data" | jq -r '.title')
gh_body=$(echo "$gh_data" | jq -r '.body // ""')
gh_state=$(echo "$gh_data" | jq -r '.state' | tr '[:upper:]' '[:lower:]')
gh_updated=$(echo "$gh_data" | jq -r '.updatedAt')

echo "  Title: $gh_title"
echo "  State: $gh_state"
echo ""

# Get local data
echo "Checking local database..."
task_data=$("$QUERY_SCRIPT" "
    SELECT
        t.id,
        t.name,
        t.description,
        t.status,
        t.updated_at,
        t.github_synced_at,
        e.name as epic_name
    FROM ccpm.tasks t
    JOIN ccpm.epics e ON t.epic_id = e.id
    WHERE t.github_issue_number = $issue_number
        AND t.deleted_at IS NULL
" "json")

if [[ -z "$task_data" ]] || [[ "$task_data" == "[]" ]]; then
    echo "  No local task found - importing from GitHub..."

    # Import as new task (simplified - goes to 'imported' epic)
    bash "$SCRIPT_DIR/import-db.sh" --label "imported-via-sync"
    echo "✅ Imported issue #$issue_number"
    exit 0
fi

# Parse local data
task_id=$(echo "$task_data" | jq -r '.[0].id')
local_name=$(echo "$task_data" | jq -r '.[0].name')
local_desc=$(echo "$task_data" | jq -r '.[0].description // ""')
local_status=$(echo "$task_data" | jq -r '.[0].status')
local_updated=$(echo "$task_data" | jq -r '.[0].updated_at')
last_sync=$(echo "$task_data" | jq -r '.[0].github_synced_at // ""')
epic_name=$(echo "$task_data" | jq -r '.[0].epic_name')

echo "  Local task: $epic_name - $local_name"
echo "  Local status: $local_status"
echo ""

# Determine sync direction
needs_update=false
update_github=false
update_local=false

if [[ -z "$last_sync" ]]; then
    echo "⚠️  Never synced - using GitHub as source of truth"
    update_local=true
elif [[ "$gh_updated" > "$last_sync" ]] && [[ "$local_updated" > "$last_sync" ]]; then
    echo "⚠️  Both GitHub and local have changes since last sync"
    echo "  GitHub updated: $gh_updated"
    echo "  Local updated: $local_updated"
    echo "  Last sync: $last_sync"
    echo ""
    read -p "Which version to keep? (github/local): " choice
    case $choice in
        github)
            update_local=true
            ;;
        local)
            update_github=true
            ;;
        *)
            echo "❌ Invalid choice"
            exit 1
            ;;
    esac
elif [[ "$gh_updated" > "$last_sync" ]]; then
    echo "ℹ️  GitHub has newer changes"
    update_local=true
elif [[ "$local_updated" > "$last_sync" ]]; then
    echo "ℹ️  Local has newer changes"
    update_github=true
else
    echo "✅ Already in sync"
    exit 0
fi

# Apply updates
if [[ "$update_local" == "true" ]]; then
    echo "Updating local database from GitHub..."

    escaped_title=$(escape_sql "$gh_title")
    escaped_body=$(escape_sql "$gh_body")
    db_state=$(echo "$gh_state" | tr '[:upper:]' '[:lower:]')

    "$QUERY_SCRIPT" "
        UPDATE ccpm.tasks
        SET
            name = '${escaped_title}',
            description = '${escaped_body}',
            status = '$db_state',
            updated_at = datetime('now'),
            github_synced_at = datetime('now')
        WHERE id = $task_id
    " > /dev/null

    echo "  ✅ Updated local task"
fi

if [[ "$update_github" == "true" ]]; then
    echo "Updating GitHub from local database..."

    # Update GitHub issue
    gh issue edit "$issue_number" --title "$local_name" --body "$local_desc" 2>/dev/null

    # Update state if different
    if [[ "$local_status" == "closed" ]] && [[ "$gh_state" == "open" ]]; then
        gh issue close "$issue_number" 2>/dev/null
        echo "  ✅ Closed GitHub issue"
    elif [[ "$local_status" == "open" ]] && [[ "$gh_state" == "closed" ]]; then
        gh issue reopen "$issue_number" 2>/dev/null
        echo "  ✅ Reopened GitHub issue"
    fi

    # Update sync timestamp
    "$QUERY_SCRIPT" "
        UPDATE ccpm.tasks
        SET github_synced_at = datetime('now')
        WHERE id = $task_id
    " > /dev/null

    echo "  ✅ Updated GitHub issue"
fi

echo ""
echo "✅ Sync complete for issue #$issue_number"
