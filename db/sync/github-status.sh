#!/usr/bin/env bash
# GitHub Sync Status - Show sync status of all entities

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/github-helpers.sh"

# =============================================================================
# Status Display Functions
# =============================================================================

# Get sync status summary
get_sync_summary() {
    check_db || return 1

    "$QUERY_SCRIPT" "
        WITH entity_status AS (
            -- PRDs
            SELECT
                'prd' as entity_type,
                COUNT(*) as total,
                SUM(CASE WHEN github_issue_number IS NULL THEN 1 ELSE 0 END) as not_synced,
                SUM(CASE WHEN github_synced_at IS NULL OR updated_at > github_synced_at THEN 1 ELSE 0 END) as pending,
                0 as conflicts
            FROM ccpm.prds
            WHERE deleted_at IS NULL

            UNION ALL

            -- Epics
            SELECT
                'epic' as entity_type,
                COUNT(*) as total,
                SUM(CASE WHEN github_issue_number IS NULL THEN 1 ELSE 0 END) as not_synced,
                SUM(CASE WHEN github_synced_at IS NULL OR updated_at > github_synced_at THEN 1 ELSE 0 END) as pending,
                0 as conflicts
            FROM ccpm.epics
            WHERE deleted_at IS NULL

            UNION ALL

            -- Tasks
            SELECT
                'task' as entity_type,
                COUNT(*) as total,
                SUM(CASE WHEN github_issue_number IS NULL THEN 1 ELSE 0 END) as not_synced,
                SUM(CASE WHEN github_synced_at IS NULL OR updated_at > github_synced_at THEN 1 ELSE 0 END) as pending,
                0 as conflicts
            FROM ccpm.tasks
            WHERE deleted_at IS NULL
        )
        SELECT * FROM entity_status
    " "json"
}

# Get conflict details
get_conflicts() {
    check_db || return 1

    "$QUERY_SCRIPT" "
        SELECT
            sm.entity_type,
            sm.entity_id,
            sm.github_issue_number,
            CASE sm.entity_type
                WHEN 'prd' THEN p.name
                WHEN 'epic' THEN e.name
                WHEN 'task' THEN CAST(t.task_number AS VARCHAR) || '. ' || t.name
            END as entity_name,
            sm.local_updated_at,
            sm.github_updated_at,
            sm.conflict_reason,
            sm.updated_at as conflict_detected_at
        FROM ccpm.sync_metadata sm
        LEFT JOIN ccpm.prds p ON sm.entity_type = 'prd' AND sm.entity_id = p.id
        LEFT JOIN ccpm.epics e ON sm.entity_type = 'epic' AND sm.entity_id = e.id
        LEFT JOIN ccpm.tasks t ON sm.entity_type = 'task' AND sm.entity_id = t.id
        WHERE sm.sync_status = 'conflict'
        ORDER BY sm.entity_type, sm.entity_id
    " "json"
}

# Get detailed entity status
get_entity_details() {
    local entity_type="$1"
    local epic_filter="${2:-}"

    check_db || return 1

    local where_clause=""
    if [[ -n "$epic_filter" ]]; then
        if [[ "$entity_type" == "epic" ]]; then
            where_clause="AND e.name = '${epic_filter}'"
        elif [[ "$entity_type" == "task" ]]; then
            where_clause="AND epic.name = '${epic_filter}'"
        fi
    fi

    case "$entity_type" in
        prd)
            "$QUERY_SCRIPT" "
                SELECT
                    p.id,
                    p.name,
                    p.github_issue_number,
                    p.updated_at,
                    p.github_synced_at,
                    sm.sync_status,
                    CASE
                        WHEN p.github_issue_number IS NULL THEN 'never'
                        WHEN p.github_synced_at IS NULL THEN 'pending'
                        WHEN p.updated_at > p.github_synced_at THEN 'pending'
                        WHEN sm.sync_status = 'conflict' THEN 'conflict'
                        ELSE 'synced'
                    END as status
                FROM ccpm.prds p
                LEFT JOIN ccpm.sync_metadata sm ON sm.entity_type = 'prd' AND sm.entity_id = p.id
                WHERE p.deleted_at IS NULL
                ORDER BY p.name
            " "json"
            ;;
        epic)
            "$QUERY_SCRIPT" "
                SELECT
                    e.id,
                    e.name,
                    p.name as prd_name,
                    e.github_issue_number,
                    e.updated_at,
                    e.github_synced_at,
                    sm.sync_status,
                    CASE
                        WHEN e.github_issue_number IS NULL THEN 'never'
                        WHEN e.github_synced_at IS NULL THEN 'pending'
                        WHEN e.updated_at > e.github_synced_at THEN 'pending'
                        WHEN sm.sync_status = 'conflict' THEN 'conflict'
                        ELSE 'synced'
                    END as status
                FROM ccpm.epics e
                JOIN ccpm.prds p ON e.prd_id = p.id
                LEFT JOIN ccpm.sync_metadata sm ON sm.entity_type = 'epic' AND sm.entity_id = e.id
                WHERE e.deleted_at IS NULL
                  ${where_clause}
                ORDER BY p.name, e.name
            " "json"
            ;;
        task)
            "$QUERY_SCRIPT" "
                SELECT
                    t.id,
                    t.task_number,
                    t.name,
                    epic.name as epic_name,
                    t.github_issue_number,
                    t.updated_at,
                    t.github_synced_at,
                    sm.sync_status,
                    CASE
                        WHEN t.github_issue_number IS NULL THEN 'never'
                        WHEN t.github_synced_at IS NULL THEN 'pending'
                        WHEN t.updated_at > t.github_synced_at THEN 'pending'
                        WHEN sm.sync_status = 'conflict' THEN 'conflict'
                        ELSE 'synced'
                    END as status
                FROM ccpm.tasks t
                JOIN ccpm.epics epic ON t.epic_id = epic.id
                LEFT JOIN ccpm.sync_metadata sm ON sm.entity_type = 'task' AND sm.entity_id = t.id
                WHERE t.deleted_at IS NULL
                  ${where_clause}
                ORDER BY epic.name, t.task_number
            " "json"
            ;;
    esac
}

# =============================================================================
# Display Formatters
# =============================================================================

# Display summary
display_summary() {
    local summary="$1"

    echo "GitHub Sync Status"
    echo "=================="
    echo ""

    # PRDs
    local prd_data=$(echo "$summary" | jq '.[] | select(.entity_type == "prd")')
    if [[ -n "$prd_data" ]]; then
        local total=$(echo "$prd_data" | jq -r '.total')
        local not_synced=$(echo "$prd_data" | jq -r '.not_synced')
        local pending=$(echo "$prd_data" | jq -r '.pending')

        echo "PRDs:"
        echo "  Total: $total"
        [[ $not_synced -gt 0 ]] && echo "  ⚠ Never synced: $not_synced"
        [[ $pending -gt 0 ]] && echo "  ⟳ Pending push: $pending"
        [[ $not_synced -eq 0 ]] && [[ $pending -eq 0 ]] && echo "  ✓ All synced"
        echo ""
    fi

    # Epics
    local epic_data=$(echo "$summary" | jq '.[] | select(.entity_type == "epic")')
    if [[ -n "$epic_data" ]]; then
        local total=$(echo "$epic_data" | jq -r '.total')
        local not_synced=$(echo "$epic_data" | jq -r '.not_synced')
        local pending=$(echo "$epic_data" | jq -r '.pending')

        echo "Epics:"
        echo "  Total: $total"
        [[ $not_synced -gt 0 ]] && echo "  ⚠ Never synced: $not_synced"
        [[ $pending -gt 0 ]] && echo "  ⟳ Pending push: $pending"
        [[ $not_synced -eq 0 ]] && [[ $pending -eq 0 ]] && echo "  ✓ All synced"
        echo ""
    fi

    # Tasks
    local task_data=$(echo "$summary" | jq '.[] | select(.entity_type == "task")')
    if [[ -n "$task_data" ]]; then
        local total=$(echo "$task_data" | jq -r '.total')
        local not_synced=$(echo "$task_data" | jq -r '.not_synced')
        local pending=$(echo "$task_data" | jq -r '.pending')

        echo "Tasks:"
        echo "  Total: $total"
        [[ $not_synced -gt 0 ]] && echo "  ⚠ Never synced: $not_synced"
        [[ $pending -gt 0 ]] && echo "  ⟳ Pending push: $pending"
        [[ $not_synced -eq 0 ]] && [[ $pending -eq 0 ]] && echo "  ✓ All synced"
        echo ""
    fi

    # Check for conflicts
    local conflicts
    conflicts=$(get_conflicts)
    local conflict_count
    conflict_count=$(echo "$conflicts" | jq 'length')

    if [[ $conflict_count -gt 0 ]]; then
        echo "⚠ Conflicts: $conflict_count"
        echo "  Run with --conflicts to see details"
        echo ""
    fi
}

# Display conflicts
display_conflicts() {
    local conflicts="$1"

    echo "Sync Conflicts"
    echo "=============="
    echo ""

    if [[ -z "$conflicts" ]] || [[ "$conflicts" == "[]" ]]; then
        echo "No conflicts found"
        return 0
    fi

    echo "$conflicts" | jq -c '.[]' | while read -r conflict; do
        local entity_type=$(echo "$conflict" | jq -r '.entity_type')
        local entity_id=$(echo "$conflict" | jq -r '.entity_id')
        local entity_name=$(echo "$conflict" | jq -r '.entity_name')
        local issue_number=$(echo "$conflict" | jq -r '.github_issue_number')
        local local_updated=$(echo "$conflict" | jq -r '.local_updated_at')
        local github_updated=$(echo "$conflict" | jq -r '.github_updated_at')
        local reason=$(echo "$conflict" | jq -r '.conflict_reason // "Unknown"')

        echo "⚠ ${entity_type^} #${issue_number}: ${entity_name}"
        echo "  Entity ID: ${entity_id}"
        echo "  Local updated: ${local_updated}"
        echo "  GitHub updated: ${github_updated}"
        echo "  Reason: ${reason}"
        echo "  Resolve with: pm sync resolve ${entity_type} ${entity_id} --use-local|--use-github"
        echo ""
    done
}

# Display detailed entity status
display_entity_details() {
    local entity_type="$1"
    local details="$2"

    echo "${entity_type^}s:"
    echo "--------"
    echo ""

    if [[ -z "$details" ]] || [[ "$details" == "[]" ]]; then
        echo "No ${entity_type}s found"
        return 0
    fi

    case "$entity_type" in
        prd)
            echo "$details" | jq -c '.[]' | while read -r entity; do
                local name=$(echo "$entity" | jq -r '.name')
                local issue=$(echo "$entity" | jq -r '.github_issue_number // "N/A"')
                local status=$(echo "$entity" | jq -r '.status')
                local synced_at=$(echo "$entity" | jq -r '.github_synced_at // "never"')

                local icon="✓"
                [[ "$status" == "pending" ]] && icon="⟳"
                [[ "$status" == "never" ]] && icon="⚠"
                [[ "$status" == "conflict" ]] && icon="⚠"

                local time_ago=""
                if [[ "$synced_at" != "never" ]]; then
                    time_ago=$(format_time_ago "$synced_at")
                fi

                if [[ "$issue" != "N/A" ]]; then
                    echo "  $icon $name (GH #$issue) - $status$([ -n "$time_ago" ] && echo " ($time_ago)")"
                else
                    echo "  $icon $name - $status"
                fi
            done
            ;;
        epic)
            local current_prd=""
            echo "$details" | jq -c '.[]' | while read -r entity; do
                local prd_name=$(echo "$entity" | jq -r '.prd_name')
                local name=$(echo "$entity" | jq -r '.name')
                local issue=$(echo "$entity" | jq -r '.github_issue_number // "N/A"')
                local status=$(echo "$entity" | jq -r '.status')
                local synced_at=$(echo "$entity" | jq -r '.github_synced_at // "never"')

                if [[ "$prd_name" != "$current_prd" ]]; then
                    [[ -n "$current_prd" ]] && echo ""
                    echo "  PRD: $prd_name"
                    current_prd="$prd_name"
                fi

                local icon="✓"
                [[ "$status" == "pending" ]] && icon="⟳"
                [[ "$status" == "never" ]] && icon="⚠"
                [[ "$status" == "conflict" ]] && icon="⚠"

                local time_ago=""
                if [[ "$synced_at" != "never" ]]; then
                    time_ago=$(format_time_ago "$synced_at")
                fi

                if [[ "$issue" != "N/A" ]]; then
                    echo "    $icon $name (GH #$issue) - $status$([ -n "$time_ago" ] && echo " ($time_ago)")"
                else
                    echo "    $icon $name - $status"
                fi
            done
            ;;
        task)
            local current_epic=""
            echo "$details" | jq -c '.[]' | while read -r entity; do
                local epic_name=$(echo "$entity" | jq -r '.epic_name')
                local task_num=$(echo "$entity" | jq -r '.task_number')
                local name=$(echo "$entity" | jq -r '.name')
                local issue=$(echo "$entity" | jq -r '.github_issue_number // "N/A"')
                local status=$(echo "$entity" | jq -r '.status')
                local synced_at=$(echo "$entity" | jq -r '.github_synced_at // "never"')

                if [[ "$epic_name" != "$current_epic" ]]; then
                    [[ -n "$current_epic" ]] && echo ""
                    echo "  Epic: $epic_name"
                    current_epic="$epic_name"
                fi

                local icon="✓"
                [[ "$status" == "pending" ]] && icon="⟳"
                [[ "$status" == "never" ]] && icon="⚠"
                [[ "$status" == "conflict" ]] && icon="⚠"

                local time_ago=""
                if [[ "$synced_at" != "never" ]]; then
                    time_ago=$(format_time_ago "$synced_at")
                fi

                if [[ "$issue" != "N/A" ]]; then
                    echo "    $icon ${task_num}. ${name} (GH #$issue) - $status$([ -n "$time_ago" ] && echo " ($time_ago)")"
                else
                    echo "    $icon ${task_num}. ${name} - $status"
                fi
            done
            ;;
    esac

    echo ""
}

# =============================================================================
# CLI Interface
# =============================================================================

show_help() {
    cat << EOF
GitHub Sync Status - Show sync status of all entities

Usage:
  $0 [options]

Options:
  --verbose              Show detailed status for all entities
  --conflicts            Show only conflicts
  --epic <name>          Filter by epic name
  --prd                  Show PRD details
  --epics                Show Epic details
  --tasks                Show Task details
  -h, --help             Show this help

Examples:
  $0                                 # Summary view
  $0 --verbose                       # Detailed view of all entities
  $0 --conflicts                     # Show only conflicts
  $0 --epics --epic user-auth        # Show epics in user-auth
  $0 --tasks --verbose               # Detailed task status

Legend:
  ✓ - Synced with GitHub
  ⟳ - Pending push to GitHub
  ⚠ - Never synced or has conflict

EOF
}

main() {
    local verbose="false"
    local show_conflicts="false"
    local show_prds="false"
    local show_epics="false"
    local show_tasks="false"
    local epic_filter=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose)
                verbose="true"
                show_prds="true"
                show_epics="true"
                show_tasks="true"
                shift
                ;;
            --conflicts)
                show_conflicts="true"
                shift
                ;;
            --prd)
                show_prds="true"
                shift
                ;;
            --epics)
                show_epics="true"
                shift
                ;;
            --tasks)
                show_tasks="true"
                shift
                ;;
            --epic)
                epic_filter="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done

    # Check prerequisites
    check_db || exit 1

    # Show conflicts only
    if [[ "$show_conflicts" == "true" ]]; then
        local conflicts
        conflicts=$(get_conflicts)
        display_conflicts "$conflicts"
        exit 0
    fi

    # Show summary by default
    if [[ "$show_prds" == "false" ]] && [[ "$show_epics" == "false" ]] && [[ "$show_tasks" == "false" ]]; then
        local summary
        summary=$(get_sync_summary)
        display_summary "$summary"
        exit 0
    fi

    # Show detailed status
    if [[ "$show_prds" == "true" ]]; then
        local details
        details=$(get_entity_details "prd")
        display_entity_details "prd" "$details"
    fi

    if [[ "$show_epics" == "true" ]]; then
        local details
        details=$(get_entity_details "epic" "$epic_filter")
        display_entity_details "epic" "$details"
    fi

    if [[ "$show_tasks" == "true" ]]; then
        local details
        details=$(get_entity_details "task" "$epic_filter")
        display_entity_details "task" "$details"
    fi
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
