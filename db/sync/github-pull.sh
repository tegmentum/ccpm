#!/usr/bin/env bash
# GitHub Pull - Sync GitHub Issues to local database

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/github-helpers.sh"

# =============================================================================
# Pull Operations
# =============================================================================

# Pull PRD from GitHub
pull_prd() {
    local issue_number="$1"
    local dry_run="${2:-false}"

    # Get issue from GitHub
    local issue_data
    issue_data=$(get_github_issue "$issue_number")

    if [[ -z "$issue_data" ]]; then
        echo "Error: Issue #${issue_number} not found on GitHub" >&2
        return 1
    fi

    local title=$(echo "$issue_data" | jq -r '.title')
    local body=$(echo "$issue_data" | jq -r '.body // ""')
    local state=$(echo "$issue_data" | jq -r '.state')
    local github_updated_at=$(echo "$issue_data" | jq -r '.updated_at')

    # Parse frontmatter
    local ccpm_entity=$(parse_frontmatter "$body" "ccpm_entity")
    local ccpm_id=$(parse_frontmatter "$body" "ccpm_id")
    local ccpm_prd=$(parse_frontmatter "$body" "ccpm_prd")

    # Validate it's a PRD
    if [[ "$ccpm_entity" != "prd" ]]; then
        echo "Error: Issue #${issue_number} is not a PRD (entity: ${ccpm_entity})" >&2
        return 1
    fi

    # Extract description sections
    local description=$(echo "$body" | sed -n '/^## Description$/,/^## /p' | sed '1d;$d' | sed '/^$/d')
    local business_value=$(echo "$body" | sed -n '/^## Business Value$/,/^## /p' | sed '1d;$d' | sed '/^$/d')
    local success_criteria=$(echo "$body" | sed -n '/^## Success Criteria$/,/^## /p' | sed '1d;$d' | sed '/^$/d')
    local target_date=$(echo "$body" | sed -n '/^## Target Date$/,/^## /p' | sed '1d;$d' | sed '/^$/d')

    # Map GitHub state to status
    local status="active"
    [[ "$state" == "closed" ]] && status="completed"

    # Dry run
    if [[ "$dry_run" == "true" ]]; then
        echo "Would pull PRD from issue #${issue_number}"
        echo "  Name: ${ccpm_prd}"
        echo "  Status: ${status}"
        echo "  Action: $([ -n "$ccpm_id" ] && echo "Update PRD ${ccpm_id}" || echo "Create new PRD")"
        return 0
    fi

    # Check if PRD exists
    if [[ -n "$ccpm_id" ]]; then
        # Check for conflicts
        local conflict_status
        conflict_status=$(detect_conflicts "prd" "$ccpm_id" "$github_updated_at")

        if [[ "$conflict_status" == "conflict" ]]; then
            echo "⚠ Conflict detected for PRD ${ccpm_id} (issue #${issue_number})"
            update_sync_metadata "prd" "$ccpm_id" "$issue_number" "conflict" "$github_updated_at" \
                "Both local and GitHub modified since last sync"
            return 2
        elif [[ "$conflict_status" == "local_newer" ]]; then
            echo "⟳ Local PRD ${ccpm_id} is newer, skipping pull"
            return 0
        fi

        # Update existing PRD
        echo "Updating PRD ${ccpm_id} from issue #${issue_number}..."

        "$QUERY_SCRIPT" "
            UPDATE ccpm.prds
            SET status = '${status}',
                description = '${description}',
                business_value = '${business_value}',
                success_criteria = '${success_criteria}',
                target_date = $([ -n "$target_date" ] && echo "'$target_date'" || echo "NULL"),
                github_synced_at = datetime('now'),
                updated_at = datetime('now')
            WHERE id = ${ccpm_id}
        " "csv" > /dev/null

        update_sync_metadata "prd" "$ccpm_id" "$issue_number" "synced" "$github_updated_at"

        echo "✓ PRD ${ccpm_id} updated"
    else
        # Create new PRD
        echo "Creating new PRD from issue #${issue_number}..."

        local new_id
        new_id=$("$QUERY_SCRIPT" "
            INSERT INTO ccpm.prds (
                name, status, description, business_value,
                success_criteria, target_date, github_issue_number,
                github_synced_at, created_at, updated_at
            ) VALUES (
                '${ccpm_prd}', '${status}', '${description}', '${business_value}',
                '${success_criteria}', $([ -n "$target_date" ] && echo "'$target_date'" || echo "NULL"), ${issue_number},
                datetime('now'), datetime('now'), datetime('now')
            ) RETURNING id
        " "csv" | tail -1)

        update_sync_metadata "prd" "$new_id" "$issue_number" "synced" "$github_updated_at"

        echo "✓ Created PRD ${new_id}"
    fi
}

# Pull Epic from GitHub
pull_epic() {
    local issue_number="$1"
    local dry_run="${2:-false}"

    # Get issue from GitHub
    local issue_data
    issue_data=$(get_github_issue "$issue_number")

    if [[ -z "$issue_data" ]]; then
        echo "Error: Issue #${issue_number} not found on GitHub" >&2
        return 1
    fi

    local title=$(echo "$issue_data" | jq -r '.title')
    local body=$(echo "$issue_data" | jq -r '.body // ""')
    local state=$(echo "$issue_data" | jq -r '.state')
    local github_updated_at=$(echo "$issue_data" | jq -r '.updated_at')

    # Parse frontmatter
    local ccpm_entity=$(parse_frontmatter "$body" "ccpm_entity")
    local ccpm_id=$(parse_frontmatter "$body" "ccpm_id")
    local ccpm_epic=$(parse_frontmatter "$body" "ccpm_epic")
    local ccpm_prd=$(parse_frontmatter "$body" "ccpm_prd")

    # Validate it's an Epic
    if [[ "$ccpm_entity" != "epic" ]]; then
        echo "Error: Issue #${issue_number} is not an Epic (entity: ${ccpm_entity})" >&2
        return 1
    fi

    # Get PRD ID
    local prd_id
    prd_id=$("$QUERY_SCRIPT" "
        SELECT id FROM ccpm.prds WHERE name = '${ccpm_prd}' AND deleted_at IS NULL
    " "csv" | tail -1)

    if [[ -z "$prd_id" ]]; then
        echo "Error: PRD '${ccpm_prd}' not found in database" >&2
        return 1
    fi

    # Extract description
    local description=$(echo "$body" | sed -n '/^## Description$/,/^## /p' | sed '1d;$d' | sed '/^$/d')

    # Map GitHub state to status
    local status="active"
    case "$state" in
        closed) status="closed" ;;
        open)
            # Check if in progress or backlog based on content
            if echo "$body" | grep -q "Status.*in-progress"; then
                status="in-progress"
            else
                status="backlog"
            fi
            ;;
    esac

    # Dry run
    if [[ "$dry_run" == "true" ]]; then
        echo "Would pull Epic from issue #${issue_number}"
        echo "  Name: ${ccpm_epic}"
        echo "  PRD: ${ccpm_prd}"
        echo "  Status: ${status}"
        echo "  Action: $([ -n "$ccpm_id" ] && echo "Update Epic ${ccpm_id}" || echo "Create new Epic")"
        return 0
    fi

    # Check if Epic exists
    if [[ -n "$ccpm_id" ]]; then
        # Check for conflicts
        local conflict_status
        conflict_status=$(detect_conflicts "epic" "$ccpm_id" "$github_updated_at")

        if [[ "$conflict_status" == "conflict" ]]; then
            echo "⚠ Conflict detected for Epic ${ccpm_id} (issue #${issue_number})"
            update_sync_metadata "epic" "$ccpm_id" "$issue_number" "conflict" "$github_updated_at" \
                "Both local and GitHub modified since last sync"
            return 2
        elif [[ "$conflict_status" == "local_newer" ]]; then
            echo "⟳ Local Epic ${ccpm_id} is newer, skipping pull"
            return 0
        fi

        # Update existing Epic
        echo "Updating Epic ${ccpm_id} from issue #${issue_number}..."

        "$QUERY_SCRIPT" "
            UPDATE ccpm.epics
            SET status = '${status}',
                description = '${description}',
                github_synced_at = datetime('now'),
                updated_at = datetime('now')
            WHERE id = ${ccpm_id}
        " "csv" > /dev/null

        update_sync_metadata "epic" "$ccpm_id" "$issue_number" "synced" "$github_updated_at"

        echo "✓ Epic ${ccpm_id} updated"
    else
        # Create new Epic
        echo "Creating new Epic from issue #${issue_number}..."

        local new_id
        new_id=$("$QUERY_SCRIPT" "
            INSERT INTO ccpm.epics (
                prd_id, name, status, description,
                github_issue_number, github_synced_at,
                created_at, updated_at
            ) VALUES (
                ${prd_id}, '${ccpm_epic}', '${status}', '${description}',
                ${issue_number}, datetime('now'),
                datetime('now'), datetime('now')
            ) RETURNING id
        " "csv" | tail -1)

        update_sync_metadata "epic" "$new_id" "$issue_number" "synced" "$github_updated_at"

        echo "✓ Created Epic ${new_id}"
    fi
}

# Pull Task from GitHub
pull_task() {
    local issue_number="$1"
    local dry_run="${2:-false}"

    # Get issue from GitHub
    local issue_data
    issue_data=$(get_github_issue "$issue_number")

    if [[ -z "$issue_data" ]]; then
        echo "Error: Issue #${issue_number} not found on GitHub" >&2
        return 1
    fi

    local title=$(echo "$issue_data" | jq -r '.title')
    local body=$(echo "$issue_data" | jq -r '.body // ""')
    local state=$(echo "$issue_data" | jq -r '.state')
    local github_updated_at=$(echo "$issue_data" | jq -r '.updated_at')

    # Parse frontmatter
    local ccpm_entity=$(parse_frontmatter "$body" "ccpm_entity")
    local ccpm_id=$(parse_frontmatter "$body" "ccpm_id")
    local ccpm_epic=$(parse_frontmatter "$body" "ccpm_epic")
    local ccpm_task_number=$(parse_frontmatter "$body" "ccpm_task_number")

    # Validate it's a Task
    if [[ "$ccpm_entity" != "task" ]]; then
        echo "Error: Issue #${issue_number} is not a Task (entity: ${ccpm_entity})" >&2
        return 1
    fi

    # Get Epic ID
    local epic_id
    epic_id=$("$QUERY_SCRIPT" "
        SELECT id FROM ccpm.epics WHERE name = '${ccpm_epic}' AND deleted_at IS NULL
    " "csv" | tail -1)

    if [[ -z "$epic_id" ]]; then
        echo "Error: Epic '${ccpm_epic}' not found in database" >&2
        return 1
    fi

    # Extract description
    local description=$(echo "$body" | sed -n '/^## Description$/,/^## /p' | sed '1d;$d' | sed '/^$/d')

    # Extract metadata
    local estimated_hours=$(echo "$body" | sed -n 's/^.*Estimated Hours\*\*: \([0-9]*\).*$/\1/p' | head -1)
    local parallel=$(echo "$body" | grep -q "Parallel Execution.*: Yes" && echo "1" || echo "0")

    # Extract task name from title (format: "Task: 1. Task name")
    local task_name=$(echo "$title" | sed 's/^Task: [0-9]*\. //')

    # Map GitHub state to status
    local status="open"
    case "$state" in
        closed) status="closed" ;;
        open) status="open" ;;
    esac

    # Dry run
    if [[ "$dry_run" == "true" ]]; then
        echo "Would pull Task from issue #${issue_number}"
        echo "  Task: ${ccpm_task_number}. ${task_name}"
        echo "  Epic: ${ccpm_epic}"
        echo "  Status: ${status}"
        echo "  Action: $([ -n "$ccpm_id" ] && echo "Update Task ${ccpm_id}" || echo "Create new Task")"
        return 0
    fi

    # Check if Task exists
    if [[ -n "$ccpm_id" ]]; then
        # Check for conflicts
        local conflict_status
        conflict_status=$(detect_conflicts "task" "$ccpm_id" "$github_updated_at")

        if [[ "$conflict_status" == "conflict" ]]; then
            echo "⚠ Conflict detected for Task ${ccpm_id} (issue #${issue_number})"
            update_sync_metadata "task" "$ccpm_id" "$issue_number" "conflict" "$github_updated_at" \
                "Both local and GitHub modified since last sync"
            return 2
        elif [[ "$conflict_status" == "local_newer" ]]; then
            echo "⟳ Local Task ${ccpm_id} is newer, skipping pull"
            return 0
        fi

        # Update existing Task
        echo "Updating Task ${ccpm_id} from issue #${issue_number}..."

        "$QUERY_SCRIPT" "
            UPDATE ccpm.tasks
            SET status = '${status}',
                name = '${task_name}',
                description = '${description}',
                estimated_hours = $([ -n "$estimated_hours" ] && echo "$estimated_hours" || echo "NULL"),
                parallel = ${parallel},
                github_synced_at = datetime('now'),
                updated_at = datetime('now')
            WHERE id = ${ccpm_id}
        " "csv" > /dev/null

        update_sync_metadata "task" "$ccpm_id" "$issue_number" "synced" "$github_updated_at"

        echo "✓ Task ${ccpm_id} updated"
    else
        # Create new Task
        echo "Creating new Task from issue #${issue_number}..."

        local new_id
        new_id=$("$QUERY_SCRIPT" "
            INSERT INTO ccpm.tasks (
                epic_id, task_number, name, status, description,
                estimated_hours, parallel, github_issue_number,
                github_synced_at, created_at, updated_at
            ) VALUES (
                ${epic_id}, ${ccpm_task_number}, '${task_name}', '${status}', '${description}',
                $([ -n "$estimated_hours" ] && echo "$estimated_hours" || echo "NULL"), ${parallel}, ${issue_number},
                datetime('now'), datetime('now'), datetime('now')
            ) RETURNING id
        " "csv" | tail -1)

        update_sync_metadata "task" "$new_id" "$issue_number" "synced" "$github_updated_at"

        echo "✓ Created Task ${new_id}"
    fi
}

# =============================================================================
# Main Pull Logic
# =============================================================================

pull_by_label() {
    local label="$1"
    local entity_type="$2"
    local since="${3:-}"
    local dry_run="${4:-false}"

    check_gh_cli || return 1
    check_db || return 1

    echo "Fetching ${label} issues from GitHub..."

    # Get issues from GitHub
    local issues
    issues=$(list_github_issues "$label" "$since")

    if [[ -z "$issues" ]]; then
        echo "No ${label} issues found on GitHub"
        return 0
    fi

    local count
    count=$(echo "$issues" | jq -s 'length')

    echo "Found $count ${label} issue(s)"
    echo ""

    # Pull each issue
    local pulled=0
    local skipped=0
    local conflicts=0
    local failed=0

    echo "$issues" | jq -c '.' | while read -r issue; do
        local number=$(echo "$issue" | jq -r '.number')
        local title=$(echo "$issue" | jq -r '.title')

        echo "--- Pulling issue #${number}: ${title} ---"

        local result=0
        "pull_${entity_type}" "$number" "$dry_run" || result=$?

        case $result in
            0) ((pulled++)) || true ;;
            1) ((failed++)) || true ;;
            2) ((conflicts++)) || true ;;
        esac

        echo ""
    done

    if [[ "$dry_run" == "true" ]]; then
        echo "Dry run complete. Would pull ${count} ${label}(s)"
    else
        echo "Pull complete: ${pulled} pulled, ${skipped} skipped, ${conflicts} conflicts, ${failed} failed"
    fi
}

pull_all() {
    local since="${1:-}"
    local dry_run="${2:-false}"

    echo "=== Pulling PRDs ==="
    pull_by_label "prd" "prd" "$since" "$dry_run"
    echo ""

    echo "=== Pulling Epics ==="
    pull_by_label "epic" "epic" "$since" "$dry_run"
    echo ""

    echo "=== Pulling Tasks ==="
    pull_by_label "task" "task" "$since" "$dry_run"
}

# =============================================================================
# CLI Interface
# =============================================================================

show_help() {
    cat << EOF
GitHub Pull - Sync GitHub Issues to local database

Usage:
  $0 <entity-type> [options]

Entity Types:
  prd                    Pull PRDs
  epic                   Pull Epics
  task                   Pull Tasks
  all                    Pull all entities (PRDs, then Epics, then Tasks)

Options:
  --issue <number>       Pull specific issue by number
  --since <timestamp>    Only pull issues updated since timestamp (ISO 8601)
  --dry-run              Preview changes without pulling
  --yes                  Skip confirmation prompts
  -h, --help             Show this help

Examples:
  $0 prd --dry-run                         # Preview PRD pulls
  $0 epic --since 2025-01-25T10:00:00Z     # Pull recent epics
  $0 task --issue 123                      # Pull specific task
  $0 all --yes                             # Pull everything without prompts

EOF
}

main() {
    local entity_type="${1:-}"
    local issue_number=""
    local since=""
    local dry_run="false"
    local auto_yes="false"

    shift || true

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --issue)
                issue_number="$2"
                shift 2
                ;;
            --since)
                since="$2"
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
        if ! confirm_action "Pull ${entity_type}(s) from GitHub?"; then
            echo "Cancelled"
            exit 0
        fi
    fi

    # Pull specific issue by number
    if [[ -n "$issue_number" ]]; then
        if [[ "$entity_type" == "all" ]]; then
            echo "Error: Cannot use --issue with 'all'" >&2
            exit 1
        fi

        "pull_${entity_type}" "$issue_number" "$dry_run"
        exit $?
    fi

    # Pull all entities by label
    if [[ "$entity_type" == "all" ]]; then
        pull_all "$since" "$dry_run"
    else
        pull_by_label "$entity_type" "$entity_type" "$since" "$dry_run"
    fi
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
