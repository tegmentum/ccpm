---
allowed-tools: Bash, Read, Write, LS
---

# PRD New

Launch brainstorming for new product requirement document.

## Usage
```
/pm:prd-new
```

Note: No feature name is required. The name will be assigned after the brainstorming session is complete.

## Required Rules

**IMPORTANT:** Before executing this command, read and follow:
- `.claude/rules/datetime.md` - For getting real current date/time

## Preflight Checklist

Before proceeding, complete these validation steps.
Do not bother the user with preflight checks progress ("I'm not going to ..."). Just do them and move on.

### Directory Validation
1. **Verify directory structure:**
   - Check if `.claude/prds/` directory exists
   - If not, create it first
   - If unable to create, tell user: "❌ Cannot create PRD directory. Please manually create: .claude/prds/"

## Instructions

You are a product manager conducting a brainstorming session to create a comprehensive Product Requirements Document (PRD).

### 1. Discovery & Context (Brainstorming Session)

**IMPORTANT: The brainstorming session is NOT complete until:**
- You have gathered all necessary information to write a comprehensive PRD, OR
- The user explicitly indicates they are done

**Brainstorming Process:**
1. Start by asking the user what they want to build
2. Ask clarifying questions to understand:
   - The problem being solved
   - Target users and use cases
   - Core features and capabilities
   - Constraints and requirements
   - Success criteria
3. Explore edge cases and potential issues
4. Dig deeper when answers are vague or incomplete
5. Continue asking questions until you have comprehensive understanding

**After each round of Q&A:**
- Synthesize what you've learned
- Identify gaps in understanding
- Ask follow-up questions to fill those gaps

**Session Completion Check:**
After gathering information, ask the user:
```
Is the brainstorming session complete? (yes/no)
```

**Expected responses:**
- "yes" - Proceed to assign name and write PRD
- "no" - Continue brainstorming with more questions

**If user says "no":**
- Ask what areas need more exploration
- Continue with targeted questions
- Repeat the completion check after gathering more information

### 2. Assign PRD Name

**IMPORTANT: Only after user confirms brainstorming is complete.**

Based on the brainstorming session:
1. Propose a descriptive kebab-case name for the PRD
2. Format requirements:
   - Must contain only lowercase letters, numbers, and hyphens
   - Must start with a letter
   - No spaces or special characters
   - Examples: user-auth, payment-v2, notification-system
3. Ask user to confirm the name or suggest alternative
4. Check if `.claude/prds/{proposed-name}.md` already exists
5. If exists, ask: "⚠️ PRD '{name}' already exists. Choose different name or overwrite? (rename/overwrite)"

### 3. PRD Structure

Create a comprehensive PRD with these sections:

#### Executive Summary
- Brief overview and value proposition

#### Problem Statement
- What problem are we solving?
- Why is this important now?

#### User Stories
- Primary user personas
- Detailed user journeys
- Pain points being addressed

#### Requirements
**Functional Requirements**
- Core features and capabilities
- User interactions and flows

**Non-Functional Requirements**
- Performance expectations
- Security considerations
- Scalability needs

#### Success Criteria
- Measurable outcomes
- Key metrics and KPIs

#### Constraints & Assumptions
- Technical limitations
- Timeline constraints
- Resource limitations

#### Out of Scope
- What we're explicitly NOT building

#### Dependencies
- External dependencies
- Internal team dependencies

### 4. File Format with Frontmatter

Save the completed PRD to: `.claude/prds/{assigned-name}.md` with this exact structure:

```markdown
---
name: {assigned-name}
description: [Brief one-line description of the PRD]
status: backlog
created: [Current ISO date/time]
---

# PRD: {assigned-name}

## Executive Summary
[Content from brainstorming...]

## Problem Statement
[Content from brainstorming...]

[Continue with all sections...]
```

### 5. Frontmatter Guidelines

- **name**: Use the assigned kebab-case name
- **description**: Write a concise one-line summary of what this PRD covers
- **status**: Always start with "backlog" for new PRDs
- **created**: Use ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ
  - Never use placeholder text
  - Must be actual system time in ISO 8601 format

### 6. Quality Checks

Before saving the PRD, verify:
- [ ] All sections are complete (no placeholder text)
- [ ] User stories include acceptance criteria
- [ ] Success criteria are measurable
- [ ] Dependencies are clearly identified
- [ ] Out of scope items are explicitly listed
- [ ] Content reflects the brainstorming discussion

### 7. Post-Creation

After successfully creating the PRD:
1. Confirm: "✅ PRD created: .claude/prds/{assigned-name}.md"
2. Show brief summary of what was captured
3. Suggest next step: "Ready to create implementation epic? Run: /pm:prd-parse {assigned-name}"

## Error Recovery

If any step fails:
- Clearly explain what went wrong
- Provide specific steps to fix the issue
- Never leave partial or corrupted files

## Important Notes

- **Do NOT rush the brainstorming session** - Take time to understand the requirements fully
- **Ask follow-up questions** when answers are vague or incomplete
- **Explore edge cases** and potential challenges
- **Only assign name AFTER** brainstorming is complete
- **Always confirm** with "Is the brainstorming session complete? (yes/no)" before proceeding to write the PRD
