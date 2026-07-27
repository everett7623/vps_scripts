#!/bin/bash
# ==============================================================================
# Script: tests/validate_docker_installer_safety.sh
# Purpose: Guard the Docker official-installer wrapper.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/docker.sh"

bash -n "${SCRIPT}"
grep -Fq 'readonly DOCKER_INSTALL_URL="https://get.docker.com"' "${SCRIPT}"
grep -Fq 'installer_file=$(mktemp "/tmp/get-docker.XXXXXX")' "${SCRIPT}"
grep -Fq 'curl -fsSL "$DOCKER_INSTALL_URL" -o "$installer_file"' "${SCRIPT}"
grep -Fq 'bash -n "$installer_file"' "${SCRIPT}"
grep -Fq 'sh "$installer_file"' "${SCRIPT}"
grep -Fq 'trap cleanup EXIT' "${SCRIPT}"
grep -Fq 'docker compose version' "${SCRIPT}"

if grep -Eq 'curl[^\n]*\|[[:space:]]*(bash|sh)' "${SCRIPT}"; then
    echo "Docker installer pipes remote content to a shell." >&2
    exit 1
fi

if grep -Eq 'download\.docker\.com|api\.github\.com/repos/docker/compose|docker-compose-linux-' "${SCRIPT}"; then
    echo "Docker installer still reimplements repository or Compose setup." >&2
    exit 1
fi

echo "Docker official installer wrapper is valid."
