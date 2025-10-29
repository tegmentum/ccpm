#!/usr/bin/env bash
# Export database to markdown files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HELPERS_SCRIPT="$PROJECT_ROOT/db/helpers.sh"
QUERY_SCRIPT="$PROJECT_ROOT/db/query.sh"

# Load database helpers
source "$HELPERS_SCRIPT"

# Check database
check_db || exit 1

# Get export target from argument
target="${1:-all}"
output_dir="${2:-.claude}"

echo "📤 Database Export Tool"
echo "======================"
echo ""

case "$target" in
    "prds"|"prd")
        echo "Exporting PRDs to $output_dir/prds/..."
        mkdir -p "$output_dir/prds"
        
        # Get all PRDs
        prds=$("$QUERY_SCRIPT" "
            SELECT id, name, status, description, content, created_at
            FROM ccpm.prds
            WHERE deleted_at IS NULL
            ORDER BY created_at
        " "json")
        
        if [[ -z "$prds" ]] || [[ "$prds" == "[]" ]]; then
            echo "  No PRDs to export"
            exit 0
        fi
        
        count=0
        while IFS= read -r prd; do
            prd_name=$(echo "$prd" | jq -r '.name')
            prd_status=$(echo "$prd" | jq -r '.status')
            prd_description=$(echo "$prd" | jq -r '.description // ""')
            prd_content=$(echo "$prd" | jq -r '.content // ""')
            prd_created=$(echo "$prd" | jq -r '.created_at')
            
            # Create PRD markdown
            cat > "$output_dir/prds/${prd_name}.md" << PRDEOF
---
name: $prd_name
status: $prd_status
created_at: $prd_created
---

# $prd_name

## Description

$prd_description

## Content

$prd_content
PRDEOF
            
            echo "  ✅ Exported: $prd_name"
            ((count++))
        done < <(echo "$prds" | jq -c '.[]')
        
        echo ""
        echo "✅ Exported $count PRD(s)"
        ;;
        
    "epics"|"epic")
        echo "Exporting epics to $output_dir/epics/..."
        
        # Get all epics
        epics=$("$QUERY_SCRIPT" "
            SELECT e.id, e.name, e.status, e.content, e.created_at, p.name as prd_name
            FROM ccpm.epics e
            JOIN ccpm.prds p ON e.prd_id = p.id
            WHERE e.deleted_at IS NULL
            ORDER BY e.created_at
        " "json")
        
        if [[ -z "$epics" ]] || [[ "$epics" == "[]" ]]; then
            echo "  No epics to export"
            exit 0
        fi
        
        count=0
        while IFS= read -r epic; do
            epic_name=$(echo "$epic" | jq -r '.name')
            epic_status=$(echo "$epic" | jq -r '.status')
            epic_content=$(echo "$epic" | jq -r '.content // ""')
            epic_created=$(echo "$epic" | jq -r '.created_at')
            prd_name=$(echo "$epic" | jq -r '.prd_name')
            epic_id=$(echo "$epic" | jq -r '.id')
            
            # Create epic directory
            mkdir -p "$output_dir/epics/$epic_name"
            
            # Create epic.md
            cat > "$output_dir/epics/$epic_name/epic.md" << EPICEOF
---
name: $epic_name
prd: $prd_name
status: $epic_status
created_at: $epic_created
---

# $epic_name

## Description

$epic_content
EPICEOF
            
            # Export tasks for this epic
            tasks=$("$QUERY_SCRIPT" "
                SELECT task_number, name, status, content, estimated_hours, parallel
                FROM ccpm.tasks
                WHERE epic_id = $epic_id AND deleted_at IS NULL
                ORDER BY task_number
            " "json")
            
            if [[ -n "$tasks" ]] && [[ "$tasks" != "[]" ]]; then
                while IFS= read -r task; do
                    task_num=$(echo "$task" | jq -r '.task_number')
                    task_name=$(echo "$task" | jq -r '.name')
                    task_status=$(echo "$task" | jq -r '.status')
                    task_content=$(echo "$task" | jq -r '.content // ""')
                    task_hours=$(echo "$task" | jq -r '.estimated_hours // ""')
                    task_parallel=$(echo "$task" | jq -r '.parallel')
                    
                    # Get dependencies
                    deps=$("$QUERY_SCRIPT" "
                        SELECT t2.task_number
                        FROM ccpm.task_dependencies td
                        JOIN ccpm.tasks t1 ON td.task_id = t1.id
                        JOIN ccpm.tasks t2 ON td.depends_on_task_id = t2.id
                        WHERE t1.task_number = $task_num AND t1.epic_id = $epic_id
                        ORDER BY t2.task_number
                    " "csv" | tail -n +2 | tr '\n' ',' | sed 's/,$//')
                    
                    # Create task markdown
                    cat > "$output_dir/epics/$epic_name/${task_num}.md" << TASKEOF
---
task_number: $task_num
name: $task_name
status: $task_status
estimated_hours: $task_hours
parallel: $task_parallel
depends_on: [$deps]
---

# Task #$task_num: $task_name

$task_content
TASKEOF
                    
                done < <(echo "$tasks" | jq -c '.[]')
            fi
            
            echo "  ✅ Exported: $epic_name"
            ((count++))
        done < <(echo "$epics" | jq -c '.[]')
        
        echo ""
        echo "✅ Exported $count epic(s)"
        ;;
        
    "all")
        echo "Exporting all data..."
        echo ""
        
        # Export PRDs
        bash "$0" prds "$output_dir"
        echo ""
        
        # Export Epics
        bash "$0" epics "$output_dir"
        ;;
        
    *)
        echo "❌ Unknown target: $target"
        echo ""
        echo "Usage: pm db-export [target] [output-dir]"
        echo ""
        echo "Targets:"
        echo "  prds   - Export PRDs only"
        echo "  epics  - Export epics and tasks"
        echo "  all    - Export everything (default)"
        echo ""
        echo "Examples:"
        echo "  pm db-export"
        echo "  pm db-export prds"
        echo "  pm db-export epics .claude"
        exit 1
        ;;
esac

exit 0
