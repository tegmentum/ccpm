# CCPM Library - Dual-Mode Support

This directory contains portable components that work in both repository and plugin modes.

## Directory Structure

```
lib/
├── docs/
│   └── rules/          # Portable rule documentation
└── python/             # (Future: Python library code for plugin mode)
```

## Dual-Mode Operation

CCPM is designed to work in two modes:

### Repository Mode (Current)
- Files in `.claude/` directory
- Database at `~/.claude/ccpm.db`
- Scripts in `.claude/scripts/pm/`
- Rules in `.claude/rules/`

### Plugin Mode (Future)
- Installed via `/plugin install ccpm`
- Database at `~/.claude/ccpm.db` (or `$CCPM_DB_PATH`)
- Scripts in `$PLUGIN_DIR/lib/python/scripts/`
- Rules in `$PLUGIN_DIR/lib/docs/rules/`

## Environment Variables

CCPM respects these environment variables for dual-mode operation:

- **`PLUGIN_DIR`**: Root directory of plugin installation
  - If set, router.py looks for scripts in `$PLUGIN_DIR/lib/python/scripts/`
  - If not set, uses repository mode (`.claude/scripts/pm/`)

- **`CCPM_DB_PATH`**: Custom database location
  - If set, overrides default `~/.claude/ccpm.db`
  - Useful for testing or multi-instance setups

## Rules Documentation

Rules are duplicated in two locations:

1. **`.claude/rules/`** - Repository mode (local development)
2. **`lib/docs/rules/`** - Plugin mode (portable)

Command files reference both locations so they work in either mode.

## For Plugin Developers

When creating the plugin version:

1. Scripts go in: `lib/python/scripts/`
2. Core library goes in: `lib/python/helpers.py`
3. Database schema goes in: `lib/sql/schema.sql`
4. Rules stay in: `lib/docs/rules/`

Commands automatically adapt based on whether `$PLUGIN_DIR` is set.

## Testing Dual-Mode

### Test Repository Mode (Current)
```bash
# Normal usage - no env vars needed
python3 .claude/scripts/pm/router.py status
```

### Test Plugin Mode (Simulated)
```bash
# Set PLUGIN_DIR to current directory
export PLUGIN_DIR="$PWD"

# Create plugin structure for testing
mkdir -p lib/python/scripts
cp -r .claude/scripts/pm/*.py lib/python/scripts/
cp db/helpers.py lib/python/

# Test router in plugin mode
python3 .claude/scripts/pm/router.py status
```

The router will automatically detect `$PLUGIN_DIR` and use plugin paths.

## Benefits

1. **Single codebase** works in both modes
2. **Easy migration** from repository to plugin
3. **Development flexibility** - test locally as repo
4. **Distribution ready** - package as plugin when stable
5. **Backward compatible** - existing users unaffected
