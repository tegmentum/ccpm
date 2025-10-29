#!/usr/bin/env bash
# Decompose epic into tasks with AI assistance - Database version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Get epic name and mode from arguments
epic_name="${1:-}"
mode="${2:-ai}"  # ai or manual

if [[ -z "$epic_name" ]]; then
    echo "❌ Usage: pm epic-decompose-ai <epic-name> [mode]"
    echo ""
    echo "Modes:"
    echo "  ai     - Use AI to suggest task breakdown (default)"
    echo "  manual - Enter tasks manually"
    echo ""
    echo "Example: pm epic-decompose-ai user-auth-backend"
    exit 1
fi

# Get epic details
epic_data=$(get_epic "$epic_name" "json")

if [[ -z "$epic_data" ]] || [[ "$epic_data" == "[]" ]]; then
    echo "❌ Epic not found: $epic_name"
    exit 1
fi

epic_id=$(echo "$epic_data" | jq -r '.[0].id')
epic_content=$(echo "$epic_data" | jq -r '.[0].content // ""')
prd_id=$(echo "$epic_data" | jq -r '.[0].prd_id')

# Get PRD details
prd_data=$("$QUERY_SCRIPT" "
    SELECT name, content FROM ccpm.prds WHERE id = $prd_id
" "json")
prd_name=$(echo "$prd_data" | jq -r '.[0].name')
prd_content=$(echo "$prd_data" | jq -r '.[0].content // ""')

# Check if epic already has tasks
existing_count=$("$QUERY_SCRIPT" "
    SELECT COUNT(*) FROM ccpm.tasks
    WHERE epic_id = $epic_id AND deleted_at IS NULL
" "csv" | tail -1)

if [[ $existing_count -gt 0 ]]; then
    echo "⚠️  Epic already has $existing_count task(s)"
    read -p "Replace existing tasks? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi
    
    # Soft delete existing tasks
    "$QUERY_SCRIPT" "
        UPDATE tasks SET deleted_at = CURRENT_TIMESTAMP
        WHERE epic_id = $epic_id
    " "csv" > /dev/null
fi

echo "📋 Decomposing epic: $epic_name"
echo "PRD: $prd_name"
echo ""

if [[ "$mode" == "ai" ]]; then
    echo "🤖 Using AI to generate task breakdown..."
    echo ""
    echo "Epic Description:"
    echo "$epic_content" | sed 's/^/  /'
    echo ""
    
    # Create a prompt file for AI
    cat > /tmp/epic_decompose_prompt.txt << PROMPTEOF
Break down the following epic into concrete, actionable tasks.

PRD Context:
$prd_content

Epic: $epic_name
Description:
$epic_content

Please provide a task breakdown in the following JSON format:
{
  "tasks": [
    {
      "name": "Task name",
      "description": "Detailed description",
      "estimated_hours": 4,
      "dependencies": [1, 2]  // Task numbers this depends on
    }
  ]
}

Guidelines:
- Each task should be completable in 1-8 hours
- Tasks should be ordered logically
- Include dependencies where tasks must wait for others
- Be specific about what needs to be done
- Include testing tasks
- Consider parallel work where possible
PROMPTEOF
    
    echo "📝 AI Prompt prepared. Please use Claude Code to generate the task breakdown."
    echo ""
    echo "Prompt saved to: /tmp/epic_decompose_prompt.txt"
    echo ""
    echo "Would you like to:"
    echo "  1. Paste JSON response directly"
    echo "  2. Load from file"
    echo "  3. Cancel"
    echo ""
    read -p "Choice (1-3): " -n 1 -r choice
    echo
    echo ""
    
    case "$choice" in
        1)
            echo "Paste the JSON response below (press Ctrl+D when done):"
            tasks_json=$(cat)
            ;;
        2)
            read -p "Enter file path: " file_path
            if [[ ! -f "$file_path" ]]; then
                echo "❌ File not found: $file_path"
                exit 1
            fi
            tasks_json=$(cat "$file_path")
            ;;
        *)
            echo "Cancelled"
            exit 0
            ;;
    esac
    
    # Validate JSON
    if ! echo "$tasks_json" | jq empty 2>/dev/null; then
        echo "❌ Invalid JSON format"
        exit 1
    fi
    
    # Extract tasks array
    tasks_array=$(echo "$tasks_json" | jq -r '.tasks // .')
    
    if [[ "$tasks_array" == "null" ]] || [[ "$tasks_array" == "[]" ]]; then
        echo "❌ No tasks found in JSON"
        exit 1
    fi
    
    # Create tasks
    task_number=1
    task_count=$(echo "$tasks_array" | jq 'length')
    
    echo "Creating $task_count tasks..."
    echo ""
    
    # First pass: Create all tasks
    declare -A task_ids
    
    while IFS= read -r task; do
        task_name=$(echo "$task" | jq -r '.name')
        task_desc=$(echo "$task" | jq -r '.description // ""')
        task_hours=$(echo "$task" | jq -r '.estimated_hours // 0')
        
        # Create task
        task_id=$(create_task "$epic_id" "$task_number" "$task_name" "$task_desc" "$task_hours" "0" "open")
        
        if [[ -n "$task_id" ]]; then
            task_ids[$task_number]=$task_id
            echo "  ✅ #$task_number - $task_name (${task_hours}h)"
            ((task_number++))
        else
            echo "  ❌ Failed to create task: $task_name"
        fi
    done < <(echo "$tasks_array" | jq -c '.[]')
    
    echo ""
    echo "Creating task dependencies..."
    echo ""
    
    # Second pass: Create dependencies
    task_number=1
    while IFS= read -r task; do
        deps=$(echo "$task" | jq -r '.dependencies // [] | join(",")')
        
        if [[ -n "$deps" ]] && [[ "$deps" != "" ]]; then
            task_id="${task_ids[$task_number]}"
            
            IFS=',' read -ra dep_array <<< "$deps"
            for dep_num in "${dep_array[@]}"; do
                if [[ -n "${task_ids[$dep_num]:-}" ]]; then
                    dep_id="${task_ids[$dep_num]}"
                    create_task_dependency "$task_id" "$dep_id"
                    echo "  ✅ Task #$task_number depends on #$dep_num"
                fi
            done
        fi
        
        ((task_number++))
    done < <(echo "$tasks_array" | jq -c '.[]')
    
else
    # Manual mode - same as original epic-decompose-db.sh
    echo "Enter tasks one at a time. Press Ctrl+D when done."
    echo "Format: <task-name> | <estimated-hours> | <description>"
    echo ""
    
    task_number=1
    while IFS='|' read -r task_name estimated_hours description; do
        task_name=$(echo "$task_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        estimated_hours=$(echo "$estimated_hours" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        description=$(echo "$description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [[ -z "$task_name" ]]; then
            continue
        fi
        
        if [[ -z "$estimated_hours" ]]; then
            estimated_hours="0"
        fi
        
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
    
    # Ask about dependencies
    echo ""
    echo "Do you want to add task dependencies? (y/N)"
    read -p "> " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Enter dependencies in format: <task-number> depends on <task-number>,<task-number>"
        echo "Press Ctrl+D when done."
        echo ""
        
        while read -r line; do
            if [[ "$line" =~ ^([0-9]+)[[:space:]]+depends[[:space:]]+on[[:space:]]+([0-9,]+)$ ]]; then
                task_num="${BASH_REMATCH[1]}"
                deps="${BASH_REMATCH[2]}"
                
                task_id=$("$QUERY_SCRIPT" "
                    SELECT id FROM ccpm.tasks
                    WHERE epic_id = $epic_id AND task_number = $task_num
                " "csv" | tail -1)
                
                if [[ -z "$task_id" ]]; then
                    echo "  ❌ Task #$task_num not found"
                    continue
                fi
                
                IFS=',' read -ra dep_array <<< "$deps"
                for dep_num in "${dep_array[@]}"; do
                    dep_num=$(echo "$dep_num" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    
                    dep_id=$("$QUERY_SCRIPT" "
                        SELECT id FROM ccpm.tasks
                        WHERE epic_id = $epic_id AND task_number = $dep_num
                    " "csv" | tail -1)
                    
                    if [[ -z "$dep_id" ]]; then
                        echo "  ❌ Dependency task #$dep_num not found"
                        continue
                    fi
                    
                    create_task_dependency "$task_id" "$dep_id"
                    echo "  ✅ Task #$task_num depends on #$dep_num"
                done
            fi
        done
    fi
fi

echo ""
echo "✅ Epic decomposed successfully!"
echo ""
echo "💡 Next steps:"
echo "  • View epic: pm epic-show $epic_name"
echo "  • Start ready tasks: pm next"
echo "  • Sync to GitHub: pm sync push epic --epic $epic_name"

exit 0
