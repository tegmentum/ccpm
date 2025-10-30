---
allowed-tools: Bash, Task
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

### 1. Run Setup Script

Run the Python script to automate all validation and setup:

```bash
python3 .claude/scripts/pm/epic-parallel.py $ARGUMENTS
```

The script will:
- ✅ Detect epic from branch (if not provided)
- ✅ Validate epic exists
- ✅ Query ready tasks from database
- ✅ Check for analysis files
- ✅ Display parallel execution plan
- ✅ Ask for confirmation
- ✅ Print agent launch instructions

### 2. Launch Agents

The script will print detailed instructions for each agent. Use the Task tool to launch them:

**For tasks WITH analysis:**
- Read the analysis file
- Launch MULTIPLE agents (one per parallel stream)
- Each agent works on its assigned files/scope

**For tasks WITHOUT analysis:**
- Launch SINGLE agent per task
- Agent implements entire task

### 3. Example Task Launch

The script prints ready-to-use Task tool invocations. Simply copy and execute them:

```yaml
Task:
  description: "{epic} - Task #{num}"
  subagent_type: "general-purpose"
  model: "sonnet"
  prompt: |
    {Script provides complete prompt template}
```

## Important Notes

- Script handles ALL deterministic work (queries, file checks, validation)
- Only agent launching requires LLM context
- Script provides complete agent prompts
- Agents work in epic worktree (../epic-{epic}/)
- Multiple agents can run simultaneously on independent tasks

## Benefits

**Token Savings:**
- Old approach: ~3,000 tokens (LLM does all setup)
- New approach: ~500 tokens (just launch agents)
- **Savings: ~2,500 tokens per use**

**Reliability:**
- Deterministic validation
- Clear error messages
- Consistent behavior

**User Experience:**
- Interactive confirmation
- Clear next steps
- Pre-built prompts

## Error Handling

Script will exit with clear messages if:
- Not in epic branch and no epic name provided
- Epic doesn't exist
- No ready tasks available
- User cancels at confirmation prompts
