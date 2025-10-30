#!/usr/bin/env bash
# Add task to existing epic - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Parse arguments
epic_name=""
task_name=""
description=""
sync_github=false
estimated_hours=""
dependencies=""

# Show usage
show_usage() {
    echo "Usage: pm task-add [epic-name] <task-name> [options]"
    echo ""
    echo "If no epic name provided, adds to 'backlog' epic (auto-created if needed)"
    echo ""
    echo "Options:"
    echo "  --description <text>     Task description"
    echo "  --estimate <hours>       Estimated hours"
    echo "  --depends-on <tasks>     Comma-separated task numbers (e.g., 1,2,3)"
    echo "  --sync                   Create GitHub issue immediately"
    echo ""
    echo "Examples:"
    echo "  pm task-add 'Fix validation bug'                      # Adds to backlog"
    echo "  pm task-add my-epic 'Fix validation bug'              # Adds to my-epic"
    echo "  pm task-add my-epic 'Add tests' --estimate 4 --depends-on 3"
    echo "  pm task-add 'Deploy feature' --sync                   # Backlog + GitHub"
}

# Parse command line
if [[ $# -lt 1 ]]; then
    show_usage
    exit 1
fi

# Detect if first arg is epic name or task name
# If first arg starts with - or has spaces/special chars, it's likely a task name
if [[ "$1" == --* ]]; then
    # Started with flag, missing task name
    show_usage
    exit 1
elif [[ $# -eq 1 ]] || [[ "$2" == --* ]]; then
    # Only one arg, or second arg is a flag -> first arg is task name, use backlog
    epic_name="backlog"
    task_name="$1"
    shift 1
else
    # Two args before flags -> first is epic, second is task
    epic_name="$1"
    task_name="$2"
    shift 2
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --description)
            description="$2"
            shift 2
            ;;
        --estimate)
            estimated_hours="$2"
            shift 2
            ;;
        --depends-on)
            dependencies="$2"
            shift 2
            ;;
        --sync)
            sync_github=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

echo "➕ Adding Task to Epic"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get epic from database
epic_data=$(get_epic "$epic_name" "json")

# Auto-create backlog epic if it doesn't exist
if [[ -z "$epic_data" ]] || [[ "$epic_data" == "[]" ]]; then
    if [[ "$epic_name" == "backlog" ]]; then
        echo "Creating 'backlog' epic for miscellaneous tasks..."

        # Use prd-new-db.sh to create backlog PRD from template
        prd_exists=$("$QUERY_SCRIPT" "
            SELECT COUNT(*) as count FROM ccpm.prds
            WHERE name = 'backlog' AND deleted_at IS NULL
        " "json" | jq -r '.[0].count')

        if [[ "$prd_exists" == "0" ]]; then
            # Create backlog PRD in database from static file
            if [[ -f "$PROJECT_ROOT/.claude/prds/backlog.md" ]]; then
                # Extract description from PRD file
                description=$(grep "^description:" "$PROJECT_ROOT/.claude/prds/backlog.md" | sed 's/description: //')

                "$QUERY_SCRIPT" "
                    INSERT INTO ccpm.prds (name, description, status, created_at)
                    VALUES ('backlog', '$description', 'active', datetime('now'))
                " > /dev/null

                echo "  ✅ Created 'backlog' PRD from template"
            else
                # Fallback if template doesn't exist
                "$QUERY_SCRIPT" "
                    INSERT INTO ccpm.prds (name, description, status, created_at)
                    VALUES ('backlog', 'Miscellaneous tasks and issues', 'active', datetime('now'))
                " > /dev/null

                echo "  ✅ Created 'backlog' PRD"
            fi
        fi

        # Get PRD ID
        prd_id=$("$QUERY_SCRIPT" "
            SELECT id FROM ccpm.prds WHERE name = 'backlog'
        " "json" | jq -r '.[0].id')

        # Create backlog epic
        "$QUERY_SCRIPT" "
            INSERT INTO ccpm.epics (
                prd_id, name, content, status, progress, created_at
            ) VALUES (
                $prd_id,
                'backlog',
                'Backlog for miscellaneous tasks, bug fixes, and issues that don''t fit into other epics.',
                'active',
                0,
                datetime('now')
            )
        " > /dev/null

        echo "  ✅ Created 'backlog' epic"
        echo ""

        # Re-fetch epic data
        epic_data=$(get_epic "$epic_name" "json")
    else
        echo "❌ Epic not found: $epic_name"
        echo ""
        echo "Available epics:"
        "$QUERY_SCRIPT" "
            SELECT name FROM ccpm.epics
            WHERE deleted_at IS NULL
            ORDER BY created_at DESC
        " "csv" | tail -n +2 | while read -r name; do
            echo "  • $name"
        done
        exit 1
    fi
fi

epic_id=$(echo "$epic_data" | jq -r '.[0].id')
epic_status=$(echo "$epic_data" | jq -r '.[0].status')

echo "Epic: $epic_name [$epic_status]"

# Get next task number
next_task_num=$("$QUERY_SCRIPT" "
    SELECT COALESCE(MAX(task_number), 0) + 1 as next_num
    FROM ccpm.tasks
    WHERE epic_id = $epic_id
        AND deleted_at IS NULL
" "json" | jq -r '.[0].next_num')

echo "Task Number: $next_task_num"
echo "Task Name: $task_name"
[[ -n "$description" ]] && echo "Description: $description"
[[ -n "$estimated_hours" ]] && echo "Estimated Hours: $estimated_hours"
echo ""

# Validate dependencies if provided
if [[ -n "$dependencies" ]]; then
    echo "Validating dependencies..."
    IFS=',' read -ra dep_array <<< "$dependencies"

    for dep_num in "${dep_array[@]}"; do
        dep_num=$(echo "$dep_num" | xargs) # trim whitespace

        # Check if dependency exists
        dep_exists=$("$QUERY_SCRIPT" "
            SELECT COUNT(*) as count
            FROM ccpm.tasks
            WHERE epic_id = $epic_id
                AND task_number = $dep_num
                AND deleted_at IS NULL
        " "json" | jq -r '.[0].count')

        if [[ "$dep_exists" == "0" ]]; then
            echo "❌ Dependency task #$dep_num not found in epic '$epic_name'"
            exit 1
        fi

        echo "  ✅ Task #$dep_num exists"
    done
    echo ""
fi

# Escape for SQL
escaped_name=$(escape_sql "$task_name")
escaped_desc=$(escape_sql "$description")

# Build INSERT query
insert_query="
    INSERT INTO ccpm.tasks (
        epic_id,
        task_number,
        name,
        description,
        status,
        estimated_hours,
        created_at,
        updated_at
    ) VALUES (
        $epic_id,
        $next_task_num,
        '$escaped_name',
        $(if [[ -n "$description" ]]; then echo "'$escaped_desc'"; else echo "NULL"; fi),
        'open',
        $(if [[ -n "$estimated_hours" ]]; then echo "$estimated_hours"; else echo "NULL"; fi),
        datetime('now'),
        datetime('now')
    )
"

# Insert task
"$QUERY_SCRIPT" "$insert_query" > /dev/null

# Get the task ID using natural key query
task_id=$("$QUERY_SCRIPT" "
    SELECT id
    FROM ccpm.tasks
    WHERE epic_id = $epic_id
        AND task_number = $next_task_num
        AND deleted_at IS NULL
" "json" | jq -r '.[0].id')

echo "✅ Task added to database"
echo "   ID: $task_id"
echo "   Epic: $epic_name"
echo "   Task Number: $next_task_num"
echo ""

# Add dependencies if provided
if [[ -n "$dependencies" ]]; then
    echo "Adding dependencies..."

    for dep_num in "${dep_array[@]}"; do
        dep_num=$(echo "$dep_num" | xargs)

        # Get dependency task ID
        dep_id=$("$QUERY_SCRIPT" "
            SELECT id
            FROM ccpm.tasks
            WHERE epic_id = $epic_id
                AND task_number = $dep_num
                AND deleted_at IS NULL
        " "json" | jq -r '.[0].id')

        # Insert dependency
        "$QUERY_SCRIPT" "
            INSERT INTO ccpm.task_dependencies (task_id, dependency_id)
            VALUES ($task_id, $dep_id)
        " > /dev/null

        echo "  ✅ Depends on task #$dep_num"
    done
    echo ""
fi

# Sync to GitHub if requested
if [[ "$sync_github" == "true" ]]; then
    if ! command -v gh &> /dev/null; then
        echo "⚠️  GitHub CLI not available - skipping sync"
    else
        echo "Syncing to GitHub..."

        # Get epic's GitHub issue number
        epic_gh_issue=$(echo "$epic_data" | jq -r '.[0].github_issue_number // "null"')

        if [[ "$epic_gh_issue" == "null" ]]; then
            echo "⚠️  Epic not synced to GitHub yet"
            echo "   Sync epic first: pm epic-sync $epic_name"
        else
            # Create task body
            task_body="Part of epic #$epic_gh_issue: $epic_name

**Task:** $task_name"

            if [[ -n "$description" ]]; then
                task_body="$task_body

**Description:**
$description"
            fi

            if [[ -n "$estimated_hours" ]]; then
                task_body="$task_body

**Estimated:** ${estimated_hours}h"
            fi

            if [[ -n "$dependencies" ]]; then
                task_body="$task_body

**Dependencies:** Tasks #$dependencies"
            fi

            # Create GitHub issue
            gh_url=$(echo "$task_body" | gh issue create --title "$task_name" --body-file - --label "task" 2>/dev/null || echo "")

            if [[ -n "$gh_url" ]]; then
                gh_issue_num=$(echo "$gh_url" | grep -oE '[0-9]+$')

                # Update task with GitHub issue number
                "$QUERY_SCRIPT" "
                    UPDATE ccpm.tasks
                    SET
                        github_issue_number = $gh_issue_num,
                        github_synced_at = datetime('now')
                    WHERE id = $task_id
                " > /dev/null

                echo "  ✅ Created GitHub issue #$gh_issue_num"
                echo "  🔗 $gh_url"

                # Update epic's task list
                bash "$SCRIPT_DIR/epic-sync-db.sh" "$epic_name" 2>&1 | grep -E "Updated|✅" | sed 's/^/  /'
            else
                echo "  ❌ Failed to create GitHub issue"
            fi
        fi
        echo ""
    fi
fi

# Show next steps
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Task $epic_name/$next_task_num added successfully"
echo ""
echo "🚀 Next steps:"
echo "   View epic: pm epic-show $epic_name"
echo "   Start task: pm task-start $epic_name $next_task_num"
[[ "$sync_github" == "false" ]] && echo "   Sync to GitHub: pm epic-sync $epic_name"
