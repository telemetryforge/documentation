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

# Disable timestamp usage otherwise we get deltas for every run: https://github.com/anchore/grype/pull/2724
export GRYPE_TIMESTAMP=false

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
if ! command -v syft &> /dev/null || ! command -v grype &> /dev/null; then
    echo "ERROR: syft and grype must be installed to run this script."
    exit 1
fi

# Start constructing a top-level index of all the OSS and Agent scans
cat <<EOF > "$CVE_DIR/cves.md"
# CVE reporting

This page hosts all known information about any security issues, mitigations and triaged CVEs.

Please reach out to us at <info@fluent.do> directly for any specific concerns or queries.
EOF

# Run grype for each Agent version
for agent_version in "${AGENT_VERSIONS[@]}"; do
    echo "Running syft for Agent version: $agent_version"
    if ! syft "ghcr.io/fluentdo/agent:$agent_version" --output json="$CVE_DIR/agent/syft-$agent_version.json" --output cyclonedx-json="$CVE_DIR/agent/cyclonedx-$agent_version.json" --output spdx-json="$CVE_DIR/agent/spdx-$agent_version.json"; then
        echo "Failed to run syft for Agent version: $agent_version, skipping grype scan."
        rm -f "$CVE_DIR/agent/*-$agent_version.json"
        continue
    fi

    [[ ! -f "$CVE_DIR/agent/syft-$agent_version.json" ]] && continue

    echo "Running grype for Agent version: $agent_version"
    grype "sbom:$CVE_DIR/agent/syft-$agent_version.json" --output json --file "$CVE_DIR/agent/grype-$agent_version.json"
    grype "sbom:$CVE_DIR/agent/syft-$agent_version.json" --output template --template "$TEMPLATE_DIR/grype-markdown.tmpl" --file "$CVE_DIR/agent/grype-$agent_version.md" --sort-by severity
    # grype "sbom:$CVE_DIR/agent/syft-$agent_version.json" --output template --template "$TEMPLATE_DIR/grype-html.tmpl" --file "$CVE_DIR/agent/grype-$agent_version.html"

    echo "Grype scan completed for Agent version: $agent_version"

    # Add to the index file
    {
    echo ""
    echo "## Agent Version: $agent_version"
    echo ""
    echo "- [Grype Markdown Report](agent/grype-$agent_version.md)"
    echo "- [Grype JSON Report](agent/grype-$agent_version.json)"
	echo ""
    echo "- [Syft JSON SBOM](agent/syft-$agent_version.json)"
    echo "- [CycloneDX JSON SBOM](agent/cyclonedx-$agent_version.json)"
    echo "- [SPDX JSON SBOM](agent/spdx-$agent_version.json)"
    } >> "$CVE_DIR/cves.md"
done

# Run grype for each OSS version
for oss_version in "${OSS_VERSIONS[@]}"; do
    # Generate syft output first as one-off that can then be fed to grype for each output format
    echo "Running syft for OSS version: $oss_version"
    if ! syft "ghcr.io/fluent/fluent-bit:$oss_version" --output json="$CVE_DIR/oss/syft-$oss_version.json" --output cyclonedx-json="$CVE_DIR/oss/cyclonedx-$oss_version.json" --output spdx-json="$CVE_DIR/oss/spdx-$oss_version.json"; then
        echo "Failed to run syft for OSS version: $oss_version, skipping grype scan."
        rm -f "$CVE_DIR/oss/syft-$oss_version.json"
        continue
    fi

    [[ ! -f "$CVE_DIR/oss/syft-$oss_version.json" ]] && continue

    echo "Running grype for OSS version: $oss_version"
    grype "sbom:$CVE_DIR/oss/syft-$oss_version.json" --output json --file "$CVE_DIR/oss/grype-$oss_version.json"
    grype "sbom:$CVE_DIR/oss/syft-$oss_version.json" --output template --template "$TEMPLATE_DIR/grype-markdown.tmpl" --file "$CVE_DIR/oss/grype-$oss_version.md" --sort-by severity
    # grype "sbom:$CVE_DIR/oss/syft-$oss_version.json" --output template --template "$TEMPLATE_DIR/grype-html.tmpl" --file "$CVE_DIR/oss/grype-$oss_version.html"

    echo "Grype scan completed for OSS version: $oss_version"

    # Add to the index file
    {
    echo ""
    echo "## OSS Version: $oss_version"
    echo ""
    echo "- [Grype Markdown Report](oss/grype-$oss_version.md)"
    echo "- [Grype JSON Report](oss/grype-$oss_version.json)"
    echo ""
    echo "- [Syft JSON SBOM](oss/syft-$oss_version.json)"
    echo "- [CycloneDX JSON SBOM](oss/cyclonedx-$oss_version.json)"
    echo "- [SPDX JSON SBOM](oss/spdx-$oss_version.json)"
    } >> "$CVE_DIR/cves.md"
done
