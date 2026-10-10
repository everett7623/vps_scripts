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

grep -Fq 'readonly RELEASE_BASE_URL="https://github.com/nezhahq/agent/releases/latest/download"' "${NEZHA_SCRIPT}"
grep -Fq '"${RELEASE_BASE_URL}/checksums.txt"' "${NEZHA_SCRIPT}"
grep -Fq 'sha256sum "${archive}"' "${NEZHA_SCRIPT}"
grep -Fq 'systemd-analyze verify "${SERVICE_FILE}"' "${NEZHA_SCRIPT}"
grep -Fq "unzip -Z1 \"\${archive}\" | grep -qx 'nezha-agent'" "${NEZHA_SCRIPT}"
grep -Fq 'chmod 600 -- "${CONFIG_FILE}"' "${NEZHA_SCRIPT}"
if grep -Eq 'naiba/nezha|ExecStart=.*-p ' "${NEZHA_SCRIPT}"; then
    echo "Nezha installer still uses the retired release or passes the secret on the command line." >&2
    exit 1
fi
grep -Fq 'run_remote_bash_installer()' "${LDNMP_SCRIPT}"
grep -Fq 'signed-by=/usr/share/keyrings/nginx-signing.gpg' "${LDNMP_SCRIPT}"
grep -Fq 'signed-by=/usr/share/keyrings/sury-php.gpg' "${LDNMP_SCRIPT}"
if grep -Eq 'curl[^\n]*\|[[:space:]]*(bash|sh)|apt-key' "${LDNMP_SCRIPT}"; then
    echo "LDNMP installer retains an unsafe remote shell pipeline or apt-key." >&2
    exit 1
fi

FRP_SCRIPT="${REPO_ROOT}/scripts/other_tools/frp.sh"
bash -n "${FRP_SCRIPT}"
grep -Fq 'readonly RELEASE_REPO_URL="https://github.com/fatedier/frp"' "${FRP_SCRIPT}"
grep -Fq 'frp_sha256_checksums.txt' "${FRP_SCRIPT}"
grep -Fq 'sha256sum "${WORK_DIR}/${asset}"' "${FRP_SCRIPT}"
grep -Fq 'auth.method = "token"' "${FRP_SCRIPT}"
grep -Fq 'run_repo_script "scripts/other_tools/frp.sh"' "${LAUNCHER}"

GO_SCRIPT="${REPO_ROOT}/scripts/service_install/go.sh"
NODE_SCRIPT="${REPO_ROOT}/scripts/service_install/nodejs.sh"
grep -Fq 'https://dl.google.com/go/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz.sha256' "${GO_SCRIPT}"
grep -Fq 'https://nodejs.org/dist/${FULL_VERSION}/SHASUMS256.txt' "${NODE_SCRIPT}"
grep -Fq 'work_dir=$(mktemp -d "/tmp/nodejs-install.XXXXXX")' "${NODE_SCRIPT}"
if grep -Fq 'funnyzak/frpc' "${LAUNCHER}"; then
    echo "Launcher still points FRP at the retired third-party installer." >&2
    exit 1
fi
grep -Fq 'DOCKER_REQUIRED_CHECK="command -v docker' "${LAUNCHER}"
while IFS= read -r docker_line; do
    if [[ ${docker_line} != *'${DOCKER_REQUIRED_CHECK}'* ]]; then
        echo "Docker-based launcher entry lacks the Docker presence check: ${docker_line}" >&2
        exit 1
    fi
done < <(grep -E 'run_remote_command ".*docker (run|volume|compose)' "${LAUNCHER}")
if grep -Fq 'louislam/uptime-kuma:1' "${LAUNCHER}"; then
    echo "Uptime Kuma entry still pins the previous major version." >&2
    exit 1
fi
for stale_proxy_url in 'gitlab.com/rwkgyg/x-ui-yg' 'xeefei/3x-ui/'; do
    if grep -Fq "${stale_proxy_url}" "${LAUNCHER}"; then
        echo "Proxy menu still uses a superseded upstream URL: ${stale_proxy_url}" >&2
        exit 1
    fi
done
grep -Fq 'Xray-install/raw/main/install-release.sh" "Official Xray-core install" install' "${LAUNCHER}"

grep -Fq 'https://ipapi.co/json/' "${BANDWIDTH_SCRIPT}"
grep -Fq 'run_repo_setup_script()' "${BANDWIDTH_SCRIPT}"
grep -Fq 'ID必须为数字' "${BANDWIDTH_SCRIPT}"
if grep -Fq -- '--no-check-certificate' "${BANDWIDTH_SCRIPT}"; then
    echo "Bandwidth test disables TLS certificate verification." >&2
    exit 1
fi

echo "Upgrade hardening checks are valid."
