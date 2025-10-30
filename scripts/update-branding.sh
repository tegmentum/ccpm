#!/bin/bash
# Update branding from Tegmentum to Tegmentum throughout codebase

set -e

PROJECT_ROOT="/Users/zacharywhitley/git/ccpm"

echo "=========================================="
echo "CCPM Branding Update"
echo "=========================================="
echo ""
echo "Replacing:"
echo "  tegmentum.ai → tegmentum.ai"
echo "  automazeio  → tegmentum"
echo "  Tegmentum    → Tegmentum"
echo "  support@tegmentum.ai → zachary.whitley@tegmentum.ai"
echo ""

# Find all files that need updating
FILES=$(find "$PROJECT_ROOT" -type f \( -name "*.md" -o -name "*.json" -o -name "*.sh" -o -name "*.bat" \) -not -path "*/.git/*" | xargs grep -l "automaze\|automazeio" 2>/dev/null || true)

if [ -z "$FILES" ]; then
    echo "No files found with automaze references."
    exit 0
fi

echo "Files to update:"
echo "$FILES" | sed 's|'"$PROJECT_ROOT"'/||g'
echo ""

FILE_COUNT=$(echo "$FILES" | wc -l | tr -d ' ')
echo "Total: $FILE_COUNT files"
echo ""

read -p "Proceed with update? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Updating files..."
echo ""

# Update each file
for file in $FILES; do
    echo "Processing: $(basename "$file")"

    # Create backup
    cp "$file" "$file.bak"

    # Perform replacements
    sed -i '' \
        -e 's|tegmentum/ccpm|tegmentum/ccpm|g' \
        -e 's|@tegmentum/ccpm|@tegmentum/ccpm|g' \
        -e 's|tegmentum-marketplace|tegmentum-marketplace|g' \
        -e 's|automaze\.io|tegmentum.ai|g' \
        -e 's|support@automaze\.io|zachary.whitley@tegmentum.ai|g' \
        -e 's|Tegmentum|Tegmentum|g' \
        -e 's|automaze|tegmentum|g' \
        "$file"

    # Check if file changed
    if ! diff -q "$file" "$file.bak" > /dev/null 2>&1; then
        echo "  ✓ Updated"
    else
        echo "  - No changes"
    fi

    # Remove backup
    rm "$file.bak"
done

echo ""
echo "=========================================="
echo "Update Complete"
echo "=========================================="
echo ""
echo "Changes made:"
echo "  - tegmentum/ccpm → tegmentum/ccpm"
echo "  - @tegmentum/ccpm → @tegmentum/ccpm"
echo "  - tegmentum-marketplace → tegmentum-marketplace"
echo "  - tegmentum.ai → tegmentum.ai"
echo "  - support@tegmentum.ai → zachary.whitley@tegmentum.ai"
echo "  - Tegmentum → Tegmentum"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Test affected files"
echo "  3. Commit: git add . && git commit -m 'refactor: update branding from Tegmentum to Tegmentum'"
echo ""
