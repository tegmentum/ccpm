# CCPM Installation Guide

## Installing CCPM into an Existing Claude Code Project

CCPM is designed to be installed as a plugin alongside your existing Claude Code configuration.

### Quick Install

1. **Download and Extract**
   ```bash
   # Download the latest release
   curl -L https://github.com/tegmentum/ccpm/archive/refs/heads/main.zip -o ccpm.zip

   # Extract directly into your project (this preserves the .claude directory structure)
   unzip ccpm.zip -d temp
   cp -r temp/ccpm-main/.claude/* .claude/
   rm -rf temp ccpm.zip
   ```

2. **Integrate Configuration**
   ```bash
   # Run the integration script to merge CCPM config with existing settings
   bash .claude/ccpm/scripts/integrate.sh
   ```

3. **Initialize CCPM**
   ```bash
   # Initialize dependencies and database
   /ccpm:init
   ```

### What Gets Installed

The CCPM plugin installs the following structure:

```
.claude/
├── agents/ccpm/              # CCPM agents (parallel-worker, test-runner, etc.)
├── commands/ccpm/            # CCPM slash commands (/ccpm:status, /ccpm:epic-list, etc.)
└── ccpm/                     # CCPM core files
    ├── CLAUDE.md             # CCPM-specific instructions
    ├── settings.local.json   # CCPM permissions
    ├── context/              # Project context files
    ├── db/                   # Database schema and scripts
    ├── lib/                  # Shared libraries and documentation
    │   └── python/
    │       └── scripts/      # Python command implementations
    └── scripts/              # Shell scripts (init, integrate, etc.)
```

### Integration Details

The `integrate.sh` script will:

1. **Merge `.claude/settings.local.json`**
   - Adds CCPM bash permissions to your existing permissions
   - Preserves all your existing settings

2. **Merge `.claude/CLAUDE.md`**
   - Appends CCPM section to your existing CLAUDE.md
   - Includes references to CCPM context files
   - Preserves all your existing instructions

### Manual Installation

If you prefer manual installation:

1. **Copy Files**
   ```bash
   # Clone the repository
   git clone https://github.com/tegmentum/ccpm.git

   # Copy CCPM files into your project
   cp -r ccpm/.claude/agents/ccpm .claude/agents/
   cp -r ccpm/.claude/commands/ccpm .claude/commands/
   cp -r ccpm/.claude/ccpm .claude/
   ```

2. **Merge Configurations**

   Add to your `.claude/CLAUDE.md`:
   ```markdown
   ## CCPM Project Management

   @.claude/ccpm/CLAUDE.md
   ```

   Add to your `.claude/settings.local.json` permissions:
   ```json
   "Bash(bash .claude/ccpm/scripts/*)",
   "Bash(.claude/ccpm/scripts/*)",
   "Bash(bash .claude/ccpm/lib/python/scripts/*)",
   "Bash(.claude/ccpm/lib/python/scripts/*)"
   ```

3. **Initialize**
   ```bash
   /ccpm:init
   ```

### Verification

After installation, verify everything works:

```bash
# Check available commands
/ccpm:help

# View project status
/ccpm:status
```

### Uninstalling

To remove CCPM:

```bash
# Remove CCPM files
rm -rf .claude/ccpm
rm -rf .claude/agents/ccpm
rm -rf .claude/commands/ccpm

# Manually remove CCPM section from .claude/CLAUDE.md
# Manually remove CCPM permissions from .claude/settings.local.json
```

### Troubleshooting

**Commands not found:**
- Verify files are in `.claude/commands/ccpm/`
- Check permissions in `.claude/settings.local.json`

**Permission errors:**
- Run `bash .claude/ccpm/scripts/integrate.sh` again
- Manually add CCPM permissions to settings

**Database errors:**
- Run `/ccpm:init` to initialize the database
- Check `~/.claude/ccpm.db` exists and is writable

### Next Steps

After installation:

1. Create your first PRD: `/ccpm:prd-new`
2. Import existing GitHub issues: `/ccpm:import`
3. View all commands: `/ccpm:help`

For full documentation, see [README.md](README.md)
