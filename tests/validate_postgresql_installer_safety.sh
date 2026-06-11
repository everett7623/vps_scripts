#!/bin/bash
# ==============================================================================
# Script: tests/validate_postgresql_installer_safety.sh
# Purpose: Guard PostgreSQL installer download, auth, and service safety.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/postgresql.sh"

bash -n "${SCRIPT}"

# Safety framework present
grep -Fq 'set -euo pipefail' "${SCRIPT}"
grep -Fq 'download_to_temp()' "${SCRIPT}"
grep -Fq 'error_exit()' "${SCRIPT}"
grep -Fq 'validate_inputs()' "${SCRIPT}"

# No pipe-to-privileged-command patterns
if grep -Eq 'wget[^\n]*-O[[:space:]]*-[[:space:]]*\|[[:space:]]*apt-key' "${SCRIPT}"; then
    echo "PostgreSQL installer pipes wget to apt-key." >&2
    exit 1
fi

# No direct remote yum/dnf RPM installs
if grep -Eq '(yum|dnf)[[:space:]]+install[[:space:]]+-y[[:space:]]+https?://' "${SCRIPT}"; then
    echo "PostgreSQL installer runs yum/dnf install with remote URL." >&2
    exit 1
fi

# Temp file for GPG key and RPM downloads
grep -Fq 'key_file=$(download_to_temp' "${SCRIPT}"
grep -Fq 'rpm_file=$(download_to_temp' "${SCRIPT}"

# No wildcard systemctl service names
if grep -Eq 'systemctl[[:space:]]+(stop|start|restart|status)[[:space:]]+postgresql\*' "${SCRIPT}"; then
    echo "PostgreSQL installer uses wildcard service name." >&2
    exit 1
fi

# No wildcard rm of data directory
if grep -Eq 'rm[[:space:]]+-rf[[:space:]]+"\$DATA_DIR"/\*' "${SCRIPT}"; then
    echo "PostgreSQL installer uses wildcard data dir removal." >&2
    exit 1
fi

# No crontab overwrite (appends instead)
if grep -Eq 'echo[^\n]*\|[[:space:]]*crontab[[:space:]]+-$' "${SCRIPT}"; then
    if ! grep -Eq 'crontab[[:space:]]+-l' "${SCRIPT}"; then
        echo "PostgreSQL installer overwrites crontab without preserving existing entries." >&2
        exit 1
    fi
fi

# No hardcoded passwords
if grep -Fq "monitor123" "${SCRIPT}"; then
    echo "PostgreSQL installer contains hardcoded password." >&2
    exit 1
fi

# Help output works
help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- "--version" <<< "${help_output}"
grep -Fq -- "--mode" <<< "${help_output}"

echo "PostgreSQL installer safety is valid."
