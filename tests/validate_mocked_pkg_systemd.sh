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

# --- change_hostname real path ---
HOSTNAME_SCRIPT="${REPO_ROOT}/scripts/system_tools/change_hostname.sh"
HN_ROOT="${TMP_ROOT}/hostname"
HN_FILE="${HN_ROOT}/hostname"
HN_HOSTS="${HN_ROOT}/hosts"
HN_BACKUP="${HN_ROOT}/backups"
HN_LOGS="${HN_ROOT}/logs"
mkdir -p "${HN_ROOT}" "${HN_BACKUP}" "${HN_LOGS}"
printf 'oldhost\n' > "${HN_FILE}"
printf '127.0.0.1\tlocalhost\n127.0.1.1\toldhost\n' > "${HN_HOSTS}"
write_stub hostnamectl 'case "$*" in *set-hostname*) exit 0 ;; *) echo oldhost; exit 0 ;; esac'
write_stub hostname 'exit 0'
write_stub systemctl 'exit 0'

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_SKIP_ROOT_CHECK=1 \
VPS_LOG_DIR="${HN_LOGS}" \
VPS_HOSTNAME_BACKUP_DIR="${HN_BACKUP}" \
VPS_HOSTNAME_FILE="${HN_FILE}" \
VPS_HOSTS_FILE="${HN_HOSTS}" \
    bash "${HOSTNAME_SCRIPT}" --yes newhost </dev/null >"${OUTPUT}" 2>&1 \
    || fail "change_hostname --yes failed"
[ "$(tr -d '[:space:]' <"${HN_FILE}")" = "newhost" ] || fail "hostname file not updated"
grep -Eq '^127\.0\.1\.1[[:space:]]+newhost' "${HN_HOSTS}" || fail "hosts file missing newhost"
ls -1d "${HN_BACKUP}"/backup_* >/dev/null 2>&1 || fail "hostname backup was not created"
expect_call '^hostnamectl set-hostname newhost'

# --- set_timezone real path (traditional file path under overrides) ---
TZ_SCRIPT="${REPO_ROOT}/scripts/system_tools/set_timezone.sh"
TZ_ROOT="${TMP_ROOT}/timezone"
TZ_FILE="${TZ_ROOT}/timezone"
TZ_LOCAL="${TZ_ROOT}/localtime"
TZ_ZONEINFO="${TZ_ROOT}/zoneinfo"
TZ_BACKUP="${TZ_ROOT}/backups"
TZ_LOGS="${TZ_ROOT}/logs"
mkdir -p "${TZ_ZONEINFO}/Asia" "${TZ_BACKUP}" "${TZ_LOGS}"
: > "${TZ_ZONEINFO}/Asia/Shanghai"
: > "${TZ_ZONEINFO}/UTC"
printf 'UTC\n' > "${TZ_FILE}"
ln -sfn "${TZ_ZONEINFO}/UTC" "${TZ_LOCAL}"

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_SKIP_ROOT_CHECK=1 \
VPS_LOG_DIR="${TZ_LOGS}" \
VPS_TIMEZONE_BACKUP_DIR="${TZ_BACKUP}" \
VPS_TIMEZONE_FILE="${TZ_FILE}" \
VPS_LOCALTIME_FILE="${TZ_LOCAL}" \
VPS_ZONEINFO_DIR="${TZ_ZONEINFO}" \
    bash "${TZ_SCRIPT}" --yes Asia/Shanghai </dev/null >"${OUTPUT}" 2>&1 \
    || fail "set_timezone --yes Asia/Shanghai failed"
[ "$(tr -d '[:space:]' <"${TZ_FILE}")" = "Asia/Shanghai" ] || fail "timezone file not updated"
# On Windows Git Bash ln -s may copy instead of symlink; require the target exists.
[ -e "${TZ_LOCAL}" ] || fail "localtime target missing"
ls -1d "${TZ_BACKUP}"/backup_* >/dev/null 2>&1 || fail "timezone backup was not created"

# --- update_system real path (apt stubs; no host reboot) ---
UPDATE_SCRIPT="${REPO_ROOT}/scripts/system_tools/update_system.sh"
UPD_ROOT="${TMP_ROOT}/update"
UPD_BACKUP="${UPD_ROOT}/backups"
UPD_LOGS="${UPD_ROOT}/logs"
UPD_REBOOT="${UPD_ROOT}/reboot-required"
UPD_CACHE="${UPD_ROOT}/pkgcache.bin"
mkdir -p "${UPD_BACKUP}" "${UPD_LOGS}"
: > "${UPD_REBOOT}"
: > "${UPD_CACHE}"
write_stub apt 'case "$*" in *list*--upgradable*|*"list --upgradable"*) printf "vim/stable 2.0 [upgradable from: 1.0]\n"; exit 0 ;; esac; exit 0'
write_stub apt-get 'exit 0'
# Forward "env VAR=value cmd ..." to the stubbed command so call logs stay on apt-get.
write_stub env '
while [ "$#" -gt 0 ]; do
    case "$1" in
        [A-Za-z_]*=*) shift ;;
        *) exec "$@" ;;
    esac
done
exit 0
'
write_stub dpkg 'case "$*" in *--get-selections*) printf "vim\tinstall\n"; exit 0 ;; esac; exit 0'
write_stub ping 'exit 0'
write_stub curl 'exit 0'
write_stub reboot 'echo "reboot $*" >> "'"${CALL_LOG}"'"; exit 0'

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_SKIP_ROOT_CHECK=1 \
VPS_SKIP_NETWORK_CHECK=1 \
VPS_OS_TYPE=debian \
VPS_LOG_DIR="${UPD_LOGS}" \
VPS_UPDATE_BACKUP_DIR="${UPD_BACKUP}" \
VPS_REBOOT_REQUIRED_FILE="${UPD_REBOOT}" \
VPS_APT_CACHE_FILE="${UPD_CACHE}" \
    bash "${UPDATE_SCRIPT}" --auto </dev/null >"${OUTPUT}" 2>&1 \
    || fail "update_system --auto failed"
ls -1d "${UPD_BACKUP}"/backup_* >/dev/null 2>&1 || fail "update_system backup was not created"
ls -1 "${UPD_BACKUP}"/backup_*/packages.list >/dev/null 2>&1 || fail "update_system packages.list missing"
expect_call '^apt-get .* upgrade -y$'
expect_call '^apt-get autoremove -y$'
grep -Fq '自动确认模式不会自动重启' "${OUTPUT}" \
    || fail "update_system --auto should not reboot without --reboot"
if grep -Eq '^reboot ' "${CALL_LOG}"; then
    fail "update_system --auto invoked reboot"
fi

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_SKIP_ROOT_CHECK=1 \
VPS_SKIP_NETWORK_CHECK=1 \
VPS_OS_TYPE=debian \
VPS_LOG_DIR="${UPD_LOGS}" \
VPS_UPDATE_BACKUP_DIR="${UPD_BACKUP}" \
VPS_REBOOT_REQUIRED_FILE="${UPD_REBOOT}" \
VPS_APT_CACHE_FILE="${UPD_CACHE}" \
    bash "${UPDATE_SCRIPT}" --auto --reboot </dev/null >"${OUTPUT}" 2>&1 \
    || fail "update_system --auto --reboot failed"
grep -Fq '跳过实际 reboot' "${OUTPUT}" \
    || fail "update_system --reboot under test hooks should skip reboot"
if grep -Eq '^reboot ' "${CALL_LOG}"; then
    fail "update_system --reboot under test hooks still called reboot"
fi

# --- Nezha status / uninstall with path overrides ---
NEZHA="${REPO_ROOT}/scripts/other_tools/nezha.sh"
NZ_ROOT="${TMP_ROOT}/nezha"
NZ_INSTALL="${NZ_ROOT}/agent"
NZ_SYSTEMD="${NZ_ROOT}/systemd"
NZ_BACKUP="${NZ_ROOT}/backups"
mkdir -p "${NZ_INSTALL}" "${NZ_SYSTEMD}" "${NZ_BACKUP}"
printf 'server: "panel.example:8008"\nclient_secret: "secret"\ntls: false\n' > "${NZ_INSTALL}/config.yml"
: > "${NZ_INSTALL}/nezha-agent"
chmod +x "${NZ_INSTALL}/nezha-agent"
printf '[Unit]\nDescription=Nezha Agent\n' > "${NZ_SYSTEMD}/nezha-agent.service"
write_stub systemctl 'exit 0'

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_NEZHA_INSTALL_DIR="${NZ_INSTALL}" \
VPS_NEZHA_SYSTEMD_DIR="${NZ_SYSTEMD}" \
VPS_BACKUP_ROOT="${NZ_BACKUP}" \
    bash "${NEZHA}" --status </dev/null >"${OUTPUT}" 2>&1 \
    || fail "nezha --status failed"
grep -Fq "${NZ_INSTALL}/nezha-agent" "${OUTPUT}" || fail "nezha --status missing install path"

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_NEZHA_INSTALL_DIR="${NZ_INSTALL}" \
VPS_NEZHA_SYSTEMD_DIR="${NZ_SYSTEMD}" \
VPS_BACKUP_ROOT="${NZ_BACKUP}" \
    bash "${NEZHA}" --uninstall --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "nezha --uninstall --yes failed"
[ ! -e "${NZ_INSTALL}" ] || fail "nezha install dir still present after uninstall"
[ ! -f "${NZ_SYSTEMD}/nezha-agent.service" ] || fail "nezha unit still present after uninstall"
ls -1 "${NZ_BACKUP}"/nezha_*/config.yml >/dev/null 2>&1 \
    || fail "nezha config backup was not created"
expect_call '^systemctl disable --now nezha-agent'
expect_call '^systemctl daemon-reload'

# --- FRP status / uninstall with path overrides ---
FRP="${REPO_ROOT}/scripts/other_tools/frp.sh"
FRP_ROOT="${TMP_ROOT}/frp"
FRP_BIN="${FRP_ROOT}/bin"
FRP_CFG="${FRP_ROOT}/etc"
FRP_SYSTEMD="${FRP_ROOT}/systemd"
FRP_BACKUP="${FRP_ROOT}/backups"
mkdir -p "${FRP_BIN}" "${FRP_CFG}" "${FRP_SYSTEMD}" "${FRP_BACKUP}"
printf '#!/bin/bash\necho frpc 0.0.0\n' > "${FRP_BIN}/frpc"
chmod +x "${FRP_BIN}/frpc"
printf 'serverAddr = "1.2.3.4"\nserverPort = 7000\nauth.token = "tok"\n' > "${FRP_CFG}/frpc.toml"
printf '[Unit]\nDescription=frp frpc\n' > "${FRP_SYSTEMD}/frpc.service"

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_FRP_BIN_DIR="${FRP_BIN}" \
VPS_FRP_CONFIG_DIR="${FRP_CFG}" \
VPS_FRP_SYSTEMD_DIR="${FRP_SYSTEMD}" \
VPS_BACKUP_ROOT="${FRP_BACKUP}" \
    bash "${FRP}" --status </dev/null >"${OUTPUT}" 2>&1 \
    || fail "frp --status failed"
grep -Fq 'frpc' "${OUTPUT}" || fail "frp --status missing frpc"

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_FRP_BIN_DIR="${FRP_BIN}" \
VPS_FRP_CONFIG_DIR="${FRP_CFG}" \
VPS_FRP_SYSTEMD_DIR="${FRP_SYSTEMD}" \
VPS_BACKUP_ROOT="${FRP_BACKUP}" \
    bash "${FRP}" --uninstall client --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "frp --uninstall client --yes failed"
[ ! -e "${FRP_BIN}/frpc" ] || fail "frpc binary still present after uninstall"
[ ! -f "${FRP_SYSTEMD}/frpc.service" ] || fail "frpc unit still present after uninstall"
[ ! -f "${FRP_CFG}/frpc.toml" ] || fail "frpc config still present after uninstall"
ls -1 "${FRP_BACKUP}"/frp_*/frpc.toml >/dev/null 2>&1 \
    || fail "frp config backup was not created"
expect_call '^systemctl disable --now frpc'
expect_call '^systemctl daemon-reload'

# --- uninstall rollback real paths ---
ROLLBACK="${REPO_ROOT}/scripts/uninstall_scripts/rollback_system_environment.sh"
RB_ROOT="${TMP_ROOT}/rollback"
RB_BACKUP="${RB_ROOT}/backups"
RB_SYSCTL="${RB_ROOT}/sysctl.conf"
RB_BBR="${RB_ROOT}/sysctl.d/99-vps-bbr.conf"
RB_SWAP="${RB_ROOT}/swapfile"
RB_FSTAB="${RB_ROOT}/fstab"
RB_PROC_SWAPS="${RB_ROOT}/proc_swaps"
RB_SWAPPINESS="${RB_ROOT}/sysctl.d/99-swappiness.conf"
RB_FAIL2BAN="${RB_ROOT}/fail2ban"
RB_HOSTNAME="${RB_ROOT}/hostname"
RB_HOSTS="${RB_ROOT}/hosts"
RB_TZ="${RB_ROOT}/timezone"
RB_LOCALTIME="${RB_ROOT}/localtime"
RB_ZONEINFO="${RB_ROOT}/zoneinfo"
mkdir -p "${RB_ROOT}/sysctl.d" "${RB_BACKUP}" "${RB_FAIL2BAN}/jail.d" "${RB_ZONEINFO}"
printf 'net.core.somaxconn = 1024\nnet.ipv4.tcp_congestion_control=bbr\nnet.core.default_qdisc=fq\n' > "${RB_SYSCTL}"
printf 'net.ipv4.tcp_congestion_control=bbr\nnet.core.default_qdisc=fq\n' > "${RB_BBR}"
: > "${RB_SWAP}"
printf 'UUID=abcd / ext4 defaults 0 1\n%s none swap sw 0 0\n/dev/vdb1 none swap sw 0 0\n' "${RB_SWAP}" > "${RB_FSTAB}"
printf 'Filename\tType\tSize\tUsed\tPriority\n%s\tfile\t1024\t0\t-3\n/dev/vdb1\tpartition\t1048572\t0\t-2\n' "${RB_SWAP}" > "${RB_PROC_SWAPS}"
printf 'vm.swappiness=10\n' > "${RB_SWAPPINESS}"
printf 'enabled\n' > "${RB_FAIL2BAN}/jail.local"
printf 'newhost\n' > "${RB_HOSTNAME}"
printf '127.0.0.1\tlocalhost\n127.0.1.1\tnewhost\n' > "${RB_HOSTS}"
: > "${RB_ZONEINFO}/UTC"
printf 'Asia/Shanghai\n' > "${RB_TZ}"
ln -sfn "${RB_ZONEINFO}/UTC" "${RB_LOCALTIME}"
write_stub sysctl 'exit 0'
write_stub systemctl 'exit 0'
write_stub swapoff 'exit 0'
write_stub hostnamectl 'exit 0'
write_stub hostname 'echo newhost; exit 0'
write_stub dpkg-query 'printf "install ok installed\n"; exit 0'
write_stub apt-get 'exit 0'

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_BACKUP_ROOT="${RB_BACKUP}" \
VPS_BBR_DROPIN="${RB_BBR}" \
VPS_SYSCTL_CONF="${RB_SYSCTL}" \
    bash "${ROLLBACK}" --target bbr --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "rollback --target bbr --yes failed"
[ ! -f "${RB_BBR}" ] || fail "BBR drop-in still present after rollback"
if grep -Eq 'tcp_congestion_control|default_qdisc' "${RB_SYSCTL}"; then
    fail "BBR lines still present in sysctl.conf after rollback"
fi
grep -Fq 'net.core.somaxconn = 1024' "${RB_SYSCTL}" || fail "rollback bbr removed unrelated sysctl lines"
ls -1 "${RB_BACKUP}"/environment_rollback_*/99-vps-bbr.conf >/dev/null 2>&1 \
    || fail "rollback bbr backup missing"
expect_call '^sysctl --system$'

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_BACKUP_ROOT="${RB_BACKUP}" \
VPS_SWAP_FILE="${RB_SWAP}" \
VPS_FSTAB_FILE="${RB_FSTAB}" \
VPS_PROC_SWAPS="${RB_PROC_SWAPS}" \
VPS_SWAPPINESS_DROPIN="${RB_SWAPPINESS}" \
    bash "${ROLLBACK}" --target swap --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "rollback --target swap --yes failed"
[ ! -e "${RB_SWAP}" ] || fail "swapfile still present after rollback"
[ ! -e "${RB_SWAPPINESS}" ] || fail "swappiness drop-in still present after rollback"
if awk -v f="${RB_SWAP}" '$1 == f {found=1} END {exit !found}' "${RB_FSTAB}"; then
    fail "fstab still contains project swapfile after rollback"
fi
grep -Fq '/dev/vdb1 none swap' "${RB_FSTAB}" || fail "rollback swap removed unrelated fstab swap"
expect_call "^swapoff -- ${RB_SWAP}$"

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_BACKUP_ROOT="${RB_BACKUP}" \
VPS_FAIL2BAN_DIR="${RB_FAIL2BAN}" \
    bash "${ROLLBACK}" --target fail2ban --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "rollback --target fail2ban --yes failed"
[ ! -d "${RB_FAIL2BAN}" ] || fail "fail2ban dir still present after rollback"
expect_call '^systemctl stop fail2ban$'
expect_call '^apt-get purge -y fail2ban$'

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_BACKUP_ROOT="${RB_BACKUP}" \
VPS_HOSTNAME_FILE="${RB_HOSTNAME}" \
VPS_HOSTS_FILE="${RB_HOSTS}" \
    bash "${ROLLBACK}" --target hostname --hostname oldhost --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "rollback --target hostname --yes failed"
[ "$(tr -d '[:space:]' <"${RB_HOSTNAME}")" = "oldhost" ] || fail "hostname file not rolled back"
grep -Eq 'newhost' "${RB_HOSTS}" && fail "hosts file still contains newhost"
grep -Eq '^127\.0\.1\.1[[:space:]]+oldhost' "${RB_HOSTS}" || fail "hosts file missing oldhost"
expect_call '^hostnamectl set-hostname oldhost$'

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_BACKUP_ROOT="${RB_BACKUP}" \
VPS_TIMEZONE_FILE="${RB_TZ}" \
VPS_LOCALTIME_FILE="${RB_LOCALTIME}" \
VPS_ZONEINFO_DIR="${RB_ZONEINFO}" \
    bash "${ROLLBACK}" --target timezone --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "rollback --target timezone --yes failed"
[ "$(tr -d '[:space:]' <"${RB_TZ}")" = "UTC" ] || fail "timezone file not set to UTC"
[ -e "${RB_LOCALTIME}" ] || fail "localtime missing after timezone rollback"

# --- clear_configuration_files nginx + security ---
CLEAR_CFG="${REPO_ROOT}/scripts/uninstall_scripts/clear_configuration_files.sh"
CLR_ROOT="${TMP_ROOT}/clear"
CLR_ETC="${CLR_ROOT}/etc"
CLR_BACKUP="${CLR_ROOT}/backups"
mkdir -p "${CLR_ETC}/nginx/conf.d" "${CLR_ETC}/ssh" "${CLR_BACKUP}"
printf 'server { listen 80; }\n' > "${CLR_ETC}/nginx/conf.d/junk.conf"
printf 'user nginx;\n' > "${CLR_ETC}/nginx/nginx.conf"
printf 'user nginx;\nworker_processes auto;\n' > "${CLR_ETC}/nginx/nginx.conf.bak"
printf 'PermitRootLogin yes\n' > "${CLR_ETC}/ssh/sshd_config"
printf 'PermitRootLogin no\n' > "${CLR_ETC}/ssh/sshd_config.bak"
write_stub sshd 'exit 0'
write_stub systemctl 'exit 0'
write_stub find 'exit 0'

# find stub above would break clear_directory_contents; restore real find via CLEAN_BIN if present.
if [ -x "${CLEAN_BIN:-}/find" ]; then
    ln -sfn "${CLEAN_BIN}/find" "${STUB_DIR}/find" 2>/dev/null || true
else
    write_stub find '
# Prefer real find when available for directory clears.
if [ -x /usr/bin/find ]; then exec /usr/bin/find "$@"; fi
if [ -x /bin/find ]; then exec /bin/find "$@"; fi
exit 0
'
fi

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_BACKUP_ROOT="${CLR_BACKUP}" \
VPS_ETC_ROOT="${CLR_ETC}" \
    bash "${CLEAR_CFG}" --target nginx --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "clear --target nginx --yes failed"
[ ! -e "${CLR_ETC}/nginx/conf.d/junk.conf" ] || fail "nginx conf.d junk still present"
grep -Fq 'worker_processes auto' "${CLR_ETC}/nginx/nginx.conf" \
    || fail "nginx.conf was not restored from .bak"
ls -1d "${CLR_BACKUP}"/config_clean_*/nginx >/dev/null 2>&1 \
    || fail "clear nginx backup missing"

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_BACKUP_ROOT="${CLR_BACKUP}" \
VPS_ETC_ROOT="${CLR_ETC}" \
VPS_SSHD_DIR="${CLR_ETC}/ssh" \
    bash "${CLEAR_CFG}" --target security --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "clear --target security --yes failed"
grep -Fq 'PermitRootLogin no' "${CLR_ETC}/ssh/sshd_config" \
    || fail "sshd_config was not restored from .bak"
expect_call '^sshd -t$'

# --- clean_service_residues wordpress + docker ---
CLEAN_SVC="${REPO_ROOT}/scripts/uninstall_scripts/clean_service_residues.sh"
CLN_ROOT="${TMP_ROOT}/clean_svc"
CLN_ETC="${CLN_ROOT}/etc"
CLN_VARLIB="${CLN_ROOT}/var/lib"
CLN_BACKUP="${CLN_ROOT}/backups"
CLN_WP="${CLN_ROOT}/wordpress"
mkdir -p "${CLN_ETC}/docker" "${CLN_VARLIB}/docker" "${CLN_BACKUP}" "${CLN_WP}"
printf 'DB_NAME\n' > "${CLN_WP}/wp-config.php"
printf '{}\n' > "${CLN_ETC}/docker/daemon.json"
: > "${CLN_VARLIB}/docker/data"
write_stub dpkg-query 'exit 1'
write_stub systemctl 'exit 0'

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_BACKUP_ROOT="${CLN_BACKUP}" \
    bash "${CLEAN_SVC}" --target wordpress --wp-dir "${CLN_WP}" --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "clean wordpress --yes failed"
[ ! -e "${CLN_WP}" ] || fail "wordpress dir still present"
ls -1d "${CLN_BACKUP}"/service_clean_*/wordpress >/dev/null 2>&1 \
    || fail "wordpress backup missing"

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_BACKUP_ROOT="${CLN_BACKUP}" \
VPS_ETC_ROOT="${CLN_ETC}" \
VPS_VAR_LIB_ROOT="${CLN_VARLIB}" \
    bash "${CLEAN_SVC}" --target docker --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "clean docker --yes failed"
[ ! -d "${CLN_ETC}/docker" ] || fail "docker config still present"
[ -e "${CLN_VARLIB}/docker/data" ] || fail "docker data removed without --purge-data"

mkdir -p "${CLN_ETC}/docker" "${CLN_VARLIB}/docker"
printf '{}\n' > "${CLN_ETC}/docker/daemon.json"
: > "${CLN_VARLIB}/docker/data"
: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_BACKUP_ROOT="${CLN_BACKUP}" \
VPS_ETC_ROOT="${CLN_ETC}" \
VPS_VAR_LIB_ROOT="${CLN_VARLIB}" \
    bash "${CLEAN_SVC}" --target docker --purge-data --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "clean docker --purge-data --yes failed"
[ ! -e "${CLN_VARLIB}/docker" ] || fail "docker data still present after --purge-data"

# --- clean_service_residues bt (local vendor uninstall + VPS_BT_*) ---
CLN_BT_ROOT="${CLN_ROOT}/bt_www"
CLN_BT_PANEL="${CLN_BT_ROOT}/server/panel"
CLN_BT_MARKER="${CLN_BT_ROOT}/vendor_uninstall.args"
mkdir -p "${CLN_BT_PANEL}" "${CLN_BT_ROOT}/server/nginx" "${CLN_BT_ROOT}/server/mysql" \
    "${CLN_BT_ROOT}/wwwroot/default" "${CLN_ETC}/init.d" "${CLN_ETC}/systemd/system"
printf 'panel\n' > "${CLN_BT_PANEL}/data.pl"
printf 'nginx\n' > "${CLN_BT_ROOT}/server/nginx/nginx.conf"
printf 'mysql\n' > "${CLN_BT_ROOT}/server/mysql/my.cnf"
printf 'site\n' > "${CLN_BT_ROOT}/wwwroot/default/index.html"
printf '#!/bin/bash\necho bt\n' > "${CLN_ETC}/init.d/bt"
printf '[Unit]\nDescription=bt\n' > "${CLN_ETC}/systemd/system/bt.service"
cat > "${CLN_BT_PANEL}/install.sh" <<EOF
#!/bin/bash
printf '%s\n' "\$*" > "${CLN_BT_MARKER}"
exit 0
EOF
chmod +x "${CLN_BT_PANEL}/install.sh"

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_BACKUP_ROOT="${CLN_BACKUP}" \
VPS_ETC_ROOT="${CLN_ETC}" \
VPS_SYSTEMD_DIR="${CLN_ETC}/systemd/system" \
VPS_BT_ROOT="${CLN_BT_ROOT}" \
    bash "${CLEAN_SVC}" --target bt --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "clean bt --yes failed"
[ -f "${CLN_BT_MARKER}" ] || fail "BT vendor uninstall helper was not invoked"
grep -Fq 'uninstall' "${CLN_BT_MARKER}" || fail "BT vendor uninstall missing uninstall arg"
[ ! -e "${CLN_BT_PANEL}" ] || fail "BT panel dir still present"
[ ! -e "${CLN_BT_ROOT}/server/nginx" ] || fail "BT nginx dir still present"
[ ! -e "${CLN_BT_ROOT}/server/mysql" ] || fail "BT mysql dir still present"
[ ! -e "${CLN_BT_ROOT}/wwwroot/default" ] || fail "BT default wwwroot still present"
[ ! -e "${CLN_ETC}/init.d/bt" ] || fail "BT init.d script still present"
[ ! -e "${CLN_ETC}/systemd/system/bt.service" ] || fail "BT systemd unit still present"
ls -1d "${CLN_BACKUP}"/service_clean_*/bt_panel >/dev/null 2>&1 \
    || fail "BT panel backup missing"
# Protected BT roots must survive (only children removed).
[ -d "${CLN_BT_ROOT}" ] || fail "BT root was removed"
[ -d "${CLN_BT_ROOT}/server" ] || fail "BT server root was removed"

# --- clean_service_residues 1panel ---
CLN_1PANEL="${CLN_ROOT}/opt_1panel"
mkdir -p "${CLN_1PANEL}" "${CLN_ETC}/systemd/system"
printf '1panel\n' > "${CLN_1PANEL}/1panel.db"
printf '[Unit]\nDescription=1panel\n' > "${CLN_ETC}/systemd/system/1panel.service"
: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_BACKUP_ROOT="${CLN_BACKUP}" \
VPS_SYSTEMD_DIR="${CLN_ETC}/systemd/system" \
VPS_1PANEL_DIR="${CLN_1PANEL}" \
    bash "${CLEAN_SVC}" --target 1panel --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "clean 1panel --yes failed"
[ ! -e "${CLN_1PANEL}" ] || fail "1panel dir still present"
[ ! -e "${CLN_ETC}/systemd/system/1panel.service" ] || fail "1panel unit still present"
ls -1d "${CLN_BACKUP}"/service_clean_*/1panel >/dev/null 2>&1 \
    || fail "1panel backup missing"
expect_call '^systemctl daemon-reload$'

# --- full_uninstall managed install ---
FULL_UNINSTALL="${REPO_ROOT}/scripts/uninstall_scripts/full_uninstall.sh"
FU_ROOT="${TMP_ROOT}/full_uninstall"
FU_PREFIX="${FU_ROOT}/usr/local"
FU_LOG="${FU_ROOT}/logs"
FU_BACKUP="${FU_ROOT}/backups"
mkdir -p "${FU_PREFIX}/bin" "${FU_PREFIX}/lib/vps-scripts" "${FU_LOG}" "${FU_BACKUP}"
printf '#!/bin/bash\nexec bash "%s/lib/vps-scripts/vps.sh" "$@"\n' "${FU_PREFIX}" > "${FU_PREFIX}/bin/vps"
printf '#!/bin/bash\n# https://github.com/everett7623/vps_scripts\necho ok\n' > "${FU_PREFIX}/lib/vps-scripts/vps.sh"
printf 'log line\n' > "${FU_LOG}/vps.log"
write_stub id 'if [ "${1:-}" = "-u" ]; then echo 0; exit 0; fi; echo 0; exit 0'

: > "${CALL_LOG}"
PATH="${STUB_DIR}:${PATH}" \
VPS_INSTALL_PREFIX="${FU_PREFIX}" \
VPS_LOG_DIR="${FU_LOG}" \
VPS_BACKUP_ROOT="${FU_BACKUP}" \
    bash "${FULL_UNINSTALL}" --yes </dev/null >"${OUTPUT}" 2>&1 \
    || fail "full_uninstall --yes failed"
[ ! -e "${FU_PREFIX}/bin/vps" ] || fail "managed vps command still present"
[ ! -d "${FU_PREFIX}/lib/vps-scripts" ] || fail "managed install dir still present"
[ ! -d "${FU_LOG}" ] || fail "log dir still present"
ls -1 "${FU_BACKUP}"/full_uninstall_*/manifest.txt >/dev/null 2>&1 \
    || fail "full_uninstall backup manifest missing"
ls -1 "${FU_BACKUP}"/full_uninstall_*/vps-command >/dev/null 2>&1 \
    || fail "full_uninstall command backup missing"

echo "Mocked pkg/systemd real-path checks are valid."
