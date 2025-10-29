#!/usr/bin/env bash
# GitHub Push - Sync local database changes to GitHub Issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/github-helpers.sh"

# =============================================================================
# Push Operations
# =============================================================================

# Push PRD to GitHub
push_prd() {
    local prd_id="$1"
    local dry_run="${2:-false}"

    # Get PRD details
    local prd_data
    prd_data=$("$QUERY_SCRIPT" "
        SELECT
            id, name, status, description, business_value,
            success_criteria, target_date, github_issue_number
        FROM ccpm.prds
        WHERE id = ${prd_id}
    " "json")

    if [[ -z "$prd_data" ]] || [[ "$prd_data" == "[]" ]]; then
        echo "Error: PRD ${prd_id} not found" >&2
        return 1
    fi

    local name=$(echo "$prd_data" | jq -r '.[0].name')
    local status=$(echo "$prd_data" | jq -r '.[0].status')
    local description=$(echo "$prd_data" | jq -r '.[0].description // ""')
    local business_value=$(echo "$prd_data" | jq -r '.[0].business_value // ""')
    local success_criteria=$(echo "$prd_data" | jq -r '.[0].success_criteria // ""')
    local target_date=$(echo "$prd_data" | jq -r '.[0].target_date // ""')
    local github_issue_number=$(echo "$prd_data" | jq -r '.[0].github_issue_number // ""')

    # Build issue title
    local title="PRD: ${name}"

    # Build issue body
    local body_content="# Product Requirements Document: ${name}

## Status
${status}

## Description
${description}

## Business Value
${business_value}

## Success Criteria
${success_criteria}

## Target Date
${target_date}
"

    local body
    body=$(build_issue_body "prd" "$prd_id" "$body_content" "ccpm_prd: ${name}
")

    # Dry run
    if [[ "$dry_run" == "true" ]]; then
        echo "Would push PRD '${name}' (ID: ${prd_id})"
        echo "  Title: ${title}"
        echo "  Action: $([ -z "$github_issue_number" ] && echo "Create new issue" || echo "Update issue #${github_issue_number}")"
        return 0
    fi

    # Create or update
    if [[ -z "$github_issue_number" ]]; then
        echo "Creating GitHub issue for PRD '${name}'..."
        github_issue_number=$(create_github_issue "$title" "$body" "prd,ccpm")

        if [[ -z "$github_issue_number" ]]; then
            echo "Error: Failed to create GitHub issue" >&2
            return 1
        fi

        echo "✓ Created issue #${github_issue_number}"
    else
        echo "Updating GitHub issue #${github_issue_number} for PRD '${name}'..."
        update_github_issue "$github_issue_number" "$title" "$body"
        echo "✓ Updated issue #${github_issue_number}"
    fi

    # Update database
    update_entity_github_info "prd" "$prd_id" "$github_issue_number"

    # Update sync metadata
    update_sync_metadata "prd" "$prd_id" "$github_issue_number" "synced"

    echo "✓ PRD '${name}' synced successfully"
}

# Push Epic to GitHub
push_epic() {
    local epic_id="$1"
    local dry_run="${2:-false}"

    # Get Epic details
    local epic_data
    epic_data=$("$QUERY_SCRIPT" "
        SELECT
            e.id, e.name, e.prd_id, p.name as prd_name, p.github_issue_number as prd_issue,
            e.status, e.description, e.progress, e.github_issue_number
        FROM ccpm.epics e
        JOIN ccpm.prds p ON e.prd_id = p.id
        WHERE e.id = ${epic_id}
    " "json")

    if [[ -z "$epic_data" ]] || [[ "$epic_data" == "[]" ]]; then
        echo "Error: Epic ${epic_id} not found" >&2
        return 1
    fi

    local name=$(echo "$epic_data" | jq -r '.[0].name')
    local prd_name=$(echo "$epic_data" | jq -r '.[0].prd_name')
    local prd_issue=$(echo "$epic_data" | jq -r '.[0].prd_issue // ""')
    local status=$(echo "$epic_data" | jq -r '.[0].status')
    local description=$(echo "$epic_data" | jq -r '.[0].description // ""')
    local progress=$(echo "$epic_data" | jq -r '.[0].progress // 0')
    local github_issue_number=$(echo "$epic_data" | jq -r '.[0].github_issue_number // ""')

    # Get tasks for this epic
    local tasks_data
    tasks_data=$("$QUERY_SCRIPT" "
        SELECT
            task_number, name, status, github_issue_number
        FROM ccpm.tasks
        WHERE epic_id = ${epic_id}
          AND deleted_at IS NULL
        ORDER BY task_number
    " "json")

    # Build task list
    local task_list=""
    if [[ -n "$tasks_data" ]] && [[ "$tasks_data" != "[]" ]]; then
        task_list="## Tasks\n\n"
        echo "$tasks_data" | jq -c '.[]' | while read -r task; do
            local task_num=$(echo "$task" | jq -r '.task_number')
            local task_name=$(echo "$task" | jq -r '.name')
            local task_status=$(echo "$task" | jq -r '.status')
            local task_issue=$(echo "$task" | jq -r '.github_issue_number // ""')

            local checkbox="[ ]"
            [[ "$task_status" == "closed" ]] && checkbox="[x]"

            if [[ -n "$task_issue" ]]; then
                task_list+="- ${checkbox} #${task_issue} - ${task_num}. ${task_name}\n"
            else
                task_list+="- ${checkbox} ${task_num}. ${task_name}\n"
            fi
        done
    fi

    # Build issue title
    local title="Epic: ${name}"

    # Build issue body
    local prd_link=""
    [[ -n "$prd_issue" ]] && prd_link="Related PRD: #${prd_issue}\n\n"

    local body_content="# Epic: ${name}

${prd_link}## Status
${status} (${progress}% complete)

## Description
${description}

${task_list}
"

    local body
    body=$(build_issue_body "epic" "$epic_id" "$body_content" "ccpm_prd: ${prd_name}
ccpm_epic: ${name}
")

    # Dry run
    if [[ "$dry_run" == "true" ]]; then
        echo "Would push Epic '${name}' (ID: ${epic_id})"
        echo "  Title: ${title}"
        echo "  Action: $([ -z "$github_issue_number" ] && echo "Create new issue" || echo "Update issue #${github_issue_number}")"
        return 0
    fi

    # Create or update
    if [[ -z "$github_issue_number" ]]; then
        echo "Creating GitHub issue for Epic '${name}'..."
        github_issue_number=$(create_github_issue "$title" "$body" "epic,ccpm")

        if [[ -z "$github_issue_number" ]]; then
            echo "Error: Failed to create GitHub issue" >&2
            return 1
        fi

        echo "✓ Created issue #${github_issue_number}"
    else
        echo "Updating GitHub issue #${github_issue_number} for Epic '${name}'..."
        update_github_issue "$github_issue_number" "$title" "$body"
        echo "✓ Updated issue #${github_issue_number}"
    fi

    # Update database
    update_entity_github_info "epic" "$epic_id" "$github_issue_number"

    # Update sync metadata
    update_sync_metadata "epic" "$epic_id" "$github_issue_number" "synced"

    echo "✓ Epic '${name}' synced successfully"
}

# Push Task to GitHub
push_task() {
    local task_id="$1"
    local dry_run="${2:-false}"

    # Get Task details
    local task_data
    task_data=$("$QUERY_SCRIPT" "
        SELECT
            t.id, t.task_number, t.name, t.status, t.description, t.epic_id,
            e.name as epic_name, e.github_issue_number as epic_issue,
            t.github_issue_number, t.estimated_hours, t.parallel
        FROM ccpm.tasks t
        JOIN ccpm.epics e ON t.epic_id = e.id
        WHERE t.id = ${task_id}
    " "json")

    if [[ -z "$task_data" ]] || [[ "$task_data" == "[]" ]]; then
        echo "Error: Task ${task_id} not found" >&2
        return 1
    fi

    local task_number=$(echo "$task_data" | jq -r '.[0].task_number')
    local name=$(echo "$task_data" | jq -r '.[0].name')
    local status=$(echo "$task_data" | jq -r '.[0].status')
    local description=$(echo "$task_data" | jq -r '.[0].description // ""')
    local epic_name=$(echo "$task_data" | jq -r '.[0].epic_name')
    local epic_issue=$(echo "$task_data" | jq -r '.[0].epic_issue // ""')
    local github_issue_number=$(echo "$task_data" | jq -r '.[0].github_issue_number // ""')
    local estimated_hours=$(echo "$task_data" | jq -r '.[0].estimated_hours // ""')
    local parallel=$(echo "$task_data" | jq -r '.[0].parallel // 0')

    # Get dependencies
    local deps_data
    deps_data=$("$QUERY_SCRIPT" "
        SELECT
            dt.task_number, dt.name, dt.github_issue_number
        FROM ccpm.task_dependencies td
        JOIN ccpm.tasks dt ON td.dependency_task_id = dt.id
        WHERE td.task_id = ${task_id}
        ORDER BY dt.task_number
    " "json")

    # Build dependencies list
    local deps_list=""
    if [[ -n "$deps_data" ]] && [[ "$deps_data" != "[]" ]]; then
        deps_list="## Dependencies\n\n"
        echo "$deps_data" | jq -c '.[]' | while read -r dep; do
            local dep_num=$(echo "$dep" | jq -r '.task_number')
            local dep_name=$(echo "$dep" | jq -r '.name')
            local dep_issue=$(echo "$dep" | jq -r '.github_issue_number // ""')

            if [[ -n "$dep_issue" ]]; then
                deps_list+="- Depends on: #${dep_issue} (${dep_num}. ${dep_name})\n"
            else
                deps_list+="- Depends on: ${dep_num}. ${dep_name}\n"
            fi
        done
    fi

    # Build issue title
    local title="Task: ${task_number}. ${name}"

    # Build issue body
    local epic_link=""
    [[ -n "$epic_issue" ]] && epic_link="Epic: #${epic_issue} (${epic_name})\n\n"

    local metadata=""
    [[ -n "$estimated_hours" ]] && metadata+="**Estimated Hours**: ${estimated_hours}\n"
    [[ "$parallel" == "1" ]] && metadata+="**Parallel Execution**: Yes\n"

    local body_content="# Task ${task_number}: ${name}

${epic_link}## Status
${status}

${metadata}

## Description
${description}

${deps_list}
"

    local body
    body=$(build_issue_body "task" "$task_id" "$body_content" "ccpm_epic: ${epic_name}
ccpm_task_number: ${task_number}
")

    # Dry run
    if [[ "$dry_run" == "true" ]]; then
        echo "Would push Task '${task_number}. ${name}' (ID: ${task_id})"
        echo "  Title: ${title}"
        echo "  Action: $([ -z "$github_issue_number" ] && echo "Create new issue" || echo "Update issue #${github_issue_number}")"
        return 0
    fi

    # Create or update
    if [[ -z "$github_issue_number" ]]; then
        echo "Creating GitHub issue for Task '${task_number}. ${name}'..."
        github_issue_number=$(create_github_issue "$title" "$body" "task,ccpm")

        if [[ -z "$github_issue_number" ]]; then
            echo "Error: Failed to create GitHub issue" >&2
            return 1
        fi

        echo "✓ Created issue #${github_issue_number}"
    else
        echo "Updating GitHub issue #${github_issue_number} for Task '${task_number}. ${name}'..."
        update_github_issue "$github_issue_number" "$title" "$body"
        echo "✓ Updated issue #${github_issue_number}"
    fi

    # Update database
    update_entity_github_info "task" "$task_id" "$github_issue_number"

    # Update sync metadata
    update_sync_metadata "task" "$task_id" "$github_issue_number" "synced"

    echo "✓ Task '${task_number}. ${name}' synced successfully"
}

# =============================================================================
# Main Push Logic
# =============================================================================

push_all() {
    local entity_type="$1"
    local epic_filter="${2:-}"
    local dry_run="${3:-false}"

    check_gh_cli || return 1
    check_db || return 1

    echo "Finding ${entity_type}s pending sync..."

    # Get pending entities
    local pending
    pending=$(get_pending_sync "$entity_type" "$epic_filter")

    if [[ -z "$pending" ]] || [[ "$pending" == "[]" ]]; then
        echo "No ${entity_type}s pending sync"
        return 0
    fi

    local count
    count=$(echo "$pending" | jq 'length')

    echo "Found $count ${entity_type}(s) to push"
    echo ""

    # Push each entity
    local pushed=0
    local failed=0

    echo "$pending" | jq -c '.[]' | while read -r entity; do
        local id=$(echo "$entity" | jq -r '.id')
        local name=$(echo "$entity" | jq -r '.name // .task_number')

        echo "--- Pushing ${entity_type} '${name}' (ID: ${id}) ---"

        if "push_${entity_type}" "$id" "$dry_run"; then
            ((pushed++)) || true
        else
            ((failed++)) || true
            echo "✗ Failed to push ${entity_type} ${id}"
        fi

        echo ""
    done

    if [[ "$dry_run" == "true" ]]; then
        echo "Dry run complete. Would push ${count} ${entity_type}(s)"
    else
        echo "Push complete: ${pushed} succeeded, ${failed} failed"
    fi
}

# =============================================================================
# CLI Interface
# =============================================================================

show_help() {
    cat << EOF
GitHub Push - Sync local database to GitHub Issues

Usage:
  $0 <entity-type> [options]

Entity Types:
  prd                    Push PRDs
  epic                   Push Epics
  task                   Push Tasks
  all                    Push all entities (PRDs, then Epics, then Tasks)

Options:
  --epic <name>          Only push entities in this epic
  --id <id>              Push specific entity by ID
  --dry-run              Preview changes without pushing
  --yes                  Skip confirmation prompts
  -h, --help             Show this help

Examples:
  $0 prd --dry-run                    # Preview PRD pushes
  $0 epic --epic user-auth            # Push single epic
  $0 task --id 42                     # Push specific task
  $0 all --yes                        # Push everything without prompts

EOF
}

main() {
    local entity_type="${1:-}"
    local epic_filter=""
    local entity_id=""
    local dry_run="false"
    local auto_yes="false"

    shift || true

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --epic)
                epic_filter="$2"
                shift 2
                ;;
            --id)
                entity_id="$2"
                shift 2
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

    # Validate entity type
    case "$entity_type" in
        prd|epic|task)
            ;;
        all)
            entity_type="all"
            ;;
        ""|"-h"|"--help")
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown entity type: $entity_type" >&2
            show_help
            exit 1
            ;;
    esac

    # Check prerequisites
    check_gh_cli || exit 1
    check_db || exit 1

    # Confirm action
    if [[ "$dry_run" != "true" ]] && [[ "$auto_yes" != "true" ]]; then
        if ! confirm_action "Push ${entity_type}(s) to GitHub?"; then
            echo "Cancelled"
            exit 0
        fi
    fi

    # Push specific entity by ID
    if [[ -n "$entity_id" ]]; then
        if [[ "$entity_type" == "all" ]]; then
            echo "Error: Cannot use --id with 'all'" >&2
            exit 1
        fi

        "push_${entity_type}" "$entity_id" "$dry_run"
        exit $?
    fi

    # Push all entities
    if [[ "$entity_type" == "all" ]]; then
        echo "=== Pushing PRDs ==="
        push_all "prd" "" "$dry_run"
        echo ""

        echo "=== Pushing Epics ==="
        push_all "epic" "$epic_filter" "$dry_run"
        echo ""

        echo "=== Pushing Tasks ==="
        push_all "task" "$epic_filter" "$dry_run"
    else
        push_all "$entity_type" "$epic_filter" "$dry_run"
    fi
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
