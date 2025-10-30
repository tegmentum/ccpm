#!/usr/bin/env bash
# Clean up database - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Parse options
dry_run=false
force=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            dry_run=true
            shift
            ;;
        --force)
            force=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: pm clean [--dry-run] [--force]"
            exit 1
            ;;
    esac
done

echo "🧹 Database Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "$dry_run" == "true" ]]; then
    echo "📋 DRY RUN MODE - No changes will be made"
    echo ""
fi

# 1. Find orphaned tasks
echo "1. Checking for orphaned tasks..."
orphaned=$("$QUERY_SCRIPT" "
    SELECT
        t.id,
        t.name,
        t.epic_id
    FROM ccpm.tasks t
    LEFT JOIN ccpm.epics e ON t.epic_id = e.id
    WHERE t.deleted_at IS NULL
        AND (e.id IS NULL OR e.deleted_at IS NOT NULL)
" "json")

if [[ -n "$orphaned" ]] && [[ "$orphaned" != "[]" ]]; then
    count=$(echo "$orphaned" | jq 'length')
    echo "   Found $count orphaned tasks"
    echo "$orphaned" | jq -r '.[] | "   • \(.name) (epic_id: \(.epic_id))"'

    if [[ "$dry_run" == "false" ]]; then
        if [[ "$force" == "true" ]] || read -p "   Delete these tasks? (yes/no): " confirm && [[ "$confirm" == "yes" ]]; then
            task_ids=$(echo "$orphaned" | jq -r '.[].id' | tr '\n' ',' | sed 's/,$//')
            "$QUERY_SCRIPT" "
                UPDATE ccpm.tasks
                SET deleted_at = datetime('now')
                WHERE id IN ($task_ids)
            " > /dev/null
            echo "   ✅ Deleted $count orphaned tasks"
        else
            echo "   ⏭️  Skipped"
        fi
    fi
else
    echo "   ✅ No orphaned tasks"
fi
echo ""

# 2. Find invalid dependencies
echo "2. Checking for invalid dependencies..."
invalid_deps=$("$QUERY_SCRIPT" "
    SELECT
        td.task_id,
        td.dependency_id
    FROM ccpm.task_dependencies td
    LEFT JOIN ccpm.tasks t ON td.dependency_id = t.id
    WHERE t.id IS NULL OR t.deleted_at IS NOT NULL
" "json")

if [[ -n "$invalid_deps" ]] && [[ "$invalid_deps" != "[]" ]]; then
    count=$(echo "$invalid_deps" | jq 'length')
    echo "   Found $count invalid dependencies"

    if [[ "$dry_run" == "false" ]]; then
        if [[ "$force" == "true" ]] || read -p "   Remove these dependencies? (yes/no): " confirm && [[ "$confirm" == "yes" ]]; then
            echo "$invalid_deps" | jq -c '.[]' | while read -r dep; do
                task_id=$(echo "$dep" | jq -r '.task_id')
                dep_id=$(echo "$dep" | jq -r '.dependency_id')
                "$QUERY_SCRIPT" "
                    DELETE FROM ccpm.task_dependencies
                    WHERE task_id = $task_id AND dependency_id = $dep_id
                " > /dev/null
            done
            echo "   ✅ Removed $count invalid dependencies"
        else
            echo "   ⏭️  Skipped"
        fi
    fi
else
    echo "   ✅ No invalid dependencies"
fi
echo ""

# 3. Fix epic progress calculations
echo "3. Checking epic progress..."
progress_issues=$("$QUERY_SCRIPT" "
    SELECT
        e.id,
        e.name,
        e.progress as stored_progress,
        ROUND(
            CAST(SUM(CASE WHEN t.status = 'closed' THEN 1 ELSE 0 END) AS REAL) * 100 /
            NULLIF(COUNT(*), 0)
        ) as calculated_progress
    FROM ccpm.epics e
    LEFT JOIN ccpm.tasks t ON e.id = t.epic_id AND t.deleted_at IS NULL
    WHERE e.deleted_at IS NULL
    GROUP BY e.id
    HAVING ABS(stored_progress - COALESCE(calculated_progress, 0)) > 1
" "json")

if [[ -n "$progress_issues" ]] && [[ "$progress_issues" != "[]" ]]; then
    count=$(echo "$progress_issues" | jq 'length')
    echo "   Found $count epics with incorrect progress"
    echo "$progress_issues" | jq -r '.[] | "   • \(.name): \(.stored_progress)% → \(.calculated_progress)%"'

    if [[ "$dry_run" == "false" ]]; then
        if [[ "$force" == "true" ]] || read -p "   Fix progress calculations? (yes/no): " confirm && [[ "$confirm" == "yes" ]]; then
            echo "$progress_issues" | jq -c '.[]' | while read -r epic; do
                epic_id=$(echo "$epic" | jq -r '.id')
                calc_progress=$(echo "$epic" | jq -r '.calculated_progress')
                "$QUERY_SCRIPT" "
                    UPDATE ccpm.epics
                    SET progress = $calc_progress
                    WHERE id = $epic_id
                " > /dev/null
            done
            echo "   ✅ Fixed $count epic progress calculations"
        else
            echo "   ⏭️  Skipped"
        fi
    fi
else
    echo "   ✅ Epic progress accurate"
fi
echo ""

# 4. Vacuum database
echo "4. Database optimization..."
if [[ "$dry_run" == "false" ]]; then
    db_size_before=$(du -h "$DB_PATH" | awk '{print $1}')
    "$QUERY_SCRIPT" "VACUUM" > /dev/null
    "$QUERY_SCRIPT" "ANALYZE" > /dev/null
    db_size_after=$(du -h "$DB_PATH" | awk '{print $1}')
    echo "   ✅ Optimized database ($db_size_before → $db_size_after)"
else
    echo "   Would run VACUUM and ANALYZE"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "$dry_run" == "true" ]]; then
    echo "📋 Dry run complete - run without --dry-run to apply changes"
else
    echo "✅ Cleanup complete"
    echo ""
    echo "💡 Run 'pm validate' to verify database integrity"
fi
