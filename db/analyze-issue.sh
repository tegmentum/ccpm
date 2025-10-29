#!/usr/bin/env bash
# Deterministic Issue Analysis
# Identifies parallel work streams based on file patterns

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# File Pattern to Work Stream Mappings
# =============================================================================

# Define work stream patterns (simplified regex patterns)
# Each pattern should match file paths
declare -A STREAM_PATTERNS=(
    ["database"]="migrations/ db/schema models/ entities/ schemas/"
    ["api"]="api/ routes/ controllers/ endpoints/ handlers/"
    ["service"]="services/ lib/ utils/ core/"
    ["frontend"]="components/ pages/ views/ ui/ client/"
    ["backend"]="server/ backend/"
    ["tests"]="tests/ test/ .test. .spec. __tests__/"
    ["docs"]="docs/ README CHANGELOG .md"
    ["config"]="config/ .config. .rc package.json"
    ["styles"]="styles/ css/ .css .scss .less"
)

# Stream priorities (lower number = earlier in pipeline)
declare -A STREAM_PRIORITY=(
    ["database"]=1
    ["service"]=2
    ["api"]=3
    ["backend"]=2
    ["frontend"]=4
    ["tests"]=5
    ["docs"]=6
    ["config"]=1
    ["styles"]=4
)

# Typical dependencies between streams
declare -A STREAM_DEPENDENCIES=(
    ["api"]="database,service"
    ["frontend"]="api"
    ["tests"]="database,service,api,frontend"
    ["docs"]="api,frontend"
)

# =============================================================================
# Helper Functions
# =============================================================================

# Match file to stream based on patterns
match_file_to_stream() {
    local file="$1"
    local matched_streams=()

    for stream in "${!STREAM_PATTERNS[@]}"; do
        local patterns="${STREAM_PATTERNS[$stream]}"
        for pattern in $patterns; do
            # Simple substring matching
            if [[ "$file" == *"$pattern"* ]]; then
                matched_streams+=("$stream")
                break
            fi
        done
    done

    # Return unique streams
    printf '%s\n' "${matched_streams[@]}" | sort -u
}

# Get files from git diff (for existing branches)
get_modified_files_from_git() {
    local base_branch="${1:-main}"
    git diff --name-only "$base_branch"...HEAD 2>/dev/null || echo ""
}

# Parse task description for file patterns
extract_file_patterns() {
    local task_file="$1"

    # Look for file mentions in various formats:
    # - `path/to/file.ts`
    # - path/to/file.ts
    # - Files: path/to/file.ts
    grep -oE '`[^`]+\.[a-z]+`|[a-zA-Z0-9_/.-]+\.[a-z]+' "$task_file" 2>/dev/null | \
        sed 's/`//g' | \
        grep -v '^http' | \
        sort -u || echo ""
}

# Analyze file list and group into streams
analyze_files() {
    local -n files_ref=$1
    local -n streams_ref=$2

    # Group files by stream
    for file in "${files_ref[@]}"; do
        local file_streams
        file_streams=$(match_file_to_stream "$file")

        while IFS= read -r stream; do
            [[ -z "$stream" ]] && continue
            if [[ ! -v streams_ref[$stream] ]]; then
                streams_ref[$stream]=""
            fi
            streams_ref[$stream]="${streams_ref[$stream]}${file},"
        done <<< "$file_streams"
    done

    # Trim trailing commas
    for stream in "${!streams_ref[@]}"; do
        streams_ref[$stream]="${streams_ref[$stream]%,}"
    done
}

# Detect file conflicts between streams
detect_conflicts() {
    local -n streams_ref=$1
    local -A file_to_streams

    # Map each file to streams that touch it
    for stream in "${!streams_ref[@]}"; do
        local files="${streams_ref[$stream]}"
        IFS=',' read -ra file_array <<< "$files"
        for file in "${file_array[@]}"; do
            [[ -z "$file" ]] && continue
            if [[ -v file_to_streams[$file] ]]; then
                file_to_streams[$file]="${file_to_streams[$file]},$stream"
            else
                file_to_streams[$file]="$stream"
            fi
        done
    done

    # Find files touched by multiple streams
    local conflicts=()
    for file in "${!file_to_streams[@]}"; do
        local stream_list="${file_to_streams[$file]}"
        local count=$(echo "$stream_list" | tr ',' '\n' | wc -l)
        if [[ $count -gt 1 ]]; then
            conflicts+=("$file:$stream_list")
        fi
    done

    printf '%s\n' "${conflicts[@]}"
}

# Calculate parallelization factor
calculate_parallelization() {
    local stream_count=$1
    local has_conflicts=$2

    if [[ $stream_count -eq 1 ]]; then
        echo "1.0"
    elif [[ $stream_count -eq 2 ]]; then
        [[ "$has_conflicts" == "true" ]] && echo "1.5" || echo "1.8"
    elif [[ $stream_count -eq 3 ]]; then
        [[ "$has_conflicts" == "true" ]] && echo "2.0" || echo "2.5"
    elif [[ $stream_count -ge 4 ]]; then
        [[ "$has_conflicts" == "true" ]] && echo "2.5" || echo "3.5"
    else
        echo "1.0"
    fi
}

# Assess conflict risk
assess_risk() {
    local conflict_count=$1
    local stream_count=$2

    if [[ $conflict_count -eq 0 ]]; then
        echo "Low"
    elif [[ $conflict_count -le 2 ]] && [[ $stream_count -gt 2 ]]; then
        echo "Medium"
    else
        echo "High"
    fi
}

# Determine if streams can run in parallel
can_run_parallel() {
    local stream="$1"
    local completed_streams="$2"

    # Check if stream has dependencies
    if [[ -v STREAM_DEPENDENCIES[$stream] ]]; then
        local deps="${STREAM_DEPENDENCIES[$stream]}"
        IFS=',' read -ra dep_array <<< "$deps"

        for dep in "${dep_array[@]}"; do
            [[ -z "$dep" ]] && continue
            # Check if dependency is in completed list
            if [[ ! "$completed_streams" =~ (^|,)${dep}(,|$) ]]; then
                echo "false"
                return
            fi
        done
    fi

    echo "true"
}

# =============================================================================
# Main Analysis Function
# =============================================================================

analyze_issue() {
    local task_file="$1"
    local output_file="$2"
    local epic_name="$3"
    local issue_num="$4"

    echo "🔍 Analyzing issue #${issue_num}..."
    echo ""

    # Extract files from task description
    echo "📄 Extracting file patterns..."
    local files=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        files+=("$line")
    done < <(extract_file_patterns "$task_file")

    # Also try to get files from git diff if on a branch
    local git_files
    git_files=$(get_modified_files_from_git "main")
    if [[ -n "$git_files" ]]; then
        echo "📊 Found modified files in git..."
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            files+=("$line")
        done <<< "$git_files"
    fi

    # Remove duplicates
    files=($(printf '%s\n' "${files[@]}" | sort -u))

    if [[ ${#files[@]} -eq 0 ]]; then
        echo "⚠️  No files detected. Analysis will be generic."
        files=("src/**/*" "tests/**/*")
    fi

    echo "   Found ${#files[@]} files to analyze"
    echo ""

    # Group files into streams
    echo "🎯 Grouping into work streams..."
    declare -A streams
    analyze_files files streams

    local stream_count=${#streams[@]}
    echo "   Identified $stream_count work streams"
    echo ""

    # Detect conflicts
    echo "🔍 Detecting conflicts..."
    local conflicts
    conflicts=$(detect_conflicts streams)
    local conflict_count=0
    if [[ -n "$conflicts" ]]; then
        conflict_count=$(echo "$conflicts" | grep -c ':')
    fi
    echo "   Found $conflict_count shared files"
    echo ""

    # Calculate metrics
    local parallelization_factor
    parallelization_factor=$(calculate_parallelization "$stream_count" "$([[ $conflict_count -gt 0 ]] && echo true || echo false)")

    local risk_level
    risk_level=$(assess_risk "$conflict_count" "$stream_count")

    # Read task info
    local task_title
    task_title=$(grep "^name:" "$task_file" | sed 's/^name: *//' || echo "Unknown")

    local estimated_hours=8  # Default estimate
    if grep -q "^estimated_hours:" "$task_file"; then
        estimated_hours=$(grep "^estimated_hours:" "$task_file" | sed 's/^estimated_hours: *//')
    fi

    # Calculate timeline
    local hours_per_stream=$((estimated_hours / stream_count))
    local wall_time_parallel=$(echo "$estimated_hours / $parallelization_factor" | bc -l | xargs printf "%.1f")

    # Get current datetime
    local analyzed_at
    analyzed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Generate analysis file
    cat > "$output_file" << EOF
---
issue: ${issue_num}
title: ${task_title}
analyzed: ${analyzed_at}
estimated_hours: ${estimated_hours}
parallelization_factor: ${parallelization_factor}
---

# Parallel Work Analysis: Issue #${issue_num}

## Overview
${task_title}

**Approach**: $([ "$stream_count" -gt 2 ] && echo "Parallel execution recommended" || echo "Sequential or parallel execution")
**Estimated Total Effort**: ${estimated_hours} hours
**Parallelization Factor**: ${parallelization_factor}x
**Conflict Risk**: ${risk_level}

## Parallel Streams

EOF

    # Generate stream sections
    local stream_num=1
    for stream in $(printf '%s\n' "${!streams[@]}" | sort -t',' -k1,1n); do
        local files_list="${streams[$stream]}"
        local priority="${STREAM_PRIORITY[$stream]:-99}"
        local deps="${STREAM_DEPENDENCIES[$stream]:-none}"

        cat >> "$output_file" << EOF
### Stream ${stream_num}: ${stream^} Layer
**Scope**: ${stream^} implementation and testing
**Files**:
EOF

        # List files
        IFS=',' read -ra file_array <<< "$files_list"
        for file in "${file_array[@]}"; do
            [[ -z "$file" ]] && continue
            echo "- ${file}" >> "$output_file"
        done

        cat >> "$output_file" << EOF
**Priority**: ${priority}
**Dependencies**: ${deps}
**Estimated Hours**: ${hours_per_stream}

EOF
        ((stream_num++))
    done

    # Add conflicts section if any
    if [[ $conflict_count -gt 0 ]]; then
        cat >> "$output_file" << EOF
## Coordination Points

### Shared Files
The following files are modified by multiple streams and require coordination:

EOF
        echo "$conflicts" | while IFS=':' read -r file stream_list; do
            [[ -z "$file" ]] && continue
            echo "- \`${file}\` - Streams: ${stream_list}" >> "$output_file"
        done
        echo "" >> "$output_file"
    fi

    # Add strategy section
    cat >> "$output_file" << EOF
## Conflict Risk Assessment
- **Risk Level**: ${risk_level}
EOF

    if [[ $conflict_count -eq 0 ]]; then
        echo "- **Analysis**: Streams work on different files - minimal coordination needed" >> "$output_file"
    elif [[ $conflict_count -le 2 ]]; then
        echo "- **Analysis**: Some shared files - coordinate type definitions and interfaces" >> "$output_file"
    else
        echo "- **Analysis**: Multiple shared files - requires careful coordination or sequential execution" >> "$output_file"
    fi

    cat >> "$output_file" << EOF

## Parallelization Strategy

EOF

    if [[ $stream_count -eq 1 ]]; then
        echo "**Recommended Approach**: Sequential - Single work stream" >> "$output_file"
    elif [[ $conflict_count -gt 3 ]]; then
        echo "**Recommended Approach**: Sequential or Hybrid - High conflict risk" >> "$output_file"
    else
        echo "**Recommended Approach**: Parallel - Launch all streams simultaneously" >> "$output_file"
    fi

    cat >> "$output_file" << EOF

## Expected Timeline

**With parallel execution**:
- Wall time: ${wall_time_parallel} hours
- Total work: ${estimated_hours} hours
- Efficiency gain: $(echo "scale=0; (1 - $wall_time_parallel / $estimated_hours) * 100" | bc)%

**Without parallel execution**:
- Wall time: ${estimated_hours} hours

## Notes
- This analysis is generated deterministically from file patterns
- Adjust stream assignments based on actual implementation needs
- Consider dependencies between streams when launching agents
EOF

    echo "✅ Analysis complete: $output_file"
}

# =============================================================================
# CLI Interface
# =============================================================================

show_help() {
    cat << EOF
Deterministic Issue Analysis

Usage:
  $0 <task_file> <output_file> <epic_name> <issue_number>

Example:
  $0 .claude/epics/user-auth/123.md .claude/epics/user-auth/123-analysis.md user-auth 123

EOF
}

main() {
    local task_file="${1:-}"
    local output_file="${2:-}"
    local epic_name="${3:-}"
    local issue_num="${4:-}"

    if [[ -z "$task_file" ]] || [[ -z "$output_file" ]]; then
        show_help
        exit 1
    fi

    if [[ ! -f "$task_file" ]]; then
        echo "Error: Task file not found: $task_file" >&2
        exit 1
    fi

    analyze_issue "$task_file" "$output_file" "$epic_name" "$issue_num"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
