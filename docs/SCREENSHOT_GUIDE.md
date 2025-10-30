# CCPM Screenshot Guide for Marketplace

This document describes the three screenshots needed for the marketplace listing and how to capture them.

## Required Screenshots

### 1. Status Dashboard (`docs/images/status-dashboard.png`)

**Command**: `/pm:status`

**Purpose**: Show the comprehensive project overview that CCPM provides

**What to capture**:
- Terminal output showing project statistics
- Epic summary (total, in progress, completed)
- Task breakdown by status
- GitHub Issues integration status
- Recent activity timeline
- Color-coded status indicators

**Setup before capture**:
```bash
# Create sample data
/pm:prd-new
# Enter a PRD with title "User Authentication System"
/pm:prd-parse user-auth
/pm:epic-decompose user-auth
/pm:epic-sync user-auth

# Run status command
/pm:status
```

**Expected output elements**:
- Header: "CCPM Project Status"
- Metrics: X epics, Y tasks, Z issues
- Breakdown: pending/in-progress/completed counts
- Active worktrees list
- GitHub sync status
- Last updated timestamp

### 2. Epic Parallel Workflow (`docs/images/epic-parallel.png`)

**Command**: `/pm:epic-parallel user-auth`

**Purpose**: Demonstrate parallel AI agent execution across git worktrees

**What to capture**:
- Terminal output showing epic decomposition
- Multiple agent spawn messages
- Worktree creation/assignment
- Parallel execution indicators
- Progress tracking across agents
- Task completion messages

**Setup before capture**:
```bash
# Ensure you have an epic with multiple tasks
/pm:epic-start user-auth
/pm:epic-decompose user-auth  # Should have 3-5 tasks

# Launch parallel execution
/pm:epic-parallel user-auth
```

**Expected output elements**:
- Epic overview (name, description, task count)
- Agent spawn messages: "Spawning agent 1/3 for task..."
- Worktree paths: `.claude/worktrees/user-auth/task-1/`
- Status updates: "Agent 1: Analyzing task..."
- Completion indicators: "✓ Task 1 completed"
- Consolidated summary at end

### 3. PRD Workflow (`docs/images/prd-workflow.png`)

**Command**: `/pm:prd-new` (showing interactive brainstorming)

**Purpose**: Showcase spec-driven development from concept to execution

**What to capture**:
- PRD brainstorming interface
- AI-assisted requirement gathering
- Technical specification generation
- Epic creation from PRD
- Task decomposition output

**Setup before capture**:
```bash
# Start PRD creation
/pm:prd-new

# When prompted, enter:
# Feature: "Real-time collaboration system"
# Description: "WebSocket-based collaborative editing with presence indicators"

# Then show the parsing
/pm:prd-parse realtime-collab
```

**Expected output elements**:
- PRD template with sections: Overview, Requirements, Technical Details
- AI brainstorming prompts: "Let's refine the requirements..."
- Requirement bullets generated interactively
- Technical spec suggestions: "Based on requirements, I suggest..."
- Epic creation confirmation
- Task breakdown preview

## Screenshot Technical Requirements

### Format
- **Format**: PNG
- **Resolution**: 1200x800 pixels minimum (2x for retina)
- **DPI**: 144 or higher for clarity
- **Color depth**: 24-bit true color

### Terminal Setup
Before capturing, configure terminal for optimal display:

```bash
# Set terminal size
export COLUMNS=120
export LINES=40

# Use high contrast theme
# Recommended: Solarized Dark, Monokai, or Dracula

# Clear screen before each capture
clear
```

### Capture Methods

#### macOS
```bash
# Capture specific window
# CMD+SHIFT+4, then SPACE, click terminal window

# Or use screencapture
screencapture -w docs/images/status-dashboard.png
```

#### Linux
```bash
# Using gnome-screenshot
gnome-screenshot -w -f docs/images/status-dashboard.png

# Or using import (ImageMagick)
import -window root docs/images/status-dashboard.png
```

#### Windows
```bash
# Using PowerShell
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.SendKeys]::SendWait('%{PRTSC}')
# Then paste into Paint and save
```

## Post-Processing

### Recommended Edits
1. **Crop**: Remove any unnecessary borders or UI elements
2. **Annotate**: Add arrows or labels to highlight key features
3. **Optimize**: Compress PNG without quality loss
   ```bash
   optipng -o7 docs/images/*.png
   ```
4. **Verify**: Check dimensions and file size
   ```bash
   file docs/images/*.png
   ```

### Target File Sizes
- Each screenshot: 100-500 KB
- Total for 3 screenshots: < 1.5 MB

## Quality Checklist

Before submission, verify each screenshot:

- [ ] Shows actual CCPM output (not mocked)
- [ ] Text is crisp and readable
- [ ] Colors are accurate and high-contrast
- [ ] No sensitive information visible (tokens, real repo names)
- [ ] Demonstrates key feature clearly
- [ ] Professional appearance (clean terminal)
- [ ] Proper filename matches marketplace.json reference
- [ ] Saved in docs/images/ directory
- [ ] Committed to git
- [ ] File size reasonable (<500KB each)

## Alternative: SVG Format

For vector-based terminal output:

```bash
# Use asciinema + svg-term
asciinema rec demo.cast
svg-term --in demo.cast --out docs/images/status-dashboard.svg
```

Benefits:
- Scalable to any resolution
- Smaller file size
- Text remains selectable
- Better for documentation

Note: Check if marketplace accepts SVG before using this format.

## Testing Screenshots

Before finalizing, test how they appear:

1. **Markdown Preview**
   ```markdown
   ![Status Dashboard](docs/images/status-dashboard.png)
   ```

2. **Different Screen Sizes**
   - Desktop (1920x1080)
   - Laptop (1366x768)
   - Mobile (responsive)

3. **Dark/Light Modes**
   - Verify contrast in both themes
   - Ensure text remains readable

## Marketplace Integration

After creating screenshots, verify they're referenced correctly:

```json
"screenshots": [
  "docs/images/status-dashboard.png",
  "docs/images/epic-parallel.png",
  "docs/images/prd-workflow.png"
]
```

Test the paths:
```bash
ls -lh docs/images/*.png
```

Expected output:
```
-rw-r--r--  1 user  staff  250K Jan 15 10:00 status-dashboard.png
-rw-r--r--  1 user  staff  320K Jan 15 10:05 epic-parallel.png
-rw-r--r--  1 user  staff  280K Jan 15 10:10 prd-workflow.png
```

## Next Steps After Screenshots

1. Update MARKETPLACE_CHECKLIST.md to mark screenshots as complete
2. Commit screenshot files to git
3. Proceed with full installation testing
4. Create GitHub release with screenshots included
5. Submit to marketplace with all assets

## Support

If you encounter issues capturing screenshots:
- **Terminal recording**: Use `asciinema` for dynamic demos
- **Image issues**: Check terminal font settings (Monaco, Menlo, or Fira Code recommended)
- **Size issues**: Resize terminal window before capturing: `printf '\e[8;40;120t'`
