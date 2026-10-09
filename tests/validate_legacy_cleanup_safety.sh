#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

CLEAN_SERVICE="${REPO_ROOT}/scripts/uninstall_scripts/clean_service_residues.sh"
CLEAR_CONFIG="${REPO_ROOT}/scripts/uninstall_scripts/clear_configuration_files.sh"
ROLLBACK_ENV="${REPO_ROOT}/scripts/uninstall_scripts/rollback_system_environment.sh"

fail() {
    echo "$*" >&2
    exit 1
}

for script in "${CLEAN_SERVICE}" "${CLEAR_CONFIG}" "${ROLLBACK_ENV}"; do
    bash -n "${script}"
    for flag in --help --list --dry-run --yes --target; do
        grep -Eq -- "^[[:space:]]*${flag}[|)]" "${script}" || fail "${script} is missing ${flag}"
    done
    grep -Fq 'BACKUP_ROOT="${VPS_BACKUP_ROOT:-/var/backups/vps_scripts}"' "${script}" ||
        fail "${script} must back up outside the launcher's temporary runtime directory"
    if grep -Fq 'bash "$0"' "${script}"; then
        fail "${script} still re-executes itself for batch mode"
    fi
    if grep -Eq 'PARENT_DIR/backup' "${script}"; then
        fail "${script} still writes backups into the script directory"
    fi
done

grep -Fq 'WordPress需要指定目录，未包含在批量清理中' "${CLEAN_SERVICE}"
grep -Fq '"${wp_dir}" != /*' "${CLEAN_SERVICE}"
grep -Fq '"${wp_dir}/wp-config.php"' "${CLEAN_SERVICE}"
grep -Fq -- '--purge-data' "${CLEAN_SERVICE}"
grep -Fq 'is_protected_path' "${CLEAN_SERVICE}"
if grep -Eq 'rm -rf -- /var/www/html' "${CLEAN_SERVICE}"; then
    fail "Service cleanup must not delete /var/www/html site data."
fi

grep -Fq 'sshd -t' "${CLEAR_CONFIG}"

grep -Fq 'current_hostname=$(hostname)' "${ROLLBACK_ENV}"
grep -Fq 'is_valid_hostname' "${ROLLBACK_ENV}"
grep -Fq 'swapoff -- "${SWAP_FILE}"' "${ROLLBACK_ENV}"
if grep -Eq 'swapoff -a|/swap/d' "${ROLLBACK_ENV}"; then
    fail "Rollback must only touch /swapfile, not every swap device."
fi

echo "Legacy cleanup safety checks are valid."
