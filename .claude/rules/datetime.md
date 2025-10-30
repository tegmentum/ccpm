# DateTime Rule

## Getting Current Date and Time

When any command requires the current date/time (for frontmatter, timestamps, or logs), you MUST obtain the REAL current date/time from the system rather than estimating or using placeholder values.

## Python-Based DateTime (Recommended)

Since CCPM now uses Python for all scripts, the preferred method is Python's datetime:

```python
from datetime import datetime

# Get current UTC datetime in ISO 8601 format
current_datetime = datetime.utcnow().isoformat() + "Z"
# Example output: "2024-01-15T14:30:45.123456Z"
```

Most CCPM Python scripts automatically handle datetime via `db/helpers.py` functions like `update_epic()` and `update_task()` which set `updated_at` automatically.

## Command Line Alternative

If you need to get datetime from command line (for LLM-written files):

```bash
# Using Python (cross-platform)
python3 -c "from datetime import datetime; print(datetime.utcnow().isoformat() + 'Z')"

# Or traditional date command (Linux/Mac only)
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

## Required Format

All dates in frontmatter MUST use ISO 8601 format with UTC timezone:
- Format: `YYYY-MM-DDTHH:MM:SSZ`
- Example: `2024-01-15T14:30:45Z`

## Usage in Frontmatter

When creating or updating frontmatter in any file (PRD, Epic, Task, Progress), always use the real current datetime:

```yaml
---
name: feature-name
created: 2024-01-15T14:30:45Z  # Use actual datetime
updated: 2024-01-15T14:30:45Z  # Use actual datetime
---
```

## Implementation Instructions

### For Python Scripts
Python scripts should use:
```python
from datetime import datetime

# When creating/updating records
fields['updated_at'] = datetime.utcnow().isoformat() + "Z"
```

The `db/helpers.py` module automatically adds `updated_at` in `update_epic()` and `update_task()` functions.

### For LLM Commands
When writing markdown files directly:

1. **Get current datetime:**
   ```bash
   python3 -c "from datetime import datetime; print(datetime.utcnow().isoformat() + 'Z')"
   ```

2. **Use the exact output** in frontmatter fields

## Why ISO 8601 with UTC?

- **Unambiguous**: No timezone confusion
- **Sortable**: Lexicographic sort = chronological sort
- **Standard**: Widely supported format
- **Parseable**: Easy to parse in any language
- **Cross-platform**: Works everywhere

## Common Mistakes to Avoid

❌ Don't use placeholder values: `YYYY-MM-DDTHH:MM:SSZ`
❌ Don't estimate or guess: `2024-01-15T12:00:00Z`
❌ Don't use local timezone: `2024-01-15T14:30:45-08:00`
✅ Always get REAL current UTC datetime from system
