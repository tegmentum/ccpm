#!/bin/bash
# PRD List - Database Version
# Replaces file-based grep with SQL queries

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_HELPERS="$SCRIPT_DIR/../../../db/helpers.sh"

# Source database helpers
if [[ ! -f "$DB_HELPERS" ]]; then
    echo "Error: Database helpers not found at: $DB_HELPERS" >&2
    exit 1
fi

source "$DB_HELPERS"

# Check if database exists
if ! check_db 2>/dev/null; then
    echo "❌ Database not initialized"
    echo "Create your first PRD with: /pm:prd-new <feature-name>"
    exit 1
fi

# Check for PRDs
total=$(CCPM_DB="${CCPM_DB}" "$QUERY_SCRIPT" "SELECT COUNT(*) as count FROM ccpm.prds WHERE deleted_at IS NULL" "csv" 2>/dev/null | tail -1)

if [[ "$total" == "0" ]] || [[ -z "$total" ]]; then
    echo "📁 No PRDs found. Create your first PRD with: /pm:prd-new <feature-name>"
    exit 0
fi

echo "📋 PRD List"
echo "==========="
echo ""

# Backlog PRDs
echo "🔍 Backlog PRDs:"
backlog=$(CCPM_DB="${CCPM_DB}" "$QUERY_SCRIPT" "
    SELECT name, description
    FROM ccpm.prds
    WHERE status = 'backlog' AND deleted_at IS NULL
    ORDER BY created_at DESC
" "csv" 2>/dev/null)

backlog_count=0
if [[ -n "$backlog" ]]; then
    while IFS=, read -r name desc; do
        # Skip header
        [[ "$name" == "name" ]] && continue
        # Handle empty descriptions
        [[ -z "$desc" ]] && desc="No description"
        echo "   📋 $name - $desc"
        ((backlog_count++))
    done <<< "$backlog"
fi
[[ $backlog_count -eq 0 ]] && echo "   (none)"

echo ""

# In-Progress PRDs
echo "🔄 In-Progress PRDs:"
in_progress=$(CCPM_DB="${CCPM_DB}" "$QUERY_SCRIPT" "
    SELECT name, description
    FROM ccpm.prds
    WHERE status = 'in-progress' AND deleted_at IS NULL
    ORDER BY created_at DESC
" "csv" 2>/dev/null)

in_progress_count=0
if [[ -n "$in_progress" ]]; then
    while IFS=, read -r name desc; do
        # Skip header
        [[ "$name" == "name" ]] && continue
        [[ -z "$desc" ]] && desc="No description"
        echo "   📋 $name - $desc"
        ((in_progress_count++))
    done <<< "$in_progress"
fi
[[ $in_progress_count -eq 0 ]] && echo "   (none)"

echo ""

# Complete PRDs
echo "✅ Complete PRDs:"
complete=$(CCPM_DB="${CCPM_DB}" "$QUERY_SCRIPT" "
    SELECT name, description
    FROM ccpm.prds
    WHERE status = 'complete' AND deleted_at IS NULL
    ORDER BY created_at DESC
" "csv" 2>/dev/null)

complete_count=0
if [[ -n "$complete" ]]; then
    while IFS=, read -r name desc; do
        # Skip header
        [[ "$name" == "name" ]] && continue
        [[ -z "$desc" ]] && desc="No description"
        echo "   📋 $name - $desc"
        ((complete_count++))
    done <<< "$complete"
fi
[[ $complete_count -eq 0 ]] && echo "   (none)"

# Summary
echo ""
echo "📊 PRD Summary"
echo "   Total PRDs: $total"
echo "   Backlog: $backlog_count"
echo "   In-Progress: $in_progress_count"
echo "   Complete: $complete_count"

exit 0
