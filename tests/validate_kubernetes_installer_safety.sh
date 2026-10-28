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
grep -Fq 'crio_minor' "${SCRIPT}"
grep -Fq 'kubic 路径 404' "${SCRIPT}"
grep -Fq 'pkgs.k8s.io/core:/stable:/v' "${SCRIPT}"
grep -Fq 'kubernetes-new/core/stable/v' "${SCRIPT}"
grep -Fq 'kubernetes-apt-keyring.gpg' "${SCRIPT}"
grep -Fq 'docker-archive-keyring.gpg' "${SCRIPT}"
grep -Fq 'libcontainers-cri-o-keyring.gpg' "${SCRIPT}"
grep -Fq 'signed-by=%s' "${SCRIPT}"
grep -Fq 'bash -n "$helm_installer"' "${SCRIPT}"
grep -Fq 'bash "$helm_installer"' "${SCRIPT}"
grep -Fq 'download_k8s_manifest' "${SCRIPT}"
grep -Fq '/tmp/k8s-manifest.XXXXXX' "${SCRIPT}"
grep -Fq '清单不是 Kubernetes YAML' "${SCRIPT}"
grep -Fq 'metrics-server/releases/download/v0.7.2/components.yaml' "${SCRIPT}"
grep -Fq 'download_k8s_manifest "https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.2/components.yaml" "Metrics Server"' "${SCRIPT}"

if grep -Eq '(^|[[:space:]])eval[[:space:]]' "${SCRIPT}"; then
    echo "Kubernetes installer still uses eval." >&2
    exit 1
fi
if grep -Eq 'apt-key[[:space:]]+add' "${SCRIPT}"; then
    echo "Kubernetes installer still uses deprecated apt-key add." >&2
    exit 1
fi
if grep -Fq 'kubernetes-xenial' "${SCRIPT}"; then
    echo "Kubernetes installer still uses retired kubernetes-xenial apt repo." >&2
    exit 1
fi
if grep -Fq 'curl -O https://docs.projectcalico.org/manifests/calico.yaml' "${SCRIPT}"; then
    echo "Kubernetes installer still downloads Calico into the working directory." >&2
    exit 1
fi
if grep -Eq 'kubectl apply -f https://' "${SCRIPT}"; then
    echo "Kubernetes installer still applies a remote manifest URL." >&2
    exit 1
fi
if grep -Fq 'metrics-server/releases/latest/download/components.yaml' "${SCRIPT}"; then
    echo "Kubernetes installer still uses unpinned Metrics Server latest." >&2
    exit 1
fi
if grep -Eq 'wget[[:space:]].*metrics-server' "${SCRIPT}"; then
    echo "Kubernetes installer still downloads Metrics Server with wget." >&2
    exit 1
fi

help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- "--mode" <<< "${help_output}"
grep -Fq -- "--master-ip" <<< "${help_output}"

echo "Kubernetes installer safety is valid."
