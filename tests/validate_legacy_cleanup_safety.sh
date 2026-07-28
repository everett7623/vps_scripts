#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

CLEAN_SERVICE="${REPO_ROOT}/scripts/uninstall_scripts/clean_service_residues.sh"
CLEAR_CONFIG="${REPO_ROOT}/scripts/uninstall_scripts/clear_configuration_files.sh"
ROLLBACK_ENV="${REPO_ROOT}/scripts/uninstall_scripts/rollback_system_environment.sh"

for script in "${CLEAN_SERVICE}" "${CLEAR_CONFIG}" "${ROLLBACK_ENV}"; do
    bash -n "${script}"
done

grep -Fq "printf 'y\\n%s\\n' \"\${service_choice}\" | bash \"\$0\"" "${CLEAN_SERVICE}"
grep -Fq 'WordPress需要指定目录，未包含在批量清理中' "${CLEAN_SERVICE}"
grep -Fq '"${wp_dir}" != /*' "${CLEAN_SERVICE}"
grep -Fq '"${wp_dir}/wp-config.php"' "${CLEAN_SERVICE}"
grep -Fq "printf 'y\\n%s\\n' \"\${config_choice}\" | bash \"\$0\"" "${CLEAR_CONFIG}"
grep -Fq "printf 'y\\n%s\\n' \"\${environment_choice}\" | bash \"\$0\"" "${ROLLBACK_ENV}"
grep -Fq 'current_hostname=$(hostname)' "${ROLLBACK_ENV}"

echo "Legacy cleanup safety checks are valid."
