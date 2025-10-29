-- Test Data for CCPM Database
-- Creates sample PRDs, Epics, and Tasks with dependencies

-- =============================================================================
-- PRDs
-- =============================================================================

INSERT INTO prds (name, description, status, created_at, updated_at, content) VALUES
('user-authentication', 'Add OAuth and SSO authentication system', 'in-progress', '2025-01-15T10:00:00Z', '2025-01-20T14:30:00Z',
'# PRD: User Authentication

## Executive Summary
Implement modern authentication system with OAuth2 and SSO support.

## Problem Statement
Current basic auth is insecure and lacks enterprise features.'),

('payment-processing', 'Integrate payment gateway with multi-currency support', 'backlog', '2025-01-18T09:00:00Z', '2025-01-18T09:00:00Z',
'# PRD: Payment Processing

## Executive Summary
Add payment processing with Stripe integration.

## Problem Statement
Need to monetize platform with subscription payments.'),

('notification-system', 'Real-time notification system with email and push', 'complete', '2025-01-10T08:00:00Z', '2025-01-25T16:00:00Z',
'# PRD: Notification System

## Executive Summary
Multi-channel notification delivery system.

## Problem Statement
Users miss important updates without notifications.');

-- =============================================================================
-- Epics
-- =============================================================================

INSERT INTO epics (name, prd_id, status, progress, created_at, updated_at, content, github_issue_number, github_url) VALUES
('user-auth-backend', 1, 'in-progress', 60, '2025-01-15T11:00:00Z', '2025-01-22T10:00:00Z',
'# Epic: User Authentication Backend

## Technical Approach
Implement OAuth2 server with JWT tokens and refresh token rotation.

## Architecture
- PostgreSQL for user storage
- Redis for session management
- Auth middleware for API protection',
123, 'https://github.com/user/repo/issues/123'),

('user-auth-frontend', 1, 'backlog', 0, '2025-01-15T11:30:00Z', '2025-01-15T11:30:00Z',
'# Epic: User Authentication Frontend

## Technical Approach
React components for login, registration, and OAuth flows.

## Architecture
- React context for auth state
- Protected route components
- Token refresh handling',
NULL, NULL),

('payment-integration', 2, 'backlog', 0, '2025-01-18T10:00:00Z', '2025-01-18T10:00:00Z',
'# Epic: Payment Integration

## Technical Approach
Stripe integration with webhook handling for payment events.

## Architecture
- Stripe API client
- Webhook endpoint for events
- Subscription management',
NULL, NULL);

-- =============================================================================
-- Tasks for user-auth-backend epic
-- =============================================================================

INSERT INTO tasks (epic_id, name, task_number, status, parallel, created_at, updated_at, content, github_issue_number, github_url, size, estimated_hours) VALUES
-- Epic 1: user-auth-backend
(1, 'Setup OAuth2 database schema', 1, 'closed', 1, '2025-01-15T12:00:00Z', '2025-01-20T15:00:00Z',
'# Task: Setup OAuth2 Database Schema

## Description
Create PostgreSQL tables for users, sessions, and OAuth clients.

## Acceptance Criteria
- [ ] Users table with email, password hash
- [ ] Sessions table with tokens and expiry
- [ ] OAuth clients table
- [ ] Migrations tested',
1234, 'https://github.com/user/repo/issues/1234', 'M', 4),

(1, 'Implement JWT token generation', 2, 'closed', 1, '2025-01-16T09:00:00Z', '2025-01-21T11:00:00Z',
'# Task: Implement JWT Token Generation

## Description
Create service for generating and validating JWT access tokens.

## Acceptance Criteria
- [ ] Generate JWT with user claims
- [ ] Validate JWT signature
- [ ] Handle token expiry
- [ ] Unit tests',
1235, 'https://github.com/user/repo/issues/1235', 'S', 3),

(1, 'Build refresh token rotation', 3, 'closed', 0, '2025-01-17T10:00:00Z', '2025-01-22T09:00:00Z',
'# Task: Build Refresh Token Rotation

## Description
Implement secure refresh token rotation mechanism.

## Acceptance Criteria
- [ ] Generate refresh tokens
- [ ] Rotate on use
- [ ] Detect reuse attacks
- [ ] Integration tests',
1236, 'https://github.com/user/repo/issues/1236', 'M', 5),

(1, 'Create OAuth2 authorization endpoint', 4, 'in-progress', 0, '2025-01-18T11:00:00Z', '2025-01-22T10:00:00Z',
'# Task: Create OAuth2 Authorization Endpoint

## Description
Implement /oauth/authorize endpoint with consent flow.

## Acceptance Criteria
- [ ] Parse authorization request
- [ ] Display consent UI
- [ ] Generate authorization code
- [ ] Redirect with code',
1237, 'https://github.com/user/repo/issues/1237', 'L', 6),

(1, 'Implement OAuth2 token endpoint', 5, 'open', 0, '2025-01-19T09:00:00Z', '2025-01-19T09:00:00Z',
'# Task: Implement OAuth2 Token Endpoint

## Description
Create /oauth/token endpoint for exchanging codes for tokens.

## Acceptance Criteria
- [ ] Validate authorization code
- [ ] Exchange for access + refresh token
- [ ] Return token response
- [ ] Handle errors',
1238, 'https://github.com/user/repo/issues/1238', 'M', 4),

-- Epic 2: user-auth-frontend (no tasks yet)

-- Epic 3: payment-integration
(3, 'Setup Stripe SDK integration', 1, 'open', 1, '2025-01-18T11:00:00Z', '2025-01-18T11:00:00Z',
'# Task: Setup Stripe SDK

## Description
Install and configure Stripe SDK with API keys.

## Acceptance Criteria
- [ ] Install stripe package
- [ ] Configure API keys
- [ ] Test connection
- [ ] Add to environment config',
NULL, NULL, 'XS', 1);

-- =============================================================================
-- Task Dependencies
-- =============================================================================

-- Task 3 (refresh tokens) depends on Task 2 (JWT generation)
INSERT INTO task_dependencies (task_id, depends_on_task_id, created_at) VALUES
(3, 2, '2025-01-17T10:00:00Z');

-- Task 4 (authorization endpoint) depends on Task 1 (database schema)
INSERT INTO task_dependencies (task_id, depends_on_task_id, created_at) VALUES
(4, 1, '2025-01-18T11:00:00Z');

-- Task 5 (token endpoint) depends on Tasks 3 and 4
INSERT INTO task_dependencies (task_id, depends_on_task_id, created_at) VALUES
(5, 3, '2025-01-19T09:00:00Z'),
(5, 4, '2025-01-19T09:00:00Z');

-- =============================================================================
-- Task Conflicts
-- =============================================================================

-- Tasks 4 and 5 both modify the OAuth controller
INSERT INTO task_conflicts (task_id, conflicts_with_task_id, conflict_type, description, created_at) VALUES
(4, 5, 'file', 'Both modify src/controllers/oauth.js', '2025-01-19T09:00:00Z');

-- =============================================================================
-- Progress Updates
-- =============================================================================

INSERT INTO progress_updates (task_id, completion_percent, started_at, last_sync_at, notes, created_at, updated_at) VALUES
(4, 65, '2025-01-22T08:00:00Z', '2025-01-22T10:00:00Z',
'Authorization endpoint implemented. Working on consent UI.',
'2025-01-22T08:00:00Z', '2025-01-22T10:00:00Z');

-- =============================================================================
-- Progress Entries (Audit Trail)
-- =============================================================================

INSERT INTO progress_entries (task_id, entry_type, content, created_at) VALUES
(4, 'note', 'Started implementation of authorization endpoint', '2025-01-22T08:00:00Z'),
(4, 'commit', 'feat: add OAuth authorization request parsing', '2025-01-22T09:30:00Z'),
(4, 'note', 'Consent UI needs UX review', '2025-01-22T10:00:00Z'),
(1, 'note', 'Database migrations completed and tested', '2025-01-20T14:00:00Z'),
(2, 'commit', 'feat: implement JWT token generation service', '2025-01-21T10:00:00Z'),
(3, 'note', 'Refresh token rotation implemented with reuse detection', '2025-01-22T09:00:00Z');

-- =============================================================================
-- Work Streams (Parallel Execution)
-- =============================================================================

INSERT INTO work_streams (task_id, stream_name, agent_type, status, scope, file_patterns, started_at, created_at, updated_at) VALUES
(4, 'backend-logic', 'general-purpose', 'completed',
'Implement authorization endpoint logic',
'["src/controllers/oauth.js", "src/services/auth.js"]',
'2025-01-22T08:00:00Z', '2025-01-22T08:00:00Z', '2025-01-22T09:30:00Z'),

(4, 'frontend-ui', 'general-purpose', 'in_progress',
'Build consent UI components',
'["src/components/ConsentDialog.jsx", "src/pages/Authorize.jsx"]',
'2025-01-22T09:00:00Z', '2025-01-22T09:00:00Z', '2025-01-22T10:00:00Z');

-- =============================================================================
-- File Modifications (for conflict detection)
-- =============================================================================

INSERT INTO file_modifications (task_id, work_stream_id, file_path, modification_type, created_at) VALUES
-- Task 1 files
(1, NULL, 'migrations/001_create_users_table.sql', 'create', '2025-01-20T14:00:00Z'),
(1, NULL, 'migrations/002_create_sessions_table.sql', 'create', '2025-01-20T14:00:00Z'),

-- Task 2 files
(2, NULL, 'src/services/jwt.js', 'create', '2025-01-21T10:00:00Z'),
(2, NULL, 'src/services/auth.js', 'update', '2025-01-21T11:00:00Z'),

-- Task 3 files
(3, NULL, 'src/services/refresh-token.js', 'create', '2025-01-22T09:00:00Z'),
(3, NULL, 'src/services/auth.js', 'update', '2025-01-22T09:00:00Z'),

-- Task 4 files (via work streams)
(4, 1, 'src/controllers/oauth.js', 'create', '2025-01-22T09:00:00Z'),
(4, 1, 'src/services/auth.js', 'update', '2025-01-22T09:30:00Z'),
(4, 2, 'src/components/ConsentDialog.jsx', 'create', '2025-01-22T10:00:00Z'),

-- Task 5 files (planned)
(5, NULL, 'src/controllers/oauth.js', 'update', '2025-01-19T09:00:00Z');

-- =============================================================================
-- Issue Analysis
-- =============================================================================

INSERT INTO issue_analyses (task_id, analyzed_at, estimated_hours, parallelization_factor, complexity, risk_level, analysis_content) VALUES
(4, '2025-01-18T11:00:00Z', 6, 2.0, 'high', 'medium',
'# Analysis: OAuth2 Authorization Endpoint

## Complexity Assessment
High complexity due to OAuth2 spec compliance requirements.

## Parallelization
Can split into backend logic (2 agents) and frontend UI (1 agent).
Estimated speedup: 2x with parallel execution.

## Risks
- Security vulnerabilities if not implemented correctly
- OAuth2 spec has many edge cases
- Consent UI requires UX considerations');

-- =============================================================================
-- Sync Metadata
-- =============================================================================

-- Note: Triggers auto-create sync_metadata entries when epics/tasks are inserted
-- Here we update them with GitHub sync information

-- Epic 1 synced
UPDATE sync_metadata SET
    github_updated_at = '2025-01-22T10:00:00Z',
    last_sync_at = '2025-01-22T10:00:00Z',
    sync_status = 'synced'
WHERE entity_type = 'epic' AND entity_id = 1;

-- Tasks 1-4 synced (have GitHub issue numbers)
UPDATE sync_metadata SET
    github_updated_at = '2025-01-20T15:00:00Z',
    last_sync_at = '2025-01-20T15:00:00Z',
    sync_status = 'synced'
WHERE entity_type = 'task' AND entity_id = 1;

UPDATE sync_metadata SET
    github_updated_at = '2025-01-21T11:00:00Z',
    last_sync_at = '2025-01-21T11:00:00Z',
    sync_status = 'synced'
WHERE entity_type = 'task' AND entity_id = 2;

UPDATE sync_metadata SET
    github_updated_at = '2025-01-22T09:00:00Z',
    last_sync_at = '2025-01-22T09:00:00Z',
    sync_status = 'synced'
WHERE entity_type = 'task' AND entity_id = 3;

UPDATE sync_metadata SET
    github_updated_at = '2025-01-22T09:30:00Z',
    last_sync_at = '2025-01-22T09:30:00Z',
    sync_status = 'pending'
WHERE entity_type = 'task' AND entity_id = 4;

-- =============================================================================
-- GitHub Labels
-- =============================================================================

INSERT INTO github_labels (entity_type, entity_id, label, created_at) VALUES
('epic', 1, 'epic', '2025-01-22T10:00:00Z'),
('epic', 1, 'epic:user-auth-backend', '2025-01-22T10:00:00Z'),
('epic', 1, 'feature', '2025-01-22T10:00:00Z'),
('task', 1, 'task', '2025-01-20T15:00:00Z'),
('task', 1, 'epic:user-auth-backend', '2025-01-20T15:00:00Z'),
('task', 4, 'task', '2025-01-22T09:30:00Z'),
('task', 4, 'epic:user-auth-backend', '2025-01-22T09:30:00Z'),
('task', 4, 'in-progress', '2025-01-22T09:30:00Z');

-- =============================================================================
-- Summary
-- =============================================================================
-- PRDs: 3 (1 in-progress, 1 backlog, 1 complete)
-- Epics: 3 (1 in-progress, 2 backlog)
-- Tasks: 6 total
--   - Epic 1 (user-auth-backend): 5 tasks
--     - 3 closed, 1 in-progress, 1 open (blocked by dependencies)
--     - Progress: 60% (3/5 closed)
--   - Epic 3 (payment-integration): 1 task (open)
-- Dependencies: 4 relationships
-- Conflicts: 1 (tasks 4 and 5)
