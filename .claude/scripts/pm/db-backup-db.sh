#!/usr/bin/env bash
# Backup database

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DB_PATH="${CCPM_DB:-$HOME/.claude/ccpm.db}"
BACKUP_DIR="$HOME/.claude/ccpm_backups"

echo "💾 Database Backup Tool"
echo "======================"
echo ""

# Check if database exists
if [[ ! -f "$DB_PATH" ]]; then
    echo "❌ Database not found: $DB_PATH"
    echo ""
    echo "Initialize database first with: db/init.sh"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Get backup name from argument or generate timestamp
backup_name="${1:-}"

if [[ -z "$backup_name" ]]; then
    # Generate timestamp-based name
    backup_name="ccpm_$(date +%Y%m%d_%H%M%S)"
fi

# Add .db extension if not present
if [[ ! "$backup_name" =~ \.db$ ]]; then
    backup_name="${backup_name}.db"
fi

backup_path="$BACKUP_DIR/$backup_name"

# Check if backup already exists
if [[ -f "$backup_path" ]]; then
    echo "⚠️  Backup already exists: $backup_name"
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi
fi

# Create backup using SQLite's backup command
echo "Creating backup..."
sqlite3 "$DB_PATH" ".backup '$backup_path'"

if [[ $? -eq 0 ]]; then
    # Get file sizes
    original_size=$(ls -lh "$DB_PATH" | awk '{print $5}')
    backup_size=$(ls -lh "$backup_path" | awk '{print $5}')
    
    # Get record counts
    record_count=$(sqlite3 "$DB_PATH" "
        SELECT 
            (SELECT COUNT(*) FROM prds) as prds,
            (SELECT COUNT(*) FROM epics) as epics,
            (SELECT COUNT(*) FROM tasks) as tasks
    ")
    
    echo ""
    echo "✅ Backup created successfully!"
    echo ""
    echo "📊 Backup Details:"
    echo "  Location: $backup_path"
    echo "  Size: $backup_size (original: $original_size)"
    echo "  Records: $record_count"
    echo "  Created: $(date)"
    echo ""
    
    # List all backups
    backup_count=$(ls -1 "$BACKUP_DIR"/*.db 2>/dev/null | wc -l)
    if [[ $backup_count -gt 1 ]]; then
        echo "📁 All Backups ($backup_count):"
        ls -lth "$BACKUP_DIR"/*.db | while read -r line; do
            size=$(echo "$line" | awk '{print $5}')
            date=$(echo "$line" | awk '{print $6, $7, $8}')
            name=$(basename "$(echo "$line" | awk '{print $9}')")
            echo "  • $name ($size) - $date"
        done
        echo ""
    fi
    
    echo "💡 Actions:"
    echo "  • Restore backup: cp $backup_path $DB_PATH"
    echo "  • List backups: ls -lh $BACKUP_DIR"
    echo "  • Clean old backups: rm $BACKUP_DIR/ccpm_*.db"
else
    echo "❌ Backup failed!"
    exit 1
fi

exit 0
