#!/bin/bash
# ==============================================================================
# Script: tests/validate_noninteractive_package_ops.sh
# Purpose: Ensure first-party apt/apt-get calls cannot block on debconf prompts
#          and that system upgrades keep locally modified configuration files.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

COMMON_FILE="${REPO_ROOT}/lib/common_functions.sh"
UPDATE_FILE="${REPO_ROOT}/scripts/system_tools/update_system.sh"
LAUNCHER_FILE="${REPO_ROOT}/vps.sh"
EXPORT_LINE='export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"'

failures=0
fail() {
    echo "$1" >&2
    failures=$((failures + 1))
}

# Every first-party script that invokes apt/apt-get must export a
# non-interactive debconf frontend before any package operation runs.
while IFS= read -r script; do
    if ! grep -Fqx "${EXPORT_LINE}" "${script}"; then
        fail "Missing non-interactive DEBIAN_FRONTEND export: ${script#"${REPO_ROOT}/"}"
        continue
    fi
    export_line=$(grep -Fnx "${EXPORT_LINE}" "${script}" | head -n 1 | cut -d: -f1)
    first_apt=$(grep -nE '^[^#]*\bapt(-get)? +(-[a-zA-Z]+ +)*(update|install|upgrade|dist-upgrade|full-upgrade|remove|purge|autoremove|autoclean|clean)\b' "${script}" \
        | head -n 1 | cut -d: -f1 || true)
    # Function bodies may appear before the export line; only top-level calls
    # before the export would run without it, and those do not exist today.
    if [ -n "${first_apt}" ] && [ "${first_apt}" -lt "${export_line}" ]; then
        if sed -n "${first_apt}p" "${script}" | grep -qE '^[a-zA-Z_]'; then
            fail "Top-level apt call before DEBIAN_FRONTEND export: ${script#"${REPO_ROOT}/"}:${first_apt}"
        fi
    fi
done < <(grep -rlE '^[^#]*\bapt(-get)? ' --include='*.sh' "${REPO_ROOT}/scripts" | sort)

grep -Fq 'env DEBIAN_FRONTEND=noninteractive apt-get update -qq' "${COMMON_FILE}" \
    || fail "ensure_command apt-get update is not non-interactive"
grep -Fq 'env DEBIAN_FRONTEND=noninteractive apt-get install -y "${package}"' "${COMMON_FILE}" \
    || fail "ensure_command apt-get install is not non-interactive"

grep -Fq 'APT_KEEP_CONF_OPTS=(-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)' "${UPDATE_FILE}" \
    || fail "update_system.sh does not define keep-config dpkg options"
grep -Fq 'UPDATE_CMD=(env DEBIAN_FRONTEND=noninteractive apt-get update -qq)' "${UPDATE_FILE}" \
    || fail "update_system.sh apt update is not non-interactive"
grep -Fq 'FULL_UPDATE_CMD=(env DEBIAN_FRONTEND=noninteractive apt-get "${APT_KEEP_CONF_OPTS[@]}" upgrade -y)' "${UPDATE_FILE}" \
    || fail "update_system.sh apt upgrade must be non-interactive and keep configs"
grep -Fq 'DIST_UPDATE_CMD=(env DEBIAN_FRONTEND=noninteractive apt-get "${APT_KEEP_CONF_OPTS[@]}" dist-upgrade -y)' "${UPDATE_FILE}" \
    || fail "update_system.sh apt dist-upgrade must be non-interactive and keep configs"
grep -Fq 'CLEANUP_CMD=(env DEBIAN_FRONTEND=noninteractive apt-get autoremove -y)' "${UPDATE_FILE}" \
    || fail "update_system.sh apt autoremove is not non-interactive"
grep -Fq 'FULL_UPDATE_CMD=(dnf update -y)' "${UPDATE_FILE}" || fail "dnf update must use -y"
grep -Fq 'FULL_UPDATE_CMD=(yum update -y)' "${UPDATE_FILE}" || fail "yum update must use -y"
grep -Fq 'FULL_UPDATE_CMD=(pacman -Su --noconfirm)' "${UPDATE_FILE}" || fail "pacman update must use --noconfirm"

if grep -nE '"apt-get install -y tmux' "${LAUNCHER_FILE}" >/dev/null; then
    fail "Launcher tmux entry must set DEBIAN_FRONTEND=noninteractive"
fi

# Executed check: the exported default must not override a caller's choice.
value=$(DEBIAN_FRONTEND=readline bash -c "${EXPORT_LINE}; printf '%s' \"\${DEBIAN_FRONTEND}\"")
[ "${value}" = "readline" ] || fail "DEBIAN_FRONTEND export overrides caller value"
value=$(env -u DEBIAN_FRONTEND bash -c "${EXPORT_LINE}; printf '%s' \"\${DEBIAN_FRONTEND}\"")
[ "${value}" = "noninteractive" ] || fail "DEBIAN_FRONTEND export default is not noninteractive"

if [ "${failures}" -ne 0 ]; then
    echo "Non-interactive package operation checks failed: ${failures}" >&2
    exit 1
fi

echo "Non-interactive package operations are valid."
