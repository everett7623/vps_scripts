#!/bin/bash
# ==============================================================================
# Script: tests/validate_mocked_pkg_systemd.sh
# Purpose: Execute real (non-dry-run) mutator paths with succeeding package and
#          systemd stubs; assert expected invocations and written configs.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

BBR="${REPO_ROOT}/scripts/other_tools/bbr.sh"
FAIL2BAN="${REPO_ROOT}/scripts/other_tools/fail2ban.sh"

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/vps_mocked_pkg.XXXXXX")
trap 'rm -rf -- "${TMP_ROOT}"' EXIT

STUB_DIR="${TMP_ROOT}/bin"
CALL_LOG="${TMP_ROOT}/calls.log"
SYSCTL_D="${TMP_ROOT}/sysctl.d"
JAIL_FILE="${TMP_ROOT}/fail2ban/jail.d/vps-scripts-sshd.local"
OUTPUT="${TMP_ROOT}/output.txt"
mkdir -p "${STUB_DIR}" "${SYSCTL_D}"
: > "${CALL_LOG}"

fail() {
    echo "$*" >&2
    if [ -f "${OUTPUT}" ]; then
        sed 's/^/    /' "${OUTPUT}" >&2
    fi
    exit 1
}

write_stub() {
    local name="$1"
    local body="$2"
    cat > "${STUB_DIR}/${name}" <<EOF
#!/bin/bash
echo "${name} \$*" >> "${CALL_LOG}"
${body}
EOF
    chmod +x "${STUB_DIR}/${name}"
}

write_stub id 'if [ "${1:-}" = "-u" ]; then echo 0; exit 0; fi; echo 0; exit 0'
write_stub sysctl 'case "$*" in *tcp_congestion_control*) echo "net.ipv4.tcp_congestion_control = cubic" ;; *default_qdisc*) echo "net.core.default_qdisc = fq_codel" ;; esac; exit 0'
write_stub apt 'exit 0'
write_stub apt-get 'exit 0'
write_stub yum 'exit 0'
write_stub bc 'echo 1; exit 0'
write_stub lsmod 'exit 0'
write_stub fail2ban-server 'exit 0'
write_stub fail2ban-client 'exit 0'
write_stub systemctl 'case "${1:-}" in is-active) exit 0 ;; esac; exit 0'

expect_call() {
    grep -Eq -- "$1" "${CALL_LOG}" || fail "Missing expected call matching: $1"
}

# --- BBR real install / uninstall ---
: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_BBR_DROPIN="${SYSCTL_D}/99-vps-bbr.conf" \
    bash "${BBR}" --install </dev/null >"${OUTPUT}" 2>&1 || fail "bbr --install failed"

[ -f "${SYSCTL_D}/99-vps-bbr.conf" ] || fail "BBR drop-in was not written"
grep -Fq 'net.ipv4.tcp_congestion_control=bbr' "${SYSCTL_D}/99-vps-bbr.conf" \
    || fail "BBR drop-in missing congestion_control"
grep -Fq 'net.core.default_qdisc=fq' "${SYSCTL_D}/99-vps-bbr.conf" \
    || fail "BBR drop-in missing default_qdisc"
expect_call '^sysctl '
expect_call '^id '

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_BBR_DROPIN="${SYSCTL_D}/99-vps-bbr.conf" \
    bash "${BBR}" --uninstall </dev/null >"${OUTPUT}" 2>&1 || fail "bbr --uninstall failed"
[ ! -f "${SYSCTL_D}/99-vps-bbr.conf" ] || fail "BBR drop-in still present after uninstall"
expect_call '^sysctl '

# --- Fail2ban real install with --yes ---
: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_OS_TYPE=ubuntu \
VPS_FAIL2BAN_JAIL_FILE="${JAIL_FILE}" \
    bash "${FAIL2BAN}" --yes </dev/null >"${OUTPUT}" 2>&1 || fail "fail2ban --yes failed"

[ -f "${JAIL_FILE}" ] || fail "Fail2ban jail file was not written"
grep -Fq '[sshd]' "${JAIL_FILE}" || fail "Fail2ban jail missing [sshd]"
grep -Fq 'backend = systemd' "${JAIL_FILE}" || fail "Fail2ban jail missing systemd backend"
expect_call '^apt-get '
expect_call '^fail2ban-client '
expect_call '^systemctl enable fail2ban'
expect_call '^systemctl restart fail2ban'

echo "Mocked pkg/systemd real-path checks are valid."
