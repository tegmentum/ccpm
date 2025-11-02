#!/bin/bash
# Generate sample data for CCPM marketplace screenshots
# This script creates realistic demo data to showcase CCPM features

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==================================="
echo "CCPM Screenshot Data Generator"
echo "==================================="
echo ""

# Check if CCPM is initialized
if [ ! -f ~/.claude/ccpm.db ]; then
    echo "❌ CCPM database not found. Please run /ccpm:init first."
    exit 1
fi

echo "✓ CCPM database found"
echo ""

# Create directories for screenshots
mkdir -p "$PROJECT_ROOT/docs/images"
echo "✓ Created docs/images directory"
echo ""

echo "Creating sample PRDs and epics..."
echo "-----------------------------------"

# Function to create a PRD via Python
create_prd() {
    local name="$1"
    local title="$2"
    local content="$3"

    python3 - <<EOF
import sys
from pathlib import Path
sys.path.insert(0, str(Path('$PROJECT_ROOT/db')))
from helpers import get_db

db = get_db()
db.create_prd(
    name='$name',
    title='$title',
    content='''$content''',
    status='approved'
)
print(f"✓ Created PRD: $name")
EOF
}

# Function to create an epic
create_epic() {
    local name="$1"
    local title="$2"
    local description="$3"
    local status="$4"

    python3 - <<EOF
import sys
from pathlib import Path
sys.path.insert(0, str(Path('$PROJECT_ROOT/db')))
from helpers import get_db

db = get_db()
db.create_epic(
    name='$name',
    title='$title',
    description='$description',
    status='$status'
)
print(f"✓ Created epic: $name")
EOF
}

# Function to create tasks for an epic
create_task() {
    local epic_name="$1"
    local task_num="$2"
    local title="$3"
    local description="$4"
    local status="$5"

    python3 - <<EOF
import sys
from pathlib import Path
sys.path.insert(0, str(Path('$PROJECT_ROOT/db')))
from helpers import get_db

db = get_db()
epic_id = db.execute("SELECT id FROM epics WHERE name = ?", ('$epic_name',)).fetchone()[0]
db.execute("""
    INSERT INTO tasks (epic_id, number, title, description, status, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'))
""", (epic_id, $task_num, '$title', '$description', '$status'))
db.conn.commit()
print(f"✓ Created task $task_num for $epic_name")
EOF
}

# Sample PRD 1: User Authentication
create_prd "user-auth" "User Authentication System" "## Overview
A comprehensive authentication system supporting multiple OAuth providers, JWT tokens, and session management.

## Requirements
- OAuth 2.0 integration (Google, GitHub, GitLab)
- JWT token generation and validation
- Secure session management with Redis
- Password reset via email
- Two-factor authentication (TOTP)
- Rate limiting on login attempts

## Technical Details
- Backend: Node.js + Express + Passport.js
- Database: PostgreSQL for user data
- Cache: Redis for sessions
- Email: SendGrid for notifications
- Security: bcrypt for passwords, helmet for headers

## Success Criteria
- < 200ms login response time
- 99.9% uptime
- Zero password leaks
- OWASP compliance"

# Create epic for user auth
create_epic "user-auth" "User Authentication System" "Comprehensive multi-provider authentication with JWT and sessions" "in_progress"

# Create tasks for user auth
create_task "user-auth" 1 "OAuth Provider Integration" "Implement OAuth 2.0 flows for Google, GitHub, and GitLab" "completed"
create_task "user-auth" 2 "JWT Token Management" "Create token generation, validation, and refresh logic" "in_progress"
create_task "user-auth" 3 "Session Management" "Implement Redis-backed session storage with TTL" "ready"
create_task "user-auth" 4 "Password Reset Flow" "Build email-based password reset with secure tokens" "ready"
create_task "user-auth" 5 "Two-Factor Authentication" "Add TOTP-based 2FA with QR code generation" "pending"

# Sample PRD 2: Real-time Collaboration
create_prd "realtime-collab" "Real-time Collaboration System" "## Overview
WebSocket-based collaborative editing with presence indicators and conflict resolution.

## Requirements
- Real-time document editing (operational transform)
- User presence indicators
- Cursor position tracking
- Conflict resolution
- Offline sync when reconnected
- Version history

## Technical Details
- WebSocket server: Socket.io
- OT library: ShareDB
- Frontend: React with hooks
- Storage: MongoDB for documents
- Pub/Sub: Redis for scaling

## Success Criteria
- < 50ms latency for edits
- Support 50+ concurrent users per document
- 100% conflict resolution accuracy"

create_epic "realtime-collab" "Real-time Collaboration" "WebSocket-based collaborative editing with presence" "ready"

create_task "realtime-collab" 1 "WebSocket Infrastructure" "Setup Socket.io server with room management" "ready"
create_task "realtime-collab" 2 "Operational Transform" "Integrate ShareDB for conflict-free editing" "ready"
create_task "realtime-collab" 3 "Presence System" "Build user presence and cursor tracking" "ready"

# Sample PRD 3: Analytics Dashboard
create_prd "analytics-dash" "Analytics Dashboard" "## Overview
Real-time analytics dashboard with custom metrics and visualizations.

## Requirements
- Custom metric definitions
- Real-time data streaming
- Interactive charts (line, bar, pie, heatmap)
- Date range filtering
- Export to PDF/CSV
- Alert thresholds

## Technical Details
- Frontend: React + D3.js + Recharts
- Backend: FastAPI + Python
- Database: TimescaleDB (PostgreSQL)
- Streaming: Apache Kafka
- Cache: Redis

## Success Criteria
- Load 1M+ data points in < 2 seconds
- 60 FPS chart rendering
- Export 100k rows in < 5 seconds"

create_epic "analytics-dash" "Analytics Dashboard" "Real-time analytics with custom metrics and visualizations" "completed"

create_task "analytics-dash" 1 "Metric Definition System" "Build UI for custom metric creation" "completed"
create_task "analytics-dash" 2 "Chart Components" "Create reusable D3/Recharts components" "completed"
create_task "analytics-dash" 3 "Real-time Streaming" "Implement Kafka consumer for live updates" "completed"

echo ""
echo "Sample data created successfully!"
echo ""
echo "==================================="
echo "Screenshot Capture Commands"
echo "==================================="
echo ""
echo "Now you can capture screenshots:"
echo ""
echo "1. Status Dashboard:"
echo "   /ccpm:status"
echo "   Screenshot: docs/images/status-dashboard.png"
echo ""
echo "2. Epic Parallel Workflow:"
echo "   /ccpm:epic-show user-auth"
echo "   /ccpm:epic-parallel user-auth"
echo "   Screenshot: docs/images/epic-parallel.png"
echo ""
echo "3. PRD Workflow:"
echo "   /ccpm:prd-show user-auth"
echo "   /ccpm:prd-parse user-auth"
echo "   Screenshot: docs/images/prd-workflow.png"
echo ""
echo "==================================="
echo "Terminal Setup for Best Results"
echo "==================================="
echo ""
echo "1. Set terminal size:"
echo "   printf '\\e[8;40;120t'"
echo ""
echo "2. Use high-contrast theme"
echo "   (Solarized Dark, Monokai, or Dracula)"
echo ""
echo "3. Clear screen before each capture:"
echo "   clear"
echo ""
echo "4. Capture window (macOS):"
echo "   CMD+SHIFT+4, then SPACE, click window"
echo ""
echo "Done! Happy screenshotting! 📸"
