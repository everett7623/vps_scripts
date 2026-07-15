#!/bin/bash
# ==============================================================================
# Script: tests/validate_release_metadata.sh
# Purpose: Keep release version, date, changelog, and public docs synchronized.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

extract_json_value() {
    local key="$1"
    sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" \
        "${REPO_ROOT}/version.json" | head -1
}

version=$(extract_json_value "version")
release_date=$(extract_json_value "release_date")

if ! [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid semantic version in version.json: ${version}" >&2
    exit 1
fi

if ! [[ "${release_date}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Invalid release date in version.json: ${release_date}" >&2
    exit 1
fi

require_text() {
    local file="$1"
    local text="$2"

    if ! grep -Fq "${text}" "${REPO_ROOT}/${file}"; then
        echo "Release metadata mismatch in ${file}: ${text}" >&2
        exit 1
    fi
}

require_text "config/vps_scripts.conf" "SCRIPT_VERSION=\"${version}\""
require_text "vps.sh" "PROJECT_VERSION=\"${version}\""
require_text "README.md" "version-${version}-blue.svg"
require_text "VERSIONING.md" "active project version listed as \`${version}\`"
require_text "CHANGELOG.md" "## ${version} - ${release_date}"
require_text "RELEASE_CHECKLIST.md" "tests/validate_release_metadata.sh"

echo "Release metadata is synchronized for ${version} (${release_date})."
