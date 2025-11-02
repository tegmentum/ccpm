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
- **39 commands** under `/ccpm:*` namespace
- **4 specialized agents** for parallel work, testing, and analysis
- **Database** at `~/.claude/ccpm.db`
- **Python dependencies** (PyGithub)

## Quick Start

After installation:

```bash
# View project status
/ccpm:status

# Create a new PRD
/ccpm:prd-new

# Transform PRD into epic
/ccpm:prd-parse my-feature

# Break down epic into tasks
/ccpm:epic-decompose my-feature

# Sync to GitHub Issues
/ccpm:github-sync

# Start work on an issue
/ccpm:issue-start 1234

# View help
/ccpm:help
```

## Commands

### Query/Display
- `/ccpm:status` - Project status dashboard
- `/ccpm:task-next` - Show ready tasks
- `/ccpm:blocked` - Show blocked tasks
- `/ccpm:in-progress` - Show tasks in progress
- `/ccpm:standup` - Daily standup report

### Epic Management
- `/ccpm:epic-list` - List all epics
- `/ccpm:epic-show <name>` - Show epic details
- `/ccpm:epic-start <name>` - Start epic worktree
- `/ccpm:epic-decompose <name>` - Break epic into tasks
- `/ccpm:epic-parallel <name>` - Launch parallel agents
- `/ccpm:epic-close <name>` - Close an epic
- `/ccpm:epic-refresh <name>` - Refresh epic progress
- `/ccpm:epic-merge <name>` - Merge epic to main
- `/ccpm:epic-edit <name>` - Edit epic details
- `/ccpm:epic-oneshot <name>` - Single-shot epic creation

### Task Management
- `/ccpm:task-add <epic> <name>` - Add task to epic
- `/ccpm:task-start <epic> <num>` - Start working on task
- `/ccpm:task-close <epic> <num>` - Complete a task
- `/ccpm:task-show <epic> <num>` - Show task details

### Issue Management
- `/ccpm:issue-show <num>` - Show issue details
- `/ccpm:issue-start <num>` - Start work on issue
- `/ccpm:issue-analyze <num>` - Analyze issue with AI
- `/ccpm:issue-close <num>` - Close an issue
- `/ccpm:issue-reopen <num>` - Reopen an issue
- `/ccpm:issue-edit <num>` - Edit issue details

### PRD Management
- `/ccpm:prd-new` - Create new PRD with AI brainstorming
- `/ccpm:prd-edit <name>` - Edit PRD with AI assistance
- `/ccpm:prd-parse <name>` - Parse PRD into epic
- `/ccpm:prd-list` - List all PRDs
- `/ccpm:prd-status` - Show PRD status

### Maintenance
- `/ccpm:search <query>` - Search across entities
- `/ccpm:validate` - Validate database integrity
- `/ccpm:clean` - Clean up database
- `/ccpm:github-sync` - Full GitHub sync
- `/ccpm:import` - Import GitHub issues
- `/ccpm:init` - Initialize/reinitialize CCPM
- `/ccpm:help` - Show help information

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
   ↓ /ccpm:prd-new

2. Epic Planning
   ↓ /ccpm:prd-parse

3. Task Decomposition
   ↓ /ccpm:epic-decompose

4. GitHub Sync
   ↓ /ccpm:github-sync

5. Parallel Execution
   ↓ /ccpm:epic-parallel or /ccpm:issue-start

6. Merge & Close
   ↓ /ccpm:epic-merge, /ccpm:epic-close
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
/ccpm:init
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

If `/ccpm:*` commands don't work:

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
- Your `epics/` directories
- Your `prds/` files
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
