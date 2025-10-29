#!/usr/bin/env bash
# Deterministic Dependency Resolution
# Implements topological sort for task ordering

# Require bash 4+ for associative arrays
if ((BASH_VERSINFO[0] < 4)); then
    echo "Error: Bash 4.0 or higher required (found $BASH_VERSION)" >&2
    exit 1
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_HELPERS="$SCRIPT_DIR/helpers.sh"

# Source database helpers
if [[ ! -f "$DB_HELPERS" ]]; then
    echo "Error: Database helpers not found at: $DB_HELPERS" >&2
    exit 1
fi

source "$DB_HELPERS"

# =============================================================================
# Dependency Resolution Functions
# =============================================================================

# Get all tasks for an epic with their dependencies
get_task_dependencies() {
    local epic_name="$1"
    local format="${2:-csv}"

    "$QUERY_SCRIPT" "
        SELECT
            t.id || '|' ||
            t.task_number || '|' ||
            t.name || '|' ||
            t.status || '|' ||
            t.parallel || '|' ||
            COALESCE(GROUP_CONCAT(td.depends_on_task_id, ':'), 'NULL') as data
        FROM ccpm.tasks t
        JOIN ccpm.epics e ON t.epic_id = e.id
        LEFT JOIN ccpm.task_dependencies td ON t.id = td.task_id
        WHERE e.name = '${epic_name}' AND t.deleted_at IS NULL
        GROUP BY t.id, t.task_number, t.name, t.status, t.parallel
        ORDER BY t.task_number
    " "$format"
}

# Build adjacency list for dependency graph
build_dependency_graph() {
    local epic_name="$1"
    local -n graph_ref=$2  # Nameref to associative array
    local -n status_ref=$3  # Nameref to status map

    # Get all tasks and dependencies
    local tasks_data
    tasks_data=$(get_task_dependencies "$epic_name" "csv" 2>/dev/null)

    # Parse pipe-delimited data
    local line_num=0
    while IFS= read -r line; do
        ((line_num++))
        # Skip header
        [[ $line_num -eq 1 ]] && continue
        [[ -z "$line" ]] && continue

        # Parse pipe-delimited line
        IFS='|' read -r task_id task_num name status parallel depends_on_ids <<< "$line"

        # Store status
        status_ref[$task_id]="$status"

        # Initialize adjacency list
        graph_ref[$task_id]=""

        # Parse dependencies
        if [[ -n "$depends_on_ids" && "$depends_on_ids" != "NULL" ]]; then
            graph_ref[$task_id]="$depends_on_ids"
        fi
    done <<< "$tasks_data"
}

# Calculate in-degree (number of dependencies) for each task
calculate_in_degree() {
    local -n graph_ref=$1
    local -n in_degree_ref=$2

    # Initialize all tasks with in-degree 0
    for task_id in "${!graph_ref[@]}"; do
        in_degree_ref[$task_id]=0
    done

    # Count incoming edges
    for task_id in "${!graph_ref[@]}"; do
        local deps="${graph_ref[$task_id]}"
        if [[ -n "$deps" ]]; then
            IFS=':' read -ra dep_array <<< "$deps"
            for dep_id in "${dep_array[@]}"; do
                [[ -n "$dep_id" ]] || continue
                ((in_degree_ref[$dep_id]++)) || true
            done
        fi
    done
}

# Topological sort using Kahn's algorithm
# Returns tasks in dependency order
topological_sort() {
    local epic_name="$1"
    local include_completed="${2:-false}"  # Include completed tasks in output?

    # Build dependency graph
    declare -A graph
    declare -A status_map
    build_dependency_graph "$epic_name" graph status_map

    # Calculate in-degrees
    declare -A in_degree
    calculate_in_degree graph in_degree

    # Queue for tasks with no dependencies (in-degree 0)
    local queue=()
    for task_id in "${!in_degree[@]}"; do
        if [[ ${in_degree[$task_id]} -eq 0 ]]; then
            queue+=("$task_id")
        fi
    done

    # Process queue
    local sorted=()
    while [[ ${#queue[@]} -gt 0 ]]; do
        # Pop from queue
        local current="${queue[0]}"
        queue=("${queue[@]:1}")

        # Add to sorted list (unless completed and we're excluding them)
        if [[ "$include_completed" == "true" ]] || [[ "${status_map[$current]}" != "closed" ]]; then
            sorted+=("$current")
        fi

        # Reduce in-degree of dependent tasks
        local deps="${graph[$current]}"
        if [[ -n "$deps" ]]; then
            IFS=':' read -ra dep_array <<< "$deps"
            for dep_id in "${dep_array[@]}"; do
                [[ -n "$dep_id" ]] || continue
                ((in_degree[$dep_id]--)) || true
                if [[ ${in_degree[$dep_id]} -eq 0 ]]; then
                    queue+=("$dep_id")
                fi
            done
        fi
    done

    # Check for cycles (tasks with non-zero in-degree)
    local has_cycle=false
    for task_id in "${!in_degree[@]}"; do
        if [[ ${in_degree[$task_id]} -gt 0 ]]; then
            has_cycle=true
            echo "Warning: Circular dependency detected involving task ID $task_id" >&2
        fi
    done

    # Output sorted task IDs
    printf '%s\n' "${sorted[@]}"

    # Return error code if cycle detected
    [[ "$has_cycle" == "false" ]]
}

# Get ready tasks (no unmet dependencies)
get_ready_tasks_deterministic() {
    local epic_name="$1"
    local format="${2:-table}"

    # Build dependency graph
    declare -A graph
    declare -A status_map
    build_dependency_graph "$epic_name" graph status_map

    # Find tasks with all dependencies closed
    local ready_ids=()
    for task_id in "${!graph[@]}"; do
        # Skip if not open
        [[ "${status_map[$task_id]}" == "open" ]] || continue

        # Check dependencies
        local deps="${graph[$task_id]}"
        local all_deps_closed=true

        if [[ -n "$deps" ]]; then
            IFS=':' read -ra dep_array <<< "$deps"
            for dep_id in "${dep_array[@]}"; do
                [[ -n "$dep_id" ]] || continue
                # Check if dependency exists in status map
                if [[ -v status_map[$dep_id] ]]; then
                    if [[ "${status_map[$dep_id]}" != "closed" ]]; then
                        all_deps_closed=false
                        break
                    fi
                else
                    # Dependency task not found - treat as unmet
                    all_deps_closed=false
                    break
                fi
            done
        fi

        if [[ "$all_deps_closed" == "true" ]]; then
            ready_ids+=("$task_id")
        fi
    done

    # Query database for full task info
    if [[ ${#ready_ids[@]} -gt 0 ]]; then
        local ids_list=$(IFS=','; echo "${ready_ids[*]}")
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
        " "$format"
    else
        echo "No ready tasks found"
        return 1
    fi
}

# Get blocked tasks (has unmet dependencies)
get_blocked_tasks_deterministic() {
    local epic_name="$1"
    local format="${2:-table}"

    # Build dependency graph
    declare -A graph
    declare -A status_map
    build_dependency_graph "$epic_name" graph status_map

    # Find tasks with unmet dependencies
    local blocked_data=()
    for task_id in "${!graph[@]}"; do
        # Skip if not open
        [[ "${status_map[$task_id]}" == "open" ]] || continue

        # Check dependencies
        local deps="${graph[$task_id]}"
        local unmet_deps=()

        if [[ -n "$deps" ]]; then
            IFS=':' read -ra dep_array <<< "$deps"
            for dep_id in "${dep_array[@]}"; do
                [[ -n "$dep_id" ]] || continue
                if [[ -v status_map[$dep_id] ]]; then
                    if [[ "${status_map[$dep_id]}" != "closed" ]]; then
                        unmet_deps+=("$dep_id:${status_map[$dep_id]}")
                    fi
                else
                    unmet_deps+=("$dep_id:missing")
                fi
            done
        fi

        if [[ ${#unmet_deps[@]} -gt 0 ]]; then
            local unmet_str=$(IFS=':'; echo "${unmet_deps[*]}")
            blocked_data+=("$task_id|$unmet_str")
        fi
    done

    # Query database and output
    if [[ ${#blocked_data[@]} -gt 0 ]]; then
        for entry in "${blocked_data[@]}"; do
            IFS='|' read -r task_id unmet_str <<< "$entry"

            local task_info
            task_info=$("$QUERY_SCRIPT" "
                SELECT task_number || '|' || name as data
                FROM ccpm.tasks
                WHERE id = $task_id
            " "csv" 2>/dev/null | tail -1)

            IFS='|' read -r task_num name <<< "$task_info"

            echo "Task #$task_num: $name"
            echo "  Blocked by: $unmet_str"
            echo ""
        done
    else
        echo "No blocked tasks found"
        return 1
    fi
}

# Detect circular dependencies
detect_cycles() {
    local epic_name="$1"

    # Use SQL recursive CTE to detect cycles
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
                dc.path || '->' || CAST(td.task_id AS VARCHAR)
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

# =============================================================================
# CLI Interface
# =============================================================================

show_help() {
    cat << EOF
Deterministic Dependency Resolution

Usage:
  $0 <command> <epic_name> [options]

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
            get_ready_tasks_deterministic "$epic_name"
            ;;
        blocked)
            echo "🚫 Blocked Tasks for: $epic_name"
            echo "================================="
            echo ""
            get_blocked_tasks_deterministic "$epic_name"
            ;;
        sort)
            echo "📊 Dependency Order for: $epic_name"
            echo "===================================="
            echo ""
            topological_sort "$epic_name" "true"
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
            get_task_dependencies "$epic_name" "table"
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
