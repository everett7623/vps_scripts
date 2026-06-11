#!/bin/bash
# ==============================================================================
# Script: tests/validate_redis_installer_safety.sh
# Purpose: Guard Redis installer download, build, and auth safety.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/redis.sh"

bash -n "${SCRIPT}"

# Safety framework present
grep -Fq 'set -euo pipefail' "${SCRIPT}"
grep -Fq 'error_exit()' "${SCRIPT}"
grep -Fq 'validate_inputs()' "${SCRIPT}"

# Isolated build directory (mktemp -d), not /tmp wildcards
grep -Fq 'mktemp -d' "${SCRIPT}"

# No wildcard /tmp removal of redis build artifacts
if grep -Eq 'rm[[:space:]]+-rf[[:space:]]+/tmp/redis-[^*]*\*' "${SCRIPT}"; then
    echo "Redis installer uses wildcard /tmp removal." >&2
    exit 1
fi

# No redis-cli -a (password in process list)
if grep -Eq 'redis-cli[[:space:]].*-a[[:space:]]*"?\$REDIS_PASSWORD' "${SCRIPT}"; then
    echo "Redis installer exposes password via redis-cli -a." >&2
    exit 1
fi

# Uses REDISCLI_AUTH env var for safe auth
grep -Fq 'REDISCLI_AUTH' "${SCRIPT}"

# No make test as actual command (can hang in non-interactive mode)
if grep -E '^[[:space:]]*make test[[:space:]]*$' "${SCRIPT}" | grep -v '^[[:space:]]*#' | grep -q .; then
    echo "Redis installer runs make test (can hang non-interactively)." >&2
    exit 1
fi

# No overwriting /etc/rc.local unconditionally
if grep -Eq 'cat[[:space:]]*>[[:space:]]*/etc/rc\.local' "${SCRIPT}"; then
    echo "Redis installer unconditionally overwrites /etc/rc.local." >&2
    exit 1
fi

# Help output works
help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- "--version" <<< "${help_output}"
grep -Fq -- "--mode" <<< "${help_output}"

echo "Redis installer safety is valid."
