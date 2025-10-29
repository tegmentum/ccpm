#!/bin/bash
# PM Status - Database Version
# Replaces file-based grep/find with SQL queries

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
    echo "Run: ./db/init.sh"
    exit 1
fi

echo "📊 Project Status"
echo "================"
echo ""

# PRDs
echo "📄 PRDs:"
prd_counts=$(CCPM_DB="${CCPM_DB}" "$QUERY_SCRIPT" "
    SELECT
        status,
        COUNT(*) as count
    FROM ccpm.prds
    WHERE deleted_at IS NULL
    GROUP BY status
    ORDER BY CASE status
        WHEN 'in-progress' THEN 1
        WHEN 'backlog' THEN 2
        WHEN 'complete' THEN 3
        ELSE 4
    END
" "csv" 2>/dev/null)

if [[ -n "$prd_counts" ]]; then
    total_prds=0
    while IFS=, read -r status count; do
        # Skip header
        [[ "$status" == "status" ]] && continue
        case "$status" in
            "in-progress") echo "  In-Progress: $count" ;;
            "backlog") echo "  Backlog: $count" ;;
            "complete") echo "  Complete: $count" ;;
            *) echo "  $status: $count" ;;
        esac
        total_prds=$((total_prds + count))
    done <<< "$prd_counts"
    echo "  Total: $total_prds"
else
    echo "  Total: 0"
fi

echo ""

# Epics
echo "📚 Epics:"
epic_counts=$(CCPM_DB="${CCPM_DB}" "$QUERY_SCRIPT" "
    SELECT
        status,
        COUNT(*) as count
    FROM ccpm.epics
    WHERE deleted_at IS NULL
    GROUP BY status
    ORDER BY CASE status
        WHEN 'in-progress' THEN 1
        WHEN 'backlog' THEN 2
        WHEN 'completed' THEN 3
        ELSE 4
    END
" "csv" 2>/dev/null)

if [[ -n "$epic_counts" ]]; then
    total_epics=0
    while IFS=, read -r status count; do
        # Skip header
        [[ "$status" == "status" ]] && continue
        case "$status" in
            "in-progress") echo "  In-Progress: $count" ;;
            "backlog") echo "  Backlog: $count" ;;
            "completed") echo "  Completed: $count" ;;
            *) echo "  $status: $count" ;;
        esac
        total_epics=$((total_epics + count))
    done <<< "$epic_counts"
    echo "  Total: $total_epics"
else
    echo "  Total: 0"
fi

echo ""

# Tasks
echo "📝 Tasks:"
task_counts=$(CCPM_DB="${CCPM_DB}" "$QUERY_SCRIPT" "
    SELECT
        status,
        COUNT(*) as count
    FROM ccpm.tasks
    WHERE deleted_at IS NULL
    GROUP BY status
    ORDER BY CASE status
        WHEN 'in-progress' THEN 1
        WHEN 'open' THEN 2
        WHEN 'closed' THEN 3
        ELSE 4
    END
" "csv" 2>/dev/null)

if [[ -n "$task_counts" ]]; then
    total_tasks=0
    open_count=0
    closed_count=0
    in_progress_count=0

    while IFS=, read -r status count; do
        # Skip header
        [[ "$status" == "status" ]] && continue
        case "$status" in
            "open") open_count=$count ;;
            "in-progress") in_progress_count=$count ;;
            "closed") closed_count=$count ;;
        esac
        total_tasks=$((total_tasks + count))
    done <<< "$task_counts"

    echo "  Open: $open_count"
    [[ $in_progress_count -gt 0 ]] && echo "  In-Progress: $in_progress_count"
    echo "  Closed: $closed_count"
    echo "  Total: $total_tasks"
else
    echo "  Total: 0"
fi

exit 0
