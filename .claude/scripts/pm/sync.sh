#!/usr/bin/env bash
# GitHub Sync - Main command wrapper
# Bidirectional sync between local database and GitHub Issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SYNC_DIR="$PROJECT_ROOT/db/sync"

# =============================================================================
# Subcommand Routing
# =============================================================================

show_help() {
    cat << EOF
GitHub Sync - Bidirectional sync with GitHub Issues

Usage:
  pm sync <command> [options]

Commands:
  push                   Push local changes to GitHub
  pull                   Pull GitHub changes to database
  status                 Show sync status
  resolve                Resolve conflicts
  help                   Show this help

Push Options:
  pm sync push [entity-type] [options]

  Entity Types:
    prd                  Push PRDs
    epic                 Push Epics
    task                 Push Tasks
    all                  Push all entities (default)

  Options:
    --epic <name>        Only push entities in this epic
    --id <id>            Push specific entity by ID
    --dry-run            Preview without pushing
    --yes                Skip confirmation prompts

  Examples:
    pm sync push --dry-run              # Preview all changes
    pm sync push epic --epic user-auth  # Push single epic
    pm sync push task --id 42           # Push specific task
    pm sync push all --yes              # Push everything

Pull Options:
  pm sync pull [entity-type] [options]

  Entity Types:
    prd                  Pull PRDs
    epic                 Pull Epics
    task                 Pull Tasks
    all                  Pull all entities (default)

  Options:
    --issue <number>     Pull specific issue by number
    --since <timestamp>  Only pull issues updated since (ISO 8601)
    --dry-run            Preview without pulling
    --yes                Skip confirmation prompts

  Examples:
    pm sync pull --dry-run              # Preview all changes
    pm sync pull epic                   # Pull epics only
    pm sync pull task --issue 123       # Pull specific issue
    pm sync pull --since 2025-01-25T10:00:00Z

Status Options:
  pm sync status [options]

  Options:
    --verbose            Show detailed status for all entities
    --conflicts          Show only conflicts
    --prd                Show PRD details
    --epics              Show Epic details
    --tasks              Show Task details
    --epic <name>        Filter by epic name

  Examples:
    pm sync status                      # Summary view
    pm sync status --verbose            # Detailed view
    pm sync status --conflicts          # Show conflicts only
    pm sync status --epics --epic user-auth

Resolve Options:
  pm sync resolve <entity-type> <entity-id> <strategy> [options]
  pm sync resolve all <strategy> [options]

  Entity Types:
    prd                  Resolve PRD conflict
    epic                 Resolve Epic conflict
    task                 Resolve Task conflict
    all                  Resolve all conflicts

  Strategies:
    --use-local          Use local version (push to GitHub)
    --use-github         Use GitHub version (pull to database)
    --show               Show conflict details without resolving

  Options:
    --dry-run            Preview resolution
    --yes                Skip confirmation prompts

  Examples:
    pm sync resolve epic 42 --show              # Show details
    pm sync resolve epic 42 --use-local         # Use local
    pm sync resolve task 15 --use-github        # Use GitHub
    pm sync resolve all --use-local --yes       # Resolve all

Common Workflows:
  # Initial setup - push all local data to GitHub
  pm sync status                # Check what needs syncing
  pm sync push --dry-run        # Preview
  pm sync push --yes            # Execute

  # Regular workflow - sync changes
  pm sync status                # Check status
  pm sync push                  # Push local changes
  pm sync pull                  # Pull GitHub updates

  # Conflict resolution
  pm sync status --conflicts    # See conflicts
  pm sync resolve epic 42 --show          # Review details
  pm sync resolve epic 42 --use-local     # Resolve

Prerequisites:
  - GitHub CLI (gh) installed and authenticated
  - GitHub repository initialized

Setup:
  1. Install GitHub CLI: https://cli.github.com
  2. Authenticate: gh auth login
  3. Ensure you're in a git repository

EOF
}

# Route to appropriate subcommand
route_command() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        push)
            exec "$SYNC_DIR/github-push.sh" "$@"
            ;;
        pull)
            exec "$SYNC_DIR/github-pull.sh" "$@"
            ;;
        status)
            exec "$SYNC_DIR/github-status.sh" "$@"
            ;;
        resolve)
            exec "$SYNC_DIR/github-resolve.sh" "$@"
            ;;
        help|--help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown command: $command" >&2
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Check if sync directory exists
    if [[ ! -d "$SYNC_DIR" ]]; then
        echo "Error: Sync directory not found: $SYNC_DIR" >&2
        exit 1
    fi

    route_command "$@"
}

# Run main
main "$@"
