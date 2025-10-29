#!/usr/bin/env bash
# GitHub Sync Helper Functions
# Shared utilities for GitHub sync operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
QUERY_SCRIPT="$DB_DIR/query.sh"
HELPERS_SCRIPT="$DB_DIR/helpers.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# =============================================================================
# Configuration
# =============================================================================

# GitHub CLI check
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        echo "Error: GitHub CLI (gh) not found. Install from: https://cli.github.com" >&2
        return 1
    fi

    # Check authentication
    if ! gh auth status &> /dev/null; then
        echo "Error: Not authenticated with GitHub. Run: gh auth login" >&2
        return 1
    fi

    return 0
}

# Get repository info
get_repo_info() {
    gh repo view --json owner,name --jq '{owner: .owner.login, name: .name}'
}

# =============================================================================
# Sync Metadata Operations
# =============================================================================

# Get sync metadata for entity
get_sync_metadata() {
    local entity_type="$1"
    local entity_id="$2"

    check_db || return 1

    "$QUERY_SCRIPT" "
        SELECT
            github_issue_number,
            local_updated_at,
            github_updated_at,
            sync_status,
            last_synced_at,
            conflict_reason
        FROM ccpm.sync_metadata
        WHERE entity_type = '${entity_type}'
          AND entity_id = ${entity_id}
        ORDER BY created_at DESC
        LIMIT 1
    " "json"
}

# Update sync metadata
update_sync_metadata() {
    local entity_type="$1"
    local entity_id="$2"
    local github_issue_number="$3"
    local sync_status="$4"
    local github_updated_at="${5:-}"
    local conflict_reason="${6:-}"

    check_db || return 1

    local now
    now=$(date -u +"%Y-%m-%d %H:%M:%S")

    # Get local updated_at
    local local_updated_at
    local_updated_at=$("$QUERY_SCRIPT" "
        SELECT updated_at FROM ccpm.${entity_type}s WHERE id = ${entity_id}
    " "csv" | tail -1)

    # Check if metadata exists
    local exists
    exists=$("$QUERY_SCRIPT" "
        SELECT COUNT(*) FROM ccpm.sync_metadata
        WHERE entity_type = '${entity_type}' AND entity_id = ${entity_id}
    " "csv" | tail -1)

    if [[ "$exists" -gt 0 ]]; then
        # Update existing
        "$QUERY_SCRIPT" "
            UPDATE ccpm.sync_metadata
            SET github_issue_number = ${github_issue_number},
                local_updated_at = '${local_updated_at}',
                github_updated_at = $([ -n "$github_updated_at" ] && echo "'$github_updated_at'" || echo "github_updated_at"),
                sync_status = '${sync_status}',
                last_synced_at = '${now}',
                conflict_reason = $([ -n "$conflict_reason" ] && echo "'$conflict_reason'" || echo "NULL"),
                updated_at = '${now}'
            WHERE entity_type = '${entity_type}' AND entity_id = ${entity_id}
        " "csv" > /dev/null
    else
        # Insert new
        "$QUERY_SCRIPT" "
            INSERT INTO ccpm.sync_metadata (
                entity_type, entity_id, github_issue_number,
                local_updated_at, github_updated_at, sync_status,
                last_synced_at, conflict_reason,
                created_at, updated_at
            ) VALUES (
                '${entity_type}', ${entity_id}, ${github_issue_number},
                '${local_updated_at}', $([ -n "$github_updated_at" ] && echo "'$github_updated_at'" || echo "NULL"), '${sync_status}',
                '${now}', $([ -n "$conflict_reason" ] && echo "'$conflict_reason'" || echo "NULL"),
                '${now}', '${now}'
            )
        " "csv" > /dev/null
    fi
}

# =============================================================================
# GitHub Issue Operations
# =============================================================================

# Create GitHub issue
create_github_issue() {
    local title="$1"
    local body="$2"
    local labels="$3"     # Comma-separated
    local milestone="${4:-}"

    check_gh_cli || return 1

    local cmd="gh issue create --title \"$title\" --body \"$body\""

    # Add labels
    if [[ -n "$labels" ]]; then
        IFS=',' read -ra label_array <<< "$labels"
        for label in "${label_array[@]}"; do
            cmd+=" --label \"$label\""
        done
    fi

    # Add milestone
    if [[ -n "$milestone" ]]; then
        cmd+=" --milestone \"$milestone\""
    fi

    # Execute and extract issue number
    eval "$cmd" | grep -oE '#[0-9]+' | tr -d '#'
}

# Update GitHub issue
update_github_issue() {
    local issue_number="$1"
    local title="$2"
    local body="$3"

    check_gh_cli || return 1

    gh issue edit "$issue_number" \
        --title "$title" \
        --body "$body"
}

# Get GitHub issue details
get_github_issue() {
    local issue_number="$1"

    check_gh_cli || return 1

    gh issue view "$issue_number" \
        --json number,title,body,state,updatedAt,labels \
        --jq '{
            number: .number,
            title: .title,
            body: .body,
            state: .state,
            updated_at: .updatedAt,
            labels: [.labels[].name] | join(",")
        }'
}

# List GitHub issues with label
list_github_issues() {
    local label="$1"
    local since="${2:-}"  # ISO 8601 timestamp

    check_gh_cli || return 1

    local search_query="label:$label"
    if [[ -n "$since" ]]; then
        search_query+=" updated:>$since"
    fi

    gh issue list \
        --search "$search_query" \
        --state all \
        --json number,title,state,updatedAt,labels \
        --limit 1000 \
        --jq '.[] | {
            number: .number,
            title: .title,
            state: .state,
            updated_at: .updatedAt,
            labels: [.labels[].name] | join(",")
        }'
}

# Close GitHub issue
close_github_issue() {
    local issue_number="$1"
    local comment="${2:-}"

    check_gh_cli || return 1

    if [[ -n "$comment" ]]; then
        gh issue close "$issue_number" --comment "$comment"
    else
        gh issue close "$issue_number"
    fi
}

# Reopen GitHub issue
reopen_github_issue() {
    local issue_number="$1"

    check_gh_cli || return 1

    gh issue reopen "$issue_number"
}

# =============================================================================
# Issue Body Formatting
# =============================================================================

# Parse YAML frontmatter from issue body
parse_frontmatter() {
    local body="$1"
    local field="$2"

    # Extract frontmatter (between --- markers)
    local frontmatter
    frontmatter=$(echo "$body" | sed -n '/^---$/,/^---$/p' | sed '1d;$d')

    # Parse field
    echo "$frontmatter" | grep "^${field}:" | sed "s/^${field}: *//"
}

# Build issue body with frontmatter
build_issue_body() {
    local entity_type="$1"
    local entity_id="$2"
    local description="$3"
    local extra_frontmatter="${4:-}"  # Additional YAML fields

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat <<EOF
---
ccpm_entity: ${entity_type}
ccpm_id: ${entity_id}
ccpm_synced_at: ${now}
${extra_frontmatter}---

${description}
EOF
}

# =============================================================================
# Entity-Specific Operations
# =============================================================================

# Get entities pending sync
get_pending_sync() {
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
                    CASE
                        WHEN p.github_issue_number IS NULL THEN 'new'
                        WHEN p.github_synced_at IS NULL THEN 'push'
                        WHEN p.updated_at > p.github_synced_at THEN 'push'
                        ELSE 'synced'
                    END as sync_action
                FROM ccpm.prds p
                WHERE p.deleted_at IS NULL
                  AND (p.github_synced_at IS NULL OR p.updated_at > p.github_synced_at)
            " "json"
            ;;
        epic)
            "$QUERY_SCRIPT" "
                SELECT
                    e.id,
                    e.name,
                    e.prd_id,
                    p.name as prd_name,
                    e.github_issue_number,
                    e.updated_at,
                    e.github_synced_at,
                    CASE
                        WHEN e.github_issue_number IS NULL THEN 'new'
                        WHEN e.github_synced_at IS NULL THEN 'push'
                        WHEN e.updated_at > e.github_synced_at THEN 'push'
                        ELSE 'synced'
                    END as sync_action
                FROM ccpm.epics e
                JOIN ccpm.prds p ON e.prd_id = p.id
                WHERE e.deleted_at IS NULL
                  AND (e.github_synced_at IS NULL OR e.updated_at > e.github_synced_at)
                  ${where_clause}
            " "json"
            ;;
        task)
            "$QUERY_SCRIPT" "
                SELECT
                    t.id,
                    t.epic_id,
                    epic.name as epic_name,
                    t.task_number,
                    t.name,
                    t.github_issue_number,
                    t.updated_at,
                    t.github_synced_at,
                    CASE
                        WHEN t.github_issue_number IS NULL THEN 'new'
                        WHEN t.github_synced_at IS NULL THEN 'push'
                        WHEN t.updated_at > t.github_synced_at THEN 'push'
                        ELSE 'synced'
                    END as sync_action
                FROM ccpm.tasks t
                JOIN ccpm.epics epic ON t.epic_id = epic.id
                WHERE t.deleted_at IS NULL
                  AND (t.github_synced_at IS NULL OR t.updated_at > t.github_synced_at)
                  ${where_clause}
            " "json"
            ;;
    esac
}

# Update entity with GitHub info
update_entity_github_info() {
    local entity_type="$1"
    local entity_id="$2"
    local github_issue_number="$3"

    check_db || return 1

    local now
    now=$(date -u +"%Y-%m-%d %H:%M:%S")

    "$QUERY_SCRIPT" "
        UPDATE ccpm.${entity_type}s
        SET github_issue_number = ${github_issue_number},
            github_synced_at = '${now}',
            updated_at = '${now}'
        WHERE id = ${entity_id}
    " "csv" > /dev/null
}

# =============================================================================
# Conflict Detection
# =============================================================================

# Check for conflicts
detect_conflicts() {
    local entity_type="$1"
    local entity_id="$2"
    local github_updated_at="$3"

    check_db || return 1

    # Get local and last sync timestamps
    local metadata
    metadata=$(get_sync_metadata "$entity_type" "$entity_id")

    if [[ -z "$metadata" ]] || [[ "$metadata" == "[]" ]]; then
        echo "no_conflict"
        return 0
    fi

    local last_synced_at
    last_synced_at=$(echo "$metadata" | jq -r '.[0].last_synced_at // empty')

    local local_updated_at
    local_updated_at=$("$QUERY_SCRIPT" "
        SELECT updated_at FROM ccpm.${entity_type}s WHERE id = ${entity_id}
    " "csv" | tail -1)

    # If no previous sync, no conflict
    if [[ -z "$last_synced_at" ]] || [[ "$last_synced_at" == "null" ]]; then
        echo "no_conflict"
        return 0
    fi

    # Check if both modified since last sync
    if [[ "$local_updated_at" > "$last_synced_at" ]] && [[ "$github_updated_at" > "$last_synced_at" ]]; then
        echo "conflict"
        return 0
    fi

    # Check which is newer
    if [[ "$local_updated_at" > "$github_updated_at" ]]; then
        echo "local_newer"
    elif [[ "$github_updated_at" > "$local_updated_at" ]]; then
        echo "github_newer"
    else
        echo "no_conflict"
    fi
}

# =============================================================================
# Utility Functions
# =============================================================================

# Format timestamp for display
format_time_ago() {
    local timestamp="$1"
    local now
    now=$(date -u +%s)
    local then
    then=$(date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" +%s 2>/dev/null || echo "$now")

    local diff=$((now - then))

    if [[ $diff -lt 60 ]]; then
        echo "${diff}s ago"
    elif [[ $diff -lt 3600 ]]; then
        echo "$((diff / 60))m ago"
    elif [[ $diff -lt 86400 ]]; then
        echo "$((diff / 3600))h ago"
    else
        echo "$((diff / 86400))d ago"
    fi
}

# Confirm action (unless --yes flag)
confirm_action() {
    local message="$1"
    local auto_yes="${2:-false}"

    if [[ "$auto_yes" == "true" ]]; then
        return 0
    fi

    read -p "$message [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Export functions
export -f check_gh_cli
export -f get_repo_info
export -f get_sync_metadata
export -f update_sync_metadata
export -f create_github_issue
export -f update_github_issue
export -f get_github_issue
export -f list_github_issues
export -f close_github_issue
export -f reopen_github_issue
export -f parse_frontmatter
export -f build_issue_body
export -f get_pending_sync
export -f update_entity_github_info
export -f detect_conflicts
export -f format_time_ago
export -f confirm_action
