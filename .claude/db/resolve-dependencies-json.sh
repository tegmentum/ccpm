#!/usr/bin/env bash
# Deterministic Dependency Resolution - JSON Version
# Uses jq for clean JSON parsing

# Require bash 4+ for associative arrays
if ((BASH_VERSINFO[0] < 4)); then
    echo "Error: Bash 4.0 or higher required (found $BASH_VERSION)" >&2
    exit 1
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed" >&2
    echo "Install with: brew install jq" >&2
    exit 1
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_HELPERS="$SCRIPT_DIR/helpers.sh"
QUERY_SCRIPT="$SCRIPT_DIR/query.sh"
CCPM_DB="${CCPM_DB:-$HOME/.claude/ccpm.db}"

# Source database helpers
if [[ ! -f "$DB_HELPERS" ]]; then
    echo "Error: Database helpers not found at: $DB_HELPERS" >&2
    exit 1
fi

source "$DB_HELPERS"

# =============================================================================
# Dependency Resolution Functions
# =============================================================================

# Get all tasks for an epic with their dependencies as JSON
get_tasks_json() {
    local epic_name="$1"

    "$QUERY_SCRIPT" "
        SELECT
            t.id,
            t.task_number,
            t.name,
            t.status,
            t.parallel,
            LIST(td.depends_on_task_id) as depends_on
        FROM ccpm.tasks t
        JOIN ccpm.epics e ON t.epic_id = e.id
        LEFT JOIN ccpm.task_dependencies td ON t.id = td.task_id
        WHERE e.name = '${epic_name}' AND t.deleted_at IS NULL
        GROUP BY t.id, t.task_number, t.name, t.status, t.parallel
        ORDER BY t.task_number
    " "json"
}

# Build dependency graph using jq
build_graph_json() {
    local epic_name="$1"
    local json_data
    json_data=$(get_tasks_json "$epic_name")

    # Parse JSON with jq and build bash associative arrays
    declare -gA TASK_STATUS
    declare -gA TASK_DEPS
    declare -gA TASK_INFO

    while IFS= read -r line; do
        local id status deps name task_num
        id=$(echo "$line" | jq -r '.id')
        status=$(echo "$line" | jq -r '.status')
        name=$(echo "$line" | jq -r '.name')
        task_num=$(echo "$line" | jq -r '.task_number')

        # DuckDB LIST returns string like "[1, 2]" or "[NULL]"
        # Parse it to extract numbers
        local deps_str
        deps_str=$(echo "$line" | jq -r '.depends_on')

        if [[ "$deps_str" == "[NULL]" ]] || [[ "$deps_str" == "[]" ]]; then
            deps=""
        else
            # Extract numbers from "[1, 2]" -> "1,2"
            deps=$(echo "$deps_str" | sed 's/\[//; s/\]//; s/, */,/g')
        fi

        TASK_STATUS[$id]="$status"
        TASK_DEPS[$id]="$deps"
        TASK_INFO[$id]="$task_num|$name"
    done < <(echo "$json_data" | jq -c '.[]')
}

# Get ready tasks (no unmet dependencies)
get_ready_tasks() {
    local epic_name="$1"

    # Build graph
    build_graph_json "$epic_name"

    local ready_tasks=()

    # Check each task
    for task_id in "${!TASK_STATUS[@]}"; do
        local status="${TASK_STATUS[$task_id]}"
        local deps="${TASK_DEPS[$task_id]}"

        # Skip if not open
        [[ "$status" == "open" ]] || continue

        # Check if all dependencies are closed
        local all_closed=true
        if [[ -n "$deps" ]]; then
            IFS=',' read -ra dep_array <<< "$deps"
            for dep_id in "${dep_array[@]}"; do
                [[ -n "$dep_id" ]] || continue
                if [[ -v TASK_STATUS[$dep_id] ]]; then
                    if [[ "${TASK_STATUS[$dep_id]}" != "closed" ]]; then
                        all_closed=false
                        break
                    fi
                else
                    # Dependency not found
                    all_closed=false
                    break
                fi
            done
        fi

        if [[ "$all_closed" == "true" ]]; then
            ready_tasks+=("$task_id")
        fi
    done

    # Output ready tasks
    if [[ ${#ready_tasks[@]} -gt 0 ]]; then
        # Get full task info from database
        local ids_list=$(IFS=','; echo "${ready_tasks[*]}")
        "$QUERY_SCRIPT" "
            SELECT
                t.id,
                t.task_number,
                t.name,
                t.status,
                t.parallel,
                t.github_issue_number
            FROM ccpm.tasks t
            WHERE t.id IN ($ids_list)
            ORDER BY t.task_number
        " "table"
    else
        echo "No ready tasks found"
        return 1
    fi
}

# Get blocked tasks
get_blocked_tasks() {
    local epic_name="$1"

    # Build graph
    build_graph_json "$epic_name"

    local found_blocked=false

    # Check each task
    for task_id in "${!TASK_STATUS[@]}"; do
        local status="${TASK_STATUS[$task_id]}"
        local deps="${TASK_DEPS[$task_id]}"
        local info="${TASK_INFO[$task_id]}"

        # Skip if not open
        [[ "$status" == "open" ]] || continue

        # Find unmet dependencies
        local unmet=()
        if [[ -n "$deps" ]]; then
            IFS=',' read -ra dep_array <<< "$deps"
            for dep_id in "${dep_array[@]}"; do
                [[ -n "$dep_id" ]] || continue
                if [[ -v TASK_STATUS[$dep_id] ]]; then
                    if [[ "${TASK_STATUS[$dep_id]}" != "closed" ]]; then
                        local dep_info="${TASK_INFO[$dep_id]}"
                        IFS='|' read -r dep_num dep_name <<< "$dep_info"
                        unmet+=("Task #$dep_num (${TASK_STATUS[$dep_id]})")
                    fi
                else
                    unmet+=("Task #$dep_id (missing)")
                fi
            done
        fi

        if [[ ${#unmet[@]} -gt 0 ]]; then
            found_blocked=true
            IFS='|' read -r task_num task_name <<< "$info"
            echo "Task #$task_num: $task_name"
            echo "  Blocked by: ${unmet[*]}"
            echo ""
        fi
    done

    if [[ "$found_blocked" == "false" ]]; then
        echo "No blocked tasks found"
        return 1
    fi
}

# Topological sort
topological_sort() {
    local epic_name="$1"

    # Build graph
    build_graph_json "$epic_name"

    # Calculate in-degrees
    declare -A in_degree
    for task_id in "${!TASK_STATUS[@]}"; do
        in_degree[$task_id]=0
    done

    for task_id in "${!TASK_DEPS[@]}"; do
        local deps="${TASK_DEPS[$task_id]}"
        if [[ -n "$deps" ]]; then
            IFS=',' read -ra dep_array <<< "$deps"
            for dep_id in "${dep_array[@]}"; do
                [[ -n "$dep_id" ]] || continue
                ((in_degree[$dep_id]++)) || true
            done
        fi
    done

    # Find tasks with no dependencies
    local queue=()
    for task_id in "${!in_degree[@]}"; do
        if [[ ${in_degree[$task_id]} -eq 0 ]]; then
            queue+=("$task_id")
        fi
    done

    # Process queue
    local sorted=()
    while [[ ${#queue[@]} -gt 0 ]]; do
        local current="${queue[0]}"
        queue=("${queue[@]:1}")
        sorted+=("$current")

        # Reduce in-degree of dependents
        local deps="${TASK_DEPS[$current]}"
        if [[ -n "$deps" ]]; then
            IFS=',' read -ra dep_array <<< "$deps"
            for dep_id in "${dep_array[@]}"; do
                [[ -n "$dep_id" ]] || continue
                ((in_degree[$dep_id]--)) || true
                if [[ ${in_degree[$dep_id]} -eq 0 ]]; then
                    queue+=("$dep_id")
                fi
            done
        fi
    done

    # Check for cycles
    local has_cycle=false
    for task_id in "${!in_degree[@]}"; do
        if [[ ${in_degree[$task_id]} -gt 0 ]]; then
            has_cycle=true
            local info="${TASK_INFO[$task_id]}"
            IFS='|' read -r task_num task_name <<< "$info"
            echo "Warning: Circular dependency involving Task #$task_num: $task_name" >&2
        fi
    done

    # Output sorted order
    for task_id in "${sorted[@]}"; do
        local info="${TASK_INFO[$task_id]}"
        IFS='|' read -r task_num task_name <<< "$info"
        echo "Task #$task_num: $task_name (${TASK_STATUS[$task_id]})"
    done

    [[ "$has_cycle" == "false" ]]
}

# Detect cycles using SQL
detect_cycles() {
    local epic_name="$1"

    "$QUERY_SCRIPT" "
        WITH RECURSIVE dep_cycle AS (
            SELECT
                td.task_id,
                td.depends_on_task_id,
                td.task_id as start_task,
                1 as depth,
                CAST(td.task_id AS VARCHAR) as path
            FROM ccpm.task_dependencies td
            JOIN ccpm.tasks t ON td.task_id = t.id
            JOIN ccpm.epics e ON t.epic_id = e.id
            WHERE e.name = '${epic_name}'

            UNION ALL

            SELECT
                td.task_id,
                td.depends_on_task_id,
                dc.start_task,
                dc.depth + 1,
                dc.path || ' -> ' || CAST(td.task_id AS VARCHAR)
            FROM ccpm.task_dependencies td
            JOIN dep_cycle dc ON td.task_id = dc.depends_on_task_id
            WHERE dc.depth < 20
              AND td.depends_on_task_id != dc.start_task
        )
        SELECT DISTINCT
            t1.task_number as start_task_num,
            t1.name as start_task_name,
            t2.task_number as end_task_num,
            t2.name as end_task_name,
            dc.path
        FROM dep_cycle dc
        JOIN ccpm.tasks t1 ON dc.start_task = t1.id
        JOIN ccpm.tasks t2 ON dc.depends_on_task_id = t2.id
        WHERE dc.depends_on_task_id = dc.start_task
    " "table"
}

# Show dependency graph
show_graph() {
    local epic_name="$1"

    "$QUERY_SCRIPT" "
        SELECT
            t.task_number,
            t.name,
            t.status,
            t.parallel,
            LIST(dep.task_number) as depends_on_tasks
        FROM ccpm.tasks t
        JOIN ccpm.epics e ON t.epic_id = e.id
        LEFT JOIN ccpm.task_dependencies td ON t.id = td.task_id
        LEFT JOIN ccpm.tasks dep ON td.depends_on_task_id = dep.id
        WHERE e.name = '${epic_name}' AND t.deleted_at IS NULL
        GROUP BY t.id, t.task_number, t.name, t.status, t.parallel
        ORDER BY t.task_number
    " "table"
}

# =============================================================================
# CLI Interface
# =============================================================================

show_help() {
    cat << EOF
Deterministic Dependency Resolution (JSON Version)

Usage:
  $0 <command> <epic_name>

Commands:
  ready <epic>        - Show tasks ready to start (no unmet dependencies)
  blocked <epic>      - Show tasks blocked by dependencies
  sort <epic>         - Topological sort (dependency order)
  cycles <epic>       - Detect circular dependencies
  graph <epic>        - Show dependency graph

Examples:
  $0 ready user-auth-backend
  $0 blocked user-auth-backend
  $0 sort user-auth-backend
  $0 cycles user-auth-backend

EOF
}

main() {
    local command="${1:-}"
    local epic_name="${2:-}"

    if [[ -z "$command" ]] || [[ -z "$epic_name" ]]; then
        show_help
        exit 1
    fi

    # Check database exists
    if ! check_db 2>/dev/null; then
        echo "Error: Database not initialized" >&2
        exit 1
    fi

    case "$command" in
        ready)
            echo "🎯 Ready Tasks for: $epic_name"
            echo "================================"
            echo ""
            get_ready_tasks "$epic_name"
            ;;
        blocked)
            echo "🚫 Blocked Tasks for: $epic_name"
            echo "================================="
            echo ""
            get_blocked_tasks "$epic_name"
            ;;
        sort)
            echo "📊 Dependency Order for: $epic_name"
            echo "===================================="
            echo ""
            topological_sort "$epic_name"
            ;;
        cycles)
            echo "🔄 Circular Dependency Check: $epic_name"
            echo "=========================================="
            echo ""
            if ! detect_cycles "$epic_name"; then
                echo "✅ No circular dependencies detected"
            fi
            ;;
        graph)
            echo "📈 Dependency Graph for: $epic_name"
            echo "===================================="
            echo ""
            show_graph "$epic_name"
            ;;
        *)
            echo "Error: Unknown command '$command'" >&2
            show_help
            exit 1
            ;;
    esac
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
