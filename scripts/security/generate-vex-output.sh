#!/bin/bash
set -eu

# This script generates VEX output from the triaged input files in `docs/security/triaged`.
# We use the `vexctl` tool to generate the initial input manually under a CVE directory.
# Each CVE directory contains one or more `*.vex.json` files that need to be merged.
# The final output is a `vex.json` file in each CVE directory and a markdown table in `docs/security/triaged.md`.
# The markdown table contains the CVE ID, status, and a relative link to the `vex.json` file.

# Prerequisites:
# - `vexctl` tool installed and available in PATH.
# - `jq` tool installed for JSON processing.

# For each directory in `docs/security/triaged`:
# 1. Merge all the `*.vex.json` files into a single `vex.json` file in the same directory using `vexctl merge`.
# 2. Take the final output status in the `vex.json` file and add it to a markdown table for the CVE with a relative link to the `vex.json` file.
# 3. Append the markdown table to `docs/security/triaged.md`.
#
# Finally we combine all the individual vex.json files into a single vex.json file for customers/users.

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

REPO_ROOT=${REPO_ROOT:-$SCRIPT_DIR/../..}
CVE_DIR=${CVE_DIR:-$REPO_ROOT/docs/security}
OUTPUT_MD=${OUTPUT_MD:-"$CVE_DIR/triaged.md"}
TRIAGED_DIR=${TRIAGED_DIR:-"$CVE_DIR/triaged"}
AUTHOR=${AUTHOR:-"info@fluent.do"}

COMBINED_VEX_FILE=${COMBINED_VEX_FILE:-"$CVE_DIR/vex.json"}
RELATIVE_VEX_PATH=$(realpath --relative-to="$(dirname "$OUTPUT_MD")" "$COMBINED_VEX_FILE")

if ! command -v vexctl &> /dev/null; then
	echo "ERROR: vexctl could not be found. Please install it and ensure it's in your PATH."
	exit 1
fi
if ! command -v jq &> /dev/null; then
	echo "ERROR: jq could not be found. Please install it and ensure it's in your PATH."
	exit 1
fi

# Create or overwrite the output markdown file with header
{
	echo "# Triaged Security Vulnerabilities"
	echo ""
	echo "This document lists all triaged security vulnerabilities along with their VEX status."
	echo ""
	echo "A VEX document is available to [download]($RELATIVE_VEX_PATH) for automation."
	echo ""
	echo "| CVE | Status | Notes |"
	echo "| --- | ------ | ----- |"
} > "$OUTPUT_MD"

for dir in "$TRIAGED_DIR"/*/; do
	if [ -d "$dir" ]; then
		echo "Processing directory: $dir"
		MERGED_VEX_FILE="$dir/vex.json"

		# Merge all *.vex.json files into a single vex.json file
		vexctl merge --author "$AUTHOR" "$dir"/*.vex.json | tee "$MERGED_VEX_FILE"

		# Extract CVE and status from the merged vex.json file
		CVE_ID=$(jq -r '.statements[0].vulnerability.name' "$MERGED_VEX_FILE")
		# We need to take the final status in the statement array
		STATUS=$(jq -r '.statements[-1].status' "$MERGED_VEX_FILE")
		# Also take the impact statement to add to the markdown, if present.
		IMPACT_STATEMENT=$(jq -r '.statements[-1].impact_statement' "$MERGED_VEX_FILE")

		echo "CVE: $CVE_ID, Status: $STATUS"

		# Validate CVE_ID format
		if [[ ! $CVE_ID =~ ^CVE-[0-9]{4}-[0-9]{4,}$ ]]; then
			echo "ERROR: Invalid CVE ID format: $CVE_ID. Skipping."
			exit 1
		fi

		# Validate STATUS value
		if [[ ! $STATUS =~ ^(fixed|not_affected|under_investigation|will_not_fix)$ ]]; then
			echo "ERROR: Invalid status value: $STATUS. Skipping."
			exit 1
		fi

		# Append to markdown table
		RELATIVE_PATH=$(realpath --relative-to="$(dirname "$OUTPUT_MD")" "$MERGED_VEX_FILE")
		echo "| [$CVE_ID]($RELATIVE_PATH) | $STATUS | $IMPACT_STATEMENT |" >> "$OUTPUT_MD"
	fi
done

echo "Triaged vulnerabilities documentation generated at $OUTPUT_MD"

# Combine all individual vex.json files into a single vex.json file in the root of the repository
find "$TRIAGED_DIR" -type f -name "vex.json" -exec vexctl merge --author "$AUTHOR" {} + | tee "$COMBINED_VEX_FILE"

echo "Combined VEX file generated at $COMBINED_VEX_FILE"
