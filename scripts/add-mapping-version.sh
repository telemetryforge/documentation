#!/bin/bash
set -eu
# This does not work with a symlink to this script
# SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# See https://stackoverflow.com/a/246128/24637657
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  [[ $SOURCE != /* ]] && SOURCE=$SCRIPT_DIR/$SOURCE
done
SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
REPO_ROOT=${REPO_ROOT:-$SCRIPT_DIR/..}
DOCS_DIR=${DOCS_DIR:-$REPO_ROOT/docs}
MAPPING_FILE=${MAPPING_FILE:-$DOCS_DIR/version-mapping.md}

NEW_OSS_VERSION=${NEW_OSS_VERSION:?}
NEW_AGENT_VERSION=${NEW_AGENT_VERSION:?}

# Handle version string with or without a v prefix - we just want semver
if [[ "$NEW_OSS_VERSION" =~ ^v?([0-9]+\.[0-9]+\.[0-9]+)$ ]] ; then
    NEW_OSS_VERSION=${BASH_REMATCH[1]}
    echo "Valid OSS version string: $NEW_OSS_VERSION"
else
    echo "ERROR: Invalid OSS semver string: $NEW_OSS_VERSION"
    exit 1
fi

# Handle version string with or without a v prefix - we just want semver
if [[ "$NEW_AGENT_VERSION" =~ ^v?([0-9]+\.[0-9]+\.[0-9]+)$ ]] ; then
    NEW_AGENT_VERSION=${BASH_REMATCH[1]}
    echo "Valid FluentDo agent version string: $NEW_AGENT_VERSION"
else
    echo "ERROR: Invalid FluentDo agent semver string: $NEW_AGENT_VERSION"
    exit 1
fi

# Check if the mapping file exists
if [[ ! -f "$MAPPING_FILE" ]]; then
    echo "ERROR: Mapping file $MAPPING_FILE does not exist."
    exit 1
fi
# Update the mapping file with the new version
if grep -q "| $NEW_AGENT_VERSION |" "$MAPPING_FILE"; then
    echo "ERROR: Mapping for FluentDo Agent version $NEW_AGENT_VERSION already exists in $MAPPING_FILE."
    exit 1
fi

# Find the table header line and insert the new mapping after it
HEADER_LINE=$(grep -n "|FluentDo Agent Version|" "$MAPPING_FILE" | cut -d: -f1)
if [[ -z "$HEADER_LINE" ]]; then
    echo "ERROR: Header line not found in $MAPPING_FILE."
    exit 1
fi
INSERT_LINE=$((HEADER_LINE + 2)) # Insert after the header and separator lines
NEW_MAPPING="| $NEW_AGENT_VERSION | $NEW_OSS_VERSION |"
# Insert the new mapping line
sed -i "${INSERT_LINE}i $NEW_MAPPING" "$MAPPING_FILE"
echo "Updated $MAPPING_FILE with new mapping: $NEW_MAPPING"

# Output the updated mapping file
echo "Current version mapping:"
cat "$MAPPING_FILE"
