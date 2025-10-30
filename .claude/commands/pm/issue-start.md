---
allowed-tools: Bash, Task
---

# Issue Start

Begin work on a GitHub issue with automated setup and agent launch instructions.

## Usage
```
/pm:issue-start <issue_number>
```

## Instructions

### 1. Run Setup Script

Run the Python script to validate and set up everything:

```bash
python3 .claude/scripts/pm/issue-start.py $ARGUMENTS
```

The script will:
- ✅ Validate GitHub issue exists
- ✅ Find task in database
- ✅ Check epic worktree exists
- ✅ Look for analysis file
- ✅ Create progress tracking directory
- ✅ Update task status to in_progress
- ✅ Assign issue on GitHub
- ✅ Print agent launch instructions

### 2. Launch Agent(s)

The script will print an agent prompt template. Use the Task tool to launch agent(s):

**If analysis exists (parallel work):**
- Read the analysis file location from script output
- Parse parallel streams from analysis
- Launch one Task agent per stream using the template

**If no analysis (single agent):**
- Launch one Task agent using the printed template
- Agent will work on entire task

### 3. Example Task Launch

```yaml
Task:
  description: "Issue #{issue_number} implementation"
  subagent_type: "general-purpose"
  model: "sonnet"
  prompt: |
    {Use the prompt template printed by the script}
```

## Important Notes

- Script handles ALL validation and setup deterministically
- Only agent launching requires LLM context
- Script prints everything needed for agent prompts
- Agents work in epic worktree (../epic-{epic}/directory)
- Progress tracked in .claude/epics/{epic}/updates/{issue}/

## Error Handling

Script will exit with clear error messages if:
- Issue doesn't exist on GitHub
- No local task found for issue
- Epic worktree doesn't exist (run: pm epic-start {epic})
- User cancels when no analysis found
