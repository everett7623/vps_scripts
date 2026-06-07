#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/common_functions.sh"

unset REPLY 2>/dev/null || true
read_input "test" "" <<< "1"
[ "${REPLY}" = "1" ]

selected=""
read_input "test" "" selected <<< "Asia/Shanghai"
[ "${selected}" = "Asia/Shanghai" ]

default_answer=""
read_input "test" "y" default_answer <<< ""
[ "${default_answer}" = "y" ]

grep -Fq 'read_input "请输入时区编号或完整时区名称" "" selection' \
    "${REPO_ROOT}/scripts/system_tools/set_timezone.sh"
grep -Fq 'read_input "请输入新的主机名" "" new_name' \
    "${REPO_ROOT}/scripts/system_tools/change_hostname.sh"

if grep -Fq 'update_ntp_choice_from_reply' "${REPO_ROOT}/scripts/system_tools/set_timezone.sh"; then
    echo "Legacy REPLY-based NTP input remains." >&2
    exit 1
fi

echo "Interactive input contract is valid."
