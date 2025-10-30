# Context System Update

## Overview

The context system has been updated to use automatic file references in `CLAUDE.md` instead of requiring manual context loading commands.

## What Changed

### Before (Deprecated)
Users had to run `/context:prime` at the start of each session to manually load all context files:

```bash
# Old workflow
/context:create      # Create context files
/context:prime       # Load context (EVERY SESSION)
# ... work ...
/context:update      # Update context
```

**Problems:**
- Users had to remember to run `/context:prime` every session
- Easy to forget, leading to sessions without context
- Extra step that added friction
- Redundant since Claude Code already reads CLAUDE.md

### After (Current)
Context files are automatically loaded through file references in `CLAUDE.md`:

```bash
# New workflow
/context:create      # Create context files
# Context automatically loaded from CLAUDE.md references
# ... work ...
/context:update      # Update context
```

**Benefits:**
- Zero additional commands required
- Context always available automatically
- Files are referenced, not loaded entirely
- More efficient - Claude only reads referenced files when needed
- Follows Claude Code's built-in reference system

## How It Works

### Automatic File References

The init script now creates a `CLAUDE.md` file with file references:

```markdown
## Project Management Context

**Key Documentation:**
- Database Schema: `db/SCHEMA.md`
- Command Reference: `db/PHASE4_FINAL_SUMMARY.md`
- GitHub Sync: `db/GITHUB_SYNC.md`
```

When Claude Code sees a file path in `CLAUDE.md`, it automatically loads that file's content into the conversation context. This happens automatically - no commands needed.

### Adding Context Files

To add your own context files:

1. Create the context file:
   ```bash
   /context:create  # Creates files in .claude/context/
   ```

2. Reference them in `CLAUDE.md`:
   ```markdown
   ## Project Context
   
   - Architecture: `.claude/context/system-patterns.md`
   - Tech Stack: `.claude/context/tech-context.md`
   - Current Status: `.claude/context/progress.md`
   ```

3. Done! They're automatically loaded in every conversation.

## Migration Guide

### For Existing Projects

**Remove `/context:prime` from your workflow:**
- ❌ Don't run `/context:prime` anymore
- ✅ Add file references to `CLAUDE.md` instead

**Update your CLAUDE.md:**

```markdown
# CLAUDE.md

## Project Context

**Core Documentation:**
- Project Overview: `.claude/context/project-overview.md`
- Current Progress: `.claude/context/progress.md`
- Tech Stack: `.claude/context/tech-context.md`
- Architecture: `.claude/context/system-patterns.md`

## Database Context (CCPM)

**Key Documentation:**
- Database Schema: `db/SCHEMA.md`
- Command Reference: `db/PHASE4_FINAL_SUMMARY.md`
- GitHub Sync: `db/GITHUB_SYNC.md`
```

### For New Projects

New projects automatically get the improved `CLAUDE.md` template when running the init script. No migration needed!

## Command Status

| Command | Status | Alternative |
|---------|--------|-------------|
| `/context:create` | ✅ Active | Create initial context files |
| `/context:prime` | ❌ Removed | File references in CLAUDE.md |
| `/context:update` | ✅ Active | Update context files |

## Why This Is Better

### 1. Follows Claude Code Standards
Claude Code is designed to automatically load files referenced in `CLAUDE.md`. Using this built-in feature is more reliable than custom commands.

### 2. Always Available
Context is loaded automatically in every conversation. You can't forget to load it because it's automatic.

### 3. Lazy Loading
Claude only reads referenced files when needed, not all at once. More efficient use of context window.

### 4. Simpler Workflow
One less command to remember. Reduced cognitive load for developers.

### 5. Better Documentation
`CLAUDE.md` becomes a single source of truth for all project context, making it easy to see what's available.

## Technical Details

### How File References Work

When you write this in `CLAUDE.md`:
```markdown
- Database Schema: `db/SCHEMA.md`
```

Claude Code automatically:
1. Detects the file path in backticks
2. Reads the file content
3. Includes it in the conversation context
4. Updates if the file changes

### Supported Reference Formats

All these formats work:
```markdown
`path/to/file.md` - Inline backticks
[Link](path/to/file.md) - Markdown links
path/to/file.md - Plain text (if clearly a file path)
```

### Best Practices

**Do:**
- ✅ Reference files in `CLAUDE.md`
- ✅ Use relative paths from project root
- ✅ Group references by category
- ✅ Add brief descriptions

**Don't:**
- ❌ Reference too many files (impacts context window)
- ❌ Reference very large files (>10KB)
- ❌ Use absolute paths
- ❌ Reference binary files

## Example CLAUDE.md

Here's a complete example:

```markdown
# CLAUDE.md

> Concise, maintainable code following project patterns.

## Project Management Context

This project uses CCPM for structured development.

**Key Documentation:**
- Database Schema: `db/SCHEMA.md` - Complete DB structure
- Command Reference: `db/PHASE4_FINAL_SUMMARY.md` - All PM commands
- GitHub Sync: `db/GITHUB_SYNC.md` - Issue synchronization

**Common Commands:**
- `pm standup` - Daily status
- `pm next` - Ready tasks
- `pm task-start <epic> <task>` - Start work

## Project Context

**Architecture & Status:**
- Overview: `.claude/context/project-overview.md`
- Tech Stack: `.claude/context/tech-context.md`
- Progress: `.claude/context/progress.md`
- Structure: `.claude/context/project-structure.md`

**Style & Patterns:**
- Code Style: `.claude/context/project-style-guide.md`
- Patterns: `.claude/context/system-patterns.md`

## Testing

Run tests before committing:
- `npm test` or equivalent

## Code Style

Follow existing patterns in the codebase.
```

## FAQs

**Q: What happened to `/context:prime`?**
A: It's been removed. The command is no longer needed because file references in `CLAUDE.md` provide automatic context loading.

**Q: What if I have too many context files?**
A: Only reference the most important ones in `CLAUDE.md`. You can always add specific file references when needed for a particular task.

**Q: How many files should I reference?**
A: Keep it to 5-10 key files. More than that and you're using up too much context window.

## Conclusion

The new file reference system is:
- **Simpler** - No extra commands
- **Automatic** - Always loaded
- **Efficient** - Lazy loading
- **Standard** - Uses Claude Code's built-in features

Update your `CLAUDE.md` with file references and enjoy automatic context loading!
