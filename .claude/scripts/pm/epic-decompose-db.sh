#!/usr/bin/env bash
# Decompose epic into tasks - Database version
# Prompts user to enter tasks manually

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Get epic name from argument
epic_name="${1:-}"

if [[ -z "$epic_name" ]]; then
    echo "❌ Usage: pm epic-decompose <epic-name>"
    echo ""
    echo "Example: pm epic-decompose user-auth-backend"
    exit 1
fi

# Get epic details
epic_data=$(get_epic "$epic_name" "json")

if [[ -z "$epic_data" ]] || [[ "$epic_data" == "[]" ]]; then
    echo "❌ Epic not found: $epic_name"
    exit 1
fi

epic_id=$(echo "$epic_data" | jq -r '.[0].id')

# Check if epic already has tasks
existing_count=$("$QUERY_SCRIPT" "
    SELECT COUNT(*) FROM ccpm.tasks
    WHERE epic_id = $epic_id AND deleted_at IS NULL
" "csv" | tail -1)

if [[ $existing_count -gt 0 ]]; then
    echo "⚠️  Epic already has $existing_count task(s)"
    read -p "Add more tasks? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi
    task_number=$((existing_count + 1))
else
    task_number=1
fi

echo "📋 Decomposing epic: $epic_name"
echo ""
echo "Enter tasks one at a time. Press Ctrl+D when done."
echo "Format: <task-name> | <estimated-hours> | <description>"
echo ""
echo "Example: Database schema | 2 | Create user and session tables"
echo ""

while IFS='|' read -r task_name estimated_hours description; do
    # Trim whitespace
    task_name=$(echo "$task_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    estimated_hours=$(echo "$estimated_hours" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    description=$(echo "$description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [[ -z "$task_name" ]]; then
        continue
    fi
    
    # Default estimated hours
    if [[ -z "$estimated_hours" ]]; then
        estimated_hours="0"
    fi
    
    # Create task
    task_id=$(create_task "$epic_id" "$task_number" "$task_name" "$description" "$estimated_hours" "0" "open")
    
    if [[ -n "$task_id" ]]; then
        echo "  ✅ #$task_number - $task_name (${estimated_hours}h)"
        ((task_number++))
    else
        echo "  ❌ Failed to create task: $task_name"
    fi
done

total_created=$((task_number - 1))

if [[ $total_created -eq 0 ]]; then
    echo ""
    echo "No tasks created"
    exit 0
fi

echo ""
echo "✅ Created $total_created task(s) for epic: $epic_name"
echo ""

# Ask about dependencies
echo "Do you want to add task dependencies? (y/N)"
read -p "> " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Enter dependencies in format: <task-number> depends on <task-number>"
    echo "Example: 3 depends on 1,2"
    echo "Press Ctrl+D when done."
    echo ""
    
    while read -r line; do
        if [[ "$line" =~ ^([0-9]+)[[:space:]]+depends[[:space:]]+on[[:space:]]+([0-9,]+)$ ]]; then
            task_num="${BASH_REMATCH[1]}"
            deps="${BASH_REMATCH[2]}"
            
            # Get task ID
            task_id=$("$QUERY_SCRIPT" "
                SELECT id FROM ccpm.tasks
                WHERE epic_id = $epic_id AND task_number = $task_num
            " "csv" | tail -1)
            
            if [[ -z "$task_id" ]]; then
                echo "  ❌ Task #$task_num not found"
                continue
            fi
            
            # Process each dependency
            IFS=',' read -ra dep_array <<< "$deps"
            for dep_num in "${dep_array[@]}"; do
                dep_num=$(echo "$dep_num" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                
                # Get dependency task ID
                dep_id=$("$QUERY_SCRIPT" "
                    SELECT id FROM ccpm.tasks
                    WHERE epic_id = $epic_id AND task_number = $dep_num
                " "csv" | tail -1)
                
                if [[ -z "$dep_id" ]]; then
                    echo "  ❌ Dependency task #$dep_num not found"
                    continue
                fi
                
                # Create dependency
                create_task_dependency "$task_id" "$dep_id"
                echo "  ✅ Task #$task_num depends on #$dep_num"
            done
        fi
    done
fi

echo ""
echo "💡 Next steps:"
echo "  • View epic: pm epic-show $epic_name"
echo "  • Start ready tasks: pm next"
echo "  • Sync to GitHub: pm sync push epic --epic $epic_name"

exit 0
