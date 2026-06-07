#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
TEST_ROOT=$(mktemp -d "/tmp/vps-command-test.XXXXXX")

cleanup() {
    rm -rf "${TEST_ROOT}"
}
trap cleanup EXIT

VPS_INSTALL_PREFIX="${TEST_ROOT}/usr/local" \
VPS_INSTALL_SOURCE_OVERRIDE="${REPO_ROOT}/vps.sh" \
bash "${REPO_ROOT}/vps.sh" --install >/dev/null

test -x "${TEST_ROOT}/usr/local/bin/vps"
test -x "${TEST_ROOT}/usr/local/lib/vps-scripts/vps.sh"

PATH="${TEST_ROOT}/usr/local/bin:${PATH}" vps --help | grep -q -- "--install"

VPS_INSTALL_PREFIX="${TEST_ROOT}/usr/local" \
bash "${REPO_ROOT}/vps.sh" --uninstall-command >/dev/null

test ! -e "${TEST_ROOT}/usr/local/bin/vps"
test ! -e "${TEST_ROOT}/usr/local/lib/vps-scripts/vps.sh"

echo "Persistent command install lifecycle is valid."
