#!/bin/bash
set -u
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
TEMPLATE_DIR=${TEMPLATE_DIR:-$SCRIPT_DIR/templates}
SCAN_FILE=${SCAN_FILE:-$SCRIPT_DIR/scan-config.json}

# Check if the scan file exists
if [[ ! -f "$SCAN_FILE" ]]; then
    echo "ERROR: Scan file $SCAN_FILE does not exist."
    exit 1
fi

# Read the scan file and extract the versions
readarray -t OSS_VERSIONS < <(jq -r '.oss_versions[]' "$SCAN_FILE")
readarray -t AGENT_VERSIONS < <(jq -r '.agent_versions[]' "$SCAN_FILE")

# Check if the versions are not empty
if [[ ${#OSS_VERSIONS[@]} -eq 0 || ${#AGENT_VERSIONS[@]} -eq 0 ]]; then
    echo "ERROR: No versions found in $SCAN_FILE."
    exit 1
fi

# Print the versions
echo "OSS Versions: ${OSS_VERSIONS[*]}"
echo "Agent Versions: ${AGENT_VERSIONS[*]}"

# Check if the versions are valid semver
for version in "${OSS_VERSIONS[@]}" "${AGENT_VERSIONS[@]}"; do
    if [[ ! "$version" =~ ^v?([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
        echo "ERROR: Invalid version format: $version"
        exit 1
    fi
done

# If all checks pass, print success message
echo "All versions are valid semver format."

# Create directories for CVE scans
mkdir -p "$CVE_DIR"/oss "$CVE_DIR"/agent

# Check if syft and grype are installed
if ! command -v syft &> /dev/null || ! command -v grype &> /dev/null || ! command -v grype &> /dev/null; then
    echo "ERROR: jq, syft and grype must be installed to run this script."
    exit 1
fi

# Start constructing a top-level index of all the OSS and Agent scans
cat <<EOF > "$CVE_DIR/cves.md"
# CVE reporting

This page hosts all known information about any security issues, mitigations and triaged CVEs.

Please reach out to us at <info@fluent.do> directly for any specific concerns or queries.

--8<-- "docs/security/triaged.md"

--8<-- "docs/security/agent/grype-latest.md"

## Previous and OSS versions
EOF

function generateReports() {
	local version="${1:?Version is required}"
	local type="${2:?Type is required}"

	# Set the first character to uppercase in the type for display purposes
	local type_capitalised="${type^}"

	local dir="$CVE_DIR/$type"
	[[ ! -d "$dir" ]] && mkdir -p "$dir"

	# Check if SBOMs are already provided, if so skip generation to prevent any issues with non-reproducible builds
	# as some fields may change each time we run in each format.
	# We check for the JSON format as that is the most likely to be used for scans.
	# Syft seems to not want to support this: https://github.com/anchore/syft/issues/1100
	if [[ -f "$dir/syft-$version.json" ]]; then
		echo "SBOMs already exist for $type_capitalised version: $version, skipping syft generation."
	else
	    echo "Running syft for $type_capitalised version: $version"
		if ! syft "ghcr.io/fluentdo/agent:$version" --output json="$dir/syft-$version.json" --output cyclonedx-json="$dir/cyclonedx-$version.cdx.json" --output spdx-json="$dir/spdx-$version.spdx.json"; then
			echo "ERROR: Failed to run syft for $type version: $version, skipping grype scan."
			rm -f "$dir/*-$version.json"
			exit 1
		fi
    fi

	# We always run CVE scans though as new ones may appear.
	# Grype supports reproducible builds as you can disable timestamps in the output which are the only thing that would change.

	# Disable timestamp usage otherwise we get deltas for every run: https://github.com/anchore/grype/pull/2724
	export GRYPE_TIMESTAMP=false

    echo "Running grype for $type_capitalised version: $version"
    grype "sbom:$dir/syft-$version.json" --output json --file "$dir/grype-$version.json"
    grype "sbom:$dir/syft-$version.json" \
		--output template \
		--template "$TEMPLATE_DIR/grype-markdown.tmpl" \
		--file "$dir/grype-$version.md" \
		--sort-by severity

    echo "Grype scan completed for $type_capitalised version: $version"

    # Add to the index file
    {
    echo ""
    echo "### $type_capitalised Version: $version"
    echo ""
    echo "- [Grype Markdown Report]($type/grype-$version.md)"
    echo "- [Grype JSON Report]($type/grype-$version.json)"
	echo ""
    echo "- [Syft JSON SBOM]($type/syft-$version.json)"
    echo "- [CycloneDX JSON SBOM]($type/cyclonedx-$version.cdx.json)"
    echo "- [SPDX JSON SBOM]($type/spdx-$version.spdx.json)"
    } >> "$CVE_DIR/cves.md"
}

# Run grype for each Agent version
for agent_version in "${AGENT_VERSIONS[@]}"; do
	generateReports "$agent_version" "agent"
	# We copy the agent grype report to a "latest" file for easy reference in the main security.md document
	cp "$CVE_DIR/agent/grype-$agent_version.md" "$CVE_DIR/agent/grype-latest.md"
	# We update latest until the final one so assuming the scan config is in order of releases.
done

# Run grype for each OSS version
for oss_version in "${OSS_VERSIONS[@]}"; do
	generateReports "$oss_version" "oss"
done

# Now iterate over each JSON file and ensure we pretty-print it rather than all on one line.
for json_file in "$CVE_DIR"/oss/*.json "$CVE_DIR"/agent/*.json; do
	if [[ -f "$json_file" ]]; then
		echo "Pretty-printing JSON file: $json_file"
		jq . "$json_file" > "$json_file.tmp" && mv "$json_file.tmp" "$json_file"
	fi
done

# Validate that all expected SBOM and scan files are non-empty and contain valid content
echo "Validating generated files..."
validation_failed=false

function validateFiles() {
	local version="${1:?Version is required}"
	local dir="${2:?Directory is required}"
	local expected_files=(
		"syft-$version.json"
		"cyclonedx-$version.cdx.json"
		"spdx-$version.spdx.json"
		"grype-$version.json"
		"grype-$version.md"
	)

	for file in "${expected_files[@]}"; do
		local file_path="$dir/$file"
		if [[ ! -f "$file_path" ]] || [[ ! -s "$file_path" ]]; then
			echo "ERROR: File $file_path is missing or empty"
			validation_failed=true
		elif [[ "$file" == *.json ]] && ! jq empty "$file_path" 2>/dev/null; then
			echo "ERROR: File $file_path contains invalid JSON"
			validation_failed=true
		fi
	done
}

for agent_version in "${AGENT_VERSIONS[@]}"; do
	validateFiles "$agent_version" "$CVE_DIR/agent"
done

for oss_version in "${OSS_VERSIONS[@]}"; do
	validateFiles "$oss_version" "$CVE_DIR/oss"
done

if [[ "$validation_failed" == "true" ]]; then
    echo "ERROR: Validation failed - some files are missing, empty, or contain invalid JSON"
    exit 1
fi

echo "CVE scans completed. Reports are available in $CVE_DIR"
