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
SWAP="${REPO_ROOT}/scripts/other_tools/swap.sh"
INSTALL_DEPS="${REPO_ROOT}/scripts/system_tools/install_deps.sh"

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

# --- Swap real create / resize / remove with --size / --yes ---
SWAP_ROOT="${TMP_ROOT}/swap"
SWAP_FILE="${SWAP_ROOT}/swapfile"
FSTAB="${SWAP_ROOT}/fstab"
PROC_SWAPS="${SWAP_ROOT}/proc_swaps"
SWAPPINESS="${SWAP_ROOT}/99-swappiness.conf"
mkdir -p "${SWAP_ROOT}"
printf 'UUID=abcd / ext4 defaults 0 1\n/dev/vdb1 none swap sw 0 0\n' > "${FSTAB}"
printf 'Filename\tType\tSize\tUsed\tPriority\n/dev/vdb1\tpartition\t1048572\t0\t-2\n' > "${PROC_SWAPS}"

# Stubs that model swap state through the fake /proc/swaps file.
write_stub fallocate 'f="${@: -1}"; : > "${f}"; exit 0'
write_stub mkswap 'exit 0'
write_stub swapon 'f="${@: -1}"; printf "%s\tfile\t1024\t0\t-3\n" "${f}" >> "${VPS_PROC_SWAPS}"; exit 0'
write_stub swapoff 'f="${@: -1}"; [ "${SWAPOFF_FAIL:-0}" = 1 ] && exit 1; grep -v "^${f}[[:space:]]" "${VPS_PROC_SWAPS}" > "${VPS_PROC_SWAPS}.n"; mv "${VPS_PROC_SWAPS}.n" "${VPS_PROC_SWAPS}"; exit 0'
write_stub df 'printf "Filesystem 1M-blocks Used Available Capacity Mounted\n/dev/vda1 40000 1000 ${DF_AVAIL_MB:-30000} 3%% /\n"; exit 0'
write_stub free 'printf "              total used free\nMem: 2048 512 1536\nSwap: 0 0 0\n"; exit 0'

run_swap() {
    PATH="${STUB_DIR}:${PATH}" \
    VPS_SWAP_FILE="${SWAP_FILE}" VPS_FSTAB_FILE="${FSTAB}" \
    VPS_PROC_SWAPS="${PROC_SWAPS}" VPS_SWAPPINESS_DROPIN="${SWAPPINESS}" \
        bash "${SWAP}" "$@" </dev/null >"${OUTPUT}" 2>&1
}

swap_fstab_count() {
    awk -v f="${SWAP_FILE}" '$1 == f' "${FSTAB}" | wc -l | tr -d ' '
}

# Preview creates nothing.
run_swap --size 2G --dry-run || fail "swap --size --dry-run failed"
[ ! -e "${SWAP_FILE}" ] || fail "swap dry-run created the swapfile"
[ "$(swap_fstab_count)" = 0 ] || fail "swap dry-run touched fstab"

# Invalid arguments are rejected before any change.
for bad in '0G' '2T' '2G;rm -rf /' '-1G' ''; do
    if run_swap --size "${bad}" --yes; then fail "swap accepted invalid size '${bad}'"; fi
done
if run_swap --yes; then fail "swap accepted --yes without --size/--remove"; fi
if run_swap --remove --size 1G --yes; then fail "swap accepted --remove with --size"; fi
if run_swap --size; then fail "swap accepted --size without a value"; fi
[ ! -e "${SWAP_FILE}" ] || fail "invalid swap arguments created the swapfile"

# Without --yes and with no input, nothing changes.
run_swap --size 1G || fail "swap without confirmation should cancel cleanly"
[ ! -e "${SWAP_FILE}" ] || fail "swap created a file without confirmation"

# Not enough disk space: refuse before touching anything.
if DF_AVAIL_MB=600 run_swap --size 1G --yes; then fail "swap ignored insufficient disk space"; fi
[ ! -e "${SWAP_FILE}" ] || fail "swap created a file despite insufficient space"

# Real create.
: > "${CALL_LOG}"
run_swap --size 2G --yes || fail "swap --size 2G --yes failed"
[ -f "${SWAP_FILE}" ] || fail "swapfile was not created"
# GNU/Linux enforces chmod; NTFS via Git Bash often ignores mode bits.
if mode=$(stat -c %a "${SWAP_FILE}" 2>/dev/null); then
    if [ "${mode}" != "600" ]; then
        case "$(uname -o 2>/dev/null || true)" in
            Msys|Cygwin) ;;
            *) fail "swapfile mode is not 600 (got ${mode})" ;;
        esac
    fi
fi
[ "$(swap_fstab_count)" = 1 ] || fail "fstab should contain exactly one swapfile entry"
grep -Fq 'UUID=abcd / ext4' "${FSTAB}" || fail "swap removed an unrelated fstab line"
grep -Fq '/dev/vdb1 none swap' "${FSTAB}" || fail "swap removed an unrelated swap partition"
grep -Fxq 'vm.swappiness=10' "${SWAPPINESS}" || fail "swappiness drop-in not written"
expect_call "^fallocate -l 2G ${SWAP_FILE}$"
expect_call "^mkswap -- ${SWAP_FILE}$"
expect_call "^swapon -- ${SWAP_FILE}$"

# Re-run (resize) is idempotent and only turns off the project swapfile.
: > "${CALL_LOG}"
run_swap --size=1G --yes || fail "swap resize failed"
[ "$(swap_fstab_count)" = 1 ] || fail "swap resize duplicated the fstab entry"
expect_call "^swapoff -- ${SWAP_FILE}$"
if grep -Eq '^swapoff .*(-a|/dev/vdb1)' "${CALL_LOG}"; then fail "swap disabled unrelated swap devices"; fi
grep -q '^/dev/vdb1' "${PROC_SWAPS}" || fail "unrelated swap partition was turned off"

# swapoff failure on an active swapfile must abort without deleting it.
if SWAPOFF_FAIL=1 run_swap --size 2G --yes; then fail "swap continued after swapoff failure"; fi
[ -f "${SWAP_FILE}" ] || fail "swap deleted an active swapfile after swapoff failure"
if SWAPOFF_FAIL=1 run_swap --remove --yes; then fail "swap --remove continued after swapoff failure"; fi
[ -f "${SWAP_FILE}" ] || fail "swap --remove deleted an active swapfile"

# Remove.
run_swap --remove --dry-run || fail "swap --remove --dry-run failed"
[ -f "${SWAP_FILE}" ] || fail "swap --remove --dry-run deleted the swapfile"
run_swap --remove --yes || fail "swap --remove --yes failed"
[ ! -e "${SWAP_FILE}" ] || fail "swapfile still present after --remove"
[ "$(swap_fstab_count)" = 0 ] || fail "fstab entry still present after --remove"
[ ! -e "${SWAPPINESS}" ] || fail "swappiness drop-in still present after --remove"
grep -Fq '/dev/vdb1 none swap' "${FSTAB}" || fail "swap --remove dropped an unrelated fstab line"

# --- install_deps real install path with stubbed root and package manager ---
DEPS_LOG_DIR="${TMP_ROOT}/deps_logs"
write_stub dpkg 'case "${1:-}" in -s) case "${2:-}" in curl|wget|git) exit 0 ;; esac; exit 1 ;; --print-architecture) echo amd64; exit 0 ;; esac; exit 0'
write_stub apt-get 'case " $* " in *" fail2ban "*) exit 100 ;; esac; exit 0'
write_stub curl 'exit 22'
write_stub git 'exit 0'
write_stub gpg 'exit 0'
write_stub lsb_release 'echo bookworm; exit 0'
write_stub systemctl 'case "${1:-}" in list-unit-files) exit 1 ;; esac; exit 0'

# Prefer stubs, then /usr/bin+/bin without host docker/node.
# Only those two dirs (not the whole PATH — slow on Windows Git Bash).
CLEAN_BIN="${TMP_ROOT}/clean_bin"
mkdir -p "${CLEAN_BIN}"
for dir in /usr/bin /bin; do
    [ -d "${dir}" ] || continue
    for exe in "${dir}"/*; do
        name=${exe##*/}
        case "${name}" in docker|dockerd|node|nodejs|npm) continue ;; esac
        [ -x "${exe}" ] && [ ! -e "${CLEAN_BIN}/${name}" ] && ln -s "${exe}" "${CLEAN_BIN}/${name}" 2>/dev/null || true
    done
done
DEPS_PATH="${STUB_DIR}:${CLEAN_BIN}"
DEPS_KEYRINGS="${TMP_ROOT}/keyrings"
DEPS_DOCKER_LIST="${TMP_ROOT}/apt/docker.list"
mkdir -p "${DEPS_KEYRINGS}" "$(dirname -- "${DEPS_DOCKER_LIST}")"

run_deps() {
    PATH="${DEPS_PATH}" HOME="${TMP_ROOT}/home" \
    VPS_OS_TYPE=debian VPS_SKIP_ROOT_CHECK=1 VPS_LOG_DIR="${DEPS_LOG_DIR}" \
    VPS_APT_KEYRINGS_DIR="${DEPS_KEYRINGS}" \
    VPS_APT_DOCKER_LIST="${DEPS_DOCKER_LIST}" \
        bash "${INSTALL_DEPS}" "$@" </dev/null >"${OUTPUT}" 2>&1
}

: > "${CALL_LOG}"
run_deps --basic --yes || fail "install_deps --basic --yes failed"
expect_call '^apt-get update -qq$'
expect_call '^apt-get install -y -qq vim$'
if grep -Eq '^apt-get install -y -qq (curl|wget|git)$' "${CALL_LOG}"; then
    fail "install_deps reinstalled packages that dpkg reports as installed"
fi
if grep -Eq '^curl ' "${CALL_LOG}"; then
    fail "install_deps --basic contacted Docker/NodeSource"
fi
[ -f "${DEPS_LOG_DIR}/install_deps.log" ] || fail "install_deps did not log to VPS_LOG_DIR"

# A failing package is reported and returns non-zero, but other packages still install.
: > "${CALL_LOG}"
if run_deps --security --yes; then fail "install_deps --security should report the failed package"; fi
grep -Fq 'fail2ban' "${OUTPUT}" || fail "install_deps did not name the failed package"
expect_call '^apt-get install -y -qq ufw$'
if grep -Eq '^curl ' "${CALL_LOG}"; then
    fail "install_deps --security contacted Docker/NodeSource"
fi

# --dev does need Docker and NodeSource: both are attempted (curl stub fails safely).
: > "${CALL_LOG}"
run_deps --dev --yes || true
expect_call '^curl .*download\.docker\.com'
expect_call '^curl .*deb\.nodesource\.com'

# Without the root check bypass the real path still requires root.
if [ "$(id -u)" != 0 ]; then
    if PATH="${DEPS_PATH}" VPS_OS_TYPE=debian VPS_LOG_DIR="${DEPS_LOG_DIR}" \
        bash "${INSTALL_DEPS}" --basic --yes </dev/null >"${OUTPUT}" 2>&1; then
        fail "install_deps ran the real path without root"
    fi
fi

# --- optimize_system real path (kernel + limits) ---
OPTIMIZE="${REPO_ROOT}/scripts/system_tools/optimize_system.sh"
OPT_ROOT="${TMP_ROOT}/optimize"
OPT_SYSCTL="${OPT_ROOT}/sysctl.d/99-vps-optimize.conf"
OPT_LIMITS="${OPT_ROOT}/limits.d/99-vps-scripts.conf"
OPT_SYSTEMD="${OPT_ROOT}/systemd/99-vps-scripts.conf"
OPT_BACKUP="${OPT_ROOT}/backups"
OPT_LOGS="${OPT_ROOT}/logs"
mkdir -p "${OPT_ROOT}/sysctl.d" "${OPT_ROOT}/limits.d" "${OPT_ROOT}/systemd" "${OPT_BACKUP}" "${OPT_LOGS}"
write_stub sysctl 'exit 0'
write_stub systemctl 'exit 0'

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_SKIP_ROOT_CHECK=1 \
VPS_LOG_DIR="${OPT_LOGS}" \
VPS_OPTIMIZE_BACKUP_DIR="${OPT_BACKUP}" \
VPS_OPTIMIZE_SYSCTL_FILE="${OPT_SYSCTL}" \
VPS_OPTIMIZE_LIMITS_FILE="${OPT_LIMITS}" \
VPS_OPTIMIZE_SYSTEMD_LIMITS_FILE="${OPT_SYSTEMD}" \
    bash "${OPTIMIZE}" --kernel --limits --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "optimize_system --kernel --limits --yes failed"

[ -f "${OPT_SYSCTL}" ] || fail "optimize sysctl drop-in missing"
grep -Fq 'tcp_congestion_control = bbr' "${OPT_SYSCTL}" || fail "optimize sysctl missing bbr"
[ -f "${OPT_LIMITS}" ] || fail "optimize limits drop-in missing"
grep -Fq 'nofile 65535' "${OPT_LIMITS}" || fail "optimize limits missing nofile"
[ -f "${OPT_SYSTEMD}" ] || fail "optimize systemd limits missing"
expect_call '^sysctl -p '

# --- clean_system real path (package cache via apt stubs; find is no-op) ---
CLEAN="${REPO_ROOT}/scripts/system_tools/clean_system.sh"
CLEAN_LOGS="${TMP_ROOT}/clean_logs"
mkdir -p "${CLEAN_LOGS}"
write_stub find 'exit 0'
write_stub journalctl 'exit 0'
write_stub docker 'exit 0'
write_stub du 'echo 0; exit 0'
write_stub df 'echo "/dev/sda1 100 50 50 50% /"; exit 0'

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_SKIP_ROOT_CHECK=1 \
VPS_OS_TYPE=debian \
VPS_LOG_DIR="${CLEAN_LOGS}" \
    bash "${CLEAN}" --auto --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "clean_system --auto --yes failed"
expect_call '^apt-get clean'
expect_call '^apt-get autoclean'
expect_call '^apt-get autoremove -y'

echo "Mocked pkg/systemd real-path checks are valid."
