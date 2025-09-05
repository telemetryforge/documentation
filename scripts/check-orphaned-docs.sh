#!/bin/bash
set -eu

# Script to check for orphaned markdown files in docs/ directory
# that are not referenced in mkdocs.yml navigation

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="${REPO_ROOT:-$SCRIPT_DIR/..}"
DOCS_DIR="${DOCS_DIR:-$REPO_ROOT/docs}"
MKDOCS_CONFIG="${MKDOCS_CONFIG:-$REPO_ROOT/mkdocs.yml}"

# Specify any files to ignore in this file
IGNORE_FILE="${IGNORE_FILE:-$REPO_ROOT/.orphaned-docs-ignore}"

if [ ! -f "$MKDOCS_CONFIG" ]; then
    echo "ERROR: mkdocs.yml not found at $MKDOCS_CONFIG"
    exit 1
fi

if [ ! -d "$DOCS_DIR" ]; then
    echo "ERROR: docs directory not found at $DOCS_DIR"
    exit 1
fi

echo "Checking for orphaned markdown files in $DOCS_DIR..."

# Find all markdown files in docs directory
MARKDOWN_FILES=$(find "$DOCS_DIR" -iname "*.md" -type f)

# Read ignore patterns if file exists
IGNORE_PATTERNS=()
if [ -f "$IGNORE_FILE" ]; then
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        IGNORE_PATTERNS+=("$line")
    done < "$IGNORE_FILE"
fi

ORPHANED_FILES=()
TOTAL_FILES=0

for file in $MARKDOWN_FILES; do
    TOTAL_FILES=$((TOTAL_FILES + 1))

    # Get relative path from docs directory
    REL_PATH=$(realpath --relative-to="$DOCS_DIR" "$file")

    # Check if file should be ignored
    SHOULD_IGNORE=false
    for pattern in "${IGNORE_PATTERNS[@]}"; do
        if [[ "$REL_PATH" == $pattern ]]; then
            echo "Ignoring: $REL_PATH (matches pattern: $pattern)"
            SHOULD_IGNORE=true
            break
        fi
    done

    if [ "$SHOULD_IGNORE" = true ]; then
        continue
    fi

    # Check if referenced in mkdocs.yml
    if ! grep -q "$REL_PATH" "$MKDOCS_CONFIG"; then
        ORPHANED_FILES+=("$REL_PATH")
        echo "ORPHANED: $REL_PATH"
    else
        echo "Referenced: $REL_PATH"
    fi
done

echo ""
echo "Summary:"
echo "- Total markdown files found: $TOTAL_FILES"
echo "- Orphaned files: ${#ORPHANED_FILES[@]}"

if [ ${#ORPHANED_FILES[@]} -gt 0 ]; then
    echo ""
    echo "ERROR: Found ${#ORPHANED_FILES[@]} orphaned markdown file(s):"
    for file in "${ORPHANED_FILES[@]}"; do
        echo "  - $file"
    done
    echo ""
    echo "These files are not referenced in mkdocs.yml navigation."
    echo "Either add them to the navigation or add them to .orphaned-docs-ignore"
    echo "if they should be excluded from this check."
    exit 1
fi

echo ""
echo "All markdown files are properly referenced in mkdocs.yml or explicitly ignored."
