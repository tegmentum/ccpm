# Command Router Pattern - Detailed Analysis

## Current State Measurements

### File Sizes (Actual)
- Simple commands (status, next, blocked): **~245 bytes** (~61 tokens)
- Contains:
  - Frontmatter: 3 lines
  - Command execution line
  - 5 formatting instructions (DO NOT truncate, etc.)

### Minimal Router Template
```markdown
---
allowed-tools: Bash
---

Run: `python3 .claude/scripts/router.py $COMMAND_NAME $ARGUMENTS`
```
- Size: **98 bytes** (~25 tokens)
- **Savings per command: 147 bytes** (~36 tokens)

## Token Savings Calculation

### Commands That Could Use Router (30 commands)
All deterministic Python-based commands:
- Query/Display: status, next, blocked, in-progress, standup (5)
- Epic: epic-list, epic-show, epic-close, epic-refresh, epic-merge, epic-edit, epic-sync, epic-start, epic-parallel (9)
- Task: task-add, task-start, task-close, task-show (4)
- Issue: issue-show, issue-close, issue-reopen, issue-sync, issue-edit, issue-start (6)
- PRD: prd-list, prd-status (2)
- Maintenance: search, validate, clean, sync, import (5)

**Total:** 30 commands + init + help = 32 commands

### Savings Per Command
- Current: ~61 tokens
- With router: ~25 tokens  
- **Savings: ~36 tokens per command invocation**

### Weekly Usage Estimate
- Power users: ~20 commands/day × 5 days = 100 commands/week
- Team (3 users): 300 commands/week
- **Token savings: 300 × 36 = 10,800 tokens/week**

### Conservative Estimate (Lower Usage)
- 5 commands/day/user × 5 days × 3 users = 75 commands/week
- **Token savings: 75 × 36 = 2,700 tokens/week**

## Benefits Beyond Token Savings

### 1. Consistency
- All commands have identical structure
- Easier to understand/maintain
- Single point of routing logic

### 2. Centralized Command Registry
- router.py contains all command mappings
- Easy to see all available commands
- Built-in help system

### 3. Easy to Add New Commands
```python
# Just add to COMMAND_MAP
'new-command': ('new-command.py', 'Description'),
```
No need to create new .md file (can auto-generate)

### 4. Type Safety
- Router validates command exists before execution
- Clear error messages for typos
- No silent failures

### 5. Future Extensibility
Could add:
- Command aliases
- Argument validation
- Usage statistics
- Deprecation warnings
- Command chaining

## Implementation Plan

### Phase 1: Proof of Concept (Completed)
✅ Create router.py with command mapping
✅ Measure token savings potential

### Phase 2: Test with 5 Commands (1 hour)
1. Update these commands to use router:
   - status.md
   - next.md
   - blocked.md
   - epic-list.md
   - task-show.md

2. Test each command works correctly

3. Measure actual token usage difference

### Phase 3: Template Generator (1 hour)
Create script to auto-generate minimal command files:

```python
# .claude/scripts/generate_commands.py
for cmd in COMMAND_MAP.keys():
    create_minimal_command_file(cmd)
```

### Phase 4: Roll Out to All Commands (30 min)
- Run generator for all 32 commands
- Update any commands with special requirements
- Test suite

### Phase 5: Documentation Update (30 min)
- Update README
- Document router pattern
- Update command creation guide

**Total implementation time: ~3 hours**

## Potential Issues

### Issue 1: $COMMAND_NAME Variable
Current template uses: `$COMMAND_NAME`

**Problem:** This variable may not exist in Claude Code slash command expansion

**Solutions:**
A. Extract from markdown filename in router
B. Pass command name explicitly in each file
C. Use path inspection in router

**Recommendation:** Use solution B (explicit):
```markdown
Run: `python3 .claude/scripts/router.py status $ARGUMENTS`
```

### Issue 2: Special Commands
Some commands need special handling:
- prd-new, prd-edit, prd-parse (LLM-based)
- epic-decompose (LLM-based)
- issue-analyze (LLM-based)

**Solution:** These keep their current detailed .md files
Router only used for deterministic commands

### Issue 3: Debugging
Routing adds indirection, could complicate debugging.

**Solution:** 
- Router logs command execution
- Clear error messages
- Keep direct script execution available

## Recommendation

**PROCEED with implementation:**

1. **Immediate value:** 2,700-10,800 tokens/week savings
2. **Low risk:** Easy to rollback (keep old files)
3. **Quick implementation:** ~3 hours
4. **Additional benefits:** Consistency, maintainability, extensibility

**ROI:**
- 3 hours implementation
- 2,700 tokens/week minimum savings
- **Pays for itself in first week**
- Ongoing benefits for maintenance and new commands

## Alternative: Even More Minimal

Could go further with ultra-minimal:
```markdown
---
allowed-tools: Bash
---
/ccpm:router status $ARGUMENTS
```

If Claude Code supports calling other slash commands, could create:
- One `/ccpm:router` command
- All other commands become aliases

This would eliminate even the router invocation line, saving another ~10 tokens/command.

**Investigate:** Can slash commands call other slash commands?

