# CCPM → Claude Code Plugin Conversion Analysis

## Executive Summary

**95% of CCPM codebase can be converted to a Claude Code plugin** with minimal modifications. The current architecture is already well-structured for plugin distribution.

## Current vs Plugin Structure Mapping

### Current Structure
```
ccpm/
├── .claude/
│   ├── commands/pm/         (39 slash commands)
│   ├── agents/              (4 agents)
│   ├── context/
│   │   └── rules/           (10 rules)
│   ├── scripts/          (35 Python scripts)
│   └── context/             (context management)
├── epics/                   (user workspace)
├── prds/                    (user workspace)
├── db/
│   ├── helpers.py           (core library)
│   ├── schema.sql           (database schema)
│   └── init.sh              (initialization)
└── docs/                    (documentation)
```

### Plugin Structure
```
ccpm-plugin/
├── .claude-plugin/
│   └── plugin.json          ← NEW: Metadata
├── commands/
│   └── pm/                  ← FROM: .claude/commands/pm/
├── agents/                  ← FROM: .claude/agents/
├── hooks/
│   └── on_install.sh        ← FROM: db/init.sh (adapted)
├── lib/
│   ├── python/
│   │   ├── helpers.py       ← FROM: db/helpers.py
│   │   └── scripts/         ← FROM: .claude/scripts/
│   └── sql/
│       └── schema.sql       ← FROM: db/schema.sql
└── docs/
    ├── README.md            ← Enhanced with rules content
    └── investigations/      ← FROM: docs/
```

## Conversion Assessment by Component

### ✅ Direct Migration (No Changes Needed)

#### 1. Commands (39 files - 100% ready)
**Source:** `.claude/commands/pm/*.md`
**Destination:** `commands/pm/*.md`
**Effort:** Copy files

All command files already follow plugin conventions:
- Proper frontmatter with `allowed-tools`
- Self-contained markdown instructions
- Router-based (minimal token usage)

**Example:**
```markdown
---
allowed-tools: Bash
---

Run: `python3 $PLUGIN_DIR/lib/python/scripts/router.py status $ARGUMENTS`
```

#### 2. Agents (4 files - 100% ready)
**Source:** `.claude/agents/*.md`
**Destination:** `agents/*.md`
**Effort:** Copy files

- `parallel-worker.md`
- `test-runner.md`
- `file-analyzer.md`
- `code-analyzer.md`

All agents are self-contained with proper tool specifications.

#### 3. Python Scripts (35 files - 100% ready)
**Source:** `.claude/scripts/*.py` and `*.sh`
**Destination:** `lib/python/scripts/*.py`
**Effort:** Copy files + update import paths

Scripts already use relative imports and pathlib. Only need to update:
```python
# Current
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / 'db'))

# Plugin
sys.path.insert(0, str(Path(__file__).parent.parent.parent))
from helpers import get_db
```

#### 4. Core Library (1 file - 100% ready)
**Source:** `db/helpers.py` (450 lines)
**Destination:** `lib/python/helpers.py`
**Effort:** Copy file

Already a well-structured Python module with:
- CCPMDatabase class
- GitHubClient class
- Helper functions
- Safe SQL parameterization

#### 5. Database Schema (1 file - 100% ready)
**Source:** `db/schema.sql`
**Destination:** `lib/sql/schema.sql`
**Effort:** Copy file

SQLite schema with all table definitions.

### ⚠️ Needs Adaptation (Minor Changes)

#### 6. Rules (REMOVED - Not needed)
**Previous location:** `.claude/context/rules/*.md`
**Status:** Removed - Python scripts handle datetime automatically via db/helpers.py

**Solution Options:**

**Option A: Inline in Commands**
Embed rule content directly in command files where needed.
```markdown
---
allowed-tools: Bash, Read
---

## Date/Time Handling
Always use ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ
Python: `datetime.utcnow().isoformat() + "Z"`

Run: `python3 $PLUGIN_DIR/lib/python/scripts/router.py epic-start $ARGUMENTS`
```

**Option B: Documentation**
Convert rules to plugin documentation sections:
- `docs/datetime-handling.md`
- `docs/github-operations.md`
- etc.

**Option C: Hooks for Enforcement**
Create validation hooks that enforce rules:
```bash
# hooks/pre_command_execute.sh
# Validates command follows datetime rules, etc.
```

**Recommendation:** Option A (inline) for critical rules + Option B (docs) for reference

#### 7. Initialization (1 file - Needs conversion to hook)
**Source:** `db/init.sh`
**Destination:** `hooks/on_install.sh`

Convert initialization script to plugin install hook:

```bash
#!/bin/bash
# hooks/on_install.sh

echo "Initializing CCPM database..."

# Get plugin directory
PLUGIN_DIR="$(dirname "$(dirname "$0")")"

# Create database directory
mkdir -p ~/.claude

# Initialize database
sqlite3 ~/.claude/ccpm.db < "$PLUGIN_DIR/lib/sql/schema.sql"

# Check for dependencies
if ! command -v python3 &> /dev/null; then
    echo "⚠️  Python 3.7+ required"
    exit 1
fi

# Check for uv (optional)
if ! command -v uv &> /dev/null; then
    echo "Installing uv package manager..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Install Python dependencies
uv pip install PyGithub --system 2>/dev/null || python3 -m pip install PyGithub

echo "✅ CCPM initialized successfully"
```

### ❌ Not Plugin Material (User-specific)

#### 8. Workspace Directories
**Not migrated:**
- `epics/` - User's epic workspaces
- `prds/` - User's PRDs
- `.claude/context/` - Session context

These are created by the plugin on first use, not distributed with it.

#### 9. Configuration
**Not migrated:**
- `.claude/settings.local.json` - User-specific settings

Plugin creates default config on install if needed.

## Changes Required for Plugin Conversion

### 1. Create Plugin Metadata

**File:** `.claude-plugin/plugin.json`

```json
{
  "name": "ccpm",
  "version": "1.0.0",
  "description": "Claude Code Project Management - Spec-driven development with GitHub Issues and Git worktrees",
  "author": "tegmentum.ai",
  "homepage": "https://github.com/tegmentum/ccpm",
  "license": "MIT",
  "requires": {
    "claude-code": ">=1.0.0",
    "python": ">=3.7"
  },
  "dependencies": {
    "system": ["git", "gh"],
    "python": ["PyGithub"]
  },
  "commands": {
    "pm:*": "Project management commands"
  },
  "agents": {
    "parallel-worker": "Execute parallel work streams in git worktrees",
    "test-runner": "Run tests and analyze results",
    "file-analyzer": "Analyze and summarize file contents",
    "code-analyzer": "Analyze code for bugs and trace logic"
  },
  "hooks": {
    "on_install": "Initialize CCPM database and dependencies",
    "on_update": "Migrate database schema if needed"
  }
}
```

### 2. Update Import Paths in Python Scripts

**Current:**
```python
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / 'db'))
from helpers import get_db
```

**Plugin:**
```python
# Get plugin lib directory
PLUGIN_LIB = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PLUGIN_LIB))
from helpers import get_db
```

**Effort:** Global find/replace in 35 Python files

### 3. Update Command File Paths

**Current:**
```markdown
Run: `python3 .claude/scripts/router.py status $ARGUMENTS`
```

**Plugin:**
```markdown
Run: `python3 $PLUGIN_DIR/lib/python/scripts/router.py status $ARGUMENTS`
```

**Effort:** Update 33 router-based command files (automated with script)

### 4. Convert Rules to Inline Documentation

Select critical rules to inline in commands:
- `context/rules/datetime.md` → Inline in time-sensitive commands
- `context/rules/github-operations.md` → Inline in GitHub sync commands
- `context/rules/worktree-operations.md` → Inline in epic-start, epic-parallel

Move rest to `docs/` for reference.

**Effort:** ~2 hours to review and inline

## Migration Path

### Phase 1: Structure Reorganization (2 hours)

```bash
# Create plugin structure
mkdir -p ccpm-plugin/{.claude-plugin,commands/pm,agents,hooks,lib/{python/scripts,sql},docs}

# Copy commands
cp -r .claude/commands/pm/*.md ccpm-plugin/commands/pm/

# Copy agents
cp -r .claude/agents/*.md ccpm-plugin/agents/

# Copy Python infrastructure
cp -r .claude/scripts/*.py ccpm-plugin/lib/python/scripts/
cp -r .claude/scripts/*.sh ccpm-plugin/lib/python/scripts/
cp db/helpers.py ccpm-plugin/lib/python/

# Copy database schema
cp db/schema.sql ccpm-plugin/lib/sql/

# Copy documentation
cp -r docs/* ccpm-plugin/docs/
cp README.md ccpm-plugin/
```

### Phase 2: Path Updates (1 hour)

```bash
# Update Python import paths
find ccpm-plugin/lib/python/scripts -name "*.py" -exec sed -i '' \
  's|parent.parent.parent.parent / .db.|parent.parent.parent|g' {} \;

# Update command file paths (create update script)
python3 << 'EOF'
from pathlib import Path

for cmd_file in Path('ccpm-plugin/commands/pm').glob('*.md'):
    content = cmd_file.read_text()
    content = content.replace(
        'python3 .claude/scripts/',
        'python3 $PLUGIN_DIR/lib/python/scripts/'
    )
    cmd_file.write_text(content)
EOF
```

### Phase 3: Create Hooks (30 min)

Convert `db/init.sh` to `hooks/on_install.sh`

### Phase 4: Create Metadata (30 min)

Write `.claude-plugin/plugin.json`

### Phase 5: Rules Integration (2 hours)

- Review 10 rule files
- Inline critical rules in commands
- Move rest to docs/

### Phase 6: Testing (1 hour)

1. Install plugin locally: `/plugin install ./ccpm-plugin`
2. Test all 39 commands
3. Verify agents work
4. Test database initialization
5. Check GitHub integration

**Total effort: ~7 hours**

## Benefits of Plugin Distribution

### 1. Easy Installation
```bash
# Instead of git clone + setup
/plugin install ccpm

# Or from marketplace
/plugin marketplace add tegmentum
/plugin install @tegmentum/ccpm
```

### 2. Automatic Updates
```bash
/plugin update ccpm
```

### 3. Version Management
Users can pin versions, rollback, etc.

### 4. Marketplace Distribution
Reach wider audience through Claude Code plugin marketplace

### 5. Cleaner Project Structure
Plugin files separate from user's workspace:
```
my-project/
├── .claude/
│   └── context/        ← Context files
├── epics/              ← User workspace
├── prds/               ← User workspace
└── src/                ← User code
```

Plugin lives in `~/.claude/plugins/ccpm/` (example location)

### 6. Multi-Project Use
Single plugin installation works across all projects

### 7. Contribution Model
Contributors can publish forks as separate plugins

## Challenges and Mitigations

### Challenge 1: Rule Enforcement
**Issue:** No built-in "rules" concept in plugins
**Mitigation:** Inline critical rules, use hooks for validation

### Challenge 2: Database Location
**Issue:** Plugin can't assume `.claude/` directory structure
**Mitigation:** Store database in standard location (`~/.claude/ccpm.db`)

### Challenge 3: Path Dependencies
**Issue:** Commands reference relative paths
**Mitigation:** Use `$PLUGIN_DIR` environment variable

### Challenge 4: GitHub CLI Dependency
**Issue:** Plugin requires `gh` CLI
**Mitigation:** Document in plugin.json, check in install hook

### Challenge 5: Backward Compatibility
**Issue:** Users with existing CCPM setup
**Mitigation:**
- Provide migration guide
- Install hook detects existing database
- Keep repository version available

## Recommendations

### Immediate Actions

1. **Create plugin branch**
   ```bash
   git checkout -b plugin-conversion
   ```

2. **Restructure for plugin**
   Follow Phase 1-6 migration path

3. **Test locally**
   Verify plugin works in isolation

4. **Document plugin installation**
   Update README with both repo and plugin install methods

### Future Enhancements

1. **Create "lite" version**
   - Core commands only (no LLM-based workflows)
   - Smaller footprint for users who want basic PM

2. **Modular plugins**
   - `ccpm-core` (database + basic commands)
   - `ccpm-github` (GitHub integration)
   - `ccpm-prd` (PRD workflow)
   Users install what they need

3. **Plugin marketplace submission**
   Once stable, submit to official Claude Code marketplace

## Conclusion

**CCPM is exceptionally well-suited for plugin conversion:**

- ✅ 95% of code already plugin-compatible
- ✅ Clean separation of concerns
- ✅ Router pattern enables easy path updates
- ✅ Self-contained agents and commands
- ✅ ~7 hours total effort for full conversion

**Primary benefit:** Wider distribution and easier installation for users.

**Primary challenge:** Rules integration (solvable via inline + docs).

**Recommendation:** Proceed with plugin conversion. The architectural work (router pattern, Python migration) has already positioned CCPM perfectly for this transition.
