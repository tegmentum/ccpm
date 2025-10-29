#!/usr/bin/env bash
# Show PRD implementation status - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Get PRD name from argument (optional)
prd_name="${1:-}"

if [[ -z "$prd_name" ]]; then
    # Show all PRDs
    echo "📋 PRD Implementation Status"
    echo "============================"
    echo ""

    prds_data=$("$QUERY_SCRIPT" "
        SELECT
            p.id,
            p.name,
            p.status,
            p.created_at,
            COUNT(DISTINCT e.id) as epic_count,
            COUNT(DISTINCT CASE WHEN e.status IN ('active', 'in-progress') THEN e.id END) as active_epics,
            COUNT(DISTINCT CASE WHEN e.status = 'closed' THEN e.id END) as closed_epics
        FROM ccpm.prds p
        LEFT JOIN ccpm.epics e ON p.id = e.prd_id AND e.deleted_at IS NULL
        WHERE p.deleted_at IS NULL
        GROUP BY p.id, p.name, p.status, p.created_at
        ORDER BY p.created_at DESC
    " "json")

    if [[ -z "$prds_data" ]] || [[ "$prds_data" == "[]" ]]; then
        echo "No PRDs found"
        echo ""
        echo "💡 Create a new PRD with: pm prd-new"
        exit 0
    fi

    echo "$prds_data" | jq -c '.[]' | while read -r prd; do
        prd_name=$(echo "$prd" | jq -r '.name')
        prd_status=$(echo "$prd" | jq -r '.status')
        epic_count=$(echo "$prd" | jq -r '.epic_count // 0')
        active_epics=$(echo "$prd" | jq -r '.active_epics // 0')
        closed_epics=$(echo "$prd" | jq -r '.closed_epics // 0')

        # Status icon
        case "$prd_status" in
            "complete")
                icon="✅"
                ;;
            "in-progress")
                icon="🚀"
                ;;
            *)
                icon="📋"
                ;;
        esac

        echo "$icon $prd_name ($prd_status)"
        echo "   Epics: $epic_count total, $active_epics active, $closed_epics closed"
    done

    echo ""
    echo "💡 View details: pm prd-status <prd-name>"
    exit 0
fi

# Show specific PRD details
prd_data=$(get_prd "$prd_name" "json")

if [[ -z "$prd_data" ]] || [[ "$prd_data" == "[]" ]]; then
    echo "❌ PRD not found: $prd_name"
    echo ""
    echo "Available PRDs:"
    "$QUERY_SCRIPT" "
        SELECT name FROM ccpm.prds
        WHERE deleted_at IS NULL
        ORDER BY created_at DESC
    " "csv" | tail -n +2 | while read -r name; do
        echo "  • $name"
    done
    exit 1
fi

# Parse PRD details
prd_id=$(echo "$prd_data" | jq -r '.[0].id')
prd_status=$(echo "$prd_data" | jq -r '.[0].status')
prd_description=$(echo "$prd_data" | jq -r '.[0].description // ""')
created_at=$(echo "$prd_data" | jq -r '.[0].created_at')

# Display PRD header
echo "📋 PRD: $prd_name"
echo "================================"
echo ""

echo "📊 Metadata:"
echo "  Status: ${prd_status}"
echo "  Created: ${created_at}"
[[ -n "$prd_description" ]] && echo "  Description: ${prd_description}"
echo ""

# Get epics for this PRD
epics_data=$("$QUERY_SCRIPT" "
    SELECT
        e.id,
        e.name,
        e.status,
        ep.calculated_progress as progress,
        ep.total_tasks,
        ep.closed_tasks,
        ep.in_progress_tasks,
        ep.open_tasks
    FROM ccpm.epics e
    LEFT JOIN ccpm.epic_progress ep ON e.id = ep.id
    WHERE e.prd_id = $prd_id
      AND e.deleted_at IS NULL
    ORDER BY e.created_at
" "json")

if [[ -z "$epics_data" ]] || [[ "$epics_data" == "[]" ]]; then
    echo "📚 Epics:"
    echo "  No epics created yet"
    echo ""
    echo "💡 Create an epic with: pm epic-new $prd_name"
    exit 0
fi

# Display epics
echo "📚 Epics:"
epic_count=$(echo "$epics_data" | jq 'length')
total_tasks=0
total_closed=0
total_in_progress=0
total_open=0

echo "$epics_data" | jq -c '.[]' | while read -r epic; do
    epic_name=$(echo "$epic" | jq -r '.name')
    epic_status=$(echo "$epic" | jq -r '.status')
    epic_progress=$(echo "$epic" | jq -r '.progress // 0')
    epic_total=$(echo "$epic" | jq -r '.total_tasks // 0')
    epic_closed=$(echo "$epic" | jq -r '.closed_tasks // 0')
    epic_in_progress=$(echo "$epic" | jq -r '.in_progress_tasks // 0')
    epic_open=$(echo "$epic" | jq -r '.open_tasks // 0')

    # Status icon
    case "$epic_status" in
        "closed")
            icon="✅"
            ;;
        "in-progress"|"active")
            icon="🚀"
            ;;
        *)
            icon="⬜"
            ;;
    esac

    echo "  $icon $epic_name ($epic_status) - ${epic_progress}%"
    if [[ $epic_total -gt 0 ]]; then
        echo "     Tasks: $epic_total total ($epic_closed closed, $epic_in_progress in-progress, $epic_open open)"
    fi
done

# Calculate overall PRD statistics
prd_stats=$("$QUERY_SCRIPT" "
    SELECT
        COUNT(*) as total_epics,
        COUNT(*) FILTER (WHERE e.status = 'closed') as closed_epics,
        COUNT(*) FILTER (WHERE e.status IN ('active', 'in-progress')) as active_epics,
        SUM(CAST(ep.total_tasks AS INTEGER)) as total_tasks,
        SUM(CAST(ep.closed_tasks AS INTEGER)) as closed_tasks,
        SUM(CAST(ep.in_progress_tasks AS INTEGER)) as in_progress_tasks,
        SUM(CAST(ep.open_tasks AS INTEGER)) as open_tasks
    FROM ccpm.epics e
    LEFT JOIN ccpm.epic_progress ep ON e.id = ep.id
    WHERE e.prd_id = $prd_id
      AND e.deleted_at IS NULL
" "json")

total_epics=$(echo "$prd_stats" | jq -r '.[0].total_epics // 0')
closed_epics=$(echo "$prd_stats" | jq -r '.[0].closed_epics // 0')
active_epics=$(echo "$prd_stats" | jq -r '.[0].active_epics // 0')
total_tasks=$(echo "$prd_stats" | jq -r '.[0].total_tasks // 0')
closed_tasks=$(echo "$prd_stats" | jq -r '.[0].closed_tasks // 0')
in_progress_tasks=$(echo "$prd_stats" | jq -r '.[0].in_progress_tasks // 0')
open_tasks=$(echo "$prd_stats" | jq -r '.[0].open_tasks // 0')

echo ""
echo "📈 Overall Statistics:"
echo "  Epics: $total_epics total ($closed_epics closed, $active_epics active)"
if [[ $total_tasks -gt 0 ]]; then
    echo "  Tasks: $total_tasks total ($closed_tasks closed, $in_progress_tasks in-progress, $open_tasks open)"
    overall_completion=$((closed_tasks * 100 / total_tasks))
    echo "  Overall Completion: ${overall_completion}%"
fi

echo ""
echo "💡 Actions:"
if [[ $active_epics -gt 0 ]]; then
    echo "  • View active epics: pm standup"
    echo "  • View epic details: pm epic-show <epic-name>"
fi
if [[ $total_tasks -eq 0 ]]; then
    echo "  • Create epics: pm epic-new $prd_name"
fi

exit 0
