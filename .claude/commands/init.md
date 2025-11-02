---
allowed-tools: Bash, Read, Write, LS
---

# Initialize CCPM System

This command initializes the CCPM system including dependencies, directory structure, database, and project context.

**IMPORTANT:** This command should only be run once after installing CCPM. It will:
- Install system dependencies
- Initialize the database
- Create CLAUDE.md in your project root
- Generate project context files

## Phase 1: Pre-flight Checks

Before proceeding, verify the installation:

```bash
# Check that .claude directory exists
test -d .claude && echo "✅ CCPM installed" || echo "❌ CCPM not installed - run installer first"

# Check if already initialized
test -f CLAUDE.md && echo "⚠️  Already initialized - CLAUDE.md exists" || echo "✅ Ready to initialize"
```

If CLAUDE.md already exists, ask the user:
```
⚠️  CLAUDE.md already exists in this project.

This suggests CCPM may already be initialized, or this project has custom Claude Code configuration.

Options:
  1. Skip initialization (recommended if CCPM is already set up)
  2. Overwrite CLAUDE.md with CCPM template (will lose custom content)
  3. Manual merge (back up CLAUDE.md first, then re-run init)

Continue with initialization? (yes/no)
```

Only proceed if user confirms "yes".

## Phase 2: System Initialization

Run the initialization script:
```bash
bash .claude/scripts/init.sh
```

This script will:
- Check and install dependencies (Python 3.7+, gh CLI, uv, PyGithub)
- Prompt for GitHub authentication if needed
- Create directory structure (.claude/context, prds, epics)
- Initialize SQLite database at ~/.claude/ccpm.db
- Copy CLAUDE.md template to project root

## Phase 3: Create Project Context

After system initialization completes, automatically create project context files.

### Context Creation Steps

1. **Check Context Directory**
   ```bash
   ls -la .claude/context/ 2>/dev/null
   ls -1 .claude/context/*.md 2>/dev/null | wc -l
   ```

2. **Get Current DateTime**
   ```bash
   date -u +"%Y-%m-%dT%H:%M:%SZ"
   ```
   Store for use in all context file frontmatter.

3. **Gather Project Information**
   - Project type: `find . -maxdepth 2 -name 'package.json' -o -name 'requirements.txt' -o -name 'Cargo.toml' -o -name 'go.mod' 2>/dev/null`
   - Git info: `git remote -v 2>/dev/null` and `git branch --show-current 2>/dev/null`
   - Current status: `git status --short 2>/dev/null`
   - Directory structure: `ls -la`
   - Read README.md if it exists

4. **Create Context Files**

   Create `.claude/context/` directory and generate these 9 files with frontmatter:

   ```yaml
   ---
   created: [REAL datetime from date command]
   last_updated: [REAL datetime from date command]
   version: 1.0
   author: Claude Code PM System
   ---
   ```

   Files to create:
   - `progress.md` - Current project status and next steps
   - `project-structure.md` - Directory layout and file organization
   - `tech-context.md` - Dependencies and technologies
   - `system-patterns.md` - Architectural patterns
   - `product-context.md` - Product requirements and users
   - `project-brief.md` - Project scope and goals
   - `project-overview.md` - High-level feature summary
   - `project-vision.md` - Long-term vision
   - `project-style-guide.md` - Coding standards

   For each file:
   - Use REAL datetime from `date` command
   - Write meaningful content based on project analysis
   - Minimum 10 lines of actual content (not just boilerplate)

5. **Validation**
   - Verify each file was created successfully
   - Check files have valid YAML frontmatter
   - Ensure minimum content length

## Phase 4: Completion Summary

Provide a completion summary:

```
✅ CCPM Initialization Complete!

📦 System Setup:
  - Dependencies installed and verified
  - Database initialized at ~/.claude/ccpm.db
  - Directory structure created
  - CLAUDE.md created in project root

📋 Context Created:
  - 9/9 context files generated
  - Location: .claude/context/

🎯 Next Steps:
  - View project status: /ccpm:status
  - Create your first PRD: /ccpm:prd-new
  - See all commands: /ccpm:help

💡 Tips:
  - Context files are automatically loaded via @ references in CLAUDE.md
  - Update context regularly with: /ccpm:context-update
  - All project data is stored in GitHub Issues for team visibility
```

## Error Recovery

If any step fails:

**Dependencies failed:**
- Show clear error: "❌ Failed to install {dependency}"
- Provide manual install instructions
- Suggest: "Install manually, then re-run /ccpm:init"

**Database initialization failed:**
- Check if ~/.claude/ directory is writable
- Verify SQLite3 is installed
- Show: "❌ Database init failed. Check permissions on ~/.claude/"

**Context file creation failed:**
- List which files were created successfully
- Note which ones failed
- Suggest: "Manually create missing files or re-run /ccpm:init"

## Important Notes

- **Run once:** This command should only be run once per project
- **No merging:** If CLAUDE.md exists, user must decide to overwrite or abort
- **Clean install:** Assumes installer already placed `.claude/` directory
- **No git operations:** Installer handles file download, not this command

$ARGUMENTS
