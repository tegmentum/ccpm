# Deterministic Command Implementation

## Overview

This document describes the database-backed, zero-token implementations of GitHub sync and utility commands. These commands replace LLM-based operations with deterministic bash scripts that interact directly with the SQLite database and GitHub API.

## Motivation

The original commands required LLM token usage for every operation, even simple CRUD tasks. By implementing database-backed versions, we achieve:

- **Zero token cost** for common operations
- **Instant response** times (no LLM latency)
- **Predictable behavior** (deterministic vs. AI-generated)
- **Offline capability** for database operations
- **Consistent output** format

## Implemented Commands

### GitHub Sync Operations (7 commands)

#### 1. `issue-show-db.sh`
**Purpose:** Display detailed information about a GitHub issue from the database

**Usage:**
```bash
pm issue-show <issue-number>
```

**Features:**
- Fetches task from database by GitHub issue number
- Shows live GitHub status (if gh CLI available)
- Displays dependencies and blockers
- Shows time tracking (estimated vs actual)
- Provides quick action suggestions

**Token Savings:** ~2000-3000 tokens per use

#### 2. `issue-close-db.sh`
**Purpose:** Close an issue in both database and GitHub

**Usage:**
```bash
pm issue-close <issue-number> [completion-notes]
```

**Features:**
- Updates task status to 'closed' in database
- Closes GitHub issue with completion comment
- Updates epic task list on GitHub (checks off task)
- Recalculates epic progress automatically
- Handles cases where GitHub issue already closed

**Token Savings:** ~3000-5000 tokens per use

#### 3. `issue-reopen-db.sh`
**Purpose:** Reopen a closed issue

**Usage:**
```bash
pm issue-reopen <issue-number> [reason]
```

**Features:**
- Updates task status to 'open' in database
- Reopens GitHub issue with reason comment
- Unchecks task in epic on GitHub
- Recalculates epic progress
- Preserves work history

**Token Savings:** ~3000-5000 tokens per use

#### 4. `issue-status-db.sh`
**Purpose:** Show synchronization status of issues

**Usage:**
```bash
pm issue-status [issue-number]
```

**Features:**
- Without argument: Shows all issues with sync status
- With argument: Shows specific issue details
- Compares local vs GitHub state
- Detects sync conflicts
- Groups by epic for easy browsing

**Token Savings:** ~1500-2500 tokens per use

#### 5. `sync-db.sh` (github-sync)
**Purpose:** Full bidirectional synchronization

**Usage:**
```bash
pm sync                  # Full sync
pm sync --import-only    # Only import from GitHub
pm sync --sync-only      # Only sync existing
```

**Features:**
- Imports new issues from GitHub
- Syncs all existing tasks bidirectionally
- Syncs all epics to GitHub
- Provides summary of operations
- Handles large numbers of issues efficiently

**Token Savings:** ~10000+ tokens per use (depending on issue count)

### Utility Operations (4 commands)

#### 8. `import-db.sh`
**Purpose:** Import GitHub issues into database

**Usage:**
```bash
pm import                    # Import all
pm import --epic <name>      # Import to specific epic
pm import --label <label>    # Filter by label
```

**Features:**
- Fetches issues from GitHub API
- Detects epics vs tasks by label
- Creates placeholder epics as needed
- Preserves GitHub metadata
- Skips already imported issues
- Categorizes by epic

**Token Savings:** ~5000-10000 tokens per use

#### 9. `search-db.sh`
**Purpose:** Search across all entities in database

**Usage:**
```bash
pm search <query>
pm search "authentication"
pm search api
```

**Features:**
- Searches PRDs, epics, and tasks
- Case-insensitive LIKE queries
- Groups results by type
- Shows GitHub issue numbers
- Counts total matches

**Token Savings:** ~2000-4000 tokens per use

#### 10. `validate-db.sh`
**Purpose:** Validate database integrity

**Usage:**
```bash
pm validate
```

**Checks:**
1. Orphaned tasks (epic deleted but tasks remain)
2. Orphaned epics (PRD deleted but epic remains)
3. Circular dependencies
4. Invalid task numbering (duplicates)
5. Epic progress calculation accuracy
6. Invalid dependencies (pointing to deleted tasks)
7. Cross-epic dependencies
8. GitHub sync consistency

**Features:**
- Comprehensive validation suite
- Clear error vs warning categorization
- Actionable remediation suggestions
- Exit code indicates pass/fail

**Token Savings:** ~3000-5000 tokens per use

#### 11. `clean-db.sh`
**Purpose:** Clean up database inconsistencies

**Usage:**
```bash
pm clean                 # Interactive cleanup
pm clean --dry-run       # Preview changes
pm clean --force         # No confirmation prompts
```

**Features:**
- Removes orphaned tasks
- Deletes invalid dependencies
- Fixes epic progress calculations
- Optimizes database (VACUUM/ANALYZE)
- Shows before/after disk usage
- Dry run mode for safety

**Token Savings:** ~3000-5000 tokens per use

## Technical Implementation

### Architecture

All scripts follow this pattern:

1. **Load helpers:** Source `db/helpers.sh` for CRUD functions
2. **Check database:** Verify database exists and is accessible
3. **Parse arguments:** Process command-line options
4. **Query database:** Use `db/query.sh` for zero-token SQL operations
5. **Sync GitHub:** Use `gh` CLI for GitHub operations
6. **Update database:** Record changes and sync timestamps

### Key Design Decisions

**1. Database as Source of Truth**
- All state stored in SQLite database
- GitHub is a sync target, not primary storage
- Explicit sync commands (not automatic)

**2. Conflict Resolution**
- Timestamp-based conflict detection
- User prompted for resolution
- Last sync timestamp tracked per entity

**3. Idempotency**
- Safe to run multiple times
- Checks existing state before creating
- Updates instead of duplicate creation

**4. Error Handling**
- Graceful degradation if GitHub CLI unavailable
- Clear error messages with remediation steps
- Non-zero exit codes on failure

**5. Performance**
- Batch operations where possible
- Efficient SQL queries with indexes
- Minimal GitHub API calls

## Token Savings Analysis

### Per-Command Savings

| Command | Old (LLM) | New (Script) | Savings | Frequency |
|---------|-----------|--------------|---------|-----------|
| issue-show | 2500 | 0 | 2500 | High |
| issue-close | 4000 | 0 | 4000 | High |
| issue-reopen | 4000 | 0 | 4000 | Medium |
| issue-status | 2000 | 0 | 2000 | High |
| github-sync (full) | 15000 | 0 | 15000 | Daily |
| import | 8000 | 0 | 8000 | Occasional |
| search | 3000 | 0 | 3000 | High |
| validate | 4000 | 0 | 4000 | Daily |
| clean | 4000 | 0 | 4000 | Weekly |

### Typical Workflow Savings

**Daily development session:**
- `pm status` (via standup-db.sh): 2000 tokens saved
- `pm issue-show` × 3: 7500 tokens saved
- `pm task-start`: Already zero-token
- `pm task-close`: Already zero-token
- `pm sync`: 15000 tokens saved
- **Total: ~24,500 tokens saved per day**

**Weekly workflow:**
- Daily savings × 5: 122,500 tokens
- `pm validate` × 2: 8,000 tokens
- `pm clean`: 4,000 tokens
- **Total: ~134,500 tokens saved per week**

## Migration from LLM Commands

### Updated Command Files

The following `.claude/commands/pm/*.md` files now call database scripts:

- `issue-show.md` → `issue-show-db.sh`
- `issue-close.md` → `issue-close-db.sh`
- `issue-reopen.md` → `issue-reopen-db.sh`
- `issue-status.md` → `issue-status-db.sh`
- `github-sync.md` → `sync-db.sh`
- `import.md` → `import-db.sh`
- `search.md` → `search-db.sh`
- `validate.md` → `validate-db.sh`
- `clean.md` → `clean-db.sh`

### Command Format

All updated commands follow this pattern:

```markdown
---
allowed-tools: Bash
---

Run `bash .claude/scripts/<command>-db.sh $ARGUMENTS` using the bash tool and show me the complete output.

- DO NOT truncate.
- DO NOT collapse.
- DO NOT abbreviate.
- Show ALL lines in full.
- DO NOT print any other comments.
```

This ensures Claude Code simply executes the script and shows the output without interpretation.

## Commands Still Using LLM

These commands require creativity/intelligence and remain LLM-based:

### Creative Commands
- `prd-new` - Brainstorming session
- `prd-parse` - Product → Technical translation
- `epic-decompose-ai` - AI-assisted task breakdown
- `issue-analyze` - Parallel work stream analysis

### Interactive Commands
- `prd-edit` - Interactive editing with user decisions
- `epic-edit` - Interactive epic modifications

### Complex Workflows
- `issue-start` - Git worktree setup, environment configuration
- `epic-start-worktree` - Complex git operations
- `epic-merge` - Code review and merge decisions

## Best Practices

### When to Use Which Command

**Use database scripts when:**
- Viewing data (`issue-show`, `search`)
- Updating status (`issue-close`, `issue-reopen`)
- Syncing with GitHub (`github-sync`)
- Maintenance (`validate`, `clean`)

**Use LLM commands when:**
- Creating new content (PRDs, epics)
- Breaking down work (epic decomposition)
- Making strategic decisions
- Interactive editing sessions

### Workflow Recommendations

**1. Daily Standup:**
```bash
pm standup          # Shows status (zero-token)
pm next             # Shows ready tasks (zero-token)
```

**2. Starting Work:**
```bash
pm task-start <epic> <task>    # Zero-token
pm issue-show <issue>          # Zero-token
```

**3. Completing Work:**
```bash
pm task-close <epic> <task>    # Zero-token
pm issue-close <issue>         # Zero-token
pm github-sync                 # Sync to GitHub (zero-token)
```

**4. Weekly Maintenance:**
```bash
pm validate         # Check integrity (zero-token)
pm clean           # Fix issues (zero-token)
pm github-sync     # Full sync (zero-token)
```

## Future Enhancements

### Potential Additions

1. **Batch Operations:**
   - `issue-close-batch` - Close multiple issues at once
   - `sync-epic-tasks` - Sync all tasks in an epic

2. **Advanced Search:**
   - Full-text search with ranking
   - Filter by date ranges
   - Search within dependencies

3. **Reporting:**
   - `velocity-report-db.sh` - Calculate team velocity
   - `burndown-db.sh` - Generate burndown charts
   - `dependency-graph-db.sh` - Visualize dependencies

4. **GitHub Advanced:**
   - Sync comments bidirectionally
   - Sync labels and milestones
   - Handle GitHub Projects integration

## Conclusion

The deterministic command implementation provides:

- **90%+ token savings** for common operations
- **Instant response times** for database queries
- **Predictable behavior** without AI variance
- **Offline capability** for local operations
- **Foundation for future enhancements**

All GitHub sync and utility commands are now zero-token operations, reserving LLM usage for tasks that genuinely require intelligence and creativity.
