#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
LAUNCHER="${LAUNCHER_OVERRIDE:-${REPO_ROOT}/vps.sh}"
NEZHA_SCRIPT="${REPO_ROOT}/scripts/other_tools/nezha.sh"
LDNMP_SCRIPT="${REPO_ROOT}/scripts/service_install/ldnmp.sh"
BANDWIDTH_SCRIPT="${REPO_ROOT}/scripts/network_test/bandwidth_test.sh"

for script in "${LAUNCHER}" "${NEZHA_SCRIPT}" "${LDNMP_SCRIPT}" "${BANDWIDTH_SCRIPT}"; do
    bash -n "${script}"
done

grep -Fq 'local -a script_args=("$@")' "${LAUNCHER}"
grep -Fq '(cd "${temp_root}" && bash "${temp_file}" "${script_args[@]}")' "${LAUNCHER}"
if grep -Eq 'run_remote_command "[^"\n]*(\|[[:space:]]*(bash|sh)|bash[[:space:]]+<\()' "${LAUNCHER}"; then
    echo "Launcher contains a remote shell pipeline or process substitution." >&2
    exit 1
fi

grep -Fq 'systemd-escape -- "${server}:${port}"' "${NEZHA_SCRIPT}"
grep -Fq 'systemd-analyze verify /etc/systemd/system/nezha-agent.service' "${NEZHA_SCRIPT}"
grep -Fq 'tar -tzf "${ARCHIVE_FILE}" | grep -qx '\''nezha-agent'\''' "${NEZHA_SCRIPT}"
grep -Fq 'run_remote_bash_installer()' "${LDNMP_SCRIPT}"
grep -Fq 'signed-by=/usr/share/keyrings/nginx-signing.gpg' "${LDNMP_SCRIPT}"
grep -Fq 'signed-by=/usr/share/keyrings/sury-php.gpg' "${LDNMP_SCRIPT}"
if grep -Eq 'curl[^\n]*\|[[:space:]]*(bash|sh)|apt-key' "${LDNMP_SCRIPT}"; then
    echo "LDNMP installer retains an unsafe remote shell pipeline or apt-key." >&2
    exit 1
fi

grep -Fq 'https://ipapi.co/json/' "${BANDWIDTH_SCRIPT}"
grep -Fq 'run_repo_setup_script()' "${BANDWIDTH_SCRIPT}"
grep -Fq 'ID必须为数字' "${BANDWIDTH_SCRIPT}"
if grep -Fq -- '--no-check-certificate' "${BANDWIDTH_SCRIPT}"; then
    echo "Bandwidth test disables TLS certificate verification." >&2
    exit 1
fi

echo "Upgrade hardening checks are valid."
