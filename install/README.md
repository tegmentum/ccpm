# Quick Install

CCPM installs into your project's `.claude/` directory. If you already have a `.claude/` directory, the installer will abort to avoid conflicts.

## Unix/Linux/macOS

```bash
curl -sSL https://raw.githubusercontent.com/tegmentum/ccpm/main/install/ccpm.sh | bash
```

Or with wget:

```bash
wget -qO- https://raw.githubusercontent.com/tegmentum/ccpm/main/install/ccpm.sh | bash
```

## Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/tegmentum/ccpm/main/install/ccpm.bat | iex
```

Or download and execute:

```powershell
curl -o ccpm.bat https://raw.githubusercontent.com/tegmentum/ccpm/main/install/ccpm.bat && ccpm.bat
```

## What Gets Installed

The installer downloads a snapshot (not a git clone) and installs:

- `.claude/` - All CCPM code, commands, and configuration
- `prds/` - Directory for your Product Requirements Documents
- `epics/` - Directory for your epic workspaces

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

## Existing Projects

If you already have a `.claude/` directory, the installer will abort with an error. This prevents accidentally overwriting existing Claude Code configuration.

To install CCPM in a project with existing `.claude/` content:
1. Backup your `.claude/` directory
2. Remove it: `rm -rf .claude`
3. Run the installer
4. Manually merge any custom configuration you want to keep

## Troubleshooting

**"Error: .claude directory already exists"**
- You already have Claude Code configuration in this project
- Either remove it or install CCPM in a fresh project

**"Error: Downloaded archive doesn't contain .claude directory"**
- Network issue or GitHub is down
- Try again in a few minutes

**"Command not found: curl"**
- Install curl: `brew install curl` (macOS) or `apt-get install curl` (Linux)
