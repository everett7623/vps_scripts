#!/bin/bash
# ==============================================================================
# Script: tests/validate_java_installer_safety.sh
# Purpose: Guard Java installer input, download, and archive handling safety.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/java.sh"

bash -n "${SCRIPT}"
grep -Fq 'set -euo pipefail' "${SCRIPT}"
grep -Fq 'validate_inputs()' "${SCRIPT}"
grep -Fq 'download_to_file()' "${SCRIPT}"
grep -Fq 'mktemp -d "/tmp/java-oracle.XXXXXX"' "${SCRIPT}"
grep -Fq 'mktemp -d "/tmp/java-graalvm.XXXXXX"' "${SCRIPT}"
grep -Fq 'mktemp -d "/tmp/java-maven.XXXXXX"' "${SCRIPT}"
grep -Fq 'mktemp -d "/tmp/java-gradle.XXXXXX"' "${SCRIPT}"
grep -Fq 'JAVA_PATH=$(readlink -f "$(command -v java)")' "${SCRIPT}"

if grep -Eq 'curl[^\n]*\|[[:space:]]*(bash|sh)' "${SCRIPT}"; then
    echo "Java installer pipes remote content to a shell." >&2
    exit 1
fi

if grep -Fq 'cd /tmp' "${SCRIPT}"; then
    echo "Java installer still downloads from a shared /tmp working directory." >&2
    exit 1
fi

if grep -Eq 'wget[^\n]*-O[[:space:]]+(oracle-jdk|graalvm)\.tar\.gz' "${SCRIPT}"; then
    echo "Java installer still uses fixed archive names." >&2
    exit 1
fi

if grep -Eq 'ln -sf \$\{?(JDK_DIR|GRAALVM_DIR)\}?' "${SCRIPT}"; then
    echo "Java installer has unquoted JDK/GraalVM symlink paths." >&2
    exit 1
fi

help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- "--type" <<< "${help_output}"
grep -Fq -- "--version" <<< "${help_output}"

echo "Java installer safety is valid."
