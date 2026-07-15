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

printf '0\n' | \
    VPS_INSTALL_PREFIX="${TEST_ROOT}/usr/local" \
    VPS_INSTALL_SOURCE_OVERRIDE="${REPO_ROOT}/vps.sh" \
    VPS_AUTO_INSTALL_COMMAND=true \
    bash "${REPO_ROOT}/vps.sh" >/dev/null

test -x "${TEST_ROOT}/usr/local/bin/vps"
test -x "${TEST_ROOT}/usr/local/lib/vps-scripts/vps.sh"

VPS_INSTALL_PREFIX="${TEST_ROOT}/usr/local" \
bash "${REPO_ROOT}/vps.sh" --uninstall-command >/dev/null

printf '0\n' | \
    VPS_INSTALL_PREFIX="${TEST_ROOT}/usr/local" \
    VPS_INSTALL_SOURCE_OVERRIDE="${REPO_ROOT}/vps.sh" \
    VPS_AUTO_INSTALL_COMMAND=auto \
    bash "${REPO_ROOT}/vps.sh" >/dev/null

test ! -e "${TEST_ROOT}/usr/local/bin/vps"

printf '0\n' | \
    VPS_INSTALL_PREFIX="${TEST_ROOT}/usr/local" \
    VPS_INSTALL_SOURCE_OVERRIDE="${REPO_ROOT}/vps.sh" \
    VPS_AUTO_INSTALL_COMMAND=false \
    bash "${REPO_ROOT}/vps.sh" >/dev/null

test ! -e "${TEST_ROOT}/usr/local/bin/vps"
test ! -e "${TEST_ROOT}/usr/local/lib/vps-scripts/vps.sh"

mkdir -p "${TEST_ROOT}/usr/local/bin"
printf '%s\n' '#!/bin/bash' 'echo occupied' > "${TEST_ROOT}/usr/local/bin/vps"
chmod 0755 "${TEST_ROOT}/usr/local/bin/vps"

printf '0\n' | \
    VPS_INSTALL_PREFIX="${TEST_ROOT}/usr/local" \
    VPS_INSTALL_SOURCE_OVERRIDE="${REPO_ROOT}/vps.sh" \
    VPS_AUTO_INSTALL_COMMAND=true \
    bash "${REPO_ROOT}/vps.sh" >/dev/null

grep -Fq 'echo occupied' "${TEST_ROOT}/usr/local/bin/vps"
test ! -e "${TEST_ROOT}/usr/local/lib/vps-scripts/vps.sh"

echo "Persistent command install lifecycle is valid."
