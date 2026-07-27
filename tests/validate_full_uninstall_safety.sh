#!/bin/bash
# ==============================================================================
# Script: tests/validate_full_uninstall_safety.sh
# Purpose: Guard full-uninstall backup placement and removal scope.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/uninstall_scripts/full_uninstall.sh"

bash -n "${SCRIPT}"
grep -Fq 'BACKUP_ROOT="${VPS_BACKUP_ROOT:-/var/backups/vps_scripts}"' "${SCRIPT}"
grep -Fq 'is_managed_command()' "${SCRIPT}"
grep -Fq 'is_managed_install_dir()' "${SCRIPT}"
grep -Fq 'safe_remove_file "$INSTALL_COMMAND"' "${SCRIPT}"
grep -Fq 'safe_remove_dir "$INSTALL_LIB_DIR"' "${SCRIPT}"
grep -Fq 'safe_remove_dir "$LOG_DIR"' "${SCRIPT}"
grep -Fq 'cp -a "$INSTALL_LIB_DIR" "${BACKUP_DIR}/vps-scripts"' "${SCRIPT}"

if grep -Eq 'BACKUP_DIR=.*PARENT_DIR|cp[[:space:]]+-r[[:space:]]+"\$PARENT_DIR"' "${SCRIPT}"; then
    echo "Full uninstall still backs a directory up inside itself." >&2
    exit 1
fi

if grep -Eq 'systemctl|apt-get|yum|dnf|/var/lib/docker|/var/lib/mysql|/var/www' "${SCRIPT}"; then
    echo "Full uninstall still mutates non-project services or data." >&2
    exit 1
fi

echo "Full uninstall safety is valid."
