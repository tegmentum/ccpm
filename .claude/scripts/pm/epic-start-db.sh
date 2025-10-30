#!/usr/bin/env bash
# Start epic work in dedicated worktree - Database version

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
    echo "Usage: pm epic-start <epic-name>"
    exit 1
fi

echo "🚀 Starting Epic: $epic_name"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Validate epic exists
epic_data=$(get_epic "$epic_name" "json")

if [[ -z "$epic_data" ]] || [[ "$epic_data" == "[]" ]]; then
    echo "❌ Epic not found: $epic_name"
    exit 1
fi

epic_id=$(echo "$epic_data" | jq -r '.[0].id')
epic_status=$(echo "$epic_data" | jq -r '.[0].status')
epic_gh_issue=$(echo "$epic_data" | jq -r '.[0].github_issue_number // "null"')

echo "Epic Status: $epic_status"
[[ "$epic_gh_issue" != "null" ]] && echo "GitHub Issue: #$epic_gh_issue"
echo ""

# Check if epic is synced to GitHub
if [[ "$epic_gh_issue" == "null" ]]; then
    echo "⚠️  Epic not synced to GitHub"
    read -p "Do you want to sync now? (yes/no): " sync_choice
    if [[ "$sync_choice" == "yes" ]]; then
        bash "$SCRIPT_DIR/epic-sync-db.sh" "$epic_name"
        echo ""
        # Re-fetch epic data
        epic_data=$(get_epic "$epic_name" "json")
        epic_gh_issue=$(echo "$epic_data" | jq -r '.[0].github_issue_number // "null"')
    fi
fi

# Get main branch name
main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# Check for uncommitted changes in current directory
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    echo "⚠️  You have uncommitted changes in the current directory"
    echo ""
    git status --short
    echo ""
    read -p "Commit or stash these changes before continuing? (commit/stash/cancel): " change_choice
    case "$change_choice" in
        commit)
            echo "Please commit your changes and run this command again."
            exit 1
            ;;
        stash)
            git stash push -m "Stashed before starting epic $epic_name"
            echo "✅ Changes stashed"
            ;;
        *)
            echo "Cancelled"
            exit 1
            ;;
    esac
    echo ""
fi

# Determine worktree location and branch name
worktree_path="../epic-$epic_name"
branch_name="epic/$epic_name"

# Check if worktree already exists
if git worktree list | grep -q "epic-$epic_name"; then
    echo "✅ Worktree already exists: $worktree_path"
    existing_path=$(git worktree list | grep "epic-$epic_name" | awk '{print $1}')
    cd "$existing_path"
    echo "   Changed to: $existing_path"
    echo ""
else
    echo "Creating worktree..."

    # Update main branch
    git checkout "$main_branch" 2>/dev/null
    git pull origin "$main_branch"

    # Check if branch exists remotely or locally
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        # Local branch exists
        git worktree add "$worktree_path" "$branch_name"
        echo "✅ Created worktree from existing local branch"
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
        # Remote branch exists
        git worktree add "$worktree_path" "$branch_name"
        echo "✅ Created worktree from existing remote branch"
    else
        # Create new branch
        git worktree add "$worktree_path" -b "$branch_name"
        git push -u origin "$branch_name"
        echo "✅ Created new worktree and branch"
    fi

    cd "$worktree_path"
    echo "   Location: $worktree_path"
    echo "   Branch: $branch_name"
    echo ""
fi

# Get ready tasks (no unmet dependencies)
ready_tasks=$("$QUERY_SCRIPT" "
    SELECT * FROM ccpm.ready_tasks
    WHERE epic_id = $epic_id
    ORDER BY task_number
" "json")

# Get blocked tasks
blocked_tasks=$("$QUERY_SCRIPT" "
    SELECT * FROM ccpm.blocked_tasks
    WHERE epic_id = $epic_id
    ORDER BY task_number
" "json")

# Get in-progress tasks
in_progress=$("$QUERY_SCRIPT" "
    SELECT
        task_number,
        name,
        github_issue_number
    FROM ccpm.tasks
    WHERE epic_id = $epic_id
        AND status = 'in_progress'
        AND deleted_at IS NULL
    ORDER BY task_number
" "json")

# Display task status
echo "📊 Task Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -n "$in_progress" ]] && [[ "$in_progress" != "[]" ]]; then
    in_progress_count=$(echo "$in_progress" | jq 'length')
    echo "🔄 In Progress ($in_progress_count):"
    echo "$in_progress" | jq -r '.[] | "   • Task #\(.task_number): \(.name)" + (if .github_issue_number then " (GitHub #\(.github_issue_number))" else "" end)'
    echo ""
fi

if [[ -n "$ready_tasks" ]] && [[ "$ready_tasks" != "[]" ]]; then
    ready_count=$(echo "$ready_tasks" | jq 'length')
    echo "✅ Ready to Start ($ready_count):"
    echo "$ready_tasks" | jq -r '.[] | "   • Task #\(.task_number): \(.name)" + (if .github_issue_number then " (GitHub #\(.github_issue_number))" else "" end)'
    echo ""
else
    echo "ℹ️  No ready tasks (all may be blocked or complete)"
    echo ""
fi

if [[ -n "$blocked_tasks" ]] && [[ "$blocked_tasks" != "[]" ]]; then
    blocked_count=$(echo "$blocked_tasks" | jq 'length')
    echo "⏸️  Blocked ($blocked_count):"
    echo "$blocked_tasks" | jq -r '.[] | "   • Task #\(.task_number): \(.name) - Blocked by: \(.unmet_dependencies)"'
    echo ""
fi

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Epic workspace ready"
echo ""
echo "📍 Current location: $(pwd)"
echo "🌿 Branch: $(git branch --show-current)"
echo ""
echo "🚀 Next steps:"
if [[ -n "$ready_tasks" ]] && [[ "$ready_tasks" != "[]" ]]; then
    first_task=$(echo "$ready_tasks" | jq -r '.[0].task_number')
    echo "   Start first task: pm task-start $epic_name $first_task"
fi
echo "   View tasks: pm epic-show $epic_name"
echo "   Check status: pm status"
echo ""
echo "💡 When done:"
echo "   Return to main: cd $PROJECT_ROOT"
echo "   Remove worktree: git worktree remove epic-$epic_name"
echo ""
