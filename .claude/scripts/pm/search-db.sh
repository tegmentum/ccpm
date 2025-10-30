#!/usr/bin/env bash
# Search database - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Get search query
query="${1:-}"

if [[ -z "$query" ]]; then
    echo "Usage: pm search <query>"
    echo ""
    echo "Searches across:"
    echo "  • PRD names and descriptions"
    echo "  • Epic names and content"
    echo "  • Task names and descriptions"
    echo ""
    echo "Examples:"
    echo "  pm search authentication"
    echo "  pm search 'user login'"
    echo "  pm search api"
    exit 1
fi

# Escape query for SQL LIKE
escaped_query=$(escape_sql "$query")

echo "🔍 Searching for: '$query'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Search PRDs
prd_results=$("$QUERY_SCRIPT" "
    SELECT
        name,
        description,
        status
    FROM ccpm.prds
    WHERE deleted_at IS NULL
        AND (
            name LIKE '%${escaped_query}%'
            OR description LIKE '%${escaped_query}%'
        )
    ORDER BY created_at DESC
" "json")

if [[ -n "$prd_results" ]] && [[ "$prd_results" != "[]" ]]; then
    prd_count=$(echo "$prd_results" | jq 'length')
    echo "📋 PRDs ($prd_count found):"
    echo "$prd_results" | jq -r '.[] | "  • \(.name) [\(.status)]"'
    echo ""
fi

# Search Epics
epic_results=$("$QUERY_SCRIPT" "
    SELECT
        e.name,
        e.status,
        e.progress,
        p.name as prd_name
    FROM ccpm.epics e
    LEFT JOIN ccpm.prds p ON e.prd_id = p.id
    WHERE e.deleted_at IS NULL
        AND (
            e.name LIKE '%${escaped_query}%'
            OR e.content LIKE '%${escaped_query}%'
        )
    ORDER BY e.created_at DESC
" "json")

if [[ -n "$epic_results" ]] && [[ "$epic_results" != "[]" ]]; then
    epic_count=$(echo "$epic_results" | jq 'length')
    echo "🎯 Epics ($epic_count found):"
    echo "$epic_results" | jq -r '.[] | "  • \(.name) [\(.status), \(.progress)%]" + (if .prd_name then " - PRD: \(.prd_name)" else "" end)'
    echo ""
fi

# Search Tasks
task_results=$("$QUERY_SCRIPT" "
    SELECT
        t.name,
        t.task_number,
        t.status,
        t.github_issue_number,
        e.name as epic_name
    FROM ccpm.tasks t
    JOIN ccpm.epics e ON t.epic_id = e.id
    WHERE t.deleted_at IS NULL
        AND (
            t.name LIKE '%${escaped_query}%'
            OR t.description LIKE '%${escaped_query}%'
        )
    ORDER BY t.created_at DESC
" "json")

if [[ -n "$task_results" ]] && [[ "$task_results" != "[]" ]]; then
    task_count=$(echo "$task_results" | jq 'length')
    echo "✅ Tasks ($task_count found):"
    echo "$task_results" | jq -r '.[] | "  • \(.epic_name)/\(.task_number) - \(.name) [\(.status)]" + (if .github_issue_number then " #\(.github_issue_number)" else "" end)'
    echo ""
fi

# Summary
total=$((
    $(echo "${prd_results:-[]}" | jq 'length') +
    $(echo "${epic_results:-[]}" | jq 'length') +
    $(echo "${task_results:-[]}" | jq 'length')
))

if [[ $total -eq 0 ]]; then
    echo "❌ No results found for '$query'"
    echo ""
    echo "Try:"
    echo "  • Different search terms"
    echo "  • Partial matches (searches are case-insensitive)"
    echo "  • pm prd-list  or  pm epic-list  to see all items"
else
    echo "Found $total total results"
fi
