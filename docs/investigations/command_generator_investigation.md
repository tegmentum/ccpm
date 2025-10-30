# Command Generator Pattern Investigation

## Current Slash Command Architecture

### How Slash Commands Work Now

1. User types: `/pm:status`
2. Claude Code reads: `.claude/commands/pm/status.md`
3. File contains markdown with instructions
4. LLM interprets instructions and executes tools
5. LLM formats output

### Current Token Usage Per Command

**Simple deterministic commands** (already optimized):
```markdown
---
allowed-tools: Bash
---

Run `python3 .claude/scripts/pm/status.py` and show output.
```
- Markdown file: ~100 tokens
- LLM interpretation: ~50 tokens
- Total: ~150 tokens per invocation

**Problem:** Even for pure pass-through commands, we're using ~150 tokens just to tell Claude "run this script and show output"

## Command Generator Pattern

### Concept

Instead of slash commands expanding to markdown instructions that Claude reads, generate a direct command invocation:

```python
# .claude/scripts/generate_command.py

COMMAND_MAP = {
    'status': 'python3 .claude/scripts/pm/status.py',
    'next': 'python3 .claude/scripts/pm/next.py {args}',
    'epic-show': 'python3 .claude/scripts/pm/epic-show.py {args}',
    # ... etc
}

def generate_command(cmd_name, args=''):
    """Generate direct command invocation."""
    template = COMMAND_MAP.get(cmd_name)
    if not template:
        return None
    return template.format(args=args)
```

### Potential Architectures

#### Architecture 1: Pre-processing Hook
Use Claude Code hooks to intercept slash commands before LLM sees them:

```bash
# .claude/hooks/command-preprocessor.sh
#!/bin/bash
# Intercepts /pm:* commands and converts to direct script calls

if [[ "$COMMAND" == /pm:* ]]; then
    cmd_name="${COMMAND#/pm:}"
    python3 .claude/scripts/generate_command.py "$cmd_name" "$ARGS"
    exit 0  # Prevent normal slash command expansion
fi
```

**Token savings:** Commands bypass LLM entirely for pure deterministic operations
**Challenge:** Need to investigate if hooks can intercept slash commands

#### Architecture 2: Minimal Expansion Files
Keep slash commands but make them ultra-minimal:

```markdown
---
allowed-tools: Bash
---
{{GENERATED: python3 .claude/scripts/pm/status.py}}
```

Generator script updates all command files to be single-line.

**Token savings:** Reduces 100-token markdown to ~20-token template
**Challenge:** Need templating system, may complicate debugging

#### Architecture 3: Slash Command Aliases
Create a command router script:

```markdown
---
allowed-tools: Bash
---
Run: python3 .claude/scripts/pm/router.py status $ARGUMENTS
```

Router script maps command names to script paths.

**Token savings:** All commands become identical ~50-token files
**Challenge:** Less discoverable, harder to document per-command

## Investigation Tasks

### 1. Check Claude Code Hook Capabilities
- Can hooks intercept slash commands?
- Can hooks prevent normal expansion?
- What's the hook execution order?

### 2. Measure Current Token Usage
Measure actual token usage for:
- Simple commands (status, next, blocked)
- Medium commands (epic-show, task-show)
- Complex commands (prd-new, epic-decompose)

### 3. Benchmark Potential Savings

Current (30 deterministic commands):
- File size: ~100 tokens each
- Interpretation overhead: ~50 tokens
- Total per command: ~150 tokens
- Weekly usage (rough estimate): 30 commands × 10 uses = 450 commands
- Weekly cost: 450 × 150 = **67,500 tokens/week**

With minimal templates:
- Template size: ~20 tokens
- Interpretation: ~30 tokens
- Total per command: ~50 tokens
- Weekly cost: 450 × 50 = **22,500 tokens/week**
- **Savings: 45,000 tokens/week**

### 4. Implementation Complexity

**Low complexity:**
- Architecture 3 (Router) - Single script, minimal changes
- Implement time: ~2 hours

**Medium complexity:**
- Architecture 2 (Minimal templates) - Generator script + update all files
- Implement time: ~4 hours

**High complexity:**
- Architecture 1 (Hooks) - Need to understand Claude Code hook system
- Implement time: ~8 hours + investigation time

## Recommendation

Start with **Architecture 3 (Router)** as proof-of-concept:

1. Create router.py that maps command → script
2. Update 5-10 simple commands to use router
3. Measure actual token savings
4. If successful, roll out to all commands
5. Benchmark and document savings

If router proves valuable, consider Architecture 1 (Hooks) for maximum optimization.

