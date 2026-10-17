#!/bin/bash
# ==============================================================================
# Script: tests/validate_rust_installer_safety.sh
# Purpose: Guard Rust installer rustup-init download and checksum verification.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/rust.sh"

bash -n "${SCRIPT}"
grep -Fq 'set -euo pipefail' "${SCRIPT}"
grep -Fq 'rustup_init_target()' "${SCRIPT}"
grep -Fq 'static.rust-lang.org/rustup/dist' "${SCRIPT}"
grep -Fq 'rustup-init.sha256' "${SCRIPT}"
grep -Fq 'rustup-init SHA-256 校验失败' "${SCRIPT}"
grep -Fq 'mktemp -d "/tmp/rustup-install.XXXXXX"' "${SCRIPT}"
grep -Fq 'rustup_init_args=( -y --default-toolchain' "${SCRIPT}"

# Must not fall back to curl|sh style sh.rustup.rs pipeline.
if grep -Eq 'curl[^\n]*sh\.rustup\.rs[^\n]*\|[[:space:]]*sh' "${SCRIPT}"; then
    echo "Rust installer still pipes sh.rustup.rs into a shell." >&2
    exit 1
fi
if grep -Fq 'https://sh.rustup.rs' "${SCRIPT}"; then
    echo "Rust installer still downloads the sh.rustup.rs wrapper script." >&2
    exit 1
fi

help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- "--channel" <<< "${help_output}"
grep -Fq -- "--china-mirror" <<< "${help_output}"

echo "Rust installer safety is valid."
