#!/bin/bash
# ==============================================================================
# Script: tests/validate_ruby_installer_safety.sh
# Purpose: Guard Ruby installer source download and checksum verification.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/ruby.sh"

bash -n "${SCRIPT}"
grep -Fq 'set -euo pipefail' "${SCRIPT}"
grep -Fq 'DEFAULT_RUBY_VERSION="3.3.12"' "${SCRIPT}"
grep -Fq 'ruby/www.ruby-lang.org/master/_data/releases.yml' "${SCRIPT}"
grep -Fq 'Ruby 源码归档 SHA-256 校验失败' "${SCRIPT}"
grep -Fq 'sha256sum "${archive_path}"' "${SCRIPT}"
grep -Fq 'mktemp -d "/tmp/ruby-build.XXXXXX"' "${SCRIPT}"
grep -Fq 'bash -n "$rvm_script"' "${SCRIPT}"
grep -Fq 'curl -fsSL https://get.rvm.io' "${SCRIPT}"
grep -Fq 'bash "$rvm_script" stable --ruby="${ruby_for_rvm}" --auto-dotfiles' "${SCRIPT}"

if grep -Eq 'curl[^\n]*\|[[:space:]]*(bash|sh)' "${SCRIPT}"; then
    echo "Ruby installer pipes remote content to a shell." >&2
    exit 1
fi
if grep -Eq 'bash "\$rvm_script" \$rvm_args' "${SCRIPT}"; then
    echo "Ruby RVM installer still uses unquoted rvm_args word-splitting." >&2
    exit 1
fi

help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- "--version" <<< "${help_output}"
grep -Fq -- "--method" <<< "${help_output}"

echo "Ruby installer safety is valid."
