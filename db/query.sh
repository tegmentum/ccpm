#!/bin/bash
# DuckDB Query Wrapper for CCPM
# Attaches SQLite database and executes query using DuckDB engine

set -euo pipefail

# Default database location
CCPM_DB="${CCPM_DB:-$HOME/.claude/ccpm.db}"

# Check if database exists
if [[ ! -f "$CCPM_DB" ]]; then
    echo "Error: Database not found at: $CCPM_DB" >&2
    echo "Set CCPM_DB environment variable or initialize database first" >&2
    exit 1
fi

# Check if query provided
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <sql_query>" >&2
    echo "Example: $0 \"SELECT * FROM ccpm.tasks WHERE status='open'\"" >&2
    exit 1
fi

QUERY="$1"
FORMAT="${2:-table}"  # Default to table format, can override with 'json', 'csv', etc.

# Execute query with DuckDB
# - Attach SQLite database as 'ccpm' schema
# - Execute the provided query
# - Format output as requested
case "$FORMAT" in
    json)
        duckdb -json -c "ATTACH '$CCPM_DB' AS ccpm (TYPE SQLITE); $QUERY"
        ;;
    csv)
        duckdb -csv -c "ATTACH '$CCPM_DB' AS ccpm (TYPE SQLITE); $QUERY"
        ;;
    markdown)
        duckdb -markdown -c "ATTACH '$CCPM_DB' AS ccpm (TYPE SQLITE); $QUERY"
        ;;
    *)
        duckdb -c "ATTACH '$CCPM_DB' AS ccpm (TYPE SQLITE); $QUERY"
        ;;
esac
