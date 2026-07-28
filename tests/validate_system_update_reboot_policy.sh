#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/system_tools/update_system.sh"

bash -n "${SCRIPT}"
help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- '--reboot' <<< "${help_output}"
grep -Fq 'REBOOT_AFTER_UPDATE=false' "${SCRIPT}"
grep -Fq -- '--reboot) REBOOT_AFTER_UPDATE=true' "${SCRIPT}"
grep -Fq '[ "${REBOOT_AFTER_UPDATE}" = "true" ]' "${SCRIPT}"
grep -Fq '自动确认模式不会自动重启；请使用 --reboot 明确请求重启。' "${SCRIPT}"
grep -Fq 'Reboot Requested: ${REBOOT_AFTER_UPDATE}' "${SCRIPT}"

if grep -Fq 'if [ "${AUTO_CONFIRM}" = "true" ]; then' "${SCRIPT}" && \
   grep -Fq '已启用自动模式，系统将在 5 秒后重启...' "${SCRIPT}"; then
    echo "Automatic update confirmation still implies reboot." >&2
    exit 1
fi

echo "System update reboot policy is valid."
