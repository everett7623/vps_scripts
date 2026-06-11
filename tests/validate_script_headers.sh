#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

main() {
    local file=""
    local first_line=""
    local failed=0

    while IFS= read -r -d '' file; do
        first_line=$(head -n 1 "${file}")

        if [ "${first_line}" != "#!/bin/bash" ]; then
            echo "Invalid shell header: ${file#${REPO_ROOT}/}" >&2
            failed=1
        fi

        if head -c 3 "${file}" | grep -q $'\xef\xbb\xbf'; then
            echo "UTF-8 BOM is not allowed in shell script: ${file#${REPO_ROOT}/}" >&2
            failed=1
        fi

        if grep -q $'\r' "${file}"; then
            echo "CRLF line ending is not allowed in shell script: ${file#${REPO_ROOT}/}" >&2
            failed=1
        fi
    done < <(find "${REPO_ROOT}" \
        -path "${REPO_ROOT}/.git" -prune -o \
        -type f -name '*.sh' -print0)

    if [ "${failed}" -ne 0 ]; then
        exit 1
    fi

    echo "Shell script headers and line endings are valid."
}

main "$@"
