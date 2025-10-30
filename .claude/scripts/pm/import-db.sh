#!/usr/bin/env bash
# Import GitHub issues to database - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Check gh CLI
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found"
    echo "Install from: https://cli.github.com/"
    exit 1
fi

# Parse options
epic_filter=""
label_filter=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --epic)
            epic_filter="$2"
            shift 2
            ;;
        --label)
            label_filter="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: pm import [--epic <epic-name>] [--label <label>]"
            exit 1
            ;;
    esac
done

echo "📥 Importing GitHub Issues"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Build GitHub query
gh_args="--limit 1000 --json number,title,body,state,labels,createdAt,updatedAt"
[[ -n "$label_filter" ]] && gh_args="$gh_args --label $label_filter"

echo "Fetching issues from GitHub..."
issues=$(gh issue list $gh_args 2>/dev/null || echo "[]")

if [[ "$issues" == "[]" ]]; then
    echo "❌ No issues found on GitHub"
    exit 0
fi

total_issues=$(echo "$issues" | jq 'length')
echo "Found $total_issues issues on GitHub"
echo ""

# Track import stats
imported_epics=0
imported_tasks=0
skipped=0

# Process each issue
echo "$issues" | jq -c '.[]' | while read -r issue; do
    number=$(echo "$issue" | jq -r '.number')
    title=$(echo "$issue" | jq -r '.title')
    body=$(echo "$issue" | jq -r '.body // ""')
    state=$(echo "$issue" | jq -r '.state')
    labels=$(echo "$issue" | jq -r '.labels[]?.name' | tr '\n' ',' | sed 's/,$//')
    created_at=$(echo "$issue" | jq -r '.createdAt')
    updated_at=$(echo "$issue" | jq -r '.updatedAt')

    # Check if already imported
    existing=$("$QUERY_SCRIPT" "
        SELECT COUNT(*) as count
        FROM ccpm.tasks
        WHERE github_issue_number = $number
            AND deleted_at IS NULL
    " "json" | jq -r '.[0].count')

    if [[ "$existing" -gt 0 ]]; then
        echo "  ⏭️  Skipping #$number (already imported)"
        ((skipped++))
        continue
    fi

    # Determine if epic or task based on labels
    is_epic=false
    epic_name=""

    if echo "$labels" | grep -q "epic"; then
        is_epic=true
        # Generate epic name from title (kebab-case)
        epic_name=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
    elif [[ -n "$epic_filter" ]]; then
        epic_name="$epic_filter"
    elif echo "$labels" | grep -qE "epic:"; then
        # Extract epic name from epic:name label
        epic_name=$(echo "$labels" | grep -oE "epic:[^,]+" | sed 's/epic://')
    else
        # Default to "imported" epic
        epic_name="imported"
    fi

    # Escape for SQL
    escaped_title=$(escape_sql "$title")
    escaped_body=$(escape_sql "$body")
    db_state=$(echo "$state" | tr '[:upper:]' '[:lower:]')
    [[ "$db_state" == "open" ]] && db_state="open"
    [[ "$db_state" == "closed" ]] && db_state="closed"

    if [[ "$is_epic" == "true" ]]; then
        # Import as epic
        # Check if PRD exists, create placeholder if not
        prd_id=$("$QUERY_SCRIPT" "
            SELECT id FROM ccpm.prds
            WHERE name = 'imported'
                AND deleted_at IS NULL
        " "json" | jq -r '.[0].id // "null"')

        if [[ "$prd_id" == "null" ]]; then
            "$QUERY_SCRIPT" "
                INSERT INTO ccpm.prds (name, description, status, created_at)
                VALUES ('imported', 'Imported from GitHub', 'active', datetime('now'))
            " > /dev/null
            prd_id=$("$QUERY_SCRIPT" "SELECT id FROM ccpm.prds WHERE name = 'imported'" "json" | jq -r '.[0].id')
        fi

        # Create epic
        "$QUERY_SCRIPT" "
            INSERT INTO ccpm.epics (
                prd_id, name, content, status, progress,
                github_issue_number, github_synced_at,
                created_at, updated_at
            ) VALUES (
                $prd_id, '${escaped_title}', '${escaped_body}', '$db_state', 0,
                $number, datetime('now'),
                '$created_at', '$updated_at'
            )
        " > /dev/null

        echo "  ✅ Imported epic #$number: $title"
        ((imported_epics++))
    else
        # Import as task
        # Ensure epic exists
        epic_id=$("$QUERY_SCRIPT" "
            SELECT id FROM ccpm.epics
            WHERE name = '$epic_name'
                AND deleted_at IS NULL
        " "json" | jq -r '.[0].id // "null"')

        if [[ "$epic_id" == "null" ]]; then
            # Create placeholder epic
            prd_id=$("$QUERY_SCRIPT" "
                SELECT id FROM ccpm.prds WHERE name = 'imported'
            " "json" | jq -r '.[0].id // "null"')

            if [[ "$prd_id" == "null" ]]; then
                "$QUERY_SCRIPT" "
                    INSERT INTO ccpm.prds (name, description, status, created_at)
                    VALUES ('imported', 'Imported from GitHub', 'active', datetime('now'))
                " > /dev/null
                prd_id=$("$QUERY_SCRIPT" "SELECT id FROM ccpm.prds WHERE name = 'imported'" "json" | jq -r '.[0].id')
            fi

            "$QUERY_SCRIPT" "
                INSERT INTO ccpm.epics (prd_id, name, content, status, progress, created_at)
                VALUES ($prd_id, '$epic_name', 'Imported tasks', 'active', 0, datetime('now'))
            " > /dev/null

            epic_id=$("$QUERY_SCRIPT" "SELECT id FROM ccpm.epics WHERE name = '$epic_name'" "json" | jq -r '.[0].id')
        fi

        # Get next task number
        max_task=$("$QUERY_SCRIPT" "
            SELECT COALESCE(MAX(task_number), 0) as max_num
            FROM ccpm.tasks
            WHERE epic_id = $epic_id
        " "json" | jq -r '.[0].max_num')
        next_task=$((max_task + 1))

        # Create task
        "$QUERY_SCRIPT" "
            INSERT INTO ccpm.tasks (
                epic_id, task_number, name, description, status,
                github_issue_number, github_synced_at,
                created_at, updated_at
            ) VALUES (
                $epic_id, $next_task, '${escaped_title}', '${escaped_body}', '$db_state',
                $number, datetime('now'),
                '$created_at', '$updated_at'
            )
        " > /dev/null

        echo "  ✅ Imported task #$number: $title → $epic_name"
        ((imported_tasks++))
    fi
done

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Import Summary:"
echo "  Epics: $imported_epics"
echo "  Tasks: $imported_tasks"
echo "  Skipped (already exists): $skipped"
echo "  Total: $total_issues"
echo ""
echo "🚀 Next:"
echo "  pm status  - View imported work"
echo "  pm epic-list  - See all epics"
