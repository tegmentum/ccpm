#!/usr/bin/env python3
"""
Launch parallel agents for ready tasks in an epic.

Automates the boilerplate of:
- Detecting epic context
- Finding ready tasks
- Checking for analysis files
- Printing agent launch instructions
"""

import sys
import os
import subprocess
from pathlib import Path

# Add db directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers import (
    get_epic, get_ready_tasks, get_db,
    print_header, print_error, print_success, print_warning, print_info, print_separator
)

def detect_epic_from_branch() -> str:
    """Detect epic name from current git branch."""
    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True,
            text=True,
            check=True
        )
        branch = result.stdout.strip()
        
        if branch.startswith("epic/"):
            return branch[5:]  # Remove "epic/" prefix
        else:
            print_error(f"Not in an epic branch. Current branch: {branch}")
            print("  Epic branches should be named: epic/<epic-name>")
            sys.exit(1)
    except subprocess.CalledProcessError:
        print_error("Could not determine current branch")
        sys.exit(1)

def check_worktree(epic_name: str) -> bool:
    """Check if currently in epic worktree."""
    try:
        result = subprocess.run(
            ["git", "worktree", "list"],
            capture_output=True,
            text=True,
            check=True
        )
        return f"epic-{epic_name}" in result.stdout
    except subprocess.CalledProcessError:
        return False

def find_analysis_files(epic_name: str, task_numbers: list) -> dict:
    """Find analysis files for tasks."""
    analyses = {}
    epic_dir = Path(f".claude/epics/{epic_name}")
    
    if not epic_dir.exists():
        return analyses
    
    for task_num in task_numbers:
        # Try different naming patterns
        patterns = [
            epic_dir / f"{task_num}-analysis.md",
            epic_dir / f"analysis-{task_num}.md",
            epic_dir / f"task-{task_num}-analysis.md",
        ]
        
        for path in patterns:
            if path.exists():
                analyses[task_num] = path
                break
    
    return analyses

def main():
    """Main entry point."""
    # Determine epic name
    if len(sys.argv) > 1:
        epic_name = sys.argv[1]
    else:
        epic_name = detect_epic_from_branch()
    
    print_header(f"🚀 Epic Parallel Execution: {epic_name}")
    
    # Validate epic exists
    epic = get_epic(epic_name)
    if not epic:
        print_error(f"Epic not found: {epic_name}")
        sys.exit(1)
    
    epic_id = epic['id']
    epic_status = epic['status']
    
    print(f"Epic Status: {epic_status}")
    print()
    
    # Get ready tasks
    print("Finding ready tasks...")
    ready_tasks = get_ready_tasks(epic_id)
    
    if not ready_tasks:
        print_info("No tasks ready for parallel execution")
        print()
        print("Reasons:")
        print("  - All tasks may be blocked by dependencies")
        print("  - Tasks may already be in progress")
        print("  - Epic may be complete")
        print()
        print(f"Check status: pm epic-show {epic_name}")
        sys.exit(0)
    
    task_count = len(ready_tasks)
    print(f"  Found {task_count} ready task(s)")
    print()
    
    # Check for analysis files
    print("Checking for analysis files...")
    task_numbers = [t['task_number'] for t in ready_tasks]
    analyses = find_analysis_files(epic_name, task_numbers)
    
    analyzed_count = len(analyses)
    print(f"  {analyzed_count}/{task_count} tasks have analysis")
    print()
    
    if analyzed_count == 0:
        print_warning("No tasks have been analyzed for parallel work streams")
        print()
        print("Options:")
        print("  1. Analyze tasks first (recommended for complex work)")
        print(f"     Example: pm issue-analyze <github-issue-number>")
        print("  2. Launch agents for whole tasks (simpler, less parallelization)")
        print("  3. Cancel")
        print()
        
        choice = input("Choose (1/2/3): ").strip()
        
        if choice == "1":
            print()
            print("Run issue-analyze for each task first, then re-run this command")
            for task in ready_tasks:
                if task.get('github_issue_number'):
                    print(f"  pm issue-analyze {task['github_issue_number']}")
            sys.exit(0)
        elif choice == "3":
            print("Cancelled")
            sys.exit(0)
        # If choice == "2", continue without analysis
    
    # Display task plan
    print_separator()
    print("📊 Parallel Execution Plan")
    print_separator()
    print()
    
    for task in ready_tasks:
        task_num = task['task_number']
        task_name = task['name']
        est_hours = task.get('estimated_hours', 0)
        gh_issue = task.get('github_issue_number')
        
        est_str = f" (~{est_hours}h)" if est_hours else ""
        gh_str = f" [GitHub #{gh_issue}]" if gh_issue else ""
        
        print(f"Task #{task_num}: {task_name}{est_str}{gh_str}")
        
        if task_num in analyses:
            print(f"  ✓ Analysis: {analyses[task_num]}")
            print(f"    (Read analysis for parallel streams)")
        else:
            print(f"  → Launch single agent for entire task")
        print()
    
    print_separator()
    print()
    
    # Ask for confirmation
    proceed = input(f"Launch agents for {task_count} task(s)? (yes/no): ").strip().lower()
    
    if proceed != "yes":
        print("Cancelled")
        sys.exit(0)
    
    print()
    print_separator()
    print_success(f"Ready to launch parallel agents")
    print_separator()
    print()
    
    # Print agent launch instructions
    print("🤖 Agent Launch Instructions")
    print()
    print("Use the Task tool to launch agents. For each ready task:")
    print()
    
    for i, task in enumerate(ready_tasks, 1):
        task_num = task['task_number']
        task_name = task['name']
        gh_issue = task.get('github_issue_number')
        
        print(f"--- Agent {i}: Task #{task_num} ---")
        print()
        
        if task_num in analyses:
            print(f"Read analysis file: {analyses[task_num]}")
            print("Launch MULTIPLE agents (one per stream) with:")
            print()
        else:
            print("Launch SINGLE agent with:")
            print()
        
        print(f"""Task:
  description: "{epic_name} - Task #{task_num}"
  subagent_type: "general-purpose"
  model: "sonnet"
  prompt: |
    Working on Epic: {epic_name}
    Task #{task_num}: {task_name}
    {"GitHub Issue #" + str(gh_issue) if gh_issue else ""}
    
    Worktree: ../epic-{epic_name}/
    
    Instructions:
    1. Change to worktree: cd ../epic-{epic_name}/
    2. Read task details from database or task file
    {"3. Read analysis file: " + str(analyses[task_num]) if task_num in analyses else "3. Implement the entire task"}
    {"4. Launch parallel work streams as described" if task_num in analyses else "4. Implement and test changes"}
    {"5. Commit with format: 'Task #" + str(task_num) + ": <change>'" if not task_num in analyses else "5. Coordinate between streams, commit frequently"}
    6. Update progress
    
    When complete:
    - Run tests
    - Mark task complete: pm task-close {epic_name} {task_num}
""")
        print()
    
    print_separator()
    print()
    print("💡 Next steps:")
    print("  1. Copy agent prompts above")
    print("  2. Use Task tool to launch each agent")
    print("  3. Monitor progress: pm epic-status " + epic_name)
    print("  4. When agents complete: pm epic-refresh " + epic_name)
    print()

if __name__ == "__main__":
    main()
