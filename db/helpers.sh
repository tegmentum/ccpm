#!/bin/bash
# Database Query Helpers for CCPM
# Common queries wrapped in reusable functions

# Only set strict mode if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
QUERY_SCRIPT="$SCRIPT_DIR/query.sh"
CCPM_DB="${CCPM_DB:-$HOME/.claude/ccpm.db}"

# Check if database exists
check_db() {
    if [[ ! -f "$CCPM_DB" ]]; then
        echo "Error: Database not found at: $CCPM_DB" >&2
        echo "Initialize with: ./db/init.sh" >&2
        return 1
    fi
}

# Escape single quotes for SQL
escape_sql() {
    echo "$1" | sed "s/'/''/g"
}

# =============================================================================
# PRD Queries
# =============================================================================

# Get all PRDs
list_prds() {
    check_db || return 1
    "$QUERY_SCRIPT" "SELECT id, name, description, status FROM ccpm.prds WHERE deleted_at IS NULL ORDER BY created_at DESC" "${1:-table}"
}

# Get PRDs by status
list_prds_by_status() {
    local status="$1"
    local format="${2:-table}"
    check_db || return 1
    "$QUERY_SCRIPT" "SELECT id, name, description FROM ccpm.prds WHERE status = '$status' AND deleted_at IS NULL ORDER BY created_at DESC" "$format"
}

# Count PRDs
count_prds() {
    check_db || return 1
    "$QUERY_SCRIPT" "SELECT COUNT(*) as total FROM ccpm.prds WHERE deleted_at IS NULL"
}

# Count PRDs by status
count_prds_by_status() {
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT
            status,
            COUNT(*) as count
        FROM ccpm.prds
        WHERE deleted_at IS NULL
        GROUP BY status
        ORDER BY status
    "
}

# Get PRD by name
get_prd() {
    local prd_name="$1"
    check_db || return 1
    "$QUERY_SCRIPT" "SELECT * FROM ccpm.prds WHERE name = '$prd_name' AND deleted_at IS NULL" "${2:-table}"
}

# =============================================================================
# Epic Queries
# =============================================================================

# Get all epics
list_epics() {
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT
            e.id,
            e.name,
            e.status,
            e.progress || '%' as progress,
            COUNT(t.id) as total_tasks,
            e.github_issue_number
        FROM ccpm.epics e
        LEFT JOIN ccpm.tasks t ON e.id = t.epic_id AND t.deleted_at IS NULL
        WHERE e.deleted_at IS NULL
        GROUP BY e.id
        ORDER BY e.created_at DESC
    " "${1:-table}"
}

# Get epics by status
list_epics_by_status() {
    local status="$1"
    local format="${2:-table}"
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT
            e.id,
            e.name,
            e.progress || '%' as progress,
            COUNT(t.id) as tasks,
            e.github_issue_number
        FROM ccpm.epics e
        LEFT JOIN ccpm.tasks t ON e.id = t.epic_id AND t.deleted_at IS NULL
        WHERE e.status = '$status' AND e.deleted_at IS NULL
        GROUP BY e.id
        ORDER BY e.created_at DESC
    " "$format"
}

# Count epics
count_epics() {
    check_db || return 1
    "$QUERY_SCRIPT" "SELECT COUNT(*) as total FROM ccpm.epics WHERE deleted_at IS NULL"
}

# Get epic by name
get_epic() {
    local epic_name="$1"
    check_db || return 1
    "$QUERY_SCRIPT" "SELECT * FROM ccpm.epics WHERE name = '$epic_name' AND deleted_at IS NULL" "${2:-table}"
}

# Get epic progress summary
get_epic_progress() {
    local epic_name="$1"
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT * FROM ccpm.epic_progress
        WHERE name = '$epic_name'
    " "${2:-table}"
}

# =============================================================================
# Task Queries
# =============================================================================

# Get all tasks
list_tasks() {
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT
            t.id,
            e.name as epic,
            t.task_number,
            t.name,
            t.status,
            t.github_issue_number
        FROM ccpm.tasks t
        JOIN ccpm.epics e ON t.epic_id = e.id
        WHERE t.deleted_at IS NULL
        ORDER BY e.name, t.task_number
    " "${1:-table}"
}

# Get tasks by status
list_tasks_by_status() {
    local status="$1"
    local format="${2:-table}"
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT
            t.id,
            e.name as epic,
            t.task_number,
            t.name,
            t.github_issue_number
        FROM ccpm.tasks t
        JOIN ccpm.epics e ON t.epic_id = e.id
        WHERE t.status = '$status' AND t.deleted_at IS NULL
        ORDER BY e.name, t.task_number
    " "$format"
}

# Count tasks
count_tasks() {
    check_db || return 1
    "$QUERY_SCRIPT" "SELECT COUNT(*) as total FROM ccpm.tasks WHERE deleted_at IS NULL"
}

# Count tasks by status
count_tasks_by_status() {
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT
            status,
            COUNT(*) as count
        FROM ccpm.tasks
        WHERE deleted_at IS NULL
        GROUP BY status
        ORDER BY status
    "
}

# Get tasks for an epic
get_epic_tasks() {
    local epic_name="$1"
    local format="${2:-table}"
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT
            t.task_number,
            t.name,
            t.status,
            t.parallel,
            t.github_issue_number
        FROM ccpm.tasks t
        JOIN ccpm.epics e ON t.epic_id = e.id
        WHERE e.name = '$epic_name' AND t.deleted_at IS NULL
        ORDER BY t.task_number
    " "$format"
}

# =============================================================================
# Dependency & Status Queries
# =============================================================================

# Get ready tasks (no unmet dependencies)
get_ready_tasks() {
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT
            rt.id,
            e.name as epic,
            rt.task_number,
            rt.name,
            rt.parallel,
            t.github_issue_number
        FROM ccpm.ready_tasks rt
        JOIN ccpm.epics e ON rt.epic_id = e.id
        JOIN ccpm.tasks t ON rt.id = t.id
        ORDER BY e.name, rt.task_number
    " "${1:-table}"
}

# Get blocked tasks
get_blocked_tasks() {
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT
            t.id,
            e.name as epic,
            t.task_number,
            t.name,
            t.blocking_tasks
        FROM ccpm.blocked_tasks t
        JOIN ccpm.epics e ON t.epic_id = e.id
        ORDER BY e.name, t.task_number
    " "${1:-table}"
}

# Get task dependencies
get_task_dependencies() {
    local task_id="$1"
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT * FROM ccpm.tasks_with_dependencies
        WHERE id = $task_id
    " "${2:-table}"
}

# Get task conflicts
get_task_conflicts() {
    local task_id="$1"
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT * FROM ccpm.tasks_with_conflicts
        WHERE id = $task_id
    " "${2:-table}"
}

# =============================================================================
# Progress Queries
# =============================================================================

# Get all epics with progress
get_all_epic_progress() {
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT
            name,
            status,
            total_tasks,
            closed_tasks,
            in_progress_tasks,
            open_tasks,
            calculated_progress || '%' as progress
        FROM ccpm.epic_progress
        ORDER BY calculated_progress DESC, name
    " "${1:-table}"
}

# Get in-progress items
get_in_progress_items() {
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT
            'epic' as type,
            e.name,
            e.progress || '%' as progress
        FROM ccpm.epics e
        WHERE e.status = 'in-progress' AND e.deleted_at IS NULL
        UNION ALL
        SELECT
            'task' as type,
            e.name || ' / ' || t.name as name,
            COALESCE(pu.completion_percent, 0) || '%' as progress
        FROM ccpm.tasks t
        JOIN ccpm.epics e ON t.epic_id = e.id
        LEFT JOIN ccpm.progress_updates pu ON t.id = pu.task_id
        WHERE t.status = 'in-progress' AND t.deleted_at IS NULL
        ORDER BY type, name
    " "${1:-table}"
}

# =============================================================================
# Sync Queries
# =============================================================================

# Get sync status
get_sync_status() {
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT
            entity_type,
            sync_status,
            COUNT(*) as count
        FROM ccpm.sync_metadata
        GROUP BY entity_type, sync_status
        ORDER BY entity_type, sync_status
    " "${1:-table}"
}

# Get pending sync items
get_pending_sync() {
    check_db || return 1
    "$QUERY_SCRIPT" "
        SELECT
            sm.entity_type,
            CASE
                WHEN sm.entity_type = 'prd' THEN p.name
                WHEN sm.entity_type = 'epic' THEN e.name
                WHEN sm.entity_type = 'task' THEN ep.name || ' / Task #' || t.task_number
            END as name,
            sm.sync_status,
            sm.local_updated_at,
            sm.github_updated_at
        FROM ccpm.sync_metadata sm
        LEFT JOIN ccpm.prds p ON sm.entity_type = 'prd' AND sm.entity_id = p.id
        LEFT JOIN ccpm.epics e ON sm.entity_type = 'epic' AND sm.entity_id = e.id
        LEFT JOIN ccpm.tasks t ON sm.entity_type = 'task' AND sm.entity_id = t.id
        LEFT JOIN ccpm.epics ep ON t.epic_id = ep.id
        WHERE sm.sync_status = 'pending'
        ORDER BY sm.entity_type, name
    " "${1:-table}"
}

# =============================================================================
# Utility Functions
# =============================================================================

# Execute custom query
query() {
    local sql="$1"
    local format="${2:-table}"
    check_db || return 1
    "$QUERY_SCRIPT" "$sql" "$format"
}

# Get database info
db_info() {
    check_db || return 1
    echo "Database: $CCPM_DB"
    echo ""
    echo "Tables:"
    "$QUERY_SCRIPT" "SELECT name, type FROM sqlite_master WHERE type='table' ORDER BY name"
    echo ""
    echo "Views:"
    "$QUERY_SCRIPT" "SELECT name FROM sqlite_master WHERE type='view' ORDER BY name"
}

# Show counts summary
summary() {
    check_db || return 1
    echo "📊 CCPM Database Summary"
    echo "========================"
    echo ""

    echo "📄 PRDs:"
    "$QUERY_SCRIPT" "
        SELECT
            COALESCE(status, 'unknown') as status,
            COUNT(*) as count
        FROM ccpm.prds
        WHERE deleted_at IS NULL
        GROUP BY status
        ORDER BY status
    "

    echo ""
    echo "📚 Epics:"
    "$QUERY_SCRIPT" "
        SELECT
            status,
            COUNT(*) as count
        FROM ccpm.epics
        WHERE deleted_at IS NULL
        GROUP BY status
        ORDER BY status
    "

    echo ""
    echo "📝 Tasks:"
    "$QUERY_SCRIPT" "
        SELECT
            status,
            COUNT(*) as count
        FROM ccpm.tasks
        WHERE deleted_at IS NULL
        GROUP BY status
        ORDER BY status
    "
}

# =============================================================================
# CREATE Operations
# =============================================================================

# Create new PRD
create_prd() {
    local name="$1"
    local description="${2:-}"
    local prd_status="${3:-draft}"
    local content="${4:-}"

    check_db || return 1

    # Escape SQL strings
    name=$(escape_sql "$name")
    description=$(escape_sql "$description")
    content=$(escape_sql "$content")

    local now
    now=$(date -u +"%Y-%m-%d %H:%M:%S")

    # Insert the PRD
    "$QUERY_SCRIPT" "
        INSERT INTO ccpm.prds (
            name, status, description, content,
            created_at, updated_at
        ) VALUES (
            '${name}', '${prd_status}', '${description}', $([ -n "$content" ] && echo "'$content'" || echo "NULL"),
            '${now}', '${now}'
        )
    " "csv" > /dev/null

    # Get the inserted ID by querying for the name
    "$QUERY_SCRIPT" "
        SELECT id FROM ccpm.prds
        WHERE name = '${name}' AND deleted_at IS NULL
        ORDER BY created_at DESC LIMIT 1
    " "csv" | tail -1
}

# Create new Epic
create_epic() {
    local prd_id="$1"
    local name="$2"
    local content="${3:-}"
    local epic_status="${4:-backlog}"

    check_db || return 1

    name=$(escape_sql "$name")
    content=$(escape_sql "$content")

    local now
    now=$(date -u +"%Y-%m-%d %H:%M:%S")

    # Insert the Epic
    "$QUERY_SCRIPT" "
        INSERT INTO ccpm.epics (
            prd_id, name, status, content, progress,
            created_at, updated_at
        ) VALUES (
            ${prd_id}, '${name}', '${epic_status}', $([ -n "$content" ] && echo "'$content'" || echo "NULL"), 0,
            '${now}', '${now}'
        )
    " "csv" > /dev/null

    # Get the inserted ID by querying for the name and prd_id
    "$QUERY_SCRIPT" "
        SELECT id FROM ccpm.epics
        WHERE prd_id = ${prd_id} AND name = '${name}' AND deleted_at IS NULL
        ORDER BY created_at DESC LIMIT 1
    " "csv" | tail -1
}

# Create new Task
create_task() {
    local epic_id="$1"
    local task_number="$2"
    local name="$3"
    local content="${4:-}"
    local estimated_hours="${5:-}"
    local parallel="${6:-0}"
    local task_status="${7:-open}"

    check_db || return 1

    name=$(escape_sql "$name")
    content=$(escape_sql "$content")

    local now
    now=$(date -u +"%Y-%m-%d %H:%M:%S")

    # Insert the Task
    "$QUERY_SCRIPT" "
        INSERT INTO ccpm.tasks (
            epic_id, task_number, name, status, content,
            estimated_hours, parallel,
            created_at, updated_at
        ) VALUES (
            ${epic_id}, ${task_number}, '${name}', '${task_status}', $([ -n "$content" ] && echo "'$content'" || echo "NULL"),
            $([ -n "$estimated_hours" ] && echo "$estimated_hours" || echo "NULL"), ${parallel},
            '${now}', '${now}'
        )
    " "csv" > /dev/null

    # Get the inserted ID by querying for epic_id and task_number (unique together)
    "$QUERY_SCRIPT" "
        SELECT id FROM ccpm.tasks
        WHERE epic_id = ${epic_id} AND task_number = ${task_number} AND deleted_at IS NULL
        ORDER BY created_at DESC LIMIT 1
    " "csv" | tail -1
}

# Create task dependency
create_task_dependency() {
    local task_id="$1"
    local depends_on_task_id="$2"

    check_db || return 1

    local now
    now=$(date -u +"%Y-%m-%d %H:%M:%S")

    "$QUERY_SCRIPT" "
        INSERT INTO ccpm.task_dependencies (task_id, depends_on_task_id, created_at)
        VALUES (${task_id}, ${depends_on_task_id}, '${now}')
    " "csv" > /dev/null
}

# =============================================================================
# UPDATE Operations
# =============================================================================

# Update PRD
update_prd() {
    local prd_id="$1"
    local field="$2"
    local value="$3"

    check_db || return 1

    value=$(escape_sql "$value")

    local now
    now=$(date -u +"%Y-%m-%d %H:%M:%S")

    "$QUERY_SCRIPT" "
        UPDATE ccpm.prds
        SET ${field} = '${value}',
            updated_at = '${now}'
        WHERE id = ${prd_id}
    " "csv" > /dev/null
}

# Update Epic
update_epic() {
    local epic_id="$1"
    local field="$2"
    local value="$3"

    check_db || return 1

    value=$(escape_sql "$value")

    local now
    now=$(date -u +"%Y-%m-%d %H:%M:%S")

    "$QUERY_SCRIPT" "
        UPDATE ccpm.epics
        SET ${field} = '${value}',
            updated_at = '${now}'
        WHERE id = ${epic_id}
    " "csv" > /dev/null
}

# Update Task
update_task() {
    local task_id="$1"
    local field="$2"
    local value="$3"

    check_db || return 1

    value=$(escape_sql "$value")

    local now
    now=$(date -u +"%Y-%m-%d %H:%M:%S")

    "$QUERY_SCRIPT" "
        UPDATE ccpm.tasks
        SET ${field} = '${value}',
            updated_at = '${now}'
        WHERE id = ${task_id}
    " "csv" > /dev/null
}

# Update task status
update_task_status() {
    local task_id="$1"
    local new_status="$2"

    check_db || return 1

    local now
    now=$(date -u +"%Y-%m-%d %H:%M:%S")

    "$QUERY_SCRIPT" "
        UPDATE ccpm.tasks
        SET status = '${new_status}',
            updated_at = '${now}'
        WHERE id = ${task_id}
    " "csv" > /dev/null
}

# =============================================================================
# DELETE Operations (Soft Delete)
# =============================================================================

# Soft delete PRD
delete_prd() {
    local prd_id="$1"

    check_db || return 1

    local now
    now=$(date -u +"%Y-%m-%d %H:%M:%S")

    "$QUERY_SCRIPT" "
        UPDATE ccpm.prds
        SET deleted_at = '${now}',
            updated_at = '${now}'
        WHERE id = ${prd_id}
    " "csv" > /dev/null
}

# Soft delete Epic
delete_epic() {
    local epic_id="$1"

    check_db || return 1

    local now
    now=$(date -u +"%Y-%m-%d %H:%M:%S")

    "$QUERY_SCRIPT" "
        UPDATE ccpm.epics
        SET deleted_at = '${now}',
            updated_at = '${now}'
        WHERE id = ${epic_id}
    " "csv" > /dev/null
}

# Soft delete Task
delete_task() {
    local task_id="$1"

    check_db || return 1

    local now
    now=$(date -u +"%Y-%m-%d %H:%M:%S")

    "$QUERY_SCRIPT" "
        UPDATE ccpm.tasks
        SET deleted_at = '${now}',
            updated_at = '${now}'
        WHERE id = ${task_id}
    " "csv" > /dev/null
}

# =============================================================================
# Bulk Operations
# =============================================================================

# Create multiple tasks for an epic
create_epic_tasks() {
    local epic_id="$1"
    local tasks_json="$2"  # Array of task objects

    check_db || return 1

    # Parse JSON array and create tasks
    echo "$tasks_json" | jq -c '.[]' | while read -r task; do
        local task_number=$(echo "$task" | jq -r '.task_number')
        local name=$(echo "$task" | jq -r '.name')
        local description=$(echo "$task" | jq -r '.description // ""')
        local estimated_hours=$(echo "$task" | jq -r '.estimated_hours // ""')
        local parallel=$(echo "$task" | jq -r '.parallel // 0')

        create_task "$epic_id" "$task_number" "$name" "$description" "$estimated_hours" "$parallel"
    done
}

# Create multiple dependencies for a task
create_task_dependencies() {
    local task_id="$1"
    local dependency_ids="$2"  # Comma-separated list of IDs

    check_db || return 1

    IFS=',' read -ra ids <<< "$dependency_ids"
    for dep_id in "${ids[@]}"; do
        [[ -z "$dep_id" ]] && continue
        create_task_dependency "$task_id" "$dep_id"
    done
}

# =============================================================================
# Show help if run directly
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "CCPM Database Helpers"
    echo "====================="
    echo ""
    echo "Source this file to use helper functions:"
    echo "  source $0"
    echo ""
    echo "Available functions:"
    echo ""
    echo "  READ Operations:"
    echo "    PRDs:        list_prds, count_prds, get_prd"
    echo "    Epics:       list_epics, count_epics, get_epic, get_epic_progress"
    echo "    Tasks:       list_tasks, count_tasks, get_epic_tasks"
    echo "    Ready:       get_ready_tasks, get_blocked_tasks"
    echo "    Progress:    get_all_epic_progress, get_in_progress_items"
    echo "    Sync:        get_sync_status, get_pending_sync"
    echo "    Utility:     query, db_info, summary"
    echo ""
    echo "  CREATE Operations:"
    echo "    create_prd <name> [description] [business_value] [success_criteria] [target_date] [status]"
    echo "    create_epic <prd_id> <name> [description] [status]"
    echo "    create_task <epic_id> <task_number> <name> [description] [estimated_hours] [parallel] [status]"
    echo "    create_task_dependency <task_id> <depends_on_task_id>"
    echo ""
    echo "  UPDATE Operations:"
    echo "    update_prd <prd_id> <field> <value>"
    echo "    update_epic <epic_id> <field> <value>"
    echo "    update_task <task_id> <field> <value>"
    echo "    update_task_status <task_id> <status>"
    echo ""
    echo "  DELETE Operations (Soft Delete):"
    echo "    delete_prd <prd_id>"
    echo "    delete_epic <epic_id>"
    echo "    delete_task <task_id>"
    echo ""
    echo "  BULK Operations:"
    echo "    create_epic_tasks <epic_id> <tasks_json>"
    echo "    create_task_dependencies <task_id> <dependency_ids>"
    echo ""
    echo "Example:"
    echo "  source $0"
    echo "  prd_id=\$(create_prd 'user-auth' 'Authentication system' 'Enable secure login')"
    echo "  epic_id=\$(create_epic \$prd_id 'user-auth-backend' 'Backend auth services')"
    echo "  update_task_status 42 'in-progress'"
    echo "  get_ready_tasks"
fi
