#!/usr/bin/env python3
"""
Command router for CCPM slash commands.

Maps command names to their Python script implementations.
This allows all slash commands to have identical minimal markdown files,
reducing token usage while maintaining functionality.
"""

import sys
import subprocess
from pathlib import Path

# Command mapping: command_name -> (script_name, description)
COMMAND_MAP = {
    # Query/Display commands
    'status': ('status.py', 'Project status dashboard'),
    'next': ('next.py', 'Show ready tasks'),
    'blocked': ('blocked.py', 'Show blocked tasks'),
    'in-progress': ('in-progress.py', 'Show tasks in progress'),
    'standup': ('standup.py', 'Daily standup report'),
    
    # Epic commands
    'epic-list': ('epic-list.py', 'List all epics'),
    'epic-show': ('epic-show.py', 'Show epic details'),
    'epic-close': ('epic-close.py', 'Close an epic'),
    'epic-refresh': ('epic-refresh.py', 'Refresh epic progress'),
    'epic-merge': ('epic-merge.py', 'Merge epic to main'),
    'epic-edit': ('epic-edit.py', 'Edit epic details'),
    'epic-sync': ('epic-sync.py', 'Sync epic to GitHub'),
    'epic-start': ('epic-start.py', 'Start epic worktree'),
    'epic-parallel': ('epic-parallel.py', 'Launch parallel agents'),
    
    # Task commands
    'task-add': ('task-add.py', 'Add task to epic'),
    'task-start': ('task-start.py', 'Start working on task'),
    'task-close': ('task-close.py', 'Complete a task'),
    'task-show': ('task-show.py', 'Show task details'),
    
    # Issue commands  
    'issue-show': ('issue-show.py', 'Show issue details'),
    'issue-close': ('issue-close.py', 'Close an issue'),
    'issue-reopen': ('issue-reopen.py', 'Reopen an issue'),
    'issue-sync': ('issue-sync.py', 'Sync issue to GitHub'),
    'issue-edit': ('issue-edit.py', 'Edit issue details'),
    'issue-start': ('issue-start.py', 'Start work on issue'),
    
    # PRD commands
    'prd-list': ('prd-list.py', 'List all PRDs'),
    'prd-status': ('prd-status.py', 'Show PRD status'),
    
    # Maintenance commands
    'search': ('search.py', 'Search across entities'),
    'validate': ('validate.py', 'Validate database'),
    'clean': ('clean.py', 'Clean up database'),
    'sync': ('sync.py', 'Full GitHub sync'),
    'import': ('import.py', 'Import GitHub issues'),
}

# Special commands that are bash scripts
BASH_COMMANDS = {
    'init': ('init.sh', 'Initialize CCPM system'),
    'help': ('help.sh', 'Show help information'),
}

def show_help():
    """Show available commands."""
    print("CCPM Command Router")
    print("=" * 60)
    print()
    print("Usage: pm <command> [arguments]")
    print()
    print("Available commands:")
    print()
    
    categories = {
        'Display': ['status', 'next', 'blocked', 'in-progress', 'standup'],
        'Epic': [k for k in COMMAND_MAP.keys() if k.startswith('epic-')],
        'Task': [k for k in COMMAND_MAP.keys() if k.startswith('task-')],
        'Issue': [k for k in COMMAND_MAP.keys() if k.startswith('issue-')],
        'PRD': [k for k in COMMAND_MAP.keys() if k.startswith('prd-')],
        'Maintenance': ['search', 'validate', 'clean', 'sync', 'import'],
        'System': list(BASH_COMMANDS.keys()),
    }
    
    for category, commands in categories.items():
        if commands:
            print(f"{category}:")
            for cmd in sorted(commands):
                desc = COMMAND_MAP.get(cmd, BASH_COMMANDS.get(cmd, ('', '')))[1]
                print(f"  {cmd:20} - {desc}")
            print()

def main():
    """Main router logic."""
    if len(sys.argv) < 2:
        show_help()
        sys.exit(1)
    
    command = sys.argv[1]
    args = sys.argv[2:] if len(sys.argv) > 2 else []
    
    # Check if it's a Python command
    if command in COMMAND_MAP:
        script_name, _ = COMMAND_MAP[command]
        script_path = Path(__file__).parent / script_name
        
        if not script_path.exists():
            print(f"Error: Script not found: {script_path}")
            sys.exit(1)
        
        # Execute the Python script
        result = subprocess.run(
            ['python3', str(script_path)] + args,
            capture_output=False  # Let output go directly to console
        )
        sys.exit(result.returncode)
    
    # Check if it's a bash command
    elif command in BASH_COMMANDS:
        script_name, _ = BASH_COMMANDS[command]
        script_path = Path(__file__).parent / script_name
        
        if not script_path.exists():
            print(f"Error: Script not found: {script_path}")
            sys.exit(1)
        
        # Execute the bash script
        result = subprocess.run(
            ['bash', str(script_path)] + args,
            capture_output=False
        )
        sys.exit(result.returncode)
    
    else:
        print(f"Error: Unknown command: {command}")
        print()
        print("Run 'pm help' or 'pm router.py' for available commands")
        sys.exit(1)

if __name__ == "__main__":
    main()
