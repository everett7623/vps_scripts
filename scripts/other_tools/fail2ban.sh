#!/bin/bash
set -euo pipefail
# ==============================================================================
# Script: scripts/other_tools/fail2ban.sh
# Purpose: Install and configure Fail2ban SSH jail with status/dry-run modes.
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
WHITE='\033[0;37m'
NC='\033[0m'

JAIL_FILE="${VPS_FAIL2BAN_JAIL_FILE:-/etc/fail2ban/jail.d/vps-scripts-sshd.local}"
DRY_RUN=false
AUTO_YES=false

require_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}" 1>&2
        exit 1
    fi
}

show_help() {
    cat <<'EOF'
用法：bash fail2ban.sh [选项]

选项：
  --status    显示 Fail2ban / SSH jail 状态
  --dry-run   预览安装与配置动作，不修改系统
  --yes       非交互确认并执行安装（可与 --dry-run 联用）
  --help      显示帮助

无参数时进入交互安装流程。
EOF
}

show_status() {
    echo -e "${WHITE}Fail2ban 状态${NC}"
    echo "------------------------"
    if command -v fail2ban-server >/dev/null 2>&1; then
        echo -e "${GREEN}已安装:${NC} $(command -v fail2ban-server)"
    else
        echo -e "${YELLOW}未安装 fail2ban-server${NC}"
    fi
    if systemctl is-active fail2ban >/dev/null 2>&1; then
        echo -e "${GREEN}服务:${NC} active"
    else
        echo -e "${YELLOW}服务:${NC} inactive 或未安装"
    fi
    if [ -f "${JAIL_FILE}" ]; then
        echo -e "${GREEN}项目 jail:${NC} ${JAIL_FILE}"
    else
        echo -e "${YELLOW}项目 jail 未部署${NC}"
    fi
    if command -v fail2ban-client >/dev/null 2>&1; then
        fail2ban-client status sshd 2>/dev/null || true
    fi
}

preview_plan() {
    echo -e "${WHITE}DRY-RUN 预览${NC}"
    echo "------------------------"
    echo "将安装 fail2ban 软件包（apt/yum）"
    echo "将写入 ${JAIL_FILE}（保留已有文件备份）"
    echo "将 fail2ban-client -t 校验配置"
    echo "将 enable/restart fail2ban 服务"
    echo -e "${YELLOW}未实际修改系统。${NC}"
}

detect_system_type() {
    if [ -n "${VPS_OS_TYPE:-}" ]; then
        echo "${VPS_OS_TYPE}"
        return 0
    fi
    if [ -f /etc/redhat-release ]; then
        echo "centos"
    elif [ -f /etc/debian_version ]; then
        if grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
            echo "ubuntu"
        else
            echo "debian"
        fi
    else
        echo ""
    fi
}

install_fail2ban() {
    local system_type
    local confirm=""
    local jail_dir=""

    echo -e "${WHITE}Fail2ban安全工具${NC}"
    echo "------------------------"

    if [ "${DRY_RUN}" = true ]; then
        preview_plan
        return 0
    fi

    if [ "${AUTO_YES}" != true ]; then
        echo -e "${YELLOW}警告: 安装Fail2ban将增强系统安全性，但可能影响正常访问${NC}"
        read -r -p "确定要安装Fail2ban吗? (y/n): " confirm
        case "${confirm}" in
            y|Y) echo -e "${GREEN}开始安装Fail2ban...${NC}" ;;
            n|N) echo -e "${YELLOW}已取消操作${NC}"; return 0 ;;
            *) echo -e "${RED}无效选择，已取消操作${NC}"; return 1 ;;
        esac
    else
        echo -e "${GREEN}开始安装Fail2ban（--yes）...${NC}"
    fi

    system_type=$(detect_system_type)
    if [ -z "${system_type}" ]; then
        echo -e "${RED}不支持的操作系统类型${NC}"
        return 1
    fi

    echo -e "${WHITE}检测到系统类型: ${YELLOW}${system_type}${NC}"
    echo -e "${WHITE}安装Fail2ban...${NC}"
    if [ "${system_type}" = "centos" ]; then
        yum -y install epel-release
        yum -y install fail2ban
    else
        apt-get update
        apt-get -y install fail2ban
    fi

    if ! command -v fail2ban-server >/dev/null 2>&1; then
        echo -e "${RED}Fail2ban安装失败，请手动检查${NC}"
        return 1
    fi

    echo -e "${WHITE}配置Fail2ban...${NC}"
    jail_dir=$(dirname -- "${JAIL_FILE}")
    mkdir -p -- "${jail_dir}"
    if [ -f "${JAIL_FILE}" ]; then
        cp -- "${JAIL_FILE}" "${JAIL_FILE}.bak"
    fi
    cat > "${JAIL_FILE}" << EOF
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime = 86400
findtime = 3600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
maxretry = 3
bantime = 86400
EOF

    echo -e "${WHITE}启动Fail2ban服务...${NC}"
    if ! fail2ban-client -t; then
        echo -e "${RED}Fail2ban配置检查失败，已保留备份文件${NC}"
        return 1
    fi
    systemctl enable fail2ban
    systemctl restart fail2ban

    if systemctl is-active fail2ban >/dev/null 2>&1; then
        echo -e "${GREEN}Fail2ban服务已成功启动${NC}"
    else
        echo -e "${RED}Fail2ban服务启动失败，请手动检查${NC}"
        return 1
    fi

    echo ""
    echo -e "${GREEN}Fail2ban安装配置完成${NC}"
    echo -e "${WHITE}主要配置参数:${NC}"
    echo -e "${YELLOW}封禁时间: 24小时${NC}"
    echo -e "${YELLOW}最大尝试次数: 3次${NC}"
    echo -e "${YELLOW}保护服务: SSH${NC}"
    echo ""
    echo -e "${WHITE}查看封禁IP: ${YELLOW}fail2ban-client status sshd${NC}"
    echo -e "${WHITE}解封IP: ${YELLOW}fail2ban-client set sshd unbanip IP地址${NC}"
    echo ""
}

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h)
                show_help
                return 0
                ;;
            --status)
                show_status
                return 0
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --yes|-y)
                AUTO_YES=true
                shift
                ;;
            *)
                echo -e "${RED}未知参数: $1${NC}"
                show_help
                return 1
                ;;
        esac
    done

    if [ "${DRY_RUN}" = true ]; then
        require_root
        preview_plan
        return 0
    fi

    require_root
    install_fail2ban
}

main "$@"
