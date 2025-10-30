# CCPM Claude Code Plugin

## Installation

### Option 1: Install from Local Directory

```bash
/plugin install /path/to/ccpm
```

### Option 2: Install from GitHub (when published)

```bash
/plugin install @tegmentum/ccpm
```

### Option 3: Install from Marketplace (when published)

```bash
/plugin marketplace add tegmentum
/plugin install ccpm
```

## What Gets Installed

The plugin installs:
- **39 commands** under `/pm:*` namespace
- **4 specialized agents** for parallel work, testing, and analysis
- **Database** at `~/.claude/ccpm.db`
- **Python dependencies** (PyGithub)

## Quick Start

After installation:

```bash
# View project status
/pm:status

# Create a new PRD
/pm:prd-new

# Transform PRD into epic
/pm:prd-parse my-feature

# Break down epic into tasks
/pm:epic-decompose my-feature

# Sync to GitHub Issues
/pm:epic-sync my-feature

# Start work on an issue
/pm:issue-start 1234

# View help
/pm:help
```

## Commands

### Query/Display
- `/pm:status` - Project status dashboard
- `/pm:next` - Show ready tasks
- `/pm:blocked` - Show blocked tasks
- `/pm:in-progress` - Show tasks in progress
- `/pm:standup` - Daily standup report

### Epic Management
- `/pm:epic-list` - List all epics
- `/pm:epic-show <name>` - Show epic details
- `/pm:epic-start <name>` - Start epic worktree
- `/pm:epic-decompose <name>` - Break epic into tasks
- `/pm:epic-parallel <name>` - Launch parallel agents
- `/pm:epic-sync <name>` - Sync epic to GitHub
- `/pm:epic-close <name>` - Close an epic
- `/pm:epic-refresh <name>` - Refresh epic progress
- `/pm:epic-merge <name>` - Merge epic to main
- `/pm:epic-edit <name>` - Edit epic details
- `/pm:epic-oneshot <name>` - Single-shot epic creation

### Task Management
- `/pm:task-add <epic> <name>` - Add task to epic
- `/pm:task-start <epic> <num>` - Start working on task
- `/pm:task-close <epic> <num>` - Complete a task
- `/pm:task-show <epic> <num>` - Show task details

### Issue Management
- `/pm:issue-show <num>` - Show issue details
- `/pm:issue-start <num>` - Start work on issue
- `/pm:issue-analyze <num>` - Analyze issue with AI
- `/pm:issue-close <num>` - Close an issue
- `/pm:issue-reopen <num>` - Reopen an issue
- `/pm:issue-sync <num>` - Sync issue to GitHub
- `/pm:issue-edit <num>` - Edit issue details

### PRD Management
- `/pm:prd-new` - Create new PRD with AI brainstorming
- `/pm:prd-edit <name>` - Edit PRD with AI assistance
- `/pm:prd-parse <name>` - Parse PRD into epic
- `/pm:prd-list` - List all PRDs
- `/pm:prd-status` - Show PRD status

### Maintenance
- `/pm:search <query>` - Search across entities
- `/pm:validate` - Validate database integrity
- `/pm:clean` - Clean up database
- `/pm:sync` - Full GitHub sync
- `/pm:import` - Import GitHub issues
- `/pm:init` - Initialize/reinitialize CCPM
- `/pm:help` - Show help information

## Agents

The plugin includes 4 specialized agents:

### parallel-worker
Executes parallel work streams in git worktrees. Handles multiple tasks simultaneously across different branches.

### test-runner
Runs tests and analyzes results. Captures full output, performs deep analysis, and surfaces key issues.

### file-analyzer
Analyzes and summarizes file contents. Extracts key information from logs and verbose outputs while reducing token usage.

### code-analyzer
Analyzes code for bugs and traces logic flow across multiple files. Perfect for reviewing changes and investigating issues.

## Configuration

### Environment Variables

**CCPM_DB_PATH**
- Custom database location
- Default: `~/.claude/ccpm.db`
- Example: `export CCPM_DB_PATH=/custom/path/ccpm.db`

**PLUGIN_DIR**
- Plugin root directory (set automatically by Claude Code)
- Used internally for path resolution

### Database

The plugin stores data in SQLite at `~/.claude/ccpm.db`:
- **PRDs** - Product requirement documents
- **Epics** - High-level features with task breakdowns
- **Tasks** - Individual work items
- **GitHub Issues** - Synced issue metadata

## Dependencies

### Required
- **Python 3.7+** - Core scripting language
- **git** - Version control and worktree management
- **PyGithub** - GitHub API integration (auto-installed)

### Optional
- **gh CLI** - Enhanced GitHub integration
  - Install from: https://cli.github.com/
  - Used for: Issue creation, PR management, authentication

## Workflow

CCPM follows a spec-driven development workflow:

```
1. PRD Creation
   ↓ /pm:prd-new

2. Epic Planning
   ↓ /pm:prd-parse

3. Task Decomposition
   ↓ /pm:epic-decompose

4. GitHub Sync
   ↓ /pm:epic-sync

5. Parallel Execution
   ↓ /pm:epic-parallel or /pm:issue-start

6. Merge & Close
   ↓ /pm:epic-merge, /pm:epic-close
```

## Features

### Git Worktrees
- Each epic gets isolated worktree
- Parallel work without branch conflicts
- Clean separation of concerns

### GitHub Issues Integration
- Epics → Parent issues
- Tasks → Sub-issues
- Automatic status sync
- Full traceability

### Parallel Agents
- Multiple AI agents working simultaneously
- Independent git worktrees per agent
- Consolidated progress tracking
- Conflict-free parallel development

### Spec-Driven Development
- Everything starts with a PRD
- LLM-assisted brainstorming
- Technical decomposition
- GitHub issue tracking

## Troubleshooting

### Database Errors

If you see "Database not found" errors:

```bash
/pm:init
```

This reinitializes the database with the correct schema.

### GitHub Authentication

If GitHub commands fail:

```bash
# Check gh CLI authentication
gh auth status

# Login if needed
gh auth login
```

### Python Dependencies

If scripts fail with import errors:

```bash
# Reinstall dependencies
python3 -m pip install PyGithub

# Or with uv
uv pip install PyGithub --system
```

### Command Not Found

If `/pm:*` commands don't work:

```bash
# Verify plugin is installed
/plugin list

# Reinstall if needed
/plugin uninstall ccpm
/plugin install /path/to/ccpm
```

## Uninstallation

```bash
# Remove plugin
/plugin uninstall ccpm

# Optionally remove database
rm ~/.claude/ccpm.db
```

This does NOT remove:
- Your `.claude/epics/` directories
- Your `.claude/prds/` files
- Your git worktrees

These are your project files and persist after uninstall.

## Version History

### 1.0.0 (Current)
- Initial plugin release
- 39 commands
- 4 specialized agents
- Router pattern for token efficiency
- Dual-mode support (repository + plugin)
- Complete GitHub Issues integration

## Support

- **Repository**: https://github.com/tegmentum/ccpm
- **Issues**: https://github.com/tegmentum/ccpm/issues
- **Documentation**: https://github.com/tegmentum/ccpm#readme

## License

MIT License - See LICENSE file for details

## Credits

Developed by [Tegmentum](https://tegmentum.ai) for developers who ship.
