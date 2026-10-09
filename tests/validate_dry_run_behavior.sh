#!/bin/bash
# ==============================================================================
# Script: tests/validate_dry_run_behavior.sh
# Purpose: Execute --help/--dry-run/--status paths of state-changing tools with
#          stubbed system commands and assert nothing destructive is invoked.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

CLEAN_SERVICE="${REPO_ROOT}/scripts/uninstall_scripts/clean_service_residues.sh"
CLEAR_CONFIG="${REPO_ROOT}/scripts/uninstall_scripts/clear_configuration_files.sh"
ROLLBACK_ENV="${REPO_ROOT}/scripts/uninstall_scripts/rollback_system_environment.sh"
NEZHA="${REPO_ROOT}/scripts/other_tools/nezha.sh"
DOCKER="${REPO_ROOT}/scripts/service_install/docker.sh"

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/vps_dry_run_test.XXXXXX")
trap 'rm -rf -- "${TMP_ROOT}"' EXIT

STUB_DIR="${TMP_ROOT}/bin"
CALL_LOG="${TMP_ROOT}/calls.log"
BACKUP_ROOT="${TMP_ROOT}/backups"
OUTPUT="${TMP_ROOT}/output.txt"
mkdir -p "${STUB_DIR}"
: > "${CALL_LOG}"

for cmd in systemctl apt-get yum dnf rm swapoff sysctl hostnamectl timedatectl \
    mkswap curl wget unzip install update-grub grubby; do
    cat > "${STUB_DIR}/${cmd}" <<EOF
#!/bin/bash
echo "${cmd} \$*" >> "${CALL_LOG}"
exit 1
EOF
    chmod +x "${STUB_DIR}/${cmd}"
done

cat > "${STUB_DIR}/systemctl" <<EOF
#!/bin/bash
case "\${1:-}" in
    is-active|is-enabled|list-unit-files|cat|status) exit 1 ;;
esac
echo "systemctl \$*" >> "${CALL_LOG}"
exit 1
EOF

fail() {
    echo "$*" >&2
    if [ -f "${OUTPUT}" ]; then
        sed 's/^/    /' "${OUTPUT}" >&2
    fi
    exit 1
}

run_case() {
    local expect="$1"
    shift
    local status=0
    PATH="${STUB_DIR}:${PATH}" VPS_BACKUP_ROOT="${BACKUP_ROOT}" \
        bash "$@" </dev/null >"${OUTPUT}" 2>&1 || status=$?
    if [ "${expect}" = ok ] && [ "${status}" -ne 0 ]; then
        fail "Expected success (got ${status}): $*"
    fi
    if [ "${expect}" = fail ] && [ "${status}" -eq 0 ]; then
        fail "Expected failure: $*"
    fi
    if [ -s "${CALL_LOG}" ]; then
        echo "Stubbed system command was invoked by: $*" >&2
        cat "${CALL_LOG}" >&2
        exit 1
    fi
    if [ -d "${BACKUP_ROOT}" ]; then
        fail "Dry-run/preview created a backup directory: $*"
    fi
}

expect_output() {
    grep -Fq -- "$1" "${OUTPUT}" || fail "Missing output '$1'"
}

for script in "${CLEAN_SERVICE}" "${CLEAR_CONFIG}" "${ROLLBACK_ENV}"; do
    run_case ok "${script}" --help
    expect_output "--dry-run"
    run_case ok "${script}" --list
    run_case ok "${script}" --dry-run --target all
    expect_output "DRY-RUN"
    run_case fail "${script}" --dry-run --target no-such-target
    run_case fail "${script}" --bogus-flag
    if [ "$(id -u)" != "0" ]; then
        run_case fail "${script}" --target all --yes
        expect_output "root"
    fi
done

run_case ok "${CLEAN_SERVICE}" --dry-run --target 4
run_case fail "${CLEAN_SERVICE}" --dry-run --yes --target wordpress
expect_output "--wp-dir"

run_case ok "${ROLLBACK_ENV}" --dry-run --target swap
run_case ok "${ROLLBACK_ENV}" --dry-run --target hostname --hostname vps-node-01
run_case fail "${ROLLBACK_ENV}" --dry-run --target hostname --hostname 'bad_name;rm'
run_case fail "${ROLLBACK_ENV}" --dry-run --yes --target hostname
run_case ok "${ROLLBACK_ENV}" --dry-run --target kernel

run_case ok "${NEZHA}" --help
expect_output "--status"
run_case ok "${NEZHA}" --status
run_case ok "${NEZHA}" --dry-run --server panel.example.com --port 5555 --secret s3cr3t-token
expect_output "panel.example.com:5555"
if grep -Fq 's3cr3t-token' "${OUTPUT}"; then
    fail "Nezha dry-run echoed the client secret."
fi
NZ_CLIENT_SECRET=env-token run_case ok "${NEZHA}" --dry-run --server 10.0.0.1 --port 8008 --tls
expect_output "tls=true"
run_case fail "${NEZHA}" --dry-run --server panel.example.com --port 70000 --secret x
run_case fail "${NEZHA}" --dry-run --yes --server panel.example.com
run_case ok "${NEZHA}" --uninstall --dry-run

run_case ok "${DOCKER}" --help
run_case ok "${DOCKER}" --status
run_case fail "${DOCKER}" --bogus-flag
if ! command -v docker >/dev/null 2>&1; then
    run_case ok "${DOCKER}" --dry-run
    expect_output "[DRY-RUN]"
fi

echo "Dry-run behavior checks are valid."
