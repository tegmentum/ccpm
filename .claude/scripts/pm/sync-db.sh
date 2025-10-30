#!/usr/bin/env bash
# Bidirectional sync - Database version

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

echo "🔄 Bidirectional Sync"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Parse options
import_new=true
sync_existing=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --import-only)
            sync_existing=false
            shift
            ;;
        --sync-only)
            import_new=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: pm sync [--import-only] [--sync-only]"
            exit 1
            ;;
    esac
done

# Step 1: Import new issues from GitHub
if [[ "$import_new" == "true" ]]; then
    echo "1. Importing new issues from GitHub..."
    bash "$SCRIPT_DIR/import-db.sh"
    echo ""
fi

# Step 2: Sync existing issues
if [[ "$sync_existing" == "true" ]]; then
    echo "2. Syncing existing issues..."

    # Get all tasks with GitHub issues
    tasks=$("$QUERY_SCRIPT" "
        SELECT
            github_issue_number,
            name
        FROM ccpm.tasks
        WHERE github_issue_number IS NOT NULL
            AND deleted_at IS NULL
        ORDER BY github_issue_number
    " "json")

    if [[ -z "$tasks" ]] || [[ "$tasks" == "[]" ]]; then
        echo "  No tasks with GitHub issues to sync"
    else
        count=$(echo "$tasks" | jq 'length')
        echo "  Found $count tasks to sync"
        echo ""

        synced=0
        failed=0

        echo "$tasks" | jq -c '.[]' | while read -r task; do
            issue_num=$(echo "$task" | jq -r '.github_issue_number')
            task_name=$(echo "$task" | jq -r '.name')

            echo "  Syncing #$issue_num: $task_name"
            if bash "$SCRIPT_DIR/issue-sync-db.sh" "$issue_num" 2>&1 | grep -q "✅"; then
                ((synced++))
            else
                ((failed++))
            fi
        done

        echo ""
        echo "  ✅ Synced: $synced"
        [[ $failed -gt 0 ]] && echo "  ❌ Failed: $failed"
    fi
    echo ""
fi

# Step 3: Sync epics to GitHub
echo "3. Syncing epics to GitHub..."

epics=$("$QUERY_SCRIPT" "
    SELECT
        name,
        github_issue_number
    FROM ccpm.epics
    WHERE deleted_at IS NULL
    ORDER BY created_at
" "json")

if [[ -z "$epics" ]] || [[ "$epics" == "[]" ]]; then
    echo "  No epics to sync"
else
    epic_count=$(echo "$epics" | jq 'length')
    echo "  Found $epic_count epics"
    echo ""

    echo "$epics" | jq -c '.[]' | while read -r epic; do
        epic_name=$(echo "$epic" | jq -r '.name')
        gh_issue=$(echo "$epic" | jq -r '.github_issue_number // "null"')

        if [[ "$gh_issue" == "null" ]]; then
            echo "  Creating epic on GitHub: $epic_name"
        else
            echo "  Updating epic on GitHub: $epic_name (#$gh_issue)"
        fi

        bash "$SCRIPT_DIR/epic-sync-db.sh" "$epic_name" 2>&1 | grep -E "✅|❌" | sed 's/^/    /'
    done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Sync complete"
echo ""
echo "💡 Next steps:"
echo "  pm status  - View current status"
echo "  pm validate  - Validate database integrity"
