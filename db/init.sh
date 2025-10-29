#!/bin/bash
# Initialize CCPM SQLite Database
# Creates database and applies schema

set -euo pipefail

CCPM_DB="${CCPM_DB:-$HOME/.claude/ccpm.db}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/schema.sql"

# Check if schema file exists
if [[ ! -f "$SCHEMA_FILE" ]]; then
    echo "Error: Schema file not found at: $SCHEMA_FILE" >&2
    exit 1
fi

# Check if database already exists
if [[ -f "$CCPM_DB" ]]; then
    read -p "Database already exists at $CCPM_DB. Overwrite? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Aborted."
        exit 0
    fi
    rm "$CCPM_DB"
fi

# Create database directory if needed
mkdir -p "$(dirname "$CCPM_DB")"

# Initialize database with schema using SQLite directly
# (DuckDB can read it, but SQLite creates it for better compatibility)
sqlite3 "$CCPM_DB" < "$SCHEMA_FILE"

echo "✅ Database initialized: $CCPM_DB"
echo "Schema applied from: $SCHEMA_FILE"
echo ""
echo "Test with: ./db/query.sh \"SELECT name FROM sqlite_master WHERE type='table'\""
