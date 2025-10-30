#!/usr/bin/env python3
"""
Database and GitHub helpers for CCPM.

This module provides:
- Database connection and query functions
- GitHub API integration via PyGithub
- Common CRUD operations for epics, tasks, PRDs
- Safe SQL parameterization
"""

import os
import sys
import json
import sqlite3
import subprocess
import logging
from pathlib import Path
from typing import Optional, List, Dict, Any, Tuple
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(message)s'
)
logger = logging.getLogger(__name__)

# Try to import PyGithub
try:
    from github import Github, GithubException
    GITHUB_AVAILABLE = True
except ImportError:
    GITHUB_AVAILABLE = False
    logger.warning("PyGithub not available. Install with: uv pip install PyGithub")


class CCPMDatabase:
    """Database connection and query management."""

    def __init__(self, db_path: Optional[str] = None):
        """Initialize database connection."""
        if db_path is None:
            db_path = os.path.expanduser("~/.claude/ccpm.db")

        self.db_path = db_path

        if not os.path.exists(db_path):
            raise FileNotFoundError(
                f"Database not found: {db_path}\n"
                f"Run: pm init"
            )

    def __enter__(self):
        """Context manager entry."""
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row  # Access columns by name
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        if self.conn:
            self.conn.close()

    def query(self, sql: str, params: tuple = ()) -> List[Dict[str, Any]]:
        """
        Execute SQL query and return results as list of dicts.

        Args:
            sql: SQL query with ? placeholders
            params: Tuple of parameters for placeholders

        Returns:
            List of dictionaries with column names as keys
        """
        cursor = self.conn.cursor()
        cursor.execute(sql, params)

        columns = [desc[0] for desc in cursor.description] if cursor.description else []
        results = []

        for row in cursor.fetchall():
            results.append(dict(zip(columns, row)))

        return results

    def execute(self, sql: str, params: tuple = ()) -> int:
        """
        Execute SQL statement (INSERT, UPDATE, DELETE).

        Args:
            sql: SQL statement with ? placeholders
            params: Tuple of parameters for placeholders

        Returns:
            Number of affected rows
        """
        cursor = self.conn.cursor()
        cursor.execute(sql, params)
        self.conn.commit()
        return cursor.rowcount

    def get_last_insert_id(self) -> int:
        """Get the last inserted row ID."""
        return self.conn.execute("SELECT last_insert_rowid()").fetchone()[0]


class GitHubClient:
    """GitHub API client wrapper."""

    def __init__(self):
        """Initialize GitHub client."""
        if not GITHUB_AVAILABLE:
            raise ImportError(
                "PyGithub not installed. Install with: uv pip install PyGithub"
            )

        self.token = self._get_token()
        self.gh = Github(self.token) if self.token else None
        self.repo = self._get_repo() if self.gh else None

    def _get_token(self) -> Optional[str]:
        """Get GitHub token from gh CLI or environment."""
        # Try gh CLI first
        try:
            result = subprocess.run(
                ["gh", "auth", "token"],
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass

        # Try environment variable
        token = os.getenv("GITHUB_TOKEN")
        if token:
            return token

        logger.warning(
            "GitHub not authenticated. Run: gh auth login\n"
            "Or set GITHUB_TOKEN environment variable"
        )
        return None

    def _get_repo(self):
        """Get current repository from git remote."""
        try:
            result = subprocess.run(
                ["git", "config", "--get", "remote.origin.url"],
                capture_output=True,
                text=True,
                check=True
            )
            url = result.stdout.strip()

            # Parse owner/repo from URL
            # https://github.com/owner/repo.git -> owner/repo
            # git@github.com:owner/repo.git -> owner/repo
            if "github.com" in url:
                parts = url.split("github.com")[1].strip(":/").replace(".git", "")
                return self.gh.get_repo(parts)
        except Exception as e:
            logger.warning(f"Could not determine GitHub repository: {e}")

        return None

    def get_issue(self, issue_number: int):
        """Get issue by number."""
        if not self.repo:
            raise ValueError("No repository configured")
        return self.repo.get_issue(issue_number)

    def create_issue(self, title: str, body: str = "", labels: List[str] = None):
        """Create a new issue."""
        if not self.repo:
            raise ValueError("No repository configured")
        return self.repo.create_issue(title=title, body=body, labels=labels or [])

    def close_issue(self, issue_number: int, comment: str = None):
        """Close an issue with optional comment."""
        issue = self.get_issue(issue_number)
        if comment:
            issue.create_comment(comment)
        issue.edit(state="closed")

    def reopen_issue(self, issue_number: int, comment: str = None):
        """Reopen an issue with optional comment."""
        issue = self.get_issue(issue_number)
        if comment:
            issue.create_comment(comment)
        issue.edit(state="open")


# Database Helper Functions

def get_db() -> CCPMDatabase:
    """Get database connection."""
    return CCPMDatabase()


def get_epic(epic_name: str) -> Optional[Dict[str, Any]]:
    """
    Get epic by name.

    Args:
        epic_name: Name of the epic

    Returns:
        Epic dict or None if not found
    """
    with get_db() as db:
        results = db.query(
            """
            SELECT *
            FROM ccpm.epics
            WHERE name = ?
                AND deleted_at IS NULL
            """,
            (epic_name,)
        )
        return results[0] if results else None


def get_epic_by_id(epic_id: int) -> Optional[Dict[str, Any]]:
    """Get epic by ID."""
    with get_db() as db:
        results = db.query(
            "SELECT * FROM ccpm.epics WHERE id = ? AND deleted_at IS NULL",
            (epic_id,)
        )
        return results[0] if results else None


def get_task(epic_name: str, task_number: int) -> Optional[Dict[str, Any]]:
    """
    Get task by epic name and task number.

    Args:
        epic_name: Name of the epic
        task_number: Task number within epic

    Returns:
        Task dict or None if not found
    """
    with get_db() as db:
        results = db.query(
            """
            SELECT t.*
            FROM ccpm.tasks t
            JOIN ccpm.epics e ON t.epic_id = e.id
            WHERE e.name = ?
                AND t.task_number = ?
                AND t.deleted_at IS NULL
            """,
            (epic_name, task_number)
        )
        return results[0] if results else None


def get_task_by_github_issue(issue_number: int) -> Optional[Dict[str, Any]]:
    """Get task by GitHub issue number."""
    with get_db() as db:
        results = db.query(
            """
            SELECT t.*, e.name as epic_name
            FROM ccpm.tasks t
            JOIN ccpm.epics e ON t.epic_id = e.id
            WHERE t.github_issue_number = ?
                AND t.deleted_at IS NULL
            """,
            (issue_number,)
        )
        return results[0] if results else None


def get_tasks_for_epic(epic_id: int) -> List[Dict[str, Any]]:
    """Get all tasks for an epic."""
    with get_db() as db:
        return db.query(
            """
            SELECT *
            FROM ccpm.tasks
            WHERE epic_id = ?
                AND deleted_at IS NULL
            ORDER BY task_number
            """,
            (epic_id,)
        )


def get_ready_tasks(epic_id: Optional[int] = None) -> List[Dict[str, Any]]:
    """Get tasks ready to start (no unmet dependencies)."""
    with get_db() as db:
        if epic_id:
            return db.query(
                """
                SELECT *
                FROM ccpm.ready_tasks
                WHERE epic_id = ?
                ORDER BY task_number
                """,
                (epic_id,)
            )
        else:
            return db.query("SELECT * FROM ccpm.ready_tasks ORDER BY epic_id, task_number")


def get_blocked_tasks(epic_id: Optional[int] = None) -> List[Dict[str, Any]]:
    """Get tasks blocked by dependencies."""
    with get_db() as db:
        if epic_id:
            return db.query(
                """
                SELECT *
                FROM ccpm.blocked_tasks
                WHERE epic_id = ?
                ORDER BY task_number
                """,
                (epic_id,)
            )
        else:
            return db.query("SELECT * FROM ccpm.blocked_tasks ORDER BY epic_id, task_number")


def update_epic(epic_id: int, **fields) -> int:
    """
    Update epic fields.

    Args:
        epic_id: Epic ID
        **fields: Fields to update (name, description, status, progress, etc.)

    Returns:
        Number of rows updated
    """
    if not fields:
        return 0

    # Always update updated_at
    fields['updated_at'] = datetime.utcnow().isoformat() + "Z"

    set_clause = ", ".join(f"{key} = ?" for key in fields.keys())
    values = tuple(fields.values()) + (epic_id,)

    with get_db() as db:
        return db.execute(
            f"UPDATE ccpm.epics SET {set_clause} WHERE id = ?",
            values
        )


def update_task(task_id: int, **fields) -> int:
    """
    Update task fields.

    Args:
        task_id: Task ID
        **fields: Fields to update (name, description, status, etc.)

    Returns:
        Number of rows updated
    """
    if not fields:
        return 0

    # Always update updated_at
    fields['updated_at'] = datetime.utcnow().isoformat() + "Z"

    set_clause = ", ".join(f"{key} = ?" for key in fields.keys())
    values = tuple(fields.values()) + (task_id,)

    with get_db() as db:
        return db.execute(
            f"UPDATE ccpm.tasks SET {set_clause} WHERE id = ?",
            values
        )


def calculate_epic_progress(epic_id: int) -> Tuple[int, int, int]:
    """
    Calculate epic progress.

    Args:
        epic_id: Epic ID

    Returns:
        Tuple of (total_tasks, closed_tasks, progress_percentage)
    """
    with get_db() as db:
        results = db.query(
            """
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN status = 'closed' THEN 1 ELSE 0 END) as closed
            FROM ccpm.tasks
            WHERE epic_id = ?
                AND deleted_at IS NULL
            """,
            (epic_id,)
        )

        if results:
            total = results[0]['total'] or 0
            closed = results[0]['closed'] or 0
            progress = int((closed / total * 100)) if total > 0 else 0
            return total, closed, progress

        return 0, 0, 0


def get_prd(prd_name: str) -> Optional[Dict[str, Any]]:
    """Get PRD by name."""
    with get_db() as db:
        results = db.query(
            "SELECT * FROM ccpm.prds WHERE name = ? AND deleted_at IS NULL",
            (prd_name,)
        )
        return results[0] if results else None


# GitHub Helper Functions

def get_github_client() -> Optional[GitHubClient]:
    """Get authenticated GitHub client."""
    try:
        return GitHubClient()
    except Exception as e:
        logger.error(f"Failed to initialize GitHub client: {e}")
        return None


# Utility Functions

def format_datetime(dt_str: Optional[str]) -> str:
    """Format ISO datetime for display."""
    if not dt_str:
        return "N/A"

    try:
        dt = datetime.fromisoformat(dt_str.replace("Z", "+00:00"))
        return dt.strftime("%Y-%m-%d %H:%M")
    except:
        return dt_str


def calculate_duration_days(start_str: str, end_str: Optional[str] = None) -> int:
    """Calculate duration in days between two ISO datetime strings."""
    try:
        start = datetime.fromisoformat(start_str.replace("Z", "+00:00"))
        end = datetime.fromisoformat(end_str.replace("Z", "+00:00")) if end_str else datetime.utcnow()
        return (end - start).days
    except:
        return 0


def print_separator(char="", length=62):
    """Print a separator line."""
    print(char * length)


def print_header(title: str):
    """Print a formatted header."""
    print_separator()
    print(title)
    print_separator()
    print()


def print_success(message: str):
    """Print success message."""
    logger.info(f" {message}")


def print_error(message: str):
    """Print error message."""
    logger.error(f"L {message}")


def print_warning(message: str):
    """Print warning message."""
    logger.warning(f"   {message}")


def print_info(message: str):
    """Print info message."""
    logger.info(f"9  {message}")
