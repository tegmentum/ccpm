#!/bin/bash
# Epic List - Database Version
# Replaces file-based operations with SQL queries

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_HELPERS="$SCRIPT_DIR/../../../db/helpers.sh"

# Source database helpers
if [[ ! -f "$DB_HELPERS" ]]; then
    echo "Error: Database helpers not found at: $DB_HELPERS" >&2
    exit 1
fi

source "$DB_HELPERS"

# Check if database exists
if ! check_db 2>/dev/null; then
    echo "❌ Database not initialized"
    echo "Create your first epic with: /pm:prd-parse <feature-name>"
    exit 1
fi

# Check for epics
total=$(CCPM_DB="${CCPM_DB}" "$QUERY_SCRIPT" "SELECT COUNT(*) as count FROM ccpm.epics WHERE deleted_at IS NULL" "csv" 2>/dev/null | tail -1)

if [[ "$total" == "0" ]] || [[ -z "$total" ]]; then
    echo "📁 No epics found. Create your first epic with: /pm:prd-parse <feature-name>"
    exit 0
fi

echo "📚 Project Epics"
echo "================"
echo ""

# Backlog Epics
echo "📝 Backlog:"
backlog=$(CCPM_DB="${CCPM_DB}" "$QUERY_SCRIPT" "
    SELECT
        e.name || '|' || e.progress || '|' || COUNT(t.id) || '|' || COALESCE(CAST(e.github_issue_number AS VARCHAR), '') as data
    FROM ccpm.epics e
    LEFT JOIN ccpm.tasks t ON e.id = t.epic_id AND t.deleted_at IS NULL
    WHERE e.status = 'backlog' AND e.deleted_at IS NULL
    GROUP BY e.id, e.name, e.progress, e.github_issue_number, e.created_at
    ORDER BY e.created_at DESC
" "csv" 2>/dev/null)

backlog_count=0
if [[ -n "$backlog" ]]; then
    while IFS= read -r line; do
        # Skip header
        [[ "$line" == "data" ]] && continue
        [[ -z "$line" ]] && continue

        IFS='|' read -r name progress tasks github_issue <<< "$line"
        [[ -z "$progress" ]] && progress="0"
        [[ -z "$tasks" ]] && tasks="0"

        if [[ -n "$github_issue" ]]; then
            echo "   📋 $name (#$github_issue) - ${progress}% complete ($tasks tasks)"
        else
            echo "   📋 $name - ${progress}% complete ($tasks tasks)"
        fi
        ((backlog_count++))
    done <<< "$backlog"
fi
[[ $backlog_count -eq 0 ]] && echo "   (none)"

echo ""

# In Progress Epics
echo "🚀 In Progress:"
in_progress=$(CCPM_DB="${CCPM_DB}" "$QUERY_SCRIPT" "
    SELECT
        e.name || '|' || e.progress || '|' || COUNT(t.id) || '|' || COALESCE(CAST(e.github_issue_number AS VARCHAR), '') as data
    FROM ccpm.epics e
    LEFT JOIN ccpm.tasks t ON e.id = t.epic_id AND t.deleted_at IS NULL
    WHERE e.status = 'in-progress' AND e.deleted_at IS NULL
    GROUP BY e.id, e.name, e.progress, e.github_issue_number, e.created_at
    ORDER BY e.created_at DESC
" "csv" 2>/dev/null)

in_progress_count=0
if [[ -n "$in_progress" ]]; then
    while IFS= read -r line; do
        # Skip header
        [[ "$line" == "data" ]] && continue
        [[ -z "$line" ]] && continue

        IFS='|' read -r name progress tasks github_issue <<< "$line"
        [[ -z "$progress" ]] && progress="0"
        [[ -z "$tasks" ]] && tasks="0"

        if [[ -n "$github_issue" ]]; then
            echo "   📋 $name (#$github_issue) - ${progress}% complete ($tasks tasks)"
        else
            echo "   📋 $name - ${progress}% complete ($tasks tasks)"
        fi
        ((in_progress_count++))
    done <<< "$in_progress"
fi
[[ $in_progress_count -eq 0 ]] && echo "   (none)"

echo ""

# Completed Epics
echo "✅ Completed:"
completed=$(CCPM_DB="${CCPM_DB}" "$QUERY_SCRIPT" "
    SELECT
        e.name || '|' || e.progress || '|' || COUNT(t.id) || '|' || COALESCE(CAST(e.github_issue_number AS VARCHAR), '') as data
    FROM ccpm.epics e
    LEFT JOIN ccpm.tasks t ON e.id = t.epic_id AND t.deleted_at IS NULL
    WHERE e.status = 'completed' AND e.deleted_at IS NULL
    GROUP BY e.id, e.name, e.progress, e.github_issue_number, e.created_at
    ORDER BY e.created_at DESC
" "csv" 2>/dev/null)

completed_count=0
if [[ -n "$completed" ]]; then
    while IFS= read -r line; do
        # Skip header
        [[ "$line" == "data" ]] && continue
        [[ -z "$line" ]] && continue

        IFS='|' read -r name progress tasks github_issue <<< "$line"
        [[ -z "$progress" ]] && progress="0"
        [[ -z "$tasks" ]] && tasks="0"

        if [[ -n "$github_issue" ]]; then
            echo "   📋 $name (#$github_issue) - ${progress}% complete ($tasks tasks)"
        else
            echo "   📋 $name - ${progress}% complete ($tasks tasks)"
        fi
        ((completed_count++))
    done <<< "$completed"
fi
[[ $completed_count -eq 0 ]] && echo "   (none)"

# Summary
echo ""
echo "📊 Summary"
total_tasks=$(CCPM_DB="${CCPM_DB}" "$QUERY_SCRIPT" "SELECT COUNT(*) as count FROM ccpm.tasks WHERE deleted_at IS NULL" "csv" 2>/dev/null | tail -1)
echo "   Total epics: $total"
echo "   Total tasks: $total_tasks"

exit 0
