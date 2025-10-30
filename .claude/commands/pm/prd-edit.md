---
allowed-tools: Bash, Read, Write, LS
---

# PRD Edit

Edit an existing Product Requirements Document through an interactive brainstorming session.

## Usage
```
/pm:prd-edit <feature_name>
```

## Required Rules

**IMPORTANT:** Before executing this command, read and follow:
- `.claude/rules/datetime.md` or `lib/docs/rules/datetime.md` - For getting real current date/time

## Instructions

You are a product manager conducting an interactive editing session for an existing Product Requirements Document (PRD).

### 1. Read Current PRD

Read `.claude/prds/$ARGUMENTS.md`:
- Parse frontmatter
- Read and understand all sections
- Summarize current state for the user

### 2. Discovery & Editing Session (Interactive Brainstorming)

**IMPORTANT: The editing session is NOT complete until:**
- You have gathered all necessary changes to update the PRD, OR
- The user explicitly indicates they are done

**Editing Process:**
1. Show the user what sections exist in the current PRD
2. Ask what they want to change or add
3. For each section being edited:
   - Show the current content
   - Ask clarifying questions about desired changes
   - Understand the reasoning behind changes
   - Explore implications and edge cases
4. Dig deeper when changes are vague or incomplete
5. Continue the conversation until you have comprehensive understanding of all changes

**Sections available to edit:**
- Executive Summary
- Problem Statement
- User Stories
- Requirements (Functional/Non-Functional)
- Success Criteria
- Constraints & Assumptions
- Out of Scope
- Dependencies

**After each round of discussing changes:**
- Synthesize what changes you've learned about
- Identify any gaps or inconsistencies
- Ask follow-up questions to clarify
- Explore how changes affect other sections

**Session Completion Check:**
After gathering change information, ask the user:
```
Is the editing session complete? (yes/no)
```

**Expected responses:**
- "yes" - Proceed to update the PRD
- "no" - Continue discussing changes

**If user says "no":**
- Ask what other areas need to be changed
- Continue with targeted questions about those sections
- Repeat the completion check after gathering more information

### 3. Update PRD

**IMPORTANT: Only after user confirms editing session is complete.**

Use ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ

Update PRD file:
- Preserve frontmatter except `updated` field
- Apply all discussed changes to affected sections
- Update `updated` field with current datetime
- Ensure consistency across all sections

### 4. Check Epic Impact

If PRD has associated epic:
- Notify user: "This PRD has epic: {epic_name}"
- Summarize what changed in the PRD
- Ask: "Epic may need updating based on PRD changes. Review epic? (yes/no)"
- If yes, show: "Review with: /pm:epic-edit {epic_name}"

### 5. Output

```
✅ Updated PRD: $ARGUMENTS
  Sections edited: {list_of_sections}
  Changes summary: {brief_summary_of_changes}

{If has epic}: ⚠️ Epic may need review: {epic_name}

Next: /pm:prd-parse $ARGUMENTS to update epic
```

## Error Recovery

If any step fails:
- Clearly explain what went wrong
- Provide specific steps to fix the issue
- Never leave partial or corrupted files

## Important Notes

- **Do NOT rush the editing session** - Take time to understand all desired changes
- **Ask follow-up questions** when changes are vague or might have side effects
- **Consider cross-section impacts** - Changes in one area may affect others
- **Show current content** before discussing changes to provide context
- **Always confirm** with "Is the editing session complete? (yes/no)" before writing changes
- **Preserve original creation date** in frontmatter
- **Keep version history** if it exists in frontmatter
