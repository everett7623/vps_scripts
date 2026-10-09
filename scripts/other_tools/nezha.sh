#!/bin/bash
# ==============================================================================
# Script: scripts/other_tools/nezha.sh
# Purpose: Install, inspect, or remove the Nezha monitoring agent (v1+).
# Author: everettlabs
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
WHITE='\033[0;37m'
NC='\033[0m'

readonly RELEASE_BASE_URL="https://github.com/nezhahq/agent/releases/latest/download"
readonly INSTALL_DIR="/opt/nezha/agent"
readonly AGENT_BIN="${INSTALL_DIR}/nezha-agent"
readonly CONFIG_FILE="${INSTALL_DIR}/config.yml"
readonly SERVICE_NAME="nezha-agent"
readonly SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

ACTION="install"
DRY_RUN=false
AUTO_YES=false
server="${NZ_SERVER_HOST:-}"
port="${NZ_SERVER_PORT:-}"
secret="${NZ_CLIENT_SECRET:-}"
use_tls="${NZ_TLS:-false}"
WORK_DIR=""

print_info() { echo -e "${WHITE}$*${NC}"; }
print_ok() { echo -e "${GREEN}$*${NC}"; }
print_warn() { echo -e "${YELLOW}$*${NC}"; }
error_exit() {
    echo -e "${RED}[错误] $*${NC}" >&2
    exit 1
}

cleanup() {
    if [ -n "${WORK_DIR}" ] && [ -d "${WORK_DIR}" ]; then
        rm -rf -- "${WORK_DIR}"
    fi
}
trap cleanup EXIT

show_help() {
    cat <<'EOF'
用法：bash nezha.sh [选项]

操作：
  （默认）             安装/更新哪吒监控 Agent（v1+）
  --status             查看 Agent 安装与服务状态
  --uninstall          停止并移除 Agent（配置备份到 /var/backups/vps_scripts）
  --help               显示帮助

安装参数（缺省时交互输入）：
  --server <域名|IP>   面板通信地址
  --port <端口>        面板通信端口
  --secret <密钥>      客户端密钥（也可用环境变量 NZ_CLIENT_SECRET 传入，避免出现在进程列表）
  --tls                与面板使用 TLS 通信
  --dry-run            仅预览将执行的操作，不修改系统
  --yes                跳过确认提示

下载的 Agent 压缩包会使用上游 checksums.txt 进行 SHA-256 校验。
EOF
}

show_status() {
    print_info "哪吒监控 Agent 状态"
    echo "------------------------"
    if [ -x "${AGENT_BIN}" ]; then
        echo -e "${GREEN}可执行文件:${NC} ${AGENT_BIN}"
        "${AGENT_BIN}" -v 2>/dev/null || true
    else
        echo -e "${YELLOW}未安装:${NC} ${AGENT_BIN}"
    fi
    if [ -f "${CONFIG_FILE}" ]; then
        echo -e "${GREEN}配置文件:${NC} ${CONFIG_FILE}"
        grep -E '^(server|tls):' "${CONFIG_FILE}" 2>/dev/null || true
    fi
    if command -v systemctl >/dev/null 2>&1; then
        echo -e "${GREEN}服务状态:${NC} $(systemctl is-active "${SERVICE_NAME}" 2>/dev/null || echo inactive)"
        echo -e "${GREEN}开机自启:${NC} $(systemctl is-enabled "${SERVICE_NAME}" 2>/dev/null || echo disabled)"
    fi
    return 0
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l|armv6l|arm) echo "arm" ;;
        i386|i686) echo "386" ;;
        riscv64) echo "riscv64" ;;
        s390x) echo "s390x" ;;
        loongarch64) echo "loong64" ;;
        *) return 1 ;;
    esac
}

validate_inputs() {
    if [[ ! "${server}" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]] &&
       [[ ! "${server}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        error_exit "服务器地址必须是域名或 IPv4 地址"
    fi
    if [[ ! "${port}" =~ ^[0-9]+$ ]] || [ "${port}" -lt 1 ] || [ "${port}" -gt 65535 ]; then
        error_exit "端口必须在 1-65535 范围内"
    fi
    if [ -z "${secret}" ] || [[ "${secret}" == *$'\n'* ]] || [[ "${secret}" == *$'\r'* ]]; then
        error_exit "客户端密钥不能为空且不能包含换行符"
    fi
    case "${use_tls}" in
        true|false) ;;
        *) error_exit "TLS 参数只能为 true 或 false" ;;
    esac
}

prompt_missing_inputs() {
    if [ -n "${server}" ] && [ -n "${port}" ] && [ -n "${secret}" ]; then
        return 0
    fi
    if [ "${AUTO_YES}" = true ] || [ ! -t 0 ]; then
        error_exit "非交互模式下请提供 --server、--port 和 --secret（或 NZ_CLIENT_SECRET）"
    fi
    [ -n "${server}" ] || read -r -p "请输入哪吒监控服务器地址: " server || true
    [ -n "${port}" ] || read -r -p "请输入哪吒监控服务器端口: " port || true
    [ -n "${secret}" ] || { read -r -s -p "请输入客户端密钥: " secret || true; echo; }
}

yaml_quote() {
    local value="$1"
    printf "'%s'" "${value//\'/\'\'}"
}

ensure_dependencies() {
    local -a missing=()
    local cmd
    for cmd in curl unzip sha256sum; do
        command -v "${cmd}" >/dev/null 2>&1 || missing+=("${cmd}")
    done
    [ "${#missing[@]}" -eq 0 ] && return 0

    print_info "安装必要依赖: unzip curl coreutils"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get -y install curl unzip coreutils
    elif command -v dnf >/dev/null 2>&1; then
        dnf -y install curl unzip coreutils
    elif command -v yum >/dev/null 2>&1; then
        yum -y install curl unzip coreutils
    else
        error_exit "缺少依赖: ${missing[*]}，且未识别包管理器"
    fi
}

download_and_verify() {
    local asset="$1"
    local archive="${WORK_DIR}/${asset}"
    local checksums="${WORK_DIR}/checksums.txt"
    local expected actual

    print_info "下载 ${asset} ..."
    curl -fsSL --retry 3 -o "${archive}" "${RELEASE_BASE_URL}/${asset}" ||
        error_exit "下载 Agent 失败"
    curl -fsSL --retry 3 -o "${checksums}" "${RELEASE_BASE_URL}/checksums.txt" ||
        error_exit "下载 checksums.txt 失败"

    expected=$(awk -v f="${asset}" '$2 == f || $2 == "*" f {print $1}' "${checksums}" | head -n 1)
    [[ ${expected} =~ ^[0-9a-fA-F]{64}$ ]] || error_exit "checksums.txt 中未找到 ${asset} 的 SHA-256"
    actual=$(sha256sum "${archive}" | awk '{print $1}')
    if [ "${actual,,}" != "${expected,,}" ]; then
        error_exit "SHA-256 校验失败（期望 ${expected}，实际 ${actual}）"
    fi
    print_ok "SHA-256 校验通过"

    unzip -Z1 "${archive}" | grep -qx 'nezha-agent' || error_exit "压缩包不包含 nezha-agent"
    unzip -o -q "${archive}" nezha-agent -d "${WORK_DIR}"
    [ -f "${WORK_DIR}/nezha-agent" ] || error_exit "未找到 Nezha Agent 可执行文件"
}

write_config() {
    local uuid=""
    if [ -f "${CONFIG_FILE}" ]; then
        uuid=$(awk -F': *' '$1 == "uuid" {gsub(/["'"'"']/, "", $2); print $2}' "${CONFIG_FILE}" | head -n 1)
    fi
    if [ -z "${uuid}" ] && [ -r /proc/sys/kernel/random/uuid ]; then
        uuid=$(cat /proc/sys/kernel/random/uuid)
    fi

    (
        umask 077
        {
            printf 'server: %s\n' "$(yaml_quote "${server}:${port}")"
            printf 'client_secret: %s\n' "$(yaml_quote "${secret}")"
            printf 'tls: %s\n' "${use_tls}"
            if [ -n "${uuid}" ]; then
                printf 'uuid: %s\n' "$(yaml_quote "${uuid}")"
            fi
            printf 'disable_auto_update: false\n'
        } > "${CONFIG_FILE}.tmp"
    )
    mv -f -- "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
    chmod 600 -- "${CONFIG_FILE}"
}

write_service() {
    cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Nezha Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${AGENT_BIN} -c ${CONFIG_FILE}
Restart=always
RestartSec=5
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF
    if command -v systemd-analyze >/dev/null 2>&1 && ! systemd-analyze verify "${SERVICE_FILE}"; then
        error_exit "systemd 服务配置校验失败"
    fi
}

confirm_or_exit() {
    local confirm=""
    [ "${AUTO_YES}" = true ] && return 0
    [ "${DRY_RUN}" = true ] && return 0
    read -r -p "$1 (y/n): " confirm || confirm="n"
    case "${confirm}" in
        y|Y) ;;
        *) print_warn "已取消操作"; exit 0 ;;
    esac
}

do_install() {
    local arch asset
    arch=$(detect_arch) || error_exit "不支持的系统架构: $(uname -m)"
    asset="nezha-agent_linux_${arch}.zip"

    print_info "哪吒监控 Agent 安装工具"
    echo "------------------------"
    print_warn "警告: 安装哪吒监控将收集系统信息并发送至你配置的面板"
    prompt_missing_inputs
    validate_inputs

    if [ "${DRY_RUN}" = true ]; then
        print_warn "DRY-RUN: 未实际修改系统。将执行："
        echo "  下载 ${RELEASE_BASE_URL}/${asset} 并按 checksums.txt 校验 SHA-256"
        echo "  安装 ${AGENT_BIN}"
        echo "  写入 ${CONFIG_FILE}（server=${server}:${port}, tls=${use_tls}, 权限 600）"
        echo "  写入 ${SERVICE_FILE} 并 enable --now ${SERVICE_NAME}"
        return 0
    fi

    [ "$(id -u)" = "0" ] || error_exit "此脚本需要root权限运行（预览可使用 --dry-run）"
    command -v systemctl >/dev/null 2>&1 || error_exit "当前系统不支持 systemd"
    confirm_or_exit "确定要安装哪吒监控 Agent 吗?"

    ensure_dependencies
    WORK_DIR=$(mktemp -d "/tmp/nezha-agent.XXXXXX") || error_exit "创建临时目录失败"
    download_and_verify "${asset}"

    mkdir -p -- "${INSTALL_DIR}"
    systemctl stop "${SERVICE_NAME}" >/dev/null 2>&1 || true
    install -m 0755 "${WORK_DIR}/nezha-agent" "${AGENT_BIN}"
    write_config
    write_service

    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}" >/dev/null
    systemctl restart "${SERVICE_NAME}"

    if systemctl is-active "${SERVICE_NAME}" >/dev/null 2>&1; then
        print_ok "哪吒监控 Agent 已成功启动"
    else
        error_exit "哪吒监控 Agent 启动失败，请执行 journalctl -u ${SERVICE_NAME} 查看日志"
    fi

    echo ""
    echo -e "${WHITE}服务器地址: ${YELLOW}${server}:${port}${NC}"
    echo -e "${WHITE}TLS: ${YELLOW}${use_tls}${NC}"
    echo -e "${WHITE}配置文件: ${YELLOW}${CONFIG_FILE}${NC}（密钥已写入，未在终端回显）"
    echo -e "${WHITE}管理命令: ${YELLOW}systemctl {start|stop|restart|status} ${SERVICE_NAME}${NC}"
}

do_uninstall() {
    local backup_dir
    backup_dir="${VPS_BACKUP_ROOT:-/var/backups/vps_scripts}/nezha_$(date +%Y%m%d_%H%M%S)"

    print_info "卸载哪吒监控 Agent"
    if [ "${DRY_RUN}" = true ]; then
        print_warn "DRY-RUN: 未实际修改系统。将执行："
        echo "  停止并禁用 ${SERVICE_NAME}"
        echo "  备份 ${CONFIG_FILE} 到 ${backup_dir}"
        echo "  删除 ${SERVICE_FILE} 与 ${INSTALL_DIR}"
        return 0
    fi
    [ "$(id -u)" = "0" ] || error_exit "此脚本需要root权限运行（预览可使用 --dry-run）"
    confirm_or_exit "确定要卸载哪吒监控 Agent 吗?"

    if command -v systemctl >/dev/null 2>&1; then
        systemctl disable --now "${SERVICE_NAME}" >/dev/null 2>&1 || true
    fi
    if [ -f "${CONFIG_FILE}" ]; then
        mkdir -p -- "${backup_dir}"
        cp -a -- "${CONFIG_FILE}" "${backup_dir}/config.yml"
        echo -e "${WHITE}配置备份: ${YELLOW}${backup_dir}/config.yml${NC}"
    fi
    rm -f -- "${SERVICE_FILE}"
    rm -rf -- "${INSTALL_DIR}"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload || true
    fi
    print_ok "哪吒监控 Agent 已卸载"
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h) show_help; exit 0 ;;
            --status) ACTION="status" ;;
            --uninstall) ACTION="uninstall" ;;
            --dry-run) DRY_RUN=true ;;
            --yes|-y) AUTO_YES=true ;;
            --tls) use_tls=true ;;
            --server|--port|--secret)
                [ $# -ge 2 ] || error_exit "$1 需要参数"
                case "$1" in
                    --server) server="$2" ;;
                    --port) port="$2" ;;
                    --secret) secret="$2" ;;
                esac
                shift
                ;;
            *) error_exit "未知参数: $1（使用 --help 查看用法）" ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"
    case "${ACTION}" in
        status) show_status ;;
        uninstall) do_uninstall ;;
        install) do_install ;;
    esac
}

main "$@"
