# Context Directory

This directory contains project context documentation that provides comprehensive information about the current state, structure, and direction of your project. The context files serve as a knowledge base for AI agents and team members to quickly understand and contribute to the project.

## Purpose

The context system enables:
- **Fast Agent Onboarding**: New AI agents can quickly understand the project through standardized documentation
- **Project Continuity**: Maintain knowledge across development sessions and team changes
- **Consistent Understanding**: Ensure all contributors have access to the same project information
- **Living Documentation**: Keep project knowledge current and actionable

## Core Context Files

When fully initialized, this directory contains:

### Project Foundation
- **`project-brief.md`** - Project scope, goals, and key objectives
- **`project-vision.md`** - Long-term vision and strategic direction
- **`project-overview.md`** - High-level summary of features and capabilities
- **`progress.md`** - Current project status, completed work, and immediate next steps

### Technical Context
- **`tech-context.md`** - Dependencies, technologies, and development tools
- **`project-structure.md`** - Directory structure and file organization
- **`system-patterns.md`** - Architectural patterns and design decisions
- **`project-style-guide.md`** - Coding standards, conventions, and style preferences

### Product Context
- **`product-context.md`** - Product requirements, target users, and core functionality

## Context Commands

Use these commands to manage your project context:

### Initialize Context
```bash
/context:create
```
Analyzes your project and creates initial context documentation. Use this when:
- Starting a new project
- Adding context to an existing project
- Major project restructuring

### Update Context
```bash
/context:update
```
Updates context documentation to reflect current project state. Use this:
- At the end of development sessions
- After completing major features
- When project direction changes
- After architectural changes

## How Context Works

**Automatic Loading:**
Context files are automatically loaded through references in `CLAUDE.md`. The init script creates a `CLAUDE.md` file that includes file references to:
- Database schema (`db/SCHEMA.md`)
- Command reference (`db/PHASE4_FINAL_SUMMARY.md`)
- GitHub sync documentation (`db/GITHUB_SYNC.md`)
- Any context files you create

**No Manual Loading Required:**
Unlike older approaches that required a `/context:prime` command, the current system automatically loads referenced files. Simply add file references to `CLAUDE.md` and they'll be included in every conversation.

## Context Workflow

1. **Project Start**: Run `/context:create` to establish baseline documentation
2. **Update CLAUDE.md**: Add file references to important documentation
3. **Development**: Context is automatically loaded in every session
4. **Session End**: Run `/context:update` to capture changes and progress

## Benefits

- **Reduced Onboarding Time**: New contributors understand the project quickly
- **Maintained Project Memory**: Nothing gets lost between sessions
- **Consistent Architecture**: Decisions are documented and followed
- **Clear Progress Tracking**: Always know what's been done and what's next
- **Enhanced AI Collaboration**: AI agents have full project understanding

## Best Practices

- **Keep Current**: Update context regularly, especially after major changes
- **Be Concise**: Focus on essential information that helps understanding
- **Stay Consistent**: Follow established formats and structures
- **Document Decisions**: Capture architectural and design decisions
- **Track Progress**: Maintain accurate status and next steps

## Integration

The context system integrates with:
- **Project Management**: Links with PRDs, epics, and task tracking
- **Development Workflow**: Supports continuous development sessions
- **Documentation**: Complements existing project documentation
- **Team Collaboration**: Provides shared understanding across contributors

Start with `/context:create` to initialize your project's knowledge base!
