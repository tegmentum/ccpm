# Quick Install

CCPM installs as a plugin into your project's `.claude/` directory using an overlay method. It works with both new projects and existing Claude Code configurations.

## Unix/Linux/macOS

### One-Line Install (Recommended)

This command downloads the installation script from GitHub and executes it directly:

```bash
curl -sSL https://raw.githubusercontent.com/tegmentum/ccpm/main/install/ccpm.sh | bash
```

**What this does:**
- `curl -sSL` - Downloads the script silently with redirects
- `| bash` - Pipes the script directly to bash for execution
- The script downloads CCPM, overlays it into `.claude/`, and runs integration

### Alternative: wget

```bash
wget -qO- https://raw.githubusercontent.com/tegmentum/ccpm/main/install/ccpm.sh | bash
```

### Manual Download and Inspect (More Secure)

If you prefer to review the script before running it:

```bash
# Download the script
curl -sSL https://raw.githubusercontent.com/tegmentum/ccpm/main/install/ccpm.sh -o ccpm.sh

# Review the script
cat ccpm.sh

# Run it
bash ccpm.sh

# Clean up
rm ccpm.sh
```

## Windows (PowerShell)

### One-Line Install (Recommended)

This command downloads and executes the installation script:

```powershell
iwr -useb https://raw.githubusercontent.com/tegmentum/ccpm/main/install/ccpm.bat | iex
```

**What this does:**
- `iwr -useb` - Invoke-WebRequest with basic parsing
- `| iex` - Pipes to Invoke-Expression for execution
- The script downloads CCPM, overlays it into `.claude\`, and runs integration

### Alternative: Download and Execute

```powershell
curl -o ccpm.bat https://raw.githubusercontent.com/tegmentum/ccpm/main/install/ccpm.bat && ccpm.bat
```

### Manual Download and Inspect (More Secure)

If you prefer to review the script before running it:

```powershell
# Download the script
curl -o ccpm.bat https://raw.githubusercontent.com/tegmentum/ccpm/main/install/ccpm.bat

# Review the script
type ccpm.bat

# Run it
.\ccpm.bat

# Clean up
del ccpm.bat
```

## What Gets Installed

The installer downloads a snapshot (not a git clone) and overlays CCPM into your project:

### Directory Structure

```
.claude/
├── agents/ccpm/              # CCPM agents (parallel-worker, test-runner, etc.)
├── commands/ccpm/            # CCPM slash commands (/ccpm:status, /ccpm:epic-list, etc.)
└── ccpm/                     # CCPM core files
    ├── CLAUDE.md             # CCPM-specific instructions
    ├── settings.local.json   # CCPM permissions
    ├── context/              # Project context files
    ├── db/                   # Database schema and scripts
    ├── lib/                  # Shared libraries
    └── scripts/              # Installation and utility scripts

prds/                         # Your Product Requirements Documents
epics/                        # Your epic workspaces
```

### Integration

The installer automatically runs `.claude/ccpm/scripts/integrate.sh` which:
- Merges CCPM permissions into your existing `.claude/settings.local.json`
- Adds CCPM section reference to your existing `.claude/CLAUDE.md`
- Preserves all your existing configuration

## After Installation

Run the initialization command in Claude Code:

```
/ccpm:init
```

This will:
- Check and install dependencies (Python, gh CLI, uv, PyGithub)
- Initialize the SQLite database
- Create your project's CLAUDE.md file with CCPM configuration
- Generate context files for your project

## Installing into Existing Claude Code Projects

CCPM now supports installation into projects with existing `.claude/` directories using an overlay approach:

### Automatic Installation

Simply run the installer - it will:
1. Overlay CCPM files into your existing `.claude/` directory
2. Automatically merge configurations (permissions and CLAUDE.md)
3. Preserve all your existing settings and customizations

### What Gets Merged

**`.claude/settings.local.json`:**
- CCPM bash permissions are added to your existing permissions array
- All other settings remain unchanged

**`.claude/CLAUDE.md`:**
- A reference to `@.claude/ccpm/CLAUDE.md` is appended
- All your existing instructions remain intact

### Manual Review (Recommended)

After installation, you may want to review:
- `.claude/CLAUDE.md` - Verify the CCPM section reference was added correctly
- `.claude/settings.local.json` - Check that CCPM permissions were merged properly

## Troubleshooting

### Installation Issues

**"Error: Downloaded archive doesn't contain .claude directory"**
- Network issue or GitHub is temporarily unavailable
- Verify you can access https://github.com/tegmentum/ccpm
- Try again in a few minutes

**"Command not found: curl"**
- Install curl: `brew install curl` (macOS) or `apt-get install curl` (Linux)

**"Command not found: unzip"**
- Install unzip: `brew install unzip` (macOS) or `apt-get install unzip` (Linux)

**"Warning: Integration script not found"**
- The integration script wasn't found after download
- Manually add CCPM configuration following the [INSTALL.md](../INSTALL.md) guide

### Post-Installation Issues

**Commands not found after installation:**
- Restart your Claude Code session
- Verify files are in `.claude/commands/ccpm/`
- Check permissions in `.claude/settings.local.json`

**Permission errors:**
- Run `bash .claude/ccpm/scripts/integrate.sh` manually
- Check that your `.claude/settings.local.json` includes CCPM bash permissions

**Database errors:**
- Run `/ccpm:init` to initialize the database
- Check `~/.claude/ccpm.db` exists and is writable

## Next Steps

After successful installation:

1. **Initialize CCPM**: `/ccpm:init`
   - Installs dependencies (Python, gh CLI, uv, PyGithub)
   - Sets up the SQLite database
   - Generates project context

2. **Create your first PRD**: `/ccpm:prd-new`
   - Interactive brainstorming session
   - Automated PRD generation

3. **Import existing work**: `/ccpm:import`
   - Import GitHub issues into CCPM

4. **Get help**: `/ccpm:help`
   - View all available commands

## Security Considerations

### Piping to Bash

The one-line install (`curl | bash`) is convenient but executes code directly. For enhanced security:

1. **Review the script first** using the "Manual Download and Inspect" method above
2. **Verify the URL** points to `raw.githubusercontent.com/tegmentum/ccpm`
3. **Check the repository** at https://github.com/tegmentum/ccpm before installing

### What the Installer Does

The installation script:
- Downloads CCPM source code from GitHub
- Copies files into `.claude/` directory
- Runs `integrate.sh` to merge configurations
- Creates `prds/` and `epics/` directories
- Does NOT modify files outside your project directory
- Does NOT require sudo/admin privileges
- Does NOT send data anywhere

For full transparency, view the source:
- [install/ccpm.sh](ccpm.sh) - Unix/Linux/macOS installer
- [install/ccpm.bat](ccpm.bat) - Windows installer

## Uninstalling

To remove CCPM:

```bash
# Remove CCPM files
rm -rf .claude/ccpm
rm -rf .claude/agents/ccpm
rm -rf .claude/commands/ccpm

# Remove workspace directories (optional)
rm -rf prds epics

# Manually remove CCPM section from .claude/CLAUDE.md
# Manually remove CCPM permissions from .claude/settings.local.json
```

## Documentation

For complete documentation, see:
- [README.md](../README.md) - Full CCPM documentation
- [INSTALL.md](../INSTALL.md) - Detailed installation guide
- [COMMANDS.md](../docs/COMMANDS.md) - All available commands
