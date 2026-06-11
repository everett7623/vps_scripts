#!/bin/bash
# ==============================================================================
# Script: tests/validate_kubernetes_installer_safety.sh
# Purpose: Guard Kubernetes installer input and join-command safety.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/kubernetes.sh"

bash -n "${SCRIPT}"
grep -Fq 'validate_inputs' "${SCRIPT}"
grep -Fq 'read -r -a join_args <<< "${JOIN_CMD}"' "${SCRIPT}"
grep -Fq 'if "${join_args[@]}"; then' "${SCRIPT}"

if grep -Eq '(^|[[:space:]])eval[[:space:]]' "${SCRIPT}"; then
    echo "Kubernetes installer still uses eval." >&2
    exit 1
fi

help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- "--mode" <<< "${help_output}"
grep -Fq -- "--master-ip" <<< "${help_output}"

echo "Kubernetes installer safety is valid."
