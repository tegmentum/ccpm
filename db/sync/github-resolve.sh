#!/usr/bin/env bash
# GitHub Conflict Resolution - Resolve sync conflicts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/github-helpers.sh"

PUSH_SCRIPT="$SCRIPT_DIR/github-push.sh"
PULL_SCRIPT="$SCRIPT_DIR/github-pull.sh"

# =============================================================================
# Conflict Resolution Operations
# =============================================================================

# Resolve conflict by using local version
resolve_use_local() {
    local entity_type="$1"
    local entity_id="$2"
    local dry_run="${3:-false}"

    # Get conflict details
    local metadata
    metadata=$(get_sync_metadata "$entity_type" "$entity_id")

    if [[ -z "$metadata" ]] || [[ "$metadata" == "[]" ]]; then
        echo "Error: No sync metadata found for ${entity_type} ${entity_id}" >&2
        return 1
    fi

    local sync_status=$(echo "$metadata" | jq -r '.[0].sync_status')
    local github_issue_number=$(echo "$metadata" | jq -r '.[0].github_issue_number')

    if [[ "$sync_status" != "conflict" ]]; then
        echo "Error: ${entity_type} ${entity_id} is not in conflict state (status: ${sync_status})" >&2
        return 1
    fi

    # Get entity name
    local entity_name
    case "$entity_type" in
        prd)
            entity_name=$("$QUERY_SCRIPT" "SELECT name FROM ccpm.prds WHERE id = ${entity_id}" "csv" | tail -1)
            ;;
        epic)
            entity_name=$("$QUERY_SCRIPT" "SELECT name FROM ccpm.epics WHERE id = ${entity_id}" "csv" | tail -1)
            ;;
        task)
            entity_name=$("$QUERY_SCRIPT" "SELECT task_number || '. ' || name FROM ccpm.tasks WHERE id = ${entity_id}" "csv" | tail -1)
            ;;
    esac

    if [[ "$dry_run" == "true" ]]; then
        echo "Would resolve conflict for ${entity_type} '${entity_name}' (ID: ${entity_id})"
        echo "  Strategy: Use local version"
        echo "  Action: Push to GitHub issue #${github_issue_number}"
        return 0
    fi

    echo "Resolving conflict for ${entity_type} '${entity_name}' using local version..."

    # Push local version to GitHub (overwrite)
    source "$PUSH_SCRIPT"
    if "push_${entity_type}" "$entity_id" "false"; then
        echo "✓ Conflict resolved - local version pushed to GitHub"

        # Update sync metadata
        local now
        now=$(date -u +"%Y-%m-%d %H:%M:%S")

        "$QUERY_SCRIPT" "
            UPDATE ccpm.sync_metadata
            SET sync_status = 'synced',
                conflict_reason = NULL,
                last_synced_at = '${now}',
                updated_at = '${now}'
            WHERE entity_type = '${entity_type}'
              AND entity_id = ${entity_id}
        " "csv" > /dev/null

        return 0
    else
        echo "✗ Failed to push local version" >&2
        return 1
    fi
}

# Resolve conflict by using GitHub version
resolve_use_github() {
    local entity_type="$1"
    local entity_id="$2"
    local dry_run="${3:-false}"

    # Get conflict details
    local metadata
    metadata=$(get_sync_metadata "$entity_type" "$entity_id")

    if [[ -z "$metadata" ]] || [[ "$metadata" == "[]" ]]; then
        echo "Error: No sync metadata found for ${entity_type} ${entity_id}" >&2
        return 1
    fi

    local sync_status=$(echo "$metadata" | jq -r '.[0].sync_status')
    local github_issue_number=$(echo "$metadata" | jq -r '.[0].github_issue_number')

    if [[ "$sync_status" != "conflict" ]]; then
        echo "Error: ${entity_type} ${entity_id} is not in conflict state (status: ${sync_status})" >&2
        return 1
    fi

    # Get entity name
    local entity_name
    case "$entity_type" in
        prd)
            entity_name=$("$QUERY_SCRIPT" "SELECT name FROM ccpm.prds WHERE id = ${entity_id}" "csv" | tail -1)
            ;;
        epic)
            entity_name=$("$QUERY_SCRIPT" "SELECT name FROM ccpm.epics WHERE id = ${entity_id}" "csv" | tail -1)
            ;;
        task)
            entity_name=$("$QUERY_SCRIPT" "SELECT task_number || '. ' || name FROM ccpm.tasks WHERE id = ${entity_id}" "csv" | tail -1)
            ;;
    esac

    if [[ "$dry_run" == "true" ]]; then
        echo "Would resolve conflict for ${entity_type} '${entity_name}' (ID: ${entity_id})"
        echo "  Strategy: Use GitHub version"
        echo "  Action: Pull from GitHub issue #${github_issue_number}"
        return 0
    fi

    echo "Resolving conflict for ${entity_type} '${entity_name}' using GitHub version..."

    # Temporarily clear conflict status to allow pull
    "$QUERY_SCRIPT" "
        UPDATE ccpm.sync_metadata
        SET sync_status = 'synced'
        WHERE entity_type = '${entity_type}'
          AND entity_id = ${entity_id}
    " "csv" > /dev/null

    # Pull GitHub version to database (overwrite)
    source "$PULL_SCRIPT"
    if "pull_${entity_type}" "$github_issue_number" "false"; then
        echo "✓ Conflict resolved - GitHub version pulled to database"
        return 0
    else
        echo "✗ Failed to pull GitHub version" >&2

        # Restore conflict status
        "$QUERY_SCRIPT" "
            UPDATE ccpm.sync_metadata
            SET sync_status = 'conflict'
            WHERE entity_type = '${entity_type}'
              AND entity_id = ${entity_id}
        " "csv" > /dev/null

        return 1
    fi
}

# Show conflict details for manual resolution
show_conflict_details() {
    local entity_type="$1"
    local entity_id="$2"

    # Get conflict metadata
    local metadata
    metadata=$(get_sync_metadata "$entity_type" "$entity_id")

    if [[ -z "$metadata" ]] || [[ "$metadata" == "[]" ]]; then
        echo "Error: No sync metadata found for ${entity_type} ${entity_id}" >&2
        return 1
    fi

    local sync_status=$(echo "$metadata" | jq -r '.[0].sync_status')
    local github_issue_number=$(echo "$metadata" | jq -r '.[0].github_issue_number')
    local local_updated_at=$(echo "$metadata" | jq -r '.[0].local_updated_at')
    local github_updated_at=$(echo "$metadata" | jq -r '.[0].github_updated_at')
    local last_synced_at=$(echo "$metadata" | jq -r '.[0].last_synced_at // "never"')
    local conflict_reason=$(echo "$metadata" | jq -r '.[0].conflict_reason // "Unknown"')

    # Get entity details
    local entity_data
    case "$entity_type" in
        prd)
            entity_data=$("$QUERY_SCRIPT" "
                SELECT name, status, description
                FROM ccpm.prds WHERE id = ${entity_id}
            " "json")
            ;;
        epic)
            entity_data=$("$QUERY_SCRIPT" "
                SELECT name, status, description, progress
                FROM ccpm.epics WHERE id = ${entity_id}
            " "json")
            ;;
        task)
            entity_data=$("$QUERY_SCRIPT" "
                SELECT task_number, name, status, description
                FROM ccpm.tasks WHERE id = ${entity_id}
            " "json")
            ;;
    esac

    local entity_name=$(echo "$entity_data" | jq -r '.[0].name')

    echo "Conflict Details"
    echo "================"
    echo ""
    echo "Entity: ${entity_type} #${entity_id} - ${entity_name}"
    echo "GitHub Issue: #${github_issue_number}"
    echo "Status: ${sync_status}"
    echo ""
    echo "Timestamps:"
    echo "  Last synced: ${last_synced_at}"
    echo "  Local updated: ${local_updated_at}"
    echo "  GitHub updated: ${github_updated_at}"
    echo ""
    echo "Reason: ${conflict_reason}"
    echo ""
    echo "Resolution Options:"
    echo "  1. Use local version (overwrite GitHub):"
    echo "     pm sync resolve ${entity_type} ${entity_id} --use-local"
    echo ""
    echo "  2. Use GitHub version (overwrite local):"
    echo "     pm sync resolve ${entity_type} ${entity_id} --use-github"
    echo ""
    echo "  3. Manually merge changes:"
    echo "     - View GitHub: gh issue view ${github_issue_number}"
    echo "     - Edit local: pm epic-show ${entity_name}  # or appropriate command"
    echo "     - Then use option 1 or 2 to sync"
    echo ""
}

# Resolve all conflicts with same strategy
resolve_all_conflicts() {
    local strategy="$1"  # 'local' or 'github'
    local dry_run="${2:-false}"

    check_db || return 1

    # Get all conflicts
    local conflicts
    conflicts=$(get_conflicts)

    if [[ -z "$conflicts" ]] || [[ "$conflicts" == "[]" ]]; then
        echo "No conflicts to resolve"
        return 0
    fi

    local count
    count=$(echo "$conflicts" | jq 'length')

    echo "Found $count conflict(s)"
    echo ""

    if [[ "$dry_run" == "true" ]]; then
        echo "Would resolve all conflicts using ${strategy} version"
        echo "$conflicts" | jq -c '.[]' | while read -r conflict; do
            local entity_type=$(echo "$conflict" | jq -r '.entity_type')
            local entity_id=$(echo "$conflict" | jq -r '.entity_id')
            local entity_name=$(echo "$conflict" | jq -r '.entity_name')
            echo "  - ${entity_type} ${entity_id}: ${entity_name}"
        done
        return 0
    fi

    # Resolve each conflict
    local resolved=0
    local failed=0

    echo "$conflicts" | jq -c '.[]' | while read -r conflict; do
        local entity_type=$(echo "$conflict" | jq -r '.entity_type')
        local entity_id=$(echo "$conflict" | jq -r '.entity_id')
        local entity_name=$(echo "$conflict" | jq -r '.entity_name')

        echo "--- Resolving ${entity_type} ${entity_id}: ${entity_name} ---"

        if [[ "$strategy" == "local" ]]; then
            if resolve_use_local "$entity_type" "$entity_id" "false"; then
                ((resolved++)) || true
            else
                ((failed++)) || true
            fi
        else
            if resolve_use_github "$entity_type" "$entity_id" "false"; then
                ((resolved++)) || true
            else
                ((failed++)) || true
            fi
        fi

        echo ""
    done

    echo "Resolution complete: ${resolved} resolved, ${failed} failed"
}

# =============================================================================
# CLI Interface
# =============================================================================

show_help() {
    cat << EOF
GitHub Conflict Resolution

Usage:
  $0 <entity-type> <entity-id> <strategy> [options]
  $0 all <strategy> [options]

Entity Types:
  prd                    Resolve PRD conflict
  epic                   Resolve Epic conflict
  task                   Resolve Task conflict
  all                    Resolve all conflicts

Strategies:
  --use-local            Use local version (push to GitHub)
  --use-github           Use GitHub version (pull to database)
  --show                 Show conflict details without resolving

Options:
  --dry-run              Preview resolution without executing
  --yes                  Skip confirmation prompts
  -h, --help             Show this help

Examples:
  $0 epic 42 --show                  # Show conflict details
  $0 epic 42 --use-local             # Use local version
  $0 task 15 --use-github --dry-run  # Preview using GitHub version
  $0 all --use-local --yes           # Resolve all with local versions

EOF
}

main() {
    local entity_type="${1:-}"
    local entity_id="${2:-}"
    local strategy=""
    local show_details="false"
    local dry_run="false"
    local auto_yes="false"

    # Validate entity type
    if [[ -z "$entity_type" ]]; then
        show_help
        exit 1
    fi

    case "$entity_type" in
        prd|epic|task|all)
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown entity type: $entity_type" >&2
            show_help
            exit 1
            ;;
    esac

    # For 'all', shift only once; for specific entity, need ID
    if [[ "$entity_type" == "all" ]]; then
        shift
    else
        # Need entity ID for specific entity
        if [[ -z "$entity_id" ]]; then
            echo "Error: Entity ID required for ${entity_type}" >&2
            show_help
            exit 1
        fi
        shift 2
    fi

    # Parse remaining arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --use-local)
                strategy="local"
                shift
                ;;
            --use-github)
                strategy="github"
                shift
                ;;
            --show)
                show_details="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --yes)
                auto_yes="true"
                shift
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

    # Show details only
    if [[ "$show_details" == "true" ]]; then
        if [[ "$entity_type" == "all" ]]; then
            echo "Error: Cannot use --show with 'all'" >&2
            exit 1
        fi
        show_conflict_details "$entity_type" "$entity_id"
        exit 0
    fi

    # Validate strategy
    if [[ -z "$strategy" ]]; then
        echo "Error: Strategy required (--use-local or --use-github)" >&2
        show_help
        exit 1
    fi

    # Confirm action
    if [[ "$dry_run" != "true" ]] && [[ "$auto_yes" != "true" ]]; then
        local msg
        if [[ "$entity_type" == "all" ]]; then
            msg="Resolve all conflicts using ${strategy} version?"
        else
            msg="Resolve ${entity_type} ${entity_id} using ${strategy} version?"
        fi

        if ! confirm_action "$msg"; then
            echo "Cancelled"
            exit 0
        fi
    fi

    # Resolve conflicts
    if [[ "$entity_type" == "all" ]]; then
        resolve_all_conflicts "$strategy" "$dry_run"
    else
        if [[ "$strategy" == "local" ]]; then
            resolve_use_local "$entity_type" "$entity_id" "$dry_run"
        else
            resolve_use_github "$entity_type" "$entity_id" "$dry_run"
        fi
    fi
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
