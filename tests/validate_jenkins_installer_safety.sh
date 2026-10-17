#!/bin/bash
# ==============================================================================
# Script: tests/validate_jenkins_installer_safety.sh
# Purpose: Guard Jenkins WAR download HTTPS and SHA-256 verification.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/jenkins.sh"

bash -n "${SCRIPT}"
grep -Fq 'set -euo pipefail' "${SCRIPT}"
grep -Fq 'https://get.jenkins.io/war-stable/' "${SCRIPT}"
grep -Fq 'checksum_url="${official_war_url}.sha256"' "${SCRIPT}"
grep -Fq 'Jenkins WAR SHA-256 校验失败' "${SCRIPT}"
grep -Fq 'mktemp -d "/tmp/jenkins-war.XXXXXX"' "${SCRIPT}"
grep -Fq 'install -m 0644 "${war_tmp}" "${JENKINS_WAR}"' "${SCRIPT}"
grep -Fq 'jenkins.io-2023.key' "${SCRIPT}"
grep -Fq 'signed-by=%s' "${SCRIPT}"
grep -Fq 'jenkins-keyring.gpg' "${SCRIPT}"
grep -Fq 'VPS_APT_JENKINS_LIST' "${SCRIPT}"

# Must not stream or install the WAR before checksum verification.
if grep -Eq 'wget -O "\$JENKINS_WAR"' "${SCRIPT}"; then
    echo "Jenkins installer still writes the WAR path before checksum verification." >&2
    exit 1
fi
if grep -Eq 'http://mirrors\.jenkins\.io/' "${SCRIPT}"; then
    echo "Jenkins installer still downloads WAR over plain HTTP." >&2
    exit 1
fi
if grep -Eq 'apt-key[[:space:]]+add' "${SCRIPT}"; then
    echo "Jenkins installer still uses deprecated apt-key add." >&2
    exit 1
fi

echo "Jenkins installer safety is valid."
