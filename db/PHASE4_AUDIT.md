# Phase 4: Command Refactoring - Audit

## Current State Analysis

### Commands Already Migrated ✅

**Database-backed commands** (created in Phase 2.1):
- `status-db.sh` - Overall project status with database queries
- `prd-list-db.sh` - List PRDs from database
- `epic-list-db.sh` - List epics from database
- `next-db.sh` - Show ready tasks from database
- `sync.sh` - GitHub sync (Phase 3)

**Database tools** (created in Phase 1 & 2):
- `db/query.sh` - DuckDB wrapper
- `db/helpers.sh` - Reusable query functions
- `db/init.sh` - Database initialization
- `db/resolve-dependencies-json.sh` - Dependency resolver
- `db/analyze-issue.sh` - Issue analyzer

### Commands Still File-Based ⚠️

**PRD Commands:**
- `prd-list.sh` - ✅ Replaced by `prd-list-db.sh`
- `prd-status.sh` - ⚠️ Still uses file system
- Missing: `prd-new`, `prd-edit`, `prd-parse`

**Epic Commands:**
- `epic-list.sh` - ✅ Replaced by `epic-list-db.sh`
- `epic-show.sh` - ⚠️ Reads from file system
- `epic-status.sh` - ⚠️ Still uses file system
- Missing: `epic-decompose`, `epic-edit`, `epic-close`, `epic-refresh`, `epic-start`

**Issue/Task Commands:**
- Missing: `issue-show`, `issue-status`, `issue-start`, `issue-close`, `issue-edit`, `issue-analyze`

**Workflow Commands:**
- `next.sh` - ✅ Replaced by `next-db.sh`
- `status.sh` - ✅ Replaced by `status-db.sh`
- `blocked.sh` - ⚠️ Still uses file system
- `in-progress.sh` - ⚠️ Still uses file system
- `standup.sh` - ⚠️ Still uses file system

**Maintenance Commands:**
- `validate.sh` - ⚠️ Validates file structure
- `search.sh` - ⚠️ Searches markdown files
- Missing: `clean`, `import`

## Migration Strategy

### Priority 1: Core CRUD Operations (High Impact)

These commands create/modify data and should write to database:

1. **`prd-new.sh`** - Create new PRD
   - Currently: Creates markdown file in `.claude/prds/`
   - New: INSERT into `prds` table
   - Optional: Also create markdown for git tracking

2. **`prd-edit.sh`** - Edit PRD
   - Currently: Opens markdown in editor
   - New: UPDATE `prds` table
   - Optional: Sync to markdown

3. **`epic-decompose.sh`** - Break epic into tasks
   - Currently: Creates task markdown files
   - New: INSERT into `tasks` table with dependencies
   - Critical: Uses LLM, should leverage database

4. **`task-start.sh` / `issue-start.sh`** - Start task
   - Currently: Updates markdown frontmatter
   - New: UPDATE `tasks` SET status = 'in-progress'
   - Should also create work stream records

5. **`task-close.sh` / `issue-close.sh`** - Complete task
   - Currently: Updates markdown, closes GitHub issue
   - New: UPDATE `tasks` SET status = 'closed'
   - Trigger should auto-update epic progress

### Priority 2: Read Operations (Medium Impact)

These commands display data and should query database:

6. **`epic-show.sh`** - Show epic details
   - Currently: Reads markdown files
   - New: Query database with joins
   - Show tasks with dependencies

7. **`blocked.sh`** - Show blocked tasks
   - Currently: Grep through markdown
   - New: Use `blocked_tasks` view or dependency resolver

8. **`in-progress.sh`** - Show in-progress work
   - Currently: Grep for status in markdown
   - New: Query `WHERE status = 'in-progress'`

9. **`standup.sh`** - Daily standup report
   - Currently: Aggregates from markdown
   - New: SQL aggregation queries

10. **`prd-status.sh`** - PRD status
    - Currently: Counts epic files
    - New: Query with epic counts

11. **`epic-status.sh`** - Epic status
    - Currently: Counts task files
    - New: Use `epic_progress` view

### Priority 3: Database Management (New Commands)

12. **`db-query.sh`** - Run arbitrary SQL
13. **`db-export.sh`** - Export to markdown
14. **`db-import.sh`** - Import from markdown
15. **`db-backup.sh`** - Backup database
16. **`db-restore.sh`** - Restore from backup

### Priority 4: Advanced Operations (Lower Priority)

17. **`validate.sh`** - Validation
    - Currently: Checks file structure
    - New: Check database integrity, foreign keys

18. **`search.sh`** - Search
    - Currently: Grep through markdown
    - New: Full-text search in database

19. **`clean.sh`** - Archive completed work
    - New: Soft delete (set `deleted_at`)

20. **`import.sh`** - Import GitHub issues
    - Use Phase 3 sync commands

## Implementation Plan

### Step 1: Create Database CRUD Helpers

Extend `db/helpers.sh` with mutation functions:

```bash
# PRD operations
create_prd() { ... }
update_prd() { ... }
delete_prd() { ... }

# Epic operations
create_epic() { ... }
update_epic() { ... }
delete_epic() { ... }

# Task operations
create_task() { ... }
update_task() { ... }
delete_task() { ... }
create_task_dependency() { ... }
```

### Step 2: Refactor High-Impact Commands

**Week 1: PRD Commands**
- `prd-new.sh` - Create PRD in database
- `prd-edit.sh` - Update PRD in database
- `prd-status.sh` - Query database for status

**Week 2: Epic Decomposition**
- `epic-decompose.sh` - Create tasks in database
- `epic-show.sh` - Query database for epic details
- `epic-status.sh` - Use database views

**Week 3: Task Management**
- `issue-start.sh` - Update task status
- `issue-close.sh` - Complete task
- `issue-show.sh` - Display task details

### Step 3: Workflow Commands

**Week 4: Status & Reporting**
- `blocked.sh` - Query blocked tasks
- `in-progress.sh` - Query active tasks
- `standup.sh` - Aggregate from database

### Step 4: Database Management

**Week 5: Utilities**
- `db-query.sh` - Interactive SQL
- `db-export.sh` - Backup to markdown
- `db-backup.sh` - Database backup

### Step 5: Deprecation

**Week 6: Cleanup**
- Mark old file-based commands as deprecated
- Update help to show new commands
- Add migration guide

## Technical Approach

### Option 1: Full Migration (Recommended)

**Database as source of truth:**
- All commands read/write to database
- Optional markdown export for git tracking
- File system becomes view layer

**Pros:**
- Single source of truth
- Better data integrity
- Faster queries
- Easier to maintain

**Cons:**
- Requires full migration
- More upfront work
- Breaking change

### Option 2: Hybrid Approach

**Database + file system:**
- Keep markdown files
- Sync bidirectionally
- Gradual migration

**Pros:**
- Backwards compatible
- Gradual migration
- Less risky

**Cons:**
- Two sources of truth
- Sync complexity
- More bugs

### Recommendation: Option 1 (Full Migration)

Reasons:
1. We already have database schema
2. GitHub sync handles external integration
3. Markdown export can be optional
4. Cleaner long-term architecture

## Backward Compatibility Strategy

### Migration Path

**Phase 1: Dual Write**
- New commands write to both database and files
- Maintains compatibility
- Users can test database commands

**Phase 2: Database Primary**
- Database becomes source of truth
- Files generated from database
- Deprecation warnings on old commands

**Phase 3: Database Only**
- Remove file-based commands
- Full database workflow
- Optional markdown export

### Data Migration

**One-time migration script:**
```bash
#!/usr/bin/env bash
# migrate-to-db.sh

# 1. Parse all markdown files
# 2. Extract frontmatter and content
# 3. Insert into database
# 4. Validate completeness
# 5. Backup original files
# 6. Generate markdown from database to verify
```

## Command-by-Command Details

### prd-new.sh

**Current Flow:**
1. LLM brainstorming session
2. Generate PRD markdown
3. Save to `.claude/prds/<name>.md`

**New Flow:**
1. LLM brainstorming session
2. Extract PRD fields (name, description, etc.)
3. INSERT into `prds` table
4. Optional: Export to markdown
5. Optional: Create GitHub issue with `pm sync push prd`

**Database Operations:**
```sql
INSERT INTO prds (name, status, description, business_value, success_criteria, target_date)
VALUES (?, 'draft', ?, ?, ?, ?);
```

### epic-decompose.sh

**Current Flow:**
1. Read PRD markdown
2. LLM breaks into epics
3. LLM breaks epic into tasks
4. Create task markdown files
5. Parse dependencies from descriptions

**New Flow:**
1. Query PRD from database
2. LLM breaks into tasks with dependencies
3. INSERT tasks into database
4. INSERT dependencies into `task_dependencies`
5. Trigger epic progress calculation
6. Optional: Run `db/analyze-issue.sh` for streams

**Database Operations:**
```sql
-- Create epic
INSERT INTO epics (prd_id, name, description) VALUES (?, ?, ?);

-- Create tasks
INSERT INTO tasks (epic_id, task_number, name, description, estimated_hours, parallel)
VALUES (?, ?, ?, ?, ?, ?);

-- Create dependencies
INSERT INTO task_dependencies (task_id, dependency_task_id)
VALUES (?, ?);
```

**LLM Integration:**
- Use LLM to break down work
- Extract structured data
- Store in database
- Reduce LLM calls for simple operations

### issue-start.sh

**Current Flow:**
1. Read task markdown
2. Check dependencies
3. Update status to in-progress
4. Save markdown
5. Optionally create GitHub issue

**New Flow:**
1. Query task from database
2. Check dependencies via `ready_tasks` view
3. UPDATE status to 'in-progress'
4. Set started_at timestamp
5. Create work stream records
6. Optional: Sync to GitHub with `pm sync push`

**Database Operations:**
```sql
-- Check if ready
SELECT * FROM ready_tasks WHERE id = ?;

-- Start task
UPDATE tasks
SET status = 'in-progress',
    started_at = datetime('now'),
    updated_at = datetime('now')
WHERE id = ?;

-- Create work streams
INSERT INTO work_streams (task_id, stream_name, agent_type, status)
SELECT ?, stream_name, 'parallel-worker', 'pending'
FROM task_stream_assignments WHERE task_id = ?;
```

### standup.sh

**Current Flow:**
1. Grep all markdown for in-progress tasks
2. Parse completion status
3. Format report

**New Flow:**
1. Query in-progress tasks
2. Query completed tasks (last 24h)
3. Query blocked tasks
4. Format report

**Database Operations:**
```sql
-- In progress
SELECT e.name, t.task_number, t.name, t.started_at
FROM tasks t
JOIN epics e ON t.epic_id = e.id
WHERE t.status = 'in-progress'
ORDER BY t.started_at DESC;

-- Completed today
SELECT e.name, t.task_number, t.name, t.completed_at
FROM tasks t
JOIN epics e ON t.epic_id = e.id
WHERE t.status = 'closed'
  AND t.completed_at > datetime('now', '-1 day')
ORDER BY t.completed_at DESC;

-- Blocked
SELECT * FROM blocked_tasks;
```

## Testing Strategy

### Unit Tests

**For each refactored command:**
1. Test database insertion
2. Test database updates
3. Test queries
4. Test error handling

### Integration Tests

**End-to-end workflows:**
1. Create PRD → Parse → Decompose → Start → Complete
2. Verify database state at each step
3. Verify GitHub sync works
4. Verify rollback scenarios

### Migration Tests

**Data integrity:**
1. Migrate sample markdown files
2. Verify all data preserved
3. Export to markdown
4. Compare with originals

## Risk Mitigation

### Data Loss Prevention

1. **Backup before migration**
   - `db-backup.sh` before any destructive operation
   - Keep markdown files during transition
   - Version control all changes

2. **Validation**
   - Compare file count vs database row count
   - Verify all relationships preserved
   - Check for orphaned records

3. **Rollback Plan**
   - Keep markdown files as backup
   - Migration script should be reversible
   - Document rollback procedure

### Breaking Changes

1. **Deprecation Warnings**
   - Add warnings to old commands
   - Suggest new equivalent command
   - Grace period before removal

2. **Parallel Commands**
   - Keep both old and new commands
   - New commands use `-db` suffix initially
   - Swap after validation

3. **Documentation**
   - Update README with new workflow
   - Migration guide for users
   - Troubleshooting section

## Success Criteria

### Functional Requirements

- ✅ All CRUD operations use database
- ✅ No data loss during migration
- ✅ GitHub sync still works
- ✅ Dependencies correctly tracked
- ✅ Progress calculations accurate

### Performance Requirements

- ✅ Commands execute faster than file-based (< 100ms for queries)
- ✅ No regression in command response time
- ✅ Database queries optimized with indexes

### Quality Requirements

- ✅ All commands have error handling
- ✅ Database integrity constraints enforced
- ✅ Comprehensive test coverage
- ✅ Documentation updated

## Next Steps

1. **Create CRUD helpers** - Extend `db/helpers.sh`
2. **Refactor prd-new** - First command to migrate
3. **Test thoroughly** - Ensure no regressions
4. **Iterate** - Migrate one command at a time
5. **Document** - Update help and README

## Estimated Timeline

- **Week 1-2:** CRUD helpers + PRD commands (3 commands)
- **Week 3-4:** Epic commands (5 commands)
- **Week 5-6:** Task/Issue commands (6 commands)
- **Week 7:** Workflow commands (4 commands)
- **Week 8:** Database management (5 commands)
- **Week 9-10:** Testing, documentation, migration

**Total: ~10 weeks for complete migration**

**Quick wins (Week 1-2):**
- CRUD helpers
- prd-new, prd-edit, prd-status
- blocked, in-progress (use existing views)
