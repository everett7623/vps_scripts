#!/bin/bash
# ==============================================================================
# Script: tests/validate_docker_installer_safety.sh
# Purpose: Guard Docker installer download and removal safety.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/docker.sh"

bash -n "${SCRIPT}"
grep -Fq 'download_to_temp()' "${SCRIPT}"
grep -Fq 'key_file=$(download_to_temp "$docker_repo_url/linux/$OS/gpg")' "${SCRIPT}"
grep -Fq 'compose_file=$(download_to_temp "$download_url")' "${SCRIPT}"
grep -Fq 'install -m 0755 "$compose_file" /usr/local/bin/docker-compose' "${SCRIPT}"
grep -Fq 'safe_remove_dir "$DOCKER_DATA_DIR"' "${SCRIPT}"
grep -Fq 'safe_remove_dir "$DOCKER_CONFIG_DIR"' "${SCRIPT}"
grep -Fq 'safe_remove_file /usr/local/bin/docker-compose' "${SCRIPT}"

if grep -Eq 'curl[^\n]*\|[[:space:]]*(bash|sh)' "${SCRIPT}"; then
    echo "Docker installer pipes remote content to a shell." >&2
    exit 1
fi

if grep -Eq 'curl[^\n]*-o[[:space:]]+/usr/local/bin/docker-compose' "${SCRIPT}"; then
    echo "Docker Compose is still downloaded directly into /usr/local/bin." >&2
    exit 1
fi

if grep -Eq 'rm[[:space:]]+-rf[[:space:]]+"\$DOCKER_(DATA|CONFIG)_DIR"' "${SCRIPT}"; then
    echo "Docker removal still bypasses safe removal helpers." >&2
    exit 1
fi

help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- "--remove" <<< "${help_output}"
grep -Fq -- "--compose" <<< "${help_output}"

echo "Docker installer safety is valid."
