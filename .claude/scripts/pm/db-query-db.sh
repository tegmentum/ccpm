#!/usr/bin/env bash
# Interactive database query tool

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Get query and format from arguments
query="${1:-}"
format="${2:-table}"

show_help() {
    echo "🔍 Database Query Tool"
    echo "====================="
    echo ""
    echo "Usage: pm db-query [query] [format]"
    echo ""
    echo "Formats:"
    echo "  table  - Pretty table output (default)"
    echo "  json   - JSON array"
    echo "  csv    - CSV format"
    echo ""
    echo "Examples:"
    echo "  pm db-query \"SELECT * FROM ccpm.prds\""
    echo "  pm db-query \"SELECT * FROM ccpm.tasks WHERE status='open'\" json"
    echo "  pm db-query  # Interactive mode"
    echo ""
    echo "Available Tables:"
    echo "  • ccpm.prds - Product Requirements Documents"
    echo "  • ccpm.epics - Implementation epics"
    echo "  • ccpm.tasks - Individual tasks"
    echo "  • ccpm.task_dependencies - Task dependencies"
    echo ""
    echo "Available Views:"
    echo "  • ccpm.ready_tasks - Tasks ready to start"
    echo "  • ccpm.blocked_tasks - Tasks with unmet dependencies"
    echo "  • ccpm.epic_progress - Epic completion statistics"
    echo ""
    echo "Useful Queries:"
    echo "  # Show all PRDs with epic counts"
    echo "  SELECT p.name, COUNT(e.id) as epics"
    echo "  FROM ccpm.prds p"
    echo "  LEFT JOIN ccpm.epics e ON p.id = e.prd_id"
    echo "  WHERE p.deleted_at IS NULL"
    echo "  GROUP BY p.name"
    echo ""
    echo "  # Show task dependencies"
    echo "  SELECT t1.task_number || ' -> ' || t2.task_number as dependency"
    echo "  FROM ccpm.task_dependencies td"
    echo "  JOIN ccpm.tasks t1 ON td.task_id = t1.id"
    echo "  JOIN ccpm.tasks t2 ON td.depends_on_task_id = t2.id"
    echo ""
    echo "  # Show epic progress"
    echo "  SELECT * FROM ccpm.epic_progress"
}

if [[ "$query" == "-h" ]] || [[ "$query" == "--help" ]]; then
    show_help
    exit 0
fi

# Interactive mode
if [[ -z "$query" ]]; then
    echo "🔍 Database Query Tool - Interactive Mode"
    echo "========================================="
    echo ""
    echo "Enter SQL query (or 'help' for examples, 'exit' to quit):"
    echo ""
    
    while true; do
        echo -n "query> "
        read -r query
        
        if [[ -z "$query" ]]; then
            continue
        fi
        
        if [[ "$query" == "exit" ]] || [[ "$query" == "quit" ]]; then
            echo "Goodbye!"
            exit 0
        fi
        
        if [[ "$query" == "help" ]]; then
            show_help
            echo ""
            continue
        fi
        
        # Show tables
        if [[ "$query" == "tables" ]] || [[ "$query" == "\\dt" ]]; then
            "$QUERY_SCRIPT" "SHOW TABLES" "table"
            echo ""
            continue
        fi
        
        # Describe table
        if [[ "$query" =~ ^\\d[[:space:]]+(.+)$ ]] || [[ "$query" =~ ^describe[[:space:]]+(.+)$ ]]; then
            table_name="${BASH_REMATCH[1]}"
            "$QUERY_SCRIPT" "DESCRIBE $table_name" "table"
            echo ""
            continue
        fi
        
        # Execute query
        "$QUERY_SCRIPT" "$query" "$format"
        echo ""
    done
else
    # Non-interactive mode
    "$QUERY_SCRIPT" "$query" "$format"
fi

exit 0
