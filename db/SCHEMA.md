# Database Schema Documentation

## Overview

This document describes the SQLite database schema for the CCPM (Claude Code Project Management) framework. The schema replaces the file-based markdown system with a relational database while maintaining compatibility with GitHub Issues sync.

## Design Principles

### 1. **Deterministic Operations**
- Status queries use SQL instead of grep/find
- Progress calculations use aggregate functions
- Dependency resolution uses graph queries

### 2. **GitHub Integration**
- Database is primary source of truth
- GitHub Issues as optional sync target
- Bidirectional sync with conflict detection
- Explicit sync command (not automatic)

### 3. **Performance**
- Indexed for common queries (status, dependencies)
- Views for expensive calculations
- Triggers for automatic updates
- Soft deletes for audit trail

### 4. **Data Integrity**
- Foreign key constraints
- Check constraints for enums
- Unique constraints for business rules
- No circular dependencies

## Schema Design Decisions

### Core Entity Tables

#### **prds** - Product Requirements Documents
**Rationale:** Simple flat table since PRDs don't have complex relationships.

Key fields:
- `name`: Unique kebab-case identifier (matches filename convention)
- `status`: Enum constraint ensures valid values
- `content`: Full markdown content (without frontmatter)
- `deleted_at`: Soft delete for audit trail

**Why not file-based?**
- SQL queries faster than grep/find
- Easy to search across all PRDs
- Consistent with other entities

#### **epics** - Technical Implementation Plans
**Rationale:** One-to-many relationship with tasks, foreign key to PRD.

Key fields:
- `prd_id`: Foreign key establishes PRD → Epic relationship
- `progress`: Calculated from task completion (0-100%)
- `github_issue_number`: Links to GitHub after sync
- `github_synced_at`: Tracks sync state

**Why store progress?**
- Denormalized for performance
- Auto-updated via trigger when tasks change
- Can compare calculated vs stored for validation

#### **tasks** - Individual Work Items
**Rationale:** Core entity with most complex relationships.

Key fields:
- `epic_id`: Foreign key to parent epic
- `task_number`: Sequential within epic (001, 002, etc.)
- `parallel`: Boolean flag for parallel execution
- `github_issue_number`: Assigned during sync
- `estimated_hours`, `actual_hours`: Time tracking

**Unique constraints:**
- `(epic_id, task_number)`: Each number unique per epic
- `(epic_id, github_issue_number)`: Each GitHub issue unique per epic

### Relationship Tables

#### **task_dependencies** - Dependency Graph
**Rationale:** Junction table for many-to-many relationships.

Design:
- Self-referential relationship (task depends on task)
- Unique constraint prevents duplicate dependencies
- Check constraint prevents self-dependency
- No circular dependency validation (handled by query)

**Why junction table vs JSON?**
- Enforces referential integrity (can't depend on non-existent task)
- Enables efficient graph queries
- Supports dependency chain resolution with recursive CTEs

#### **task_conflicts** - File Conflicts
**Rationale:** Similar to dependencies but different semantics.

Design:
- Conflicts are bidirectional (if A conflicts with B, B conflicts with A)
- Optional `conflict_type` and `description` for details
- Used for parallel work coordination

**Future enhancement:**
- Could auto-populate from `file_modifications` table

### Progress Tracking Tables

#### **progress_updates** - Current Progress State
**Rationale:** One-to-one with tasks, tracks current state.

Design:
- Single record per task (latest state)
- `completion_percent`: 0-100% progress
- `started_at`: When work began (NULL if not started)
- `last_sync_at`: Last GitHub sync

#### **progress_entries** - Audit Trail
**Rationale:** Time-series log of progress events.

Design:
- Multiple entries per task over time
- `entry_type`: Categorizes entries (note, commit, blocker, milestone)
- Chronological audit trail

**Why separate tables?**
- `progress_updates` optimized for queries (current state)
- `progress_entries` for history (append-only log)

#### **work_streams** - Parallel Execution
**Rationale:** Supports parallel work on single task.

Design:
- Multiple streams per task
- Each stream has own status, scope, file patterns
- Tracks which agent is working on stream

**Use case:**
- Task 123 has 3 streams: database, api, frontend
- Each stream progresses independently
- Overall task complete when all streams done

### Analysis & Metadata Tables

#### **issue_analyses** - Task Analysis Results
**Rationale:** Caches LLM analysis to avoid re-running.

Design:
- One analysis per task
- Stores estimated hours, parallelization factor
- Complexity and risk assessments
- Full analysis content (markdown)

**Why cache?**
- Expensive LLM operation
- Results used for planning
- Can be regenerated if needed

#### **file_modifications** - File Change Tracking
**Rationale:** Enables deterministic conflict detection.

Design:
- Tracks which files each task/stream modifies
- Used to detect overlapping file changes
- Auto-generate task conflicts from file overlaps

**Future enhancement:**
- Populated by git diff analysis
- Used to auto-populate `task_conflicts` table

### GitHub Sync Tables

#### **sync_metadata** - Sync State Tracking
**Rationale:** Critical for bidirectional sync and conflict detection.

Design:
- One record per entity (prd/epic/task)
- Tracks local vs GitHub update timestamps
- Sync status: synced, pending, conflict, error
- Conflict resolution tracking

**Conflict detection algorithm:**
```
IF local_updated_at > last_sync_at AND github_updated_at > last_sync_at:
    STATUS = 'conflict'
ELSE IF local_updated_at > last_sync_at:
    STATUS = 'pending' (need to push)
ELSE IF github_updated_at > last_sync_at:
    STATUS = 'pending' (need to pull)
ELSE:
    STATUS = 'synced'
```

#### **github_labels** - Label Tracking
**Rationale:** GitHub uses labels for organization (epic:name, task, etc.).

Design:
- Many-to-many between entities and labels
- Tracks which labels applied to which entities
- Synced bidirectionally with GitHub

#### **github_comments** - Comment Cache
**Rationale:** Avoid repeated API calls for comment history.

Design:
- Caches GitHub comments locally
- Includes author, body, timestamps
- Synced on demand (not every sync)

## Views (Computed Queries)

### **tasks_with_dependencies**
- Joins tasks with their dependencies
- Returns comma-separated list of dependency IDs and task numbers
- Used by UI to display dependency chains

### **tasks_with_conflicts**
- Similar to dependencies but for conflicts
- Shows which tasks conflict with each other

### **epic_progress**
- Calculates epic progress from task statuses
- Compares calculated vs reported progress
- Shows breakdown: total, closed, in-progress, open

### **ready_tasks**
- Tasks with status='open' and no unmet dependencies
- Critical query for "what can I work on next?"
- Used by `/pm:next` command

### **blocked_tasks**
- Tasks that can't start yet (unmet dependencies)
- Shows which tasks are blocking
- Helps identify bottlenecks

### **sync_status_overview**
- Summary of sync state by entity type
- How many PRDs/epics/tasks pending sync?
- Quick health check

## Indexes

### Strategy
- Index foreign keys for join performance
- Index status fields for filtering
- Index unique identifiers (name, github_issue_number)
- Partial indexes (WHERE deleted_at IS NULL) for active records

### Key Indexes
- `idx_tasks_epic_id`: Fast task lookup by epic
- `idx_tasks_status`: Filter tasks by status
- `idx_task_deps_task_id`: Dependency resolution
- `idx_epics_github_issue`: Sync by GitHub issue number

## Triggers

### **update_epic_progress_on_task_update**
- Automatically recalculates epic progress when task status changes
- Keeps `epics.progress` in sync with actual task completion

### **update_epic_on_task_create**
- Updates epic's `updated_at` timestamp when tasks added
- Maintains accurate modification tracking

### **update_sync_on_*_update**
- Marks entity as 'pending' sync when modified locally
- Creates/updates sync_metadata record
- Ensures changes propagate to GitHub on next sync

## Migration Strategy

### From Markdown Files to Database

**Step 1: Parse Frontmatter**
- Read all `.md` files in `.claude/prds/`, `.claude/epics/`
- Extract frontmatter using regex: `/^---\n(.*?)\n---/s`
- Parse YAML into key-value pairs

**Step 2: Insert Core Entities**
```sql
-- Parse and insert PRDs
INSERT INTO prds (name, description, status, created_at, updated_at, content)
SELECT ... FROM parsed_frontmatter;

-- Parse and insert Epics
INSERT INTO epics (name, prd_id, status, progress, ...)
SELECT ... FROM parsed_frontmatter;

-- Parse and insert Tasks
INSERT INTO tasks (epic_id, name, task_number, status, ...)
SELECT ... FROM parsed_frontmatter;
```

**Step 3: Resolve Dependencies**
```sql
-- Parse depends_on arrays [001, 002, 003]
-- Resolve task numbers to task IDs
INSERT INTO task_dependencies (task_id, depends_on_task_id)
SELECT task.id, dep_task.id
FROM parsed_dependencies pd
JOIN tasks task ON pd.task_number = task.task_number
JOIN tasks dep_task ON pd.depends_on_number = dep_task.task_number;
```

**Step 4: Validate**
- Check all foreign keys resolved
- Verify no circular dependencies
- Validate calculated progress matches frontmatter

**Step 5: Backup**
- Create `.claude/backups/YYYY-MM-DD/` directory
- Copy all original markdown files
- Store migration log

## Query Patterns

### Get Next Available Task
```sql
SELECT * FROM ready_tasks
WHERE epic_id = ?
ORDER BY task_number
LIMIT 1;
```

### Calculate Epic Progress
```sql
SELECT
    COUNT(*) as total_tasks,
    SUM(CASE WHEN status = 'closed' THEN 1 ELSE 0 END) as closed_tasks,
    CAST(SUM(CASE WHEN status = 'closed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS INTEGER) as progress
FROM tasks
WHERE epic_id = ? AND deleted_at IS NULL;
```

### Find Circular Dependencies
```sql
WITH RECURSIVE dep_cycle AS (
    SELECT task_id, depends_on_task_id, task_id as start_task, 1 as depth
    FROM task_dependencies
    UNION ALL
    SELECT td.task_id, td.depends_on_task_id, dc.start_task, dc.depth + 1
    FROM task_dependencies td
    JOIN dep_cycle dc ON td.task_id = dc.depends_on_task_id
    WHERE dc.depth < 20 AND td.depends_on_task_id != dc.start_task
)
SELECT DISTINCT start_task, task_id, depends_on_task_id
FROM dep_cycle
WHERE depends_on_task_id = start_task;
```

### Detect File Conflicts
```sql
SELECT
    t1.name as task1, t2.name as task2,
    fm1.file_path as conflicting_file
FROM file_modifications fm1
JOIN file_modifications fm2
    ON fm1.file_path = fm2.file_path
    AND fm1.task_id < fm2.task_id  -- Avoid duplicates
JOIN tasks t1 ON fm1.task_id = t1.id
JOIN tasks t2 ON fm2.task_id = t2.id
WHERE t1.epic_id = ?
GROUP BY t1.id, t2.id, fm1.file_path;
```

### Sync Status Check
```sql
SELECT
    entity_type,
    COUNT(*) as total,
    SUM(CASE WHEN sync_status = 'synced' THEN 1 ELSE 0 END) as synced,
    SUM(CASE WHEN sync_status = 'pending' THEN 1 ELSE 0 END) as pending,
    SUM(CASE WHEN sync_status = 'conflict' THEN 1 ELSE 0 END) as conflicts
FROM sync_metadata
GROUP BY entity_type;
```

## Performance Considerations

### Fast Queries (< 1ms)
- Status lookups by ID
- Epic/task counts
- Progress calculation for single epic

### Medium Queries (1-10ms)
- Dependency resolution (single task)
- Conflict detection (single epic)
- Ready tasks query

### Slow Queries (10-100ms)
- Full dependency graph for large epic
- Circular dependency detection
- Cross-epic file conflict analysis

### Optimization Strategies
1. **Limit result sets**: Use LIMIT for pagination
2. **Filter early**: WHERE clauses on indexed columns
3. **Avoid N+1**: Use JOINs instead of multiple queries
4. **Cache views**: Materialize expensive views if needed
5. **Batch operations**: Single transaction for multiple updates

## DuckDB-Specific Features

### Why DuckDB?
- Full SQL support (better aggregations than SQLite)
- Native JSON support (can query JSON fields)
- Better analytics performance
- Still file-based (no server)
- Excellent CLI for debugging

### JSON Support Example
```sql
-- If we stored depends_on as JSON array instead of junction table:
SELECT
    id,
    name,
    json_extract(depends_on, '$[*]') as dependencies
FROM tasks
WHERE json_array_length(depends_on) > 0;
```

### Aggregation Example
```sql
-- Window functions for task ordering:
SELECT
    task_number,
    name,
    status,
    ROW_NUMBER() OVER (PARTITION BY epic_id ORDER BY task_number) as sequence
FROM tasks
WHERE epic_id = ?;
```

## Future Enhancements

### Phase 2: Auto-populate Conflicts
- Run git diff analysis on each task
- Parse modified files into `file_modifications` table
- Auto-generate `task_conflicts` from file overlaps

### Phase 3: Time Tracking
- Add `time_entries` table (start_time, end_time, duration)
- Aggregate to calculate `actual_hours` in tasks
- Compare estimated vs actual for better planning

### Phase 4: Workflow States
- Add `workflow_states` table (custom statuses per project)
- Support custom transitions (e.g., 'in-review', 'testing')
- Validation rules for state transitions

### Phase 5: Full-Text Search
- Add FTS5 virtual tables for content search
- Search across PRDs, epics, tasks
- Faster than grep for large projects

## Appendix: SQL Standards

### Date/Time Format
- Always use ISO 8601: `YYYY-MM-DDTHH:MM:SSZ`
- Store in UTC
- Convert to local for display

### Boolean Values
- SQLite uses INTEGER: 0 = false, 1 = true
- Use CHECK constraints where needed
- Consider NULL as distinct from false

### Soft Deletes
- Use `deleted_at` timestamp (NULL = active)
- Add `WHERE deleted_at IS NULL` to queries
- Partial indexes exclude deleted records
- Hard delete only when necessary (GDPR, etc.)

### Transactions
- Wrap multiple updates in BEGIN/COMMIT
- Use ROLLBACK on error
- Savepoints for nested transactions
