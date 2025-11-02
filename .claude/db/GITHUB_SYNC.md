# GitHub Sync Architecture

## Overview

Deterministic bidirectional synchronization between SQLite database and GitHub Issues.

## Design Principles

1. **Deterministic**: No LLM calls - pure code-based sync
2. **Explicit**: User controls when sync happens (not automatic)
3. **Conflict-aware**: Detects and reports conflicts, doesn't auto-resolve
4. **Audit trail**: All sync operations logged in sync_metadata table
5. **Incremental**: Only syncs changed entities since last sync

## Data Model

### Existing Schema Support

```sql
-- PRDs and Epics track GitHub issue numbers
prds.github_issue_number INTEGER
epics.github_issue_number INTEGER
tasks.github_issue_number INTEGER

-- Last sync timestamps
prds.github_synced_at TEXT
epics.github_synced_at TEXT
tasks.github_synced_at TEXT

-- Sync metadata table tracks all operations
sync_metadata (
    entity_type,        -- 'prd', 'epic', 'task'
    entity_id,          -- Foreign key to entity
    github_issue_number,
    local_updated_at,   -- When entity last modified locally
    github_updated_at,  -- When GitHub issue last modified
    sync_status,        -- 'synced', 'pending', 'conflict'
    last_synced_at,
    conflict_reason
)
```

## Sync Operations

### 1. Push (DB → GitHub)

Pushes local changes to GitHub:

```bash
pm sync push [--epic epic-name] [--dry-run]
```

**Algorithm**:
1. Find entities with `github_synced_at IS NULL` OR `updated_at > github_synced_at`
2. For each entity:
   - If `github_issue_number IS NULL`: Create new GitHub issue
   - Else: Update existing GitHub issue
3. Store GitHub issue number and update `github_synced_at`
4. Update `sync_metadata` with operation details

**GitHub Operations**:
- PRD → Create issue with label `prd`, milestone, and full description
- Epic → Create issue with label `epic`, link to PRD, list of tasks
- Task → Create issue with label `task`, link to Epic, dependencies in body

### 2. Pull (GitHub → DB)

Pulls GitHub changes into database:

```bash
pm sync pull [--epic epic-name] [--dry-run]
```

**Algorithm**:
1. Query GitHub issues with labels: `prd`, `epic`, `task`
2. For each GitHub issue:
   - Find local entity by `github_issue_number`
   - If not found: Import as new entity (orphan detection)
   - If found: Compare `github_updated_at` vs `local_updated_at`
     - If GitHub newer: Update local (if no local changes)
     - If local newer: Skip (already pushed)
     - If both changed: Mark as conflict
3. Update `sync_metadata` with operation details

**Conflict Detection**:
- Compare timestamps: `github_updated_at` vs `local_updated_at`
- If both > `last_synced_at`: CONFLICT
- Store conflict reason in `sync_metadata.conflict_reason`

### 3. Status

Shows sync status of all entities:

```bash
pm sync status [--verbose]
```

**Output**:
```
PRDs:
  ✓ user-auth (GH #123) - synced 2h ago
  ⟳ payment-system - pending push

Epics:
  ✓ user-auth-backend (GH #124) - synced 2h ago
  ⚠ user-auth-frontend (GH #125) - CONFLICT: modified both locally and on GitHub

Tasks:
  ✓ 15 synced
  ⟳ 3 pending push
  ⚠ 1 conflicts
```

### 4. Resolve Conflicts

Manual conflict resolution:

```bash
pm sync resolve <entity-type> <entity-id> --use-local|--use-github
```

**Algorithm**:
1. Load conflicting entity
2. If `--use-local`: Push local version to GitHub (overwrite)
3. If `--use-github`: Pull GitHub version to DB (overwrite)
4. Update `sync_metadata` status to 'synced'

## GitHub API Integration

### Using `gh` CLI

All GitHub operations use `gh` command-line tool:

```bash
# Create issue
gh issue create \
  --title "Title" \
  --body "Body" \
  --label "epic,ccpm" \
  --milestone "Sprint 1"

# Update issue
gh issue edit 123 \
  --title "New Title" \
  --body "New Body"

# Get issue details
gh issue view 123 --json title,body,state,updatedAt,labels

# List issues
gh issue list \
  --label "epic" \
  --state all \
  --json number,title,state,updatedAt \
  --limit 1000
```

### Issue Body Format

Issues contain metadata as YAML frontmatter:

```markdown
---
ccpm_entity: epic
ccpm_id: 42
ccpm_prd: user-auth
ccpm_synced_at: 2025-01-25T10:00:00Z
---

# Epic: User Authentication Backend

## Description
Build backend authentication system...

## Tasks
- [ ] #126 - Database schema
- [ ] #127 - API endpoints
- [x] #128 - JWT service

## Dependencies
- Depends on: #124 (Database Layer)
```

**Parsing Strategy**:
1. Extract YAML frontmatter with sed/awk
2. Parse fields to identify entity type and relationships
3. Extract body content for description
4. Parse task lists for task relationships

## File Structure

```
db/
├── sync/
│   ├── github-push.sh          # Push operations
│   ├── github-pull.sh          # Pull operations
│   ├── github-status.sh        # Sync status
│   ├── github-resolve.sh       # Conflict resolution
│   ├── github-helpers.sh       # Shared functions
│   └── issue-template.sh       # GitHub issue formatting
└── GITHUB_SYNC.md              # This document
```

## Sync Metadata State Machine

```
pending → pushing → synced
            ↓
         conflict → resolving → synced
                                  ↓
                              (modified)
                                  ↓
                               pending
```

**States**:
- `pending`: Entity changed locally, needs push
- `pushing`: Push operation in progress
- `synced`: Local and GitHub in sync
- `conflict`: Both modified since last sync
- `resolving`: Conflict resolution in progress

## Error Handling

### Network Errors
- Retry with exponential backoff (3 attempts)
- Log error to sync_metadata.conflict_reason
- Set status to 'pending' for retry

### GitHub API Errors
- 404: Linked issue deleted on GitHub → orphan local entity
- 422: Validation error → log and skip
- 403: Rate limit → wait and retry

### Data Validation
- Ensure required fields present before push
- Validate entity relationships (epic → prd exists)
- Check for orphaned references

## Usage Examples

### Initial Setup
```bash
# Push all local data to GitHub (first time)
pm sync push --dry-run    # Preview
pm sync push              # Execute
```

### Regular Workflow
```bash
# Check what needs syncing
pm sync status

# Push local changes
pm sync push --epic user-auth

# Pull GitHub updates
pm sync pull

# Resolve conflicts
pm sync status --verbose  # See conflict details
pm sync resolve epic 42 --use-local
```

### Epic-Specific Sync
```bash
# Sync single epic and its tasks
pm sync push --epic user-auth-backend
pm sync pull --epic user-auth-backend
```

## Performance Considerations

### Batch Operations
- Group create/update operations
- Use GraphQL for bulk queries (future optimization)

### Rate Limiting
- GitHub allows 5000 requests/hour (authenticated)
- Track request count in sync_metadata
- Implement backoff if approaching limit

### Incremental Sync
- Only query issues modified since last sync:
  ```bash
  gh issue list --search "updated:>2025-01-25T10:00:00Z"
  ```

## Testing Strategy

### Unit Tests
- Test issue body parsing
- Test conflict detection logic
- Test state transitions

### Integration Tests
- Test against GitHub test repository
- Use `--dry-run` mode for safety
- Validate roundtrip: push → pull → compare

### Test Data
- Create sample PRD/Epic/Task in DB
- Push to GitHub test repo
- Modify both sides
- Test conflict detection and resolution

## Security

### Authentication
- Uses `gh` CLI authentication
- Respects `GH_TOKEN` environment variable
- No credentials stored in database

### Data Privacy
- Only sync to repositories user has access to
- Sync metadata stays local
- Can exclude sensitive fields from sync

## Future Enhancements

1. **Webhooks**: Automatic pull when GitHub issue updated
2. **GraphQL**: Batch operations for better performance
3. **Selective Sync**: Choose which fields to sync
4. **Merge Strategies**: Smart conflict resolution
5. **Offline Mode**: Queue operations when offline
