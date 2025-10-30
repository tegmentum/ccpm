# CCPM Concepts and Hierarchy

## Overview

CCPM (Claude Code Project Management) uses a hierarchical structure to organize work from high-level product vision down to individual tasks. Understanding this hierarchy is essential for effective project management.

## The Hierarchy

```
PRD (Product Requirements Document)
  └─ Epic (Technical Implementation)
      └─ Tasks (Individual Work Items)
          └─ GitHub Issues (Optional Sync)
```

## 1. PRD (Product Requirements Document)

**What it is:**
A product-focused document that describes WHAT to build and WHY, from the user's perspective.

**Purpose:**
- Define product vision and user needs
- Capture business requirements
- Document success criteria
- Establish scope and constraints

**Created by:** Product Manager perspective (LLM brainstorming session)

**Contains:**
- Executive Summary
- Problem Statement
- User Stories
- Functional Requirements
- Non-Functional Requirements
- Success Criteria
- Constraints & Assumptions
- Out of Scope
- Dependencies

**Example:**
```markdown
PRD: user-authentication

Problem: Users need secure access to their accounts
User Story: As a user, I want to log in securely...
Requirements: Email/password auth, 2FA, password reset...
Success: 99.9% login success rate, <500ms response time
```

**Commands:**
- `pm prd-new` - Create new PRD (interactive brainstorming)
- `pm prd-edit <name>` - Edit existing PRD
- `pm prd-list` - List all PRDs
- `pm prd-show <name>` - View PRD details
- `pm prd-status` - Show implementation status

**Storage:**
- File: `.claude/prds/{name}.md` (version-controlled markdown)
- Database: Metadata (name, description, status)

---

## 2. Epic (Technical Implementation Plan)

**What it is:**
A technical translation of a PRD that describes HOW to build it, from the engineering perspective.

**Purpose:**
- Break down product requirements into technical tasks
- Define architecture and technical approach
- Identify dependencies and risks
- Estimate effort and timeline

**Created by:** Technical Lead perspective (LLM parsing PRD)

**Contains:**
- Architecture Decisions
- Technical Approach (Frontend, Backend, Infrastructure)
- Implementation Strategy
- Task Breakdown
- Technical Dependencies
- Estimated Effort

**Relationship to PRD:**
- One PRD → One Epic (1:1 relationship)
- Epic references its source PRD
- Special case: `backlog` epic has no PRD (for ad-hoc tasks)

**Example:**
```markdown
Epic: user-authentication (from PRD: user-authentication)

Architecture: JWT tokens, bcrypt hashing, Redis sessions
Technical Approach:
  - Backend: Express middleware, Passport.js
  - Database: Users table with password_hash
  - Frontend: Login form, token storage
Tasks: 10 tasks (database schema, API endpoints, UI, tests...)
```

**Commands:**
- `pm prd-parse <prd-name>` - Create epic from PRD
- `pm epic-decompose <name>` - Break into tasks (AI or manual)
- `pm epic-show <name>` - View epic and tasks
- `pm epic-sync <name>` - Sync to GitHub
- `pm epic-start <name>` - Setup worktree for work
- `pm epic-parallel` - Launch parallel agents
- `pm epic-close <name>` - Mark complete

**Storage:**
- Database: Epic metadata and content
- GitHub: Epic issue (when synced)

---

## 3. Task (Individual Work Item)

**What it is:**
A single, concrete piece of work that can be completed by one person in a reasonable timeframe (hours to days).

**Purpose:**
- Break epic into manageable units
- Track progress and dependencies
- Enable parallel work
- Estimate effort accurately

**Created by:**
- `epic-decompose` - AI breaks epic into tasks
- `task-add` - Manually add task to epic

**Contains:**
- Name (brief description)
- Description (detailed requirements)
- Status (open, in_progress, closed)
- Estimated hours
- Dependencies (other tasks that must complete first)
- Parallel flag (can run simultaneously with other tasks)

**Relationship to Epic:**
- One Epic → Many Tasks (1:N relationship)
- Tasks are numbered sequentially per epic (1, 2, 3...)
- Tasks can depend on other tasks in same epic

**Example:**
```markdown
Task: user-authentication/3 - Create login API endpoint

Description:
  - POST /api/auth/login endpoint
  - Validate email/password
  - Generate JWT token
  - Return user data

Dependencies: Task 1 (database schema), Task 2 (user model)
Estimated: 4 hours
Status: open
```

**Commands:**
- `pm task-add <epic> <name>` - Add task to epic
- `pm task-add <name>` - Add to backlog epic
- `pm task-start <epic> <num>` - Start work on task
- `pm task-close <epic> <num>` - Mark complete
- `pm task-show <epic> <num>` - View details

**Storage:**
- Database: Task details, dependencies, status
- Worktree: Working directory when active

---

## 4. GitHub Issue (Optional External Tracking)

**What it is:**
The GitHub representation of an epic or task, used for external visibility and collaboration.

**Purpose:**
- Make work visible on GitHub
- Enable external collaboration
- Track in GitHub Projects
- Link to pull requests

**Created by:**
- `epic-sync` - Creates epic issue + task sub-issues
- `task-add --sync` - Creates issue immediately
- `import` - Imports existing GitHub issues

**Relationship:**
- One Epic → One GitHub Issue
- One Task → One GitHub Issue (optional)
- Database stores `github_issue_number` for sync

**Example:**
```
GitHub Issue #123: user-authentication (Epic)

Tasks:
- [x] #124 Database schema
- [ ] #125 User model
- [ ] #126 Login API endpoint
...
```

**Commands:**
- `pm epic-sync <name>` - Sync epic + tasks to GitHub
- `pm issue-show <num>` - View issue from database
- `pm issue-close <num>` - Close in DB + GitHub
- `pm issue-sync <num>` - Bidirectional sync
- `pm sync` - Full sync all issues
- `pm import` - Import GitHub issues to DB

**Storage:**
- GitHub: Issue with description, comments, labels
- Database: Linked via `github_issue_number`

---

## Key Differences Summary

| Concept | Perspective | Granularity | Lifespan | Storage |
|---------|------------|-------------|----------|---------|
| **PRD** | Product/User | High-level feature | Weeks-Months | File + DB metadata |
| **Epic** | Technical | Implementation plan | Weeks-Months | Database |
| **Task** | Developer | Single work unit | Hours-Days | Database |
| **Issue** | External | Public tracking | Varies | GitHub (synced) |

## Special Cases

### Backlog Epic

**Purpose:** Container for ad-hoc tasks that don't fit into feature epics.

**Use cases:**
- Bug fixes discovered during development
- Technical debt cleanup
- Documentation improvements
- Dependency updates
- Small improvements

**Created automatically** when you run:
```bash
pm task-add 'Fix validation bug'  # No epic specified
```

**Has a static PRD** in `.claude/prds/backlog.md` (no brainstorming needed).

**Benefits:**
- No ceremony for quick tasks
- Still tracked and queryable
- Can prioritize alongside feature work

---

## Workflow Patterns

### Pattern 1: Full Feature Development (PRD → Epic → Tasks)

**When to use:** Major features with clear product requirements.

```bash
# 1. Product brainstorming
pm prd-new
# Interactive session, assigns name after brainstorming
# Result: .claude/prds/user-auth.md

# 2. Technical planning
pm prd-parse user-auth
# Result: Epic in database with architecture decisions

# 3. Break into tasks
pm epic-decompose user-auth
# Result: 10 tasks with dependencies

# 4. Sync to GitHub
pm epic-sync user-auth
# Result: Epic issue + task sub-issues on GitHub

# 5. Start work
pm epic-start user-auth
# Result: Worktree at ../epic-user-auth

# 6. Work in parallel (optional)
cd ../epic-user-auth
pm epic-parallel
# Result: Multiple agents working on independent tasks

# 7. Or work sequentially
pm task-start user-auth 1
# Work on task...
pm task-close user-auth 1
pm task-start user-auth 2
# ...

# 8. Complete epic
pm epic-close user-auth
```

### Pattern 2: Quick Task (Direct to Backlog)

**When to use:** Bugs, chores, tech debt, small improvements.

```bash
# Add task (no epic needed)
pm task-add 'Fix validation bug in login form'

# Optionally sync to GitHub
pm task-add 'Update dependencies' --sync

# Start work
pm task-start backlog 1

# Complete
pm task-close backlog 1
```

### Pattern 3: Adding Tasks During Development

**When to use:** Discover new work while implementing an epic.

```bash
# While working on epic, discover issue
pm task-add my-epic 'Handle edge case in parser' --estimate 2

# Optionally sync immediately
pm task-add my-epic 'Add error logging' --sync

# Continue working
pm task-start my-epic 8  # The newly added task
```

### Pattern 4: Importing Existing Work

**When to use:** Moving existing GitHub issues into CCPM.

```bash
# Import all issues
pm import

# Import specific epic
pm import --epic auth-system

# Import by label
pm import --label bug

# Result: Issues in database, queryable with pm commands
```

---

## Database vs Files

### What's in Files

**PRDs only:**
- `.claude/prds/{name}.md` - Full markdown document
- Version-controlled, human-editable
- Can reference in PRs and docs

### What's in Database

**Everything:**
- PRDs (metadata: name, description, status)
- Epics (full content and metadata)
- Tasks (all details, dependencies)
- Sync timestamps, GitHub issue numbers

**Why:**
- Fast queries (zero-token operations)
- Dependency tracking
- Progress calculations
- Ready/blocked task views

### Sync to GitHub

**Optional for all entities:**
- Epics → GitHub Issues with "epic" label
- Tasks → GitHub Issues with "task" label
- Epic issue body contains task checklist
- Bidirectional sync maintains consistency

---

## Status Values

### PRD Status
- `backlog` - Not started
- `active` - Being worked on
- `complete` - Finished

### Epic Status
- `backlog` - Not started
- `active` - Work in progress
- `closed` - Complete

### Task Status
- `open` - Ready to start (if no dependencies) or blocked
- `in_progress` - Currently being worked on
- `closed` - Completed

---

## Querying the Hierarchy

### View Everything
```bash
pm status           # Dashboard of all work
pm standup          # Daily status report
```

### By Level
```bash
pm prd-list         # All PRDs
pm epic-list        # All epics
pm next             # Ready tasks across all epics
pm blocked          # Blocked tasks
pm in-progress      # Active work
```

### By Entity
```bash
pm prd-show user-auth          # PRD details
pm epic-show user-auth         # Epic + all tasks
pm task-show user-auth 3       # Specific task
pm issue-show 123              # By GitHub issue number
```

### Search
```bash
pm search authentication       # Search across all entities
pm validate                    # Check database integrity
```

---

## Best Practices

### When to Create a PRD
- ✅ New user-facing feature
- ✅ Complex system change
- ✅ Needs product-level planning
- ❌ Bug fix (use backlog)
- ❌ Small improvement (use backlog)
- ❌ Technical chore (use backlog)

### When to Use Backlog
- ✅ Bug fixes
- ✅ Technical debt
- ✅ Documentation
- ✅ Dependency updates
- ✅ Small improvements discovered during work

### Task Granularity
- **Good:** 2-8 hours of work
- **Too small:** 30 minutes (just do it)
- **Too large:** Multiple days (break down further)

### Dependencies
- Only add if truly required (task 2 can't start until task 1 done)
- Don't over-specify (allows parallel work)
- Cross-epic dependencies possible but discouraged

### Parallel Work
- Use `parallel: true` flag for independent tasks
- Analyze with `pm issue-analyze` for complex parallelization
- Launch with `pm epic-parallel`
- Monitor with `git log` in worktree

---

## Summary

**The Mental Model:**

1. **PRD** = Product vision (WHAT and WHY)
2. **Epic** = Technical plan (HOW)
3. **Task** = Concrete work (DO)
4. **Issue** = External tracking (SHOW)

**The Flow:**

```
Product Idea
  ↓ pm prd-new (brainstorm)
PRD
  ↓ pm prd-parse (translate)
Epic
  ↓ pm epic-decompose (break down)
Tasks
  ↓ pm epic-sync (publish)
GitHub Issues
  ↓ pm epic-start (setup)
Worktree
  ↓ pm task-start (work)
Implementation
  ↓ pm task-close (complete)
Done!
```
