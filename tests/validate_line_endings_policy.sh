#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
ATTRIBUTES_FILE="${REPO_ROOT}/.gitattributes"

require_rule() {
    local pattern="$1"
    local attrs="$2"

    if ! grep -Eq "^${pattern}[[:space:]]+${attrs}$" "${ATTRIBUTES_FILE}"; then
        echo "Missing .gitattributes rule: ${pattern} ${attrs}" >&2
        return 1
    fi
}

main() {
    if [ ! -f "${ATTRIBUTES_FILE}" ]; then
        echo "Missing .gitattributes" >&2
        exit 1
    fi

    require_rule '\*\.sh' 'text eol=lf'
    require_rule '\*\.md' 'text eol=lf'
    require_rule '\*\.json' 'text eol=lf'
    require_rule '\*\.conf' 'text eol=lf'

    echo "Line-ending policy is valid."
}

main "$@"
