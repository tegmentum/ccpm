# GitHub Sync Testing Guide

## Test Environment Setup

### Prerequisites

1. **GitHub CLI installed and authenticated**
   ```bash
   # Check if installed
   gh --version

   # Authenticate if needed
   gh auth login
   ```

2. **Test repository**
   - Create a test GitHub repository or use existing
   - Ensure you have push access

3. **Database with sample data**
   ```bash
   # Initialize database
   cd /Users/zacharywhitley/git/ccpm
   db/init.sh

   # Load test data
   db/query.sh "$(cat db/test_data.sql)" csv
   ```

## Test Scenarios

### Scenario 1: Initial Push (Empty GitHub)

Test pushing all local data to GitHub for the first time.

```bash
# Check what will be pushed
pm sync status

# Preview push
pm sync push --dry-run

# Execute push
pm sync push prd --yes
pm sync push epic --yes
pm sync push task --yes

# Verify on GitHub
gh issue list --label ccpm

# Check sync status
pm sync status --verbose
```

**Expected Results:**
- All PRDs, Epics, Tasks created as GitHub issues
- Each issue has ccpm label and frontmatter metadata
- Database updated with github_issue_number
- All entities show as "synced" in status

### Scenario 2: Pull from GitHub

Test pulling existing issues from GitHub.

```bash
# List GitHub issues
gh issue list --label ccpm

# Pull all
pm sync pull --dry-run
pm sync pull --yes

# Pull specific issue
pm sync pull task --issue 123

# Check results
pm sync status --verbose
```

**Expected Results:**
- Issues imported with correct entity types
- Relationships maintained (epic → prd, task → epic)
- Timestamps tracked correctly

### Scenario 3: Update and Push

Test pushing local changes to GitHub.

```bash
# Make local change
db/query.sh "
  UPDATE ccpm.epics
  SET description = 'Updated description for testing',
      updated_at = datetime('now')
  WHERE name = 'user-auth-backend'
" csv

# Check what needs syncing
pm sync status

# Push changes
pm sync push epic --epic user-auth-backend

# Verify on GitHub
gh issue view <issue-number>
```

**Expected Results:**
- GitHub issue updated with new description
- Timestamps updated
- Status shows "synced"

### Scenario 4: Update on GitHub and Pull

Test pulling changes made on GitHub.

```bash
# Make change on GitHub
gh issue edit <issue-number> --body "Updated from GitHub"

# Pull changes
pm sync pull epic --issue <issue-number>

# Verify in database
db/query.sh "
  SELECT name, description, github_synced_at
  FROM ccpm.epics
  WHERE github_issue_number = <issue-number>
" table
```

**Expected Results:**
- Local database updated with GitHub changes
- Timestamps reflect GitHub update time
- Status shows "synced"

### Scenario 5: Conflict Detection

Test conflict detection when both sides modified.

```bash
# 1. Update locally
db/query.sh "
  UPDATE ccpm.epics
  SET description = 'Local change',
      updated_at = datetime('now')
  WHERE name = 'user-auth-backend'
" csv

# 2. Update on GitHub
gh issue edit <issue-number> --body "GitHub change"

# 3. Try to pull (should detect conflict)
pm sync pull epic --issue <issue-number>

# 4. Check conflict status
pm sync status --conflicts

# 5. Show conflict details
pm sync resolve epic <epic-id> --show
```

**Expected Results:**
- Conflict detected and logged
- sync_metadata shows 'conflict' status
- Both timestamps recorded
- Conflict reason stored

### Scenario 6: Conflict Resolution - Use Local

Test resolving conflict by keeping local version.

```bash
# View conflict
pm sync resolve epic <epic-id> --show

# Resolve with local version
pm sync resolve epic <epic-id> --use-local --dry-run
pm sync resolve epic <epic-id> --use-local

# Verify
gh issue view <issue-number>
pm sync status
```

**Expected Results:**
- Local version pushed to GitHub
- Conflict status cleared
- GitHub issue matches local database

### Scenario 7: Conflict Resolution - Use GitHub

Test resolving conflict by keeping GitHub version.

```bash
# View conflict
pm sync resolve epic <epic-id> --show

# Resolve with GitHub version
pm sync resolve epic <epic-id> --use-github --dry-run
pm sync resolve epic <epic-id> --use-github

# Verify
db/query.sh "SELECT description FROM ccpm.epics WHERE id = <epic-id>" table
pm sync status
```

**Expected Results:**
- GitHub version pulled to database
- Conflict status cleared
- Database matches GitHub issue

### Scenario 8: Epic-Specific Sync

Test syncing a single epic with all its tasks.

```bash
# Push epic and tasks
pm sync push epic --epic user-auth-backend
pm sync push task --epic user-auth-backend

# Check status
pm sync status --epics --epic user-auth-backend
pm sync status --tasks --epic user-auth-backend
```

**Expected Results:**
- Only specified epic and its tasks synced
- Other epics unaffected

### Scenario 9: Incremental Pull

Test pulling only recent changes from GitHub.

```bash
# Get current timestamp
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Make changes on GitHub (edit some issues)

# Pull only recent changes
pm sync pull --since "$NOW"

# Check what was pulled
pm sync status --verbose
```

**Expected Results:**
- Only recently modified issues pulled
- Older issues skipped
- Efficient incremental sync

### Scenario 10: Batch Conflict Resolution

Test resolving multiple conflicts at once.

```bash
# Create multiple conflicts (update both sides for multiple entities)

# View all conflicts
pm sync status --conflicts

# Resolve all with same strategy
pm sync resolve all --use-local --dry-run
pm sync resolve all --use-local --yes

# Verify
pm sync status --conflicts
```

**Expected Results:**
- All conflicts resolved with chosen strategy
- No conflicts remaining
- All entities synced

## Manual Testing Checklist

### Push Operations

- [ ] Push new PRD (no GitHub issue)
- [ ] Push existing PRD (update existing issue)
- [ ] Push new Epic with PRD reference
- [ ] Push existing Epic (update existing issue)
- [ ] Push new Task with Epic reference and dependencies
- [ ] Push existing Task (update existing issue)
- [ ] Push all entities at once
- [ ] Dry-run shows correct actions
- [ ] Issue body contains correct frontmatter
- [ ] Issue body contains correct description
- [ ] Task list in Epic shows correct tasks
- [ ] Dependencies shown in Task body

### Pull Operations

- [ ] Pull PRD from GitHub issue
- [ ] Pull Epic from GitHub issue (creates correct PRD reference)
- [ ] Pull Task from GitHub issue (creates correct Epic reference)
- [ ] Pull all entities at once
- [ ] Dry-run shows correct actions
- [ ] Frontmatter parsed correctly
- [ ] Entity relationships maintained
- [ ] Status mapped correctly (open/closed)
- [ ] Timestamps recorded correctly

### Status Display

- [ ] Summary shows correct counts
- [ ] Verbose shows all entities
- [ ] Conflicts highlighted
- [ ] Icons show correct status (✓ ⟳ ⚠)
- [ ] Time ago formatted correctly
- [ ] Epic filter works
- [ ] Entity-specific filters work

### Conflict Resolution

- [ ] Conflict detected when both modified
- [ ] Conflict ignored when only local modified
- [ ] Conflict ignored when only GitHub modified
- [ ] Show command displays all details
- [ ] Use-local pushes correctly
- [ ] Use-github pulls correctly
- [ ] Batch resolution works
- [ ] Conflict status cleared after resolution

### Error Handling

- [ ] GitHub CLI not installed - clear error
- [ ] Not authenticated - clear error
- [ ] Issue not found - clear error
- [ ] Invalid entity type - clear error
- [ ] Network error - retry/fail gracefully
- [ ] Missing PRD reference - clear error
- [ ] Missing Epic reference - clear error

## Automated Test Script

```bash
#!/usr/bin/env bash
# Automated sync testing

set -euo pipefail

echo "=== GitHub Sync Automated Tests ==="
echo ""

# Test 1: Status check
echo "Test 1: Status check"
pm sync status
echo "✓ Status check passed"
echo ""

# Test 2: Dry-run push
echo "Test 2: Dry-run push"
pm sync push --dry-run
echo "✓ Dry-run push passed"
echo ""

# Test 3: Dry-run pull
echo "Test 3: Dry-run pull"
pm sync pull --dry-run
echo "✓ Dry-run pull passed"
echo ""

# Test 4: Status with options
echo "Test 4: Status with options"
pm sync status --verbose
pm sync status --conflicts
echo "✓ Status with options passed"
echo ""

echo "=== All automated tests passed ==="
```

## Performance Testing

### Large Dataset Test

```bash
# Create 100 tasks across 10 epics
for i in {1..10}; do
  for j in {1..10}; do
    db/query.sh "
      INSERT INTO ccpm.tasks (epic_id, task_number, name, status, created_at, updated_at)
      VALUES (${i}, ${j}, 'Test task ${j}', 'open', datetime('now'), datetime('now'))
    " csv
  done
done

# Time the push
time pm sync push task --yes

# Check rate limiting
pm sync status
```

### Concurrent Sync Test

```bash
# Push and pull simultaneously (from different machines/branches)
# This tests conflict detection under real concurrent access

# Machine 1
pm sync push --yes &

# Machine 2 (simultaneously)
pm sync pull --yes &

wait

# Check for conflicts
pm sync status --conflicts
```

## Cleanup

```bash
# Remove all test issues from GitHub
gh issue list --label ccpm --json number --jq '.[].number' | \
  xargs -I {} gh issue close {}

# Delete issues permanently (careful!)
# gh api -X DELETE /repos/:owner/:repo/issues/:number

# Reset database
rm ~/.claude/ccpm.db
db/init.sh
```

## Troubleshooting

### Issue: "gh: command not found"
```bash
# Install GitHub CLI
# macOS
brew install gh

# Linux
# See: https://github.com/cli/cli/blob/trunk/docs/install_linux.md
```

### Issue: "Not authenticated with GitHub"
```bash
gh auth login
gh auth status
```

### Issue: "Rate limit exceeded"
```bash
# Check rate limit
gh api rate_limit

# Wait for reset or use different token
export GH_TOKEN="your-personal-access-token"
```

### Issue: Conflicts won't resolve
```bash
# Check sync metadata
db/query.sh "
  SELECT * FROM ccpm.sync_metadata
  WHERE sync_status = 'conflict'
" table

# Manually clear conflict
db/query.sh "
  UPDATE ccpm.sync_metadata
  SET sync_status = 'synced', conflict_reason = NULL
  WHERE entity_type = 'epic' AND entity_id = <id>
" csv

# Then re-sync
pm sync push epic --id <id>
```

## Success Criteria

All tests pass if:
1. ✓ Push creates correct GitHub issues with labels and frontmatter
2. ✓ Pull imports issues with correct entity types and relationships
3. ✓ Status displays accurate sync state
4. ✓ Conflicts detected and resolved correctly
5. ✓ No data loss during sync
6. ✓ Timestamps tracked accurately
7. ✓ Error messages are clear and actionable
8. ✓ Performance acceptable for typical dataset sizes
