-- CCPM Database Schema
-- SQLite 3.x compatible, DuckDB optimized
-- Version: 1.0.0

-- =============================================================================
-- CORE ENTITIES
-- =============================================================================

-- PRDs (Product Requirements Documents)
-- Maps to: .claude/prds/{name}.md
CREATE TABLE prds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,                    -- kebab-case feature name (e.g., 'user-auth')
    description TEXT NOT NULL,                     -- One-line summary
    status TEXT NOT NULL CHECK(status IN ('backlog', 'in-progress', 'complete')),
    created_at TEXT NOT NULL,                      -- ISO 8601: YYYY-MM-DDTHH:MM:SSZ
    updated_at TEXT NOT NULL,                      -- ISO 8601: YYYY-MM-DDTHH:MM:SSZ
    content TEXT,                                  -- Full markdown content (without frontmatter)

    -- Metadata
    created_by TEXT,                               -- Optional: track who created
    deleted_at TEXT,                               -- Soft delete timestamp

    -- Indexes
    CONSTRAINT prd_name_lowercase CHECK(name = lower(name))
);

-- Epics (Technical Implementation Plans)
-- Maps to: .claude/epics/{name}/epic.md
CREATE TABLE epics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,                    -- kebab-case epic name
    prd_id INTEGER NOT NULL,                      -- Reference to parent PRD
    status TEXT NOT NULL CHECK(status IN ('backlog', 'in-progress', 'completed')),
    progress INTEGER DEFAULT 0 CHECK(progress >= 0 AND progress <= 100), -- 0-100%
    created_at TEXT NOT NULL,                      -- ISO 8601
    updated_at TEXT NOT NULL,                      -- ISO 8601
    content TEXT,                                  -- Full markdown content

    -- GitHub Integration
    github_issue_number INTEGER,                   -- GitHub issue # (NULL before sync)
    github_url TEXT,                               -- Full GitHub URL
    github_synced_at TEXT,                         -- Last sync timestamp

    -- Metadata
    estimated_hours REAL,                          -- Total estimated effort
    actual_hours REAL,                             -- Actual time spent
    deleted_at TEXT,                               -- Soft delete

    FOREIGN KEY (prd_id) REFERENCES prds(id) ON DELETE CASCADE
);

-- Tasks (Individual Work Items)
-- Maps to: .claude/epics/{epic_name}/{task_number}.md
CREATE TABLE tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    epic_id INTEGER NOT NULL,                     -- Reference to parent epic
    name TEXT NOT NULL,                            -- Task title
    task_number INTEGER NOT NULL,                  -- Sequential number within epic (001, 002, etc.)
    status TEXT NOT NULL CHECK(status IN ('open', 'in-progress', 'closed')),
    parallel BOOLEAN DEFAULT 1,                    -- Can run in parallel? (1=true, 0=false)
    created_at TEXT NOT NULL,                      -- ISO 8601
    updated_at TEXT NOT NULL,                      -- ISO 8601
    content TEXT,                                  -- Full markdown content

    -- GitHub Integration
    github_issue_number INTEGER,                   -- GitHub issue # (NULL before sync)
    github_url TEXT,                               -- Full GitHub URL
    github_synced_at TEXT,                         -- Last sync timestamp
    github_state TEXT CHECK(github_state IN ('OPEN', 'CLOSED', NULL)),

    -- Work Estimates
    size TEXT CHECK(size IN ('XS', 'S', 'M', 'L', 'XL', NULL)),
    estimated_hours REAL,
    actual_hours REAL,

    -- Metadata
    imported BOOLEAN DEFAULT 0,                    -- Was imported from GitHub?
    deleted_at TEXT,                               -- Soft delete

    FOREIGN KEY (epic_id) REFERENCES epics(id) ON DELETE CASCADE,
    UNIQUE(epic_id, task_number),                  -- Each task number unique within epic
    UNIQUE(epic_id, github_issue_number)           -- Each GitHub issue unique within epic
);

-- =============================================================================
-- RELATIONSHIPS & DEPENDENCIES
-- =============================================================================

-- Task Dependencies (depends_on)
-- Represents: Task X depends on Task Y completing first
CREATE TABLE task_dependencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,                     -- Task that has the dependency
    depends_on_task_id INTEGER NOT NULL,          -- Task that must complete first
    created_at TEXT NOT NULL,                      -- When dependency was added

    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
    FOREIGN KEY (depends_on_task_id) REFERENCES tasks(id) ON DELETE CASCADE,
    UNIQUE(task_id, depends_on_task_id),          -- Prevent duplicate dependencies
    CHECK(task_id != depends_on_task_id)          -- Prevent self-dependency
);

-- Task Conflicts (conflicts_with)
-- Represents: Task X modifies same files as Task Y
CREATE TABLE task_conflicts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,                     -- First task
    conflicts_with_task_id INTEGER NOT NULL,      -- Conflicting task
    conflict_type TEXT,                           -- e.g., 'file', 'database', 'api'
    description TEXT,                              -- What files/resources conflict
    created_at TEXT NOT NULL,

    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
    FOREIGN KEY (conflicts_with_task_id) REFERENCES tasks(id) ON DELETE CASCADE,
    UNIQUE(task_id, conflicts_with_task_id),
    CHECK(task_id != conflicts_with_task_id)
);

-- =============================================================================
-- PROGRESS TRACKING
-- =============================================================================

-- Progress Updates
-- Maps to: .claude/epics/{epic}/updates/{issue}/progress.md
CREATE TABLE progress_updates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    completion_percent INTEGER DEFAULT 0 CHECK(completion_percent >= 0 AND completion_percent <= 100),
    started_at TEXT,                               -- When work started
    last_sync_at TEXT,                             -- Last sync to GitHub
    notes TEXT,                                    -- Progress notes
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,

    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

-- Progress Notes/Updates (audit trail)
-- Stores individual progress entries over time
CREATE TABLE progress_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    entry_type TEXT CHECK(entry_type IN ('note', 'commit', 'blocker', 'milestone')),
    content TEXT NOT NULL,
    created_at TEXT NOT NULL,

    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

-- Work Streams (for parallel execution)
-- Maps to: .claude/epics/{epic}/updates/{issue}/stream-{X}.md
CREATE TABLE work_streams (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    stream_name TEXT NOT NULL,                    -- e.g., 'database', 'api', 'frontend'
    agent_type TEXT,                              -- Agent type assigned (e.g., 'general-purpose')
    status TEXT CHECK(status IN ('pending', 'in_progress', 'completed', 'blocked')),
    scope TEXT,                                   -- Scope definition for this stream
    file_patterns TEXT,                           -- File patterns assigned (JSON array)
    started_at TEXT,
    completed_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,

    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
    UNIQUE(task_id, stream_name)
);

-- =============================================================================
-- ANALYSIS & METADATA
-- =============================================================================

-- Issue Analysis
-- Maps to: .claude/epics/{epic}/updates/{issue}/{issue}-analysis.md
CREATE TABLE issue_analyses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    analyzed_at TEXT NOT NULL,
    estimated_hours REAL,
    parallelization_factor REAL CHECK(parallelization_factor >= 1.0 AND parallelization_factor <= 5.0),
    complexity TEXT CHECK(complexity IN ('low', 'medium', 'high', NULL)),
    risk_level TEXT CHECK(risk_level IN ('low', 'medium', 'high', NULL)),
    analysis_content TEXT,                        -- Full analysis markdown

    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

-- File Modifications (for conflict detection)
CREATE TABLE file_modifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER,
    work_stream_id INTEGER,                       -- Optional: associate with stream
    file_path TEXT NOT NULL,
    modification_type TEXT CHECK(modification_type IN ('create', 'update', 'delete')),
    created_at TEXT NOT NULL,

    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
    FOREIGN KEY (work_stream_id) REFERENCES work_streams(id) ON DELETE CASCADE
);

-- =============================================================================
-- GITHUB SYNC METADATA
-- =============================================================================

-- Sync State (track what's been synced)
CREATE TABLE sync_metadata (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL CHECK(entity_type IN ('prd', 'epic', 'task')),
    entity_id INTEGER NOT NULL,                   -- ID in respective table
    local_updated_at TEXT NOT NULL,               -- Last local modification
    github_updated_at TEXT,                       -- Last GitHub modification
    last_sync_at TEXT,                            -- Last successful sync
    sync_status TEXT CHECK(sync_status IN ('synced', 'pending', 'conflict', 'error')),
    conflict_resolution TEXT,                     -- How conflict was resolved
    error_message TEXT,                           -- Last sync error
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,

    UNIQUE(entity_type, entity_id)
);

-- GitHub Labels (for filtering and organization)
CREATE TABLE github_labels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL CHECK(entity_type IN ('epic', 'task')),
    entity_id INTEGER NOT NULL,
    label TEXT NOT NULL,
    created_at TEXT NOT NULL,

    UNIQUE(entity_type, entity_id, label)
);

-- GitHub Comments (cache for performance)
CREATE TABLE github_comments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    github_issue_number INTEGER NOT NULL,
    comment_id INTEGER,                           -- GitHub comment ID
    author TEXT,
    body TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

-- =============================================================================
-- VIEWS (Computed/Convenience Queries)
-- =============================================================================

-- Tasks with resolved dependencies
CREATE VIEW tasks_with_dependencies AS
SELECT
    t.id,
    t.epic_id,
    t.name,
    t.task_number,
    t.status,
    t.parallel,
    t.github_issue_number,
    GROUP_CONCAT(td.depends_on_task_id) AS depends_on_task_ids,
    GROUP_CONCAT(dep_task.task_number) AS depends_on_task_numbers
FROM tasks t
LEFT JOIN task_dependencies td ON t.id = td.task_id
LEFT JOIN tasks dep_task ON td.depends_on_task_id = dep_task.id
WHERE t.deleted_at IS NULL
GROUP BY t.id;

-- Tasks with conflicts
CREATE VIEW tasks_with_conflicts AS
SELECT
    t.id,
    t.epic_id,
    t.name,
    t.task_number,
    GROUP_CONCAT(tc.conflicts_with_task_id) AS conflicts_with_task_ids,
    GROUP_CONCAT(conf_task.task_number) AS conflicts_with_task_numbers
FROM tasks t
LEFT JOIN task_conflicts tc ON t.id = tc.task_id
LEFT JOIN tasks conf_task ON tc.conflicts_with_task_id = conf_task.id
WHERE t.deleted_at IS NULL
GROUP BY t.id;

-- Epic progress summary
CREATE VIEW epic_progress AS
SELECT
    e.id,
    e.name,
    e.status,
    COUNT(t.id) AS total_tasks,
    SUM(CASE WHEN t.status = 'closed' THEN 1 ELSE 0 END) AS closed_tasks,
    SUM(CASE WHEN t.status = 'in-progress' THEN 1 ELSE 0 END) AS in_progress_tasks,
    SUM(CASE WHEN t.status = 'open' THEN 1 ELSE 0 END) AS open_tasks,
    CAST(SUM(CASE WHEN t.status = 'closed' THEN 1 ELSE 0 END) * 100.0 / COUNT(t.id) AS INTEGER) AS calculated_progress,
    e.progress AS reported_progress
FROM epics e
LEFT JOIN tasks t ON e.id = t.epic_id AND t.deleted_at IS NULL
WHERE e.deleted_at IS NULL
GROUP BY e.id;

-- Ready tasks (no unmet dependencies)
CREATE VIEW ready_tasks AS
SELECT
    t.id,
    t.epic_id,
    t.name,
    t.task_number,
    t.status,
    t.parallel
FROM tasks t
WHERE t.status = 'open'
  AND t.deleted_at IS NULL
  AND NOT EXISTS (
    SELECT 1
    FROM task_dependencies td
    JOIN tasks dep ON td.depends_on_task_id = dep.id
    WHERE td.task_id = t.id
      AND dep.status != 'closed'
  );

-- Blocked tasks (has unmet dependencies)
CREATE VIEW blocked_tasks AS
SELECT
    t.id,
    t.epic_id,
    t.name,
    t.task_number,
    t.status,
    GROUP_CONCAT(dep.task_number || ':' || dep.status) AS blocking_tasks
FROM tasks t
JOIN task_dependencies td ON t.id = td.task_id
JOIN tasks dep ON td.depends_on_task_id = dep.id
WHERE t.status = 'open'
  AND dep.status != 'closed'
  AND t.deleted_at IS NULL
GROUP BY t.id;

-- Sync status overview
CREATE VIEW sync_status_overview AS
SELECT
    entity_type,
    sync_status,
    COUNT(*) AS count
FROM sync_metadata
GROUP BY entity_type, sync_status;

-- =============================================================================
-- INDEXES (Performance Optimization)
-- =============================================================================

-- PRDs
CREATE INDEX idx_prds_status ON prds(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_prds_name ON prds(name) WHERE deleted_at IS NULL;

-- Epics
CREATE INDEX idx_epics_prd_id ON epics(prd_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_epics_status ON epics(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_epics_github_issue ON epics(github_issue_number) WHERE github_issue_number IS NOT NULL;
CREATE INDEX idx_epics_name ON epics(name) WHERE deleted_at IS NULL;

-- Tasks
CREATE INDEX idx_tasks_epic_id ON tasks(epic_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_tasks_status ON tasks(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_tasks_github_issue ON tasks(github_issue_number) WHERE github_issue_number IS NOT NULL;
CREATE INDEX idx_tasks_task_number ON tasks(epic_id, task_number) WHERE deleted_at IS NULL;

-- Dependencies & Conflicts
CREATE INDEX idx_task_deps_task_id ON task_dependencies(task_id);
CREATE INDEX idx_task_deps_depends_on ON task_dependencies(depends_on_task_id);
CREATE INDEX idx_task_conflicts_task_id ON task_conflicts(task_id);

-- Progress
CREATE INDEX idx_progress_task_id ON progress_updates(task_id);
CREATE INDEX idx_progress_entries_task_id ON progress_entries(task_id);
CREATE INDEX idx_work_streams_task_id ON work_streams(task_id);
CREATE INDEX idx_work_streams_status ON work_streams(status);

-- Sync Metadata
CREATE INDEX idx_sync_entity ON sync_metadata(entity_type, entity_id);
CREATE INDEX idx_sync_status ON sync_metadata(sync_status);

-- File Modifications
CREATE INDEX idx_file_mods_task_id ON file_modifications(task_id);
CREATE INDEX idx_file_mods_file_path ON file_modifications(file_path);

-- GitHub
CREATE INDEX idx_github_labels_entity ON github_labels(entity_type, entity_id);
CREATE INDEX idx_github_comments_issue ON github_comments(github_issue_number);

-- =============================================================================
-- TRIGGERS (Automatic Updates)
-- =============================================================================

-- Auto-update epic progress when tasks change
CREATE TRIGGER update_epic_progress_on_task_update
AFTER UPDATE OF status ON tasks
BEGIN
    UPDATE epics
    SET
        progress = (
            SELECT CAST(SUM(CASE WHEN status = 'closed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS INTEGER)
            FROM tasks
            WHERE epic_id = NEW.epic_id AND deleted_at IS NULL
        ),
        updated_at = datetime('now')
    WHERE id = NEW.epic_id;
END;

-- Update epic updated_at when tasks are created/deleted
CREATE TRIGGER update_epic_on_task_create
AFTER INSERT ON tasks
BEGIN
    UPDATE epics
    SET updated_at = datetime('now')
    WHERE id = NEW.epic_id;
END;

-- Update sync metadata on entity updates
CREATE TRIGGER update_sync_on_prd_update
AFTER UPDATE ON prds
BEGIN
    INSERT INTO sync_metadata (entity_type, entity_id, local_updated_at, sync_status, created_at, updated_at)
    VALUES ('prd', NEW.id, NEW.updated_at, 'pending', datetime('now'), datetime('now'))
    ON CONFLICT(entity_type, entity_id) DO UPDATE SET
        local_updated_at = NEW.updated_at,
        sync_status = 'pending',
        updated_at = datetime('now');
END;

CREATE TRIGGER update_sync_on_epic_update
AFTER UPDATE ON epics
BEGIN
    INSERT INTO sync_metadata (entity_type, entity_id, local_updated_at, sync_status, created_at, updated_at)
    VALUES ('epic', NEW.id, NEW.updated_at, 'pending', datetime('now'), datetime('now'))
    ON CONFLICT(entity_type, entity_id) DO UPDATE SET
        local_updated_at = NEW.updated_at,
        sync_status = 'pending',
        updated_at = datetime('now');
END;

CREATE TRIGGER update_sync_on_task_update
AFTER UPDATE ON tasks
BEGIN
    INSERT INTO sync_metadata (entity_type, entity_id, local_updated_at, sync_status, created_at, updated_at)
    VALUES ('task', NEW.id, NEW.updated_at, 'pending', datetime('now'), datetime('now'))
    ON CONFLICT(entity_type, entity_id) DO UPDATE SET
        local_updated_at = NEW.updated_at,
        sync_status = 'pending',
        updated_at = datetime('now');
END;

-- =============================================================================
-- FUNCTIONS / STORED QUERIES (Comments for DuckDB UDFs)
-- =============================================================================

-- Query: Get all ready tasks for an epic
-- SELECT * FROM ready_tasks WHERE epic_id = ?;

-- Query: Get dependency chain for a task
-- WITH RECURSIVE dep_chain AS (
--   SELECT task_id, depends_on_task_id, 1 as depth
--   FROM task_dependencies
--   WHERE task_id = ?
--   UNION ALL
--   SELECT td.task_id, td.depends_on_task_id, dc.depth + 1
--   FROM task_dependencies td
--   JOIN dep_chain dc ON td.task_id = dc.depends_on_task_id
--   WHERE dc.depth < 10
-- )
-- SELECT t.* FROM dep_chain dc
-- JOIN tasks t ON dc.depends_on_task_id = t.id;

-- Query: Detect circular dependencies
-- WITH RECURSIVE dep_cycle AS (
--   SELECT task_id, depends_on_task_id, task_id as start_task, 1 as depth
--   FROM task_dependencies
--   UNION ALL
--   SELECT td.task_id, td.depends_on_task_id, dc.start_task, dc.depth + 1
--   FROM task_dependencies td
--   JOIN dep_cycle dc ON td.task_id = dc.depends_on_task_id
--   WHERE dc.depth < 20 AND td.depends_on_task_id != dc.start_task
-- )
-- SELECT DISTINCT start_task, task_id, depends_on_task_id
-- FROM dep_cycle
-- WHERE depends_on_task_id = start_task;

-- Query: Get file conflicts between tasks
-- SELECT
--   t1.id as task1_id, t1.name as task1_name,
--   t2.id as task2_id, t2.name as task2_name,
--   fm1.file_path
-- FROM file_modifications fm1
-- JOIN file_modifications fm2 ON fm1.file_path = fm2.file_path AND fm1.task_id != fm2.task_id
-- JOIN tasks t1 ON fm1.task_id = t1.id
-- JOIN tasks t2 ON fm2.task_id = t2.id
-- WHERE t1.epic_id = ? AND t2.epic_id = ?
-- GROUP BY t1.id, t2.id, fm1.file_path;
