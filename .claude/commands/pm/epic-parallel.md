---
allowed-tools: Bash, Read, Task
---

# Epic Parallel

Launch parallel agents to work on ready tasks in the current epic.

## Usage
```
/pm:epic-parallel [epic_name]
```

If no epic name provided, detects epic from current worktree/branch.

## Prerequisites

Before running this command:
1. Epic workspace must be set up (`pm epic-start <epic>`)
2. At least one task should be ready to start
3. Optionally, tasks can have analysis files for better parallelization

## Instructions

### 1. Detect Epic Context

**If in worktree:**
```bash
# Get current branch name
branch=$(git branch --show-current)

# Extract epic name from branch (epic/name -> name)
if [[ "$branch" == epic/* ]]; then
    epic_name="${branch#epic/}"
else
    echo "❌ Not in an epic branch. Current branch: $branch"
    echo "Epic branches should be named: epic/<epic-name>"
    exit 1
fi
```

**If epic name provided:**
Use `$ARGUMENTS` as epic name.

### 2. Validate Epic and Get Ready Tasks

Run deterministic query:
```bash
bash .claude/scripts/pm/next-db.sh "$epic_name"
```

Parse output to get ready tasks. If none ready:
```
ℹ️  No tasks ready for parallel execution

Reasons:
  - All tasks may be blocked by dependencies
  - Tasks may already be in progress
  - Epic may be complete

Check status: pm epic-show $epic_name
```

### 3. Check for Analysis Files

For each ready task, check if analysis exists:
```bash
# Check if task has been analyzed
if [ -f ".claude/epics/$epic_name/${task_number}-analysis.md" ]; then
    echo "✅ Task ${task_number} has analysis"
else
    echo "⚠️  Task ${task_number} not analyzed"
fi
```

**If no analyses exist:**
Ask user:
```
No tasks have been analyzed for parallel work streams.

Options:
  1. Analyze all ready tasks now
  2. Work sequentially (skip parallel execution)
  3. Cancel

Choose (1/2/3):
```

If user chooses 1, analyze each ready task using `/pm:issue-analyze`.

### 4. Review Parallel Plan

For each ready task with analysis, show parallel work streams:

```
📊 Parallel Execution Plan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Task #1: Database Schema
  From analysis: 2 parallel streams identified
  ├─ Stream A: Schema DDL (database-specialist)
  │  Files: db/schema.sql, db/migrations/
  │  Estimated: 4h
  └─ Stream B: Seed Data (database-specialist)
     Files: db/seeds/
     Estimated: 2h

Task #2: API Endpoints
  From analysis: 3 parallel streams identified
  ├─ Stream A: User endpoints (backend-specialist)
  │  Files: src/api/users/
  │  Estimated: 6h
  ├─ Stream B: Auth endpoints (backend-specialist)
  │  Files: src/api/auth/
  │  Estimated: 4h
  └─ Stream C: Tests (backend-specialist)
     Files: tests/api/
     Estimated: 3h
     Dependencies: Stream A, B

Total: 5 streams across 2 tasks
Estimated parallel time: 6h (vs 19h sequential)
```

Ask for confirmation:
```
Launch parallel agents? (yes/no):
```

### 5. Launch Parallel Agents

**IMPORTANT:** Use the Task tool to launch agents in parallel. Send a single message with multiple Task tool calls.

For each stream, create a task invocation:

```yaml
Task:
  description: "Epic $epic_name - Task ${task_number} - ${stream_name}"
  subagent_type: "parallel-worker"
  model: "sonnet"  # Use sonnet for complex work
  prompt: |
    You are working on Epic: $epic_name
    Task #${task_number}: ${task_name}
    Stream: ${stream_name}

    ## Context

    Working directory: $(pwd)
    Branch: $(git branch --show-current)
    Epic Issue: ${epic_github_issue}
    Task Issue: ${task_github_issue}

    ## Your Scope

    ${stream_scope}

    Files you should modify:
    ${stream_files}

    ## Requirements

    Read the full task requirements:
    - Task file: .claude/epics/$epic_name/tasks/${task_number}.md (if exists)
    - Analysis: .claude/epics/$epic_name/${task_number}-analysis.md

    ## Coordination Rules

    1. **Stay in scope**: Only modify files listed in your stream
    2. **Commit frequently**: Use format "Task #${task_number} (${stream_name}): <specific change>"
    3. **Dependencies**: ${stream_dependencies}
    4. **Conflicts**: Check analysis for files that need coordination

    ## When Complete

    1. Run tests for your changes
    2. Commit all changes
    3. Report completion with summary of:
       - Files modified
       - Tests added/updated
       - Any blockers encountered
```

**Launch all streams in parallel:**
Send a single message containing all Task tool invocations for independent streams.

For dependent streams, wait for dependencies to complete before launching.

### 6. Track Execution

Create/update execution tracking file:
```bash
mkdir -p .claude/epics/$epic_name/execution
cat > .claude/epics/$epic_name/execution/parallel-run-$(date +%Y%m%d-%H%M%S).md << EOF
---
started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
epic: $epic_name
branch: $(git branch --show-current)
---

# Parallel Execution

## Active Streams

$(for each stream)
- Stream ${stream_id}: Task #${task_number} ${stream_name}
  - Agent: parallel-worker
  - Status: Running
  - Started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
$(done)

## Monitoring

Watch progress:
  git log --oneline
  git status

Check branch:
  git diff main...HEAD

Stop and review:
  Review agent outputs when complete
EOF
```

### 7. Monitor Progress

Show monitoring information:
```
🚀 Parallel Agents Launched
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Active Streams: ${stream_count}
  • Stream 1: Task #1 Schema DDL
  • Stream 2: Task #1 Seed Data
  • Stream 3: Task #2 User endpoints
  • Stream 4: Task #2 Auth endpoints

Waiting for Dependencies: ${waiting_count}
  • Stream 5: Task #2 Tests (waiting for 3, 4)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Monitor Progress:

  Watch commits:
    git log --oneline --graph

  Check changes:
    git status
    git diff

  View by stream:
    git log --grep "Task #1"
    git log --grep "Schema DDL"

💡 The agents will work independently and commit their changes.
   You'll see their outputs when each completes.

⏸️  To stop: The agents will complete their current work.
   You can review and merge their commits when done.
```

### 8. Handle Dependencies

As streams complete:
1. Check if any waiting streams can now start
2. Launch newly-ready streams
3. Update execution tracking file

### 9. Completion Summary

When all streams complete (or user stops):
```
✅ Parallel Execution Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Completed Streams: ${completed_count}
Failed Streams: ${failed_count}
Cancelled: ${cancelled_count}

Branch Status:
  Commits: $(git rev-list --count HEAD ^main)
  Changed files: $(git diff --name-only main...HEAD | wc -l)

Next Steps:
  1. Review changes: git diff main...HEAD
  2. Run full test suite
  3. Create PR: pm epic-merge $epic_name
  4. Or continue work: pm task-start $epic_name <next-task>
```

## Error Handling

**If not in epic worktree:**
```
❌ Not in an epic workspace

You must be in an epic worktree to launch parallel work.

Setup workspace first:
  pm epic-start <epic-name>
  cd ../epic-<epic-name>
  pm epic-parallel
```

**If no ready tasks:**
```
ℹ️  No tasks ready to start

Check epic status:
  pm epic-show $epic_name

View blocked tasks:
  pm blocked $epic_name
```

**If agent launch fails:**
```
❌ Failed to launch Stream ${stream_id}
  Error: ${error_message}

Continue with remaining streams? (yes/no):
```

## Important Notes

- **Use parallel-worker subagent type** for coordination
- **Launch independent streams in parallel** using single message with multiple Task calls
- **Launch dependent streams sequentially** after dependencies complete
- **Track in execution files** for audit trail
- **Agents commit their own work** in the worktree
- **Review all changes** before merging to main
