#!/usr/bin/env python3
"""
Start work on a GitHub issue with parallel agents.

This script automates the boilerplate of starting issue work:
- Validates issue exists in database
- Checks for analysis file
- Ensures epic worktree exists
- Creates progress tracking structure
- Prints agent launch instructions for Claude to execute
"""

import sys
import os
import json
import subprocess
from pathlib import Path
from datetime import datetime

# Add db directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from helpers import (
    get_task_by_github_issue, get_epic_by_id, get_db,
    print_header, print_error, print_success, print_warning, print_info
)

def check_gh_issue(issue_number: int) -> dict:
    """Check if GitHub issue exists and is accessible."""
    try:
        result = subprocess.run(
            ["gh", "issue", "view", str(issue_number), "--json", "state,title,labels,body"],
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError:
        print_error(f"Cannot access issue #{issue_number}")
        print("  Check issue number or run: gh auth login")
        sys.exit(1)
    except FileNotFoundError:
        print_error("gh CLI not found. Install: https://cli.github.com/")
        sys.exit(1)

def check_worktree(epic_name: str) -> bool:
    """Check if epic worktree exists."""
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

def find_analysis_file(epic_name: str, issue_number: int) -> Path:
    """Find analysis file for the issue."""
    # Try common locations
    possible_paths = [
        Path(f".claude/epics/{epic_name}/{issue_number}-analysis.md"),
        Path(f".claude/epics/{epic_name}/analysis-{issue_number}.md"),
    ]
    
    for path in possible_paths:
        if path.exists():
            return path
    
    return None

def read_analysis(analysis_path: Path) -> dict:
    """Parse analysis file to extract streams."""
    if not analysis_path or not analysis_path.exists():
        return {"streams": []}
    
    # Simple parsing - look for stream sections
    content = analysis_path.read_text()
    
    # This is simplified - real implementation would parse markdown structure
    # For now, just indicate analysis exists
    return {
        "streams": ["Stream information available in analysis file"],
        "file": str(analysis_path)
    }

def create_progress_structure(epic_name: str, issue_number: int):
    """Create progress tracking directory."""
    progress_dir = Path(f".claude/epics/{epic_name}/updates/{issue_number}")
    progress_dir.mkdir(parents=True, exist_ok=True)
    return progress_dir

def assign_issue_on_github(issue_number: int):
    """Assign issue to current user and mark in-progress."""
    try:
        subprocess.run(
            ["gh", "issue", "edit", str(issue_number), 
             "--add-assignee", "@me", "--add-label", "in-progress"],
            capture_output=True,
            check=True
        )
        print_success(f"Assigned issue #{issue_number} to you")
    except subprocess.CalledProcessError:
        print_warning(f"Could not assign issue #{issue_number} on GitHub")

def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print_error("Usage: pm issue-start <issue-number>")
        sys.exit(1)
    
    try:
        issue_number = int(sys.argv[1])
    except ValueError:
        print_error(f"Invalid issue number: {sys.argv[1]}")
        sys.exit(1)
    
    print_header(f"🚀 Starting Work on Issue #{issue_number}")
    
    # 1. Check GitHub issue
    print("Checking GitHub issue...")
    gh_issue = check_gh_issue(issue_number)
    print(f"  Title: {gh_issue['title']}")
    print(f"  State: {gh_issue['state']}")
    print()
    
    # 2. Find task in database
    print("Finding local task...")
    task = get_task_by_github_issue(issue_number)
    if not task:
        print_error(f"No local task found for issue #{issue_number}")
        print("  This issue may have been created outside the PM system.")
        sys.exit(1)
    
    epic_name = task['epic_name']
    task_number = task['task_number']
    print(f"  Found: {epic_name} / Task #{task_number}")
    print()
    
    # 3. Get epic details
    epic = get_epic_by_id(task['epic_id'])
    if not epic:
        print_error(f"Epic not found for task")
        sys.exit(1)
    
    # 4. Check worktree
    print("Checking epic worktree...")
    if not check_worktree(epic_name):
        print_error(f"No worktree for epic: {epic_name}")
        print(f"  Run: pm epic-start {epic_name}")
        sys.exit(1)
    print(f"  ✓ Worktree exists: ../epic-{epic_name}/")
    print()
    
    # 5. Check for analysis
    print("Checking for analysis...")
    analysis_path = find_analysis_file(epic_name, issue_number)
    
    if not analysis_path:
        print_warning(f"No analysis found for issue #{issue_number}")
        print()
        print("Options:")
        print(f"  1. Analyze first: pm issue-analyze {issue_number}")
        print(f"  2. Start without analysis (single agent)")
        print()
        
        choice = input("Continue without analysis? (yes/no): ").strip().lower()
        if choice != "yes":
            print("Cancelled. Run issue-analyze first for parallel work streams.")
            sys.exit(0)
        
        analysis = {"streams": []}
    else:
        print(f"  ✓ Analysis found: {analysis_path}")
        analysis = read_analysis(analysis_path)
        print()
    
    # 6. Create progress tracking
    print("Setting up progress tracking...")
    progress_dir = create_progress_structure(epic_name, issue_number)
    print(f"  ✓ Progress directory: {progress_dir}")
    print()
    
    # 7. Update task status in database
    with get_db() as db:
        db.execute(
            "UPDATE ccpm.tasks SET status = 'in_progress', updated_at = datetime('now') WHERE id = ?",
            (task['id'],)
        )
    print_success("Task status updated to in_progress")
    print()
    
    # 8. Assign on GitHub
    assign_issue_on_github(issue_number)
    print()
    
    # 9. Print agent launch instructions for Claude
    print("=" * 62)
    print_success(f"Ready to start work on issue #{issue_number}")
    print()
    print(f"Epic: {epic_name}")
    print(f"Task: #{task_number} - {task['name']}")
    print(f"Worktree: ../epic-{epic_name}/")
    print(f"Progress: {progress_dir}")
    print()
    
    if analysis_path:
        print("📋 Analysis available")
        print(f"   Read: {analysis_path}")
        print()
        print("🤖 Launch parallel agents using Task tool with prompts from analysis")
        print()
    else:
        print("🤖 Launch single agent to work on this task")
        print()
    
    print("Agent Prompt Template:")
    print("-" * 62)
    print(f"""
Working on Issue #{issue_number} in epic worktree

Epic: {epic_name}
Task: #{task_number} - {task['name']}
Worktree: ../epic-{epic_name}/

Requirements:
1. Change directory to worktree: cd ../epic-{epic_name}/
2. Read full task requirements
3. Implement the changes
4. Test your changes
5. Commit with format: "Issue #{issue_number}: <specific change>"
6. Update progress in: {progress_dir}/stream-1.md

When complete:
- Run tests
- Create PR or mark task complete
- Update issue with summary
""")
    print("-" * 62)
    print()
    print("💡 Next steps:")
    print(f"   1. Use Task tool to launch agent(s) with above context")
    print(f"   2. Monitor progress: pm epic-status {epic_name}")
    print(f"   3. When done: pm task-close {epic_name} {task_number}")
    print()

if __name__ == "__main__":
    main()
