#!/bin/bash
# ==============================================================================
# Script: tests/validate_mysql_installer_safety.sh
# Purpose: Guard MySQL/MariaDB installer download, auth, and removal safety.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/mysql.sh"

bash -n "${SCRIPT}"

# Safety framework present
grep -Fq 'set -euo pipefail' "${SCRIPT}"
grep -Fq 'download_to_temp()' "${SCRIPT}"
grep -Fq 'error_exit()' "${SCRIPT}"
grep -Fq 'validate_inputs()' "${SCRIPT}"

# No pipe-to-privileged-command patterns
if grep -Eq 'curl[^\n]*\|[[:space:]]*apt-key' "${SCRIPT}"; then
    echo "MySQL installer pipes curl to apt-key." >&2
    exit 1
fi

if grep -Eq 'wget[^\n]*-O[[:space:]]*-[[:space:]]*\|[[:space:]]*apt-key' "${SCRIPT}"; then
    echo "MySQL installer pipes wget to apt-key." >&2
    exit 1
fi

# No direct remote RPM installs
if grep -Eq 'rpm[[:space:]]+-Uvh[[:space:]]+https?://' "${SCRIPT}"; then
    echo "MySQL installer runs rpm -Uvh with remote URL." >&2
    exit 1
fi

# Temp-file downloads for repo packages
grep -Fq 'deb_file=$(download_to_temp' "${SCRIPT}"
grep -Fq 'rpm_file=$(download_rpm_to_temp' "${SCRIPT}"
grep -Fq 'key_file=$(download_to_temp' "${SCRIPT}"

# No wildcard temp file removal
if grep -Eq 'rm[[:space:]]+-rf?[[:space:]]+/tmp/(mysql|mariadb)[^/]*\*' "${SCRIPT}"; then
    echo "MySQL installer uses wildcard /tmp removal." >&2
    exit 1
fi

# Password not exposed via mysql command line (uses --defaults-extra-file)
grep -Fq 'defaults-extra-file' "${SCRIPT}"

# Help output works
help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- "--type" <<< "${help_output}"
grep -Fq -- "--mode" <<< "${help_output}"

echo "MySQL installer safety is valid."
