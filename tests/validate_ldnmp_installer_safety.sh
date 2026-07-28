#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/ldnmp.sh"

bash -n "${SCRIPT}"
help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- '--demo-site' <<< "${help_output}"
grep -Fq 'CREATE_DEMO_SITE=false' "${SCRIPT}"
grep -Fq 'validate_php_version()' "${SCRIPT}"
grep -Fq 'MySQL 与 MariaDB 不能同时选择。' "${SCRIPT}"
grep -Fq 'write_root_password()' "${SCRIPT}"
grep -Fq '数据库 root 密码文件: /root/.mysql_root_password' "${SCRIPT}"
grep -Fq 'mkdir -p "${WEB_ROOT}/default"' "${SCRIPT}"

if grep -Fq '数据库root密码:' "${SCRIPT}"; then
    echo "LDNMP installer still prints the database root password." >&2
    exit 1
fi

if grep -Eq 'mkdir -p[[:space:]]+\$\{?WEB_ROOT\}?/|cat >[[:space:]]+\$\{?WEB_ROOT\}?/' "${SCRIPT}"; then
    echo "LDNMP installer has unquoted web-root filesystem writes." >&2
    exit 1
fi

echo "LDNMP installer safety is valid."
