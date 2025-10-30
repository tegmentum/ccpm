#!/usr/bin/env bash
# Validate database integrity - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

echo "🔍 Validating Database Integrity"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

errors=0
warnings=0

# 1. Check for orphaned tasks (epic deleted but tasks remain)
echo "1. Checking for orphaned tasks..."
orphaned=$("$QUERY_SCRIPT" "
    SELECT COUNT(*) as count
    FROM ccpm.tasks t
    LEFT JOIN ccpm.epics e ON t.epic_id = e.id
    WHERE t.deleted_at IS NULL
        AND (e.id IS NULL OR e.deleted_at IS NOT NULL)
" "json" | jq -r '.[0].count')

if [[ "$orphaned" -gt 0 ]]; then
    echo "   ❌ Found $orphaned orphaned tasks (epic deleted but tasks remain)"
    ((errors++))
else
    echo "   ✅ No orphaned tasks"
fi

# 2. Check for orphaned epics (PRD deleted but epic remains)
echo "2. Checking for orphaned epics..."
orphaned_epics=$("$QUERY_SCRIPT" "
    SELECT COUNT(*) as count
    FROM ccpm.epics e
    LEFT JOIN ccpm.prds p ON e.prd_id = p.id
    WHERE e.deleted_at IS NULL
        AND e.prd_id IS NOT NULL
        AND (p.id IS NULL OR p.deleted_at IS NOT NULL)
" "json" | jq -r '.[0].count')

if [[ "$orphaned_epics" -gt 0 ]]; then
    echo "   ⚠️  Found $orphaned_epics epics with deleted PRDs"
    ((warnings++))
else
    echo "   ✅ No orphaned epics"
fi

# 3. Check for circular dependencies
echo "3. Checking for circular dependencies..."
circular=$("$QUERY_SCRIPT" "
    WITH RECURSIVE dep_chain(task_id, dependency_id, depth, path) AS (
        -- Base case: direct dependencies
        SELECT task_id, dependency_id, 1, task_id || '-' || dependency_id
        FROM ccpm.task_dependencies

        UNION ALL

        -- Recursive case: follow dependency chain
        SELECT dc.task_id, td.dependency_id, dc.depth + 1, dc.path || '-' || td.dependency_id
        FROM dep_chain dc
        JOIN ccpm.task_dependencies td ON dc.dependency_id = td.task_id
        WHERE dc.depth < 10  -- Prevent infinite recursion
            AND dc.path NOT LIKE '%' || td.dependency_id || '%'  -- Detect cycles
    )
    SELECT COUNT(*) as count
    FROM dep_chain
    WHERE dependency_id = task_id  -- Found a cycle
" "json" | jq -r '.[0].count')

if [[ "$circular" -gt 0 ]]; then
    echo "   ❌ Found $circular circular dependencies"
    ((errors++))
else
    echo "   ✅ No circular dependencies"
fi

# 4. Check for invalid task numbers (gaps or duplicates)
echo "4. Checking task numbering..."
invalid_numbers=$("$QUERY_SCRIPT" "
    SELECT
        epic_id,
        task_number,
        COUNT(*) as count
    FROM ccpm.tasks
    WHERE deleted_at IS NULL
    GROUP BY epic_id, task_number
    HAVING count > 1
" "json")

if [[ -n "$invalid_numbers" ]] && [[ "$invalid_numbers" != "[]" ]]; then
    dup_count=$(echo "$invalid_numbers" | jq 'length')
    echo "   ❌ Found $dup_count duplicate task numbers"
    ((errors++))
else
    echo "   ✅ No duplicate task numbers"
fi

# 5. Check epic progress consistency
echo "5. Checking epic progress calculations..."
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
    issue_count=$(echo "$progress_issues" | jq 'length')
    echo "   ⚠️  Found $issue_count epics with incorrect progress"
    ((warnings++))
    echo "$progress_issues" | jq -r '.[] | "      • \(.name): stored=\(.stored_progress)% actual=\(.calculated_progress)%"'
else
    echo "   ✅ Epic progress accurate"
fi

# 6. Check for tasks with invalid dependencies (dependency doesn't exist)
echo "6. Checking dependency validity..."
invalid_deps=$("$QUERY_SCRIPT" "
    SELECT COUNT(*) as count
    FROM ccpm.task_dependencies td
    LEFT JOIN ccpm.tasks t ON td.dependency_id = t.id
    WHERE t.id IS NULL OR t.deleted_at IS NOT NULL
" "json" | jq -r '.[0].count')

if [[ "$invalid_deps" -gt 0 ]]; then
    echo "   ❌ Found $invalid_deps dependencies pointing to deleted/nonexistent tasks"
    ((errors++))
else
    echo "   ✅ All dependencies valid"
fi

# 7. Check for cross-epic dependencies
echo "7. Checking cross-epic dependencies..."
cross_epic=$("$QUERY_SCRIPT" "
    SELECT
        t1.epic_id as task_epic,
        t2.epic_id as dep_epic,
        COUNT(*) as count
    FROM ccpm.task_dependencies td
    JOIN ccpm.tasks t1 ON td.task_id = t1.id
    JOIN ccpm.tasks t2 ON td.dependency_id = t2.id
    WHERE t1.epic_id != t2.epic_id
        AND t1.deleted_at IS NULL
        AND t2.deleted_at IS NULL
    GROUP BY t1.epic_id, t2.epic_id
" "json")

if [[ -n "$cross_epic" ]] && [[ "$cross_epic" != "[]" ]]; then
    cross_count=$(echo "$cross_epic" | jq -r '[.[].count] | add')
    echo "   ⚠️  Found $cross_count cross-epic dependencies (may be intentional)"
    ((warnings++))
else
    echo "   ✅ No cross-epic dependencies"
fi

# 8. Check GitHub sync consistency
echo "8. Checking GitHub sync status..."
sync_issues=$("$QUERY_SCRIPT" "
    SELECT COUNT(*) as count
    FROM ccpm.tasks
    WHERE deleted_at IS NULL
        AND github_issue_number IS NOT NULL
        AND github_synced_at IS NULL
" "json" | jq -r '.[0].count')

if [[ "$sync_issues" -gt 0 ]]; then
    echo "   ⚠️  Found $sync_issues tasks with GitHub issue but no sync timestamp"
    ((warnings++))
else
    echo "   ✅ GitHub sync status consistent"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $errors -gt 0 ]]; then
    echo "❌ Validation FAILED: $errors errors, $warnings warnings"
    echo ""
    echo "Recommended actions:"
    [[ $orphaned -gt 0 ]] && echo "  • Run: pm clean  to remove orphaned tasks"
    [[ $circular -gt 0 ]] && echo "  • Review and fix circular dependencies"
    [[ $invalid_deps -gt 0 ]] && echo "  • Clean up invalid dependencies"
    exit 1
elif [[ $warnings -gt 0 ]]; then
    echo "⚠️  Validation passed with $warnings warnings"
    echo ""
    echo "Recommended actions:"
    [[ $orphaned_epics -gt 0 ]] && echo "  • Review epics with deleted PRDs"
    exit 0
else
    echo "✅ Validation PASSED: Database is healthy"
    exit 0
fi
