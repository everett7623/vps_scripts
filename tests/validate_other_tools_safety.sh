#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

BBR_SCRIPT="${REPO_ROOT}/scripts/other_tools/bbr.sh"
SWAP_SCRIPT="${REPO_ROOT}/scripts/other_tools/swap.sh"
FAIL2BAN_SCRIPT="${REPO_ROOT}/scripts/other_tools/fail2ban.sh"
NEZHA_SCRIPT="${REPO_ROOT}/scripts/other_tools/nezha.sh"
FRP_SCRIPT="${REPO_ROOT}/scripts/other_tools/frp.sh"
LAUNCHER="${LAUNCHER_OVERRIDE:-${REPO_ROOT}/vps.sh}"

for script in "${BBR_SCRIPT}" "${SWAP_SCRIPT}" "${FAIL2BAN_SCRIPT}" "${NEZHA_SCRIPT}" "${FRP_SCRIPT}" "${LAUNCHER}"; do
    bash -n "${script}"
done

if grep -Fq 'cat > /etc/sysctl.conf' "${BBR_SCRIPT}"; then
    echo "BBR tool must not replace /etc/sysctl.conf." >&2
    exit 1
fi

grep -Fq '/etc/sysctl.d/99-vps-bbr.conf' "${BBR_SCRIPT}"
# Swap: exact-path fstab dedup, project-file-only swapoff, validated sizes.
grep -Fq "awk -v f=\"\${SWAP_FILE}\" '\$1 != f'" "${SWAP_SCRIPT}"
grep -Fq 'swapoff -- "${SWAP_FILE}"' "${SWAP_SCRIPT}"
grep -Fq '[[ ${1} =~ ^[1-9][0-9]*[GM]$ ]]' "${SWAP_SCRIPT}"
if grep -Eq 'swapoff[[:space:]]+-a' "${SWAP_SCRIPT}"; then
    echo "Swap tool must not disable all swap devices." >&2
    exit 1
fi
if grep -Fq 'swapoff -- "${SWAP_FILE}" 2>/dev/null || true' "${SWAP_SCRIPT}"; then
    echo "Swap tool must not ignore swapoff failure before deleting the swapfile." >&2
    exit 1
fi
for swap_flag in --size --yes --remove --dry-run; do
    grep -Fq -- "${swap_flag}" "${SWAP_SCRIPT}"
done
grep -Fq -- '--status' "${SWAP_SCRIPT}"
grep -Fq '/etc/fail2ban/jail.d/vps-scripts-sshd.local' "${FAIL2BAN_SCRIPT}"
grep -Fq 'fail2ban-client -t' "${FAIL2BAN_SCRIPT}"
grep -Fq -- '--status' "${FAIL2BAN_SCRIPT}"
grep -Fq -- '--yes' "${FAIL2BAN_SCRIPT}"
grep -Fq 'VPS_FAIL2BAN_JAIL_FILE' "${FAIL2BAN_SCRIPT}"
grep -Fq 'VPS_BBR_DROPIN' "${BBR_SCRIPT}"
grep -Fq 'VPS_OS_TYPE' "${FAIL2BAN_SCRIPT}"
grep -Fq 'VPS_NEZHA_INSTALL_DIR' "${NEZHA_SCRIPT}"
grep -Fq 'VPS_NEZHA_SYSTEMD_DIR' "${NEZHA_SCRIPT}"
grep -Fq 'VPS_FRP_BIN_DIR' "${FRP_SCRIPT}"
grep -Fq 'VPS_FRP_CONFIG_DIR' "${FRP_SCRIPT}"
grep -Fq 'VPS_FRP_SYSTEMD_DIR' "${FRP_SCRIPT}"
grep -Fq 'return "${exit_code}"' "${LAUNCHER}"
grep -Fq 'aarch64|arm64) arch=arm64' "${LAUNCHER}"
grep -Fq '模块被中断' "${LAUNCHER}"

echo "Other-tools safety checks are valid."
