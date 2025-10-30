# CCPM Plugin Quick Start

Ship faster with spec-driven development, GitHub Issues, Git worktrees, and parallel AI agents.

## Install

```bash
/plugin install /path/to/ccpm
```

## Quick Commands

```bash
/pm:status          # Project dashboard
/pm:prd-new         # Create PRD
/pm:epic-start      # Start epic worktree
/pm:issue-start     # Work on issue
/pm:help            # All commands
```

## Workflow

```mermaid
graph LR
    A[PRD] --> B[Epic]
    B --> C[Tasks]
    C --> D[GitHub]
    D --> E[Parallel Work]
```

1. **Brainstorm** → `/pm:prd-new`
2. **Plan** → `/pm:prd-parse`
3. **Decompose** → `/pm:epic-decompose`
4. **Sync** → `/pm:epic-sync`
5. **Execute** → `/pm:epic-parallel`

## What You Get

- ✅ 39 slash commands
- ✅ 4 specialized agents
- ✅ GitHub Issues integration
- ✅ Git worktree management
- ✅ Parallel AI execution
- ✅ Token-optimized (63.5% reduction)

## Full Documentation

See [PLUGIN.md](./PLUGIN.md) for complete documentation.

## Support

- **GitHub**: https://github.com/automazeio/ccpm
- **Website**: https://automaze.io
