#!/bin/bash
# ==============================================================================
# Script: scripts/other_tools/frp.sh
# Purpose: Install, inspect, or remove frp client/server from official releases.
# Author: everettlabs
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
WHITE='\033[0;37m'
NC='\033[0m'

readonly RELEASE_REPO_URL="https://github.com/fatedier/frp"
readonly BIN_DIR="/usr/local/bin"
readonly CONFIG_DIR="/etc/frp"

ACTION=""
ROLE=""
DRY_RUN=false
AUTO_YES=false
FRP_VERSION="${FRP_VERSION:-}"
server_addr=""
server_port="7000"
auth_token="${FRP_TOKEN:-}"
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
用法：bash frp.sh [操作] [选项]

操作：
  --install client|server   安装 frpc（客户端）或 frps（服务端）
  --status                  查看 frpc/frps 安装与服务状态
  --uninstall client|server 停止并移除（配置备份到 /var/backups/vps_scripts）
  --help                    显示帮助

选项：
  --version vX.Y.Z          指定版本（默认最新正式版）
  --server-addr <地址>      客户端连接的服务端地址
  --server-port <端口>      服务端监听/连接端口（默认 7000）
  --token <令牌>            认证令牌（也可用环境变量 FRP_TOKEN；服务端缺省时自动生成）
  --dry-run                 仅预览，不修改系统
  --yes                     跳过确认提示

说明：
  - 从 github.com/fatedier/frp 官方 Release 下载，并按 frp_sha256_checksums.txt 校验 SHA-256
  - 已存在的 /etc/frp/frpc.toml 或 frps.toml 不会被覆盖
  - 服务端默认启用 token 认证，避免无认证暴露在公网
EOF
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l|armv7) echo "arm_hf" ;;
        armv6l|arm) echo "arm" ;;
        riscv64) echo "riscv64" ;;
        loongarch64) echo "loong64" ;;
        *) return 1 ;;
    esac
}

binary_name() {
    case "$1" in
        client) echo "frpc" ;;
        server) echo "frps" ;;
        *) return 1 ;;
    esac
}

show_status() {
    local role bin
    print_info "frp 状态"
    echo "------------------------"
    for role in client server; do
        bin=$(binary_name "${role}")
        if [ -x "${BIN_DIR}/${bin}" ]; then
            echo -e "${GREEN}${bin}:${NC} $("${BIN_DIR}/${bin}" -v 2>/dev/null || echo '版本未知')"
        else
            echo -e "${YELLOW}${bin}:${NC} 未安装"
        fi
        if [ -f "${CONFIG_DIR}/${bin}.toml" ]; then
            echo "  配置: ${CONFIG_DIR}/${bin}.toml"
        fi
        if command -v systemctl >/dev/null 2>&1; then
            echo "  服务: $(systemctl is-active "${bin}" 2>/dev/null || echo inactive) / $(systemctl is-enabled "${bin}" 2>/dev/null || echo disabled)"
        fi
    done
    return 0
}

validate_inputs() {
    if [[ ! "${server_port}" =~ ^[0-9]+$ ]] || [ "${server_port}" -lt 1 ] || [ "${server_port}" -gt 65535 ]; then
        error_exit "端口必须在 1-65535 范围内"
    fi
    if [ -n "${server_addr}" ] &&
       [[ ! "${server_addr}" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]] &&
       [[ ! "${server_addr}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        error_exit "服务端地址必须是域名或 IPv4 地址"
    fi
    if [ -n "${auth_token}" ] && [[ ! "${auth_token}" =~ ^[A-Za-z0-9._~+=-]{8,128}$ ]]; then
        error_exit "令牌需为 8-128 位，且仅包含字母、数字和 ._~+=-"
    fi
    if [ -n "${FRP_VERSION}" ] && [[ ! "${FRP_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error_exit "版本格式应为 vX.Y.Z"
    fi
}

resolve_version() {
    local effective
    [ -n "${FRP_VERSION}" ] && return 0
    effective=$(curl -fsSL -o /dev/null -w '%{url_effective}' "${RELEASE_REPO_URL}/releases/latest") ||
        error_exit "无法获取 frp 最新版本"
    FRP_VERSION="${effective##*/}"
    [[ ${FRP_VERSION} =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || error_exit "无法解析 frp 最新版本: ${effective}"
}

generate_token() {
    if [ -r /proc/sys/kernel/random/uuid ]; then
        tr -d '-' < /proc/sys/kernel/random/uuid
    else
        od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
    fi
}

download_and_verify() {
    local arch="$1"
    local version_no="${FRP_VERSION#v}"
    local asset="frp_${version_no}_linux_${arch}.tar.gz"
    local base="${RELEASE_REPO_URL}/releases/download/${FRP_VERSION}"
    local expected actual

    print_info "下载 ${asset} ..."
    curl -fsSL --retry 3 -o "${WORK_DIR}/${asset}" "${base}/${asset}" || error_exit "下载 frp 失败"
    curl -fsSL --retry 3 -o "${WORK_DIR}/checksums.txt" "${base}/frp_sha256_checksums.txt" ||
        error_exit "下载 frp_sha256_checksums.txt 失败"

    expected=$(awk -v f="${asset}" '$2 == f {print $1}' "${WORK_DIR}/checksums.txt" | head -n 1)
    [[ ${expected} =~ ^[0-9a-fA-F]{64}$ ]] || error_exit "校验文件中未找到 ${asset}"
    actual=$(sha256sum "${WORK_DIR}/${asset}" | awk '{print $1}')
    [ "${actual,,}" = "${expected,,}" ] || error_exit "SHA-256 校验失败（期望 ${expected}，实际 ${actual}）"
    print_ok "SHA-256 校验通过"

    tar -xzf "${WORK_DIR}/${asset}" -C "${WORK_DIR}" --no-same-owner
    EXTRACTED_DIR="${WORK_DIR}/frp_${version_no}_linux_${arch}"
    [ -d "${EXTRACTED_DIR}" ] || error_exit "解压后未找到 ${EXTRACTED_DIR}"
}

write_config() {
    local bin="$1"
    local config="${CONFIG_DIR}/${bin}.toml"

    if [ -f "${config}" ]; then
        print_warn "[保留] 已存在 ${config}，不覆盖"
        return 0
    fi
    mkdir -p -- "${CONFIG_DIR}"
    (
        umask 077
        if [ "${bin}" = "frps" ]; then
            cat > "${config}" <<EOF
bindPort = ${server_port}
auth.method = "token"
auth.token = "${auth_token}"
EOF
        else
            cat > "${config}" <<EOF
serverAddr = "${server_addr}"
serverPort = ${server_port}
auth.method = "token"
auth.token = "${auth_token}"

# 在下方添加代理，例如：
# [[proxies]]
# name = "ssh"
# type = "tcp"
# localIP = "127.0.0.1"
# localPort = 22
# remotePort = 6000
EOF
        fi
    )
    chmod 600 -- "${config}"
}

write_service() {
    local bin="$1"
    cat > "/etc/systemd/system/${bin}.service" <<EOF
[Unit]
Description=frp ${bin}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${BIN_DIR}/${bin} -c ${CONFIG_DIR}/${bin}.toml
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

confirm_or_exit() {
    local confirm=""
    [ "${AUTO_YES}" = true ] && return 0
    read -r -p "$1 (y/n): " confirm || confirm="n"
    case "${confirm}" in
        y|Y) ;;
        *) print_warn "已取消操作"; exit 0 ;;
    esac
}

prompt_role() {
    local choice=""
    [ -n "${ROLE}" ] && return 0
    if [ "${AUTO_YES}" = true ] || [ ! -t 0 ]; then
        error_exit "非交互模式下请指定 client 或 server"
    fi
    echo "1. frpc 客户端（把本机服务映射出去）"
    echo "2. frps 服务端（在有公网 IP 的机器上运行）"
    read -r -p "请选择 [1-2]: " choice || choice=""
    case "${choice}" in
        1) ROLE="client" ;;
        2) ROLE="server" ;;
        *) error_exit "无效的选择" ;;
    esac
}

do_install() {
    local arch bin
    prompt_role
    bin=$(binary_name "${ROLE}") || error_exit "角色必须为 client 或 server"
    arch=$(detect_arch) || error_exit "不支持的系统架构: $(uname -m)"

    if [ "${ROLE}" = "client" ] && [ -z "${server_addr}" ] && [ ! -f "${CONFIG_DIR}/frpc.toml" ]; then
        if [ "${AUTO_YES}" = true ] || [ ! -t 0 ]; then
            error_exit "安装客户端时请提供 --server-addr（或预先放置 ${CONFIG_DIR}/frpc.toml）"
        fi
        read -r -p "请输入 frps 服务端地址: " server_addr || server_addr=""
        [ -n "${auth_token}" ] || read -r -p "请输入认证令牌: " auth_token || true
    fi
    validate_inputs

    if [ "${DRY_RUN}" = true ]; then
        print_warn "DRY-RUN：以下仅为预览，不会修改系统。"
        echo "[DRY-RUN] 下载 ${RELEASE_REPO_URL} ${FRP_VERSION:-最新版} 的 linux_${arch} 包并校验 SHA-256"
        echo "[DRY-RUN] 安装 ${BIN_DIR}/${bin}"
        if [ -f "${CONFIG_DIR}/${bin}.toml" ]; then
            echo "[DRY-RUN] 保留现有 ${CONFIG_DIR}/${bin}.toml"
        else
            echo "[DRY-RUN] 写入 ${CONFIG_DIR}/${bin}.toml（权限 600，token 认证，端口 ${server_port}）"
        fi
        echo "[DRY-RUN] 写入 /etc/systemd/system/${bin}.service 并 enable --now ${bin}"
        return 0
    fi

    [ "$(id -u)" = "0" ] || error_exit "此脚本需要root权限运行（预览可使用 --dry-run）"
    command -v systemctl >/dev/null 2>&1 || error_exit "当前系统不支持 systemd"
    command -v sha256sum >/dev/null 2>&1 || error_exit "缺少 sha256sum"
    confirm_or_exit "确定要安装 ${bin} 吗?"

    if [ "${ROLE}" = "server" ] && [ -z "${auth_token}" ] && [ ! -f "${CONFIG_DIR}/frps.toml" ]; then
        auth_token=$(generate_token)
    fi
    if [ "${ROLE}" = "client" ] && [ -z "${auth_token}" ] && [ ! -f "${CONFIG_DIR}/frpc.toml" ]; then
        error_exit "客户端需要与服务端一致的认证令牌（--token 或 FRP_TOKEN）"
    fi

    resolve_version
    WORK_DIR=$(mktemp -d "/tmp/frp-install.XXXXXX") || error_exit "创建临时目录失败"
    download_and_verify "${arch}"

    systemctl stop "${bin}" >/dev/null 2>&1 || true
    install -m 0755 "${EXTRACTED_DIR}/${bin}" "${BIN_DIR}/${bin}"
    write_config "${bin}"
    if ! "${BIN_DIR}/${bin}" verify -c "${CONFIG_DIR}/${bin}.toml" >/dev/null 2>&1; then
        error_exit "配置校验失败：${BIN_DIR}/${bin} verify -c ${CONFIG_DIR}/${bin}.toml"
    fi
    write_service "${bin}"
    systemctl daemon-reload
    systemctl enable "${bin}" >/dev/null
    systemctl restart "${bin}"

    if systemctl is-active "${bin}" >/dev/null 2>&1; then
        print_ok "${bin} ${FRP_VERSION} 已启动"
    else
        error_exit "${bin} 启动失败，请执行 journalctl -u ${bin} 查看日志"
    fi
    echo -e "${WHITE}配置文件: ${YELLOW}${CONFIG_DIR}/${bin}.toml${NC}"
    if [ "${ROLE}" = "server" ]; then
        echo -e "${WHITE}监听端口: ${YELLOW}$(awk -F' *= *' '$1 == "bindPort" {print $2}' "${CONFIG_DIR}/frps.toml")${NC}"
        echo -e "${WHITE}客户端令牌请查看配置文件中的 auth.token（未在终端回显）${NC}"
        print_warn "请在防火墙/安全组放行监听端口及 remotePort 端口"
    fi
}

do_uninstall() {
    local bin backup_dir
    prompt_role
    bin=$(binary_name "${ROLE}") || error_exit "角色必须为 client 或 server"
    backup_dir="${VPS_BACKUP_ROOT:-/var/backups/vps_scripts}/frp_$(date +%Y%m%d_%H%M%S)"

    if [ "${DRY_RUN}" = true ]; then
        print_warn "DRY-RUN：以下仅为预览，不会修改系统。"
        echo "[DRY-RUN] 停止并禁用 ${bin}"
        echo "[DRY-RUN] 备份 ${CONFIG_DIR}/${bin}.toml 到 ${backup_dir}"
        echo "[DRY-RUN] 删除 ${BIN_DIR}/${bin}、/etc/systemd/system/${bin}.service、${CONFIG_DIR}/${bin}.toml"
        return 0
    fi
    [ "$(id -u)" = "0" ] || error_exit "此脚本需要root权限运行（预览可使用 --dry-run）"
    confirm_or_exit "确定要卸载 ${bin} 吗?"

    if command -v systemctl >/dev/null 2>&1; then
        systemctl disable --now "${bin}" >/dev/null 2>&1 || true
    fi
    if [ -f "${CONFIG_DIR}/${bin}.toml" ]; then
        mkdir -p -- "${backup_dir}"
        cp -a -- "${CONFIG_DIR}/${bin}.toml" "${backup_dir}/"
        rm -f -- "${CONFIG_DIR}/${bin}.toml"
        echo -e "${WHITE}配置备份: ${YELLOW}${backup_dir}/${bin}.toml${NC}"
    fi
    rm -f -- "${BIN_DIR}/${bin}" "/etc/systemd/system/${bin}.service"
    rmdir -- "${CONFIG_DIR}" 2>/dev/null || true
    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload || true
    fi
    print_ok "${bin} 已卸载"
}

parse_role_arg() {
    case "${1:-}" in
        client|frpc) ROLE="client" ;;
        server|frps) ROLE="server" ;;
        *) return 1 ;;
    esac
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h) show_help; exit 0 ;;
            --status) ACTION="status" ;;
            --install|--uninstall)
                ACTION="${1#--}"
                if [ $# -ge 2 ] && parse_role_arg "$2"; then
                    shift
                fi
                ;;
            --dry-run) DRY_RUN=true ;;
            --yes|-y) AUTO_YES=true ;;
            --version|--server-addr|--server-port|--token)
                [ $# -ge 2 ] || error_exit "$1 需要参数"
                case "$1" in
                    --version) FRP_VERSION="$2" ;;
                    --server-addr) server_addr="$2" ;;
                    --server-port) server_port="$2" ;;
                    --token) auth_token="$2" ;;
                esac
                shift
                ;;
            *) error_exit "未知参数: $1（使用 --help 查看用法）" ;;
        esac
        shift
    done
}

interactive_action() {
    local choice=""
    [ -t 0 ] || { show_status; return 0; }
    show_status
    echo ""
    echo "1. 安装 / 更新"
    echo "2. 卸载"
    echo "0. 返回"
    read -r -p "请选择 [0-2]: " choice || choice="0"
    case "${choice}" in
        1) ACTION="install" ;;
        2) ACTION="uninstall" ;;
        *) ACTION="none" ;;
    esac
}

main() {
    parse_args "$@"
    [ -n "${ACTION}" ] || interactive_action
    case "${ACTION}" in
        status) show_status ;;
        install) do_install ;;
        uninstall) do_uninstall ;;
        *) return 0 ;;
    esac
}

main "$@"
