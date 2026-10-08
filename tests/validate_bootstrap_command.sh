#!/bin/bash
# ==============================================================================
# Script: tests/validate_bootstrap_command.sh
# Purpose: Keep public bootstrap commands on the shared one-line format.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

PRIMARY_URL="https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps.sh"
ONE_LINER="curl -fsSL ${PRIMARY_URL} -o /tmp/vps.sh && bash /tmp/vps.sh"

fail() {
    echo "$1" >&2
    exit 1
}

# README must advertise the one-liner and must not keep the old 3-line mktemp dance
grep -Fq "${ONE_LINER}" "${REPO_ROOT}/README.md" || fail "README.md missing canonical bootstrap one-liner"
if grep -Fq 'tmp_script=$(mktemp /tmp/vps.XXXXXX)' "${REPO_ROOT}/README.md"; then
    fail "README.md still uses multi-line mktemp bootstrap"
fi

# Launcher update hint
grep -Fq 'curl -fsSL ${GITHUB_RAW_URL}/vps.sh -o /tmp/vps.sh && bash /tmp/vps.sh' "${REPO_ROOT}/vps.sh" \
    || fail "vps.sh update hint missing one-line bootstrap"

# Legacy launcher quick-start hint
grep -Fq 'curl -fsSL ${SCRIPT_URL} -o /tmp/vps.sh && bash /tmp/vps.sh' "${REPO_ROOT}/vps_scripts.sh" \
    || fail "vps_scripts.sh quick-start missing one-line bootstrap"

# Do not reintroduce process-substitution bootstrap in public docs
if grep -Eq 'bash[[:space:]]+<\(curl|curl[^\n]*\|[[:space:]]*bash' "${REPO_ROOT}/README.md"; then
    fail "README.md reintroduced curl|bash or process-substitution bootstrap"
fi

echo "Bootstrap command format is valid."
