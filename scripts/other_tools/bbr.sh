#!/bin/bash
set -euo pipefail
#/vps_scripts/scripts/other_tools/bbr.sh - VPS Scripts BBR网络加速工具

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 恢复默认颜色

SYSCTL_CONF="${VPS_SYSCTL_CONF:-/etc/sysctl.conf}"
BBR_DROPIN="${VPS_BBR_DROPIN:-/etc/sysctl.d/99-vps-bbr.conf}"
SYSCTL_D=$(dirname -- "${BBR_DROPIN}")

# 检查是否有root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 此脚本需要root权限运行!${NC}"
        echo -e "${YELLOW}请使用sudo或root用户执行此脚本。${NC}"
        exit 1
    fi
}

# 安装必要工具
install_tools() {
    # 检查bc命令是否存在
    if ! command -v bc &> /dev/null; then
        echo -e "${YELLOW}正在安装bc工具...${NC}"
        
        # 根据不同系统安装
        if command -v apt &> /dev/null; then
            apt update && apt install -y bc
        elif command -v yum &> /dev/null; then
            yum install -y bc
        elif command -v pacman &> /dev/null; then
            pacman -S --noconfirm bc
        else
            echo -e "${RED}无法安装bc工具，请手动安装。${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}bc工具安装完成。${NC}"
    fi
}

# 检查系统内核版本
check_kernel() {
    local kernel_version=$(uname -r | cut -d. -f1-2)
    echo -e "${YELLOW}当前内核版本: ${GREEN}$(uname -r)${NC}"
    
    # BBR需要4.9或更高版本的内核
    if (( $(echo "$kernel_version >= 4.9" | bc -l) )); then
        echo -e "${GREEN}内核版本符合BBR要求。${NC}"
        return 0
    else
        echo -e "${YELLOW}警告: 内核版本过低，可能无法支持BBR。${NC}"
        echo -e "${YELLOW}建议升级到4.9或更高版本的内核。${NC}"
        return 1
    fi
}

# 检查BBR是否已启用
check_bbr_status() {
    local bbr_status=""
    local fq_status=""

    bbr_status=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -o "bbr" || true)
    fq_status=$(sysctl net.core.default_qdisc 2>/dev/null | grep -o "fq" || true)
    
    if [ "$bbr_status" == "bbr" ] && [ "$fq_status" == "fq" ]; then
        echo -e "${GREEN}BBR已经启用!${NC}"
        return 0
    else
        echo -e "${YELLOW}BBR未启用或配置不完整。${NC}"
        return 1
    fi
}

# 安装BBR
install_bbr() {
    echo -e "${YELLOW}正在配置BBR网络优化...${NC}"

    mkdir -p -- "${SYSCTL_D}"

    # 备份原配置文件（仅当指向系统默认路径时）
    if [ -f "${SYSCTL_CONF}" ] && [ "${SYSCTL_CONF}" = "/etc/sysctl.conf" ]; then
        cp -- "${SYSCTL_CONF}" "${SYSCTL_CONF}.bak"
        echo -e "${YELLOW}已备份原配置文件到 ${SYSCTL_CONF}.bak${NC}"
    fi

    # 写入BBR配置（默认 /etc/sysctl.d/99-vps-bbr.conf）
    cat > "${BBR_DROPIN}" << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

    # 应用配置
    if sysctl -p && sysctl --system; then
        echo -e "${GREEN}BBR配置已成功应用!${NC}"
        return 0
    else
        echo -e "${RED}应用BBR配置失败!${NC}"
        return 1
    fi
}

# 卸载BBR
uninstall_bbr() {
    echo -e "${YELLOW}正在卸载BBR网络优化...${NC}"

    # 移除本工具写入的 drop-in（默认 /etc/sysctl.d/99-vps-bbr.conf）
    if [ -f "${BBR_DROPIN}" ]; then
        rm -f -- "${BBR_DROPIN}"
        echo -e "${YELLOW}已移除本工具写入的BBR配置。${NC}"
    else
        echo -e "${YELLOW}未找到本工具写入的BBR配置。${NC}"
    fi

    # 应用配置
    if sysctl -p && sysctl --system; then
        echo -e "${GREEN}BBR配置已成功卸载!${NC}"
        return 0
    else
        echo -e "${RED}卸载BBR配置失败!${NC}"
        return 1
    fi
}

# 显示BBR状态
show_bbr_status() {
    echo -e "${YELLOW}正在检查BBR状态...${NC}"
    
    # 显示当前TCP拥塞控制算法
    local tcp_cc=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    echo -e "${YELLOW}TCP拥塞控制算法: ${GREEN}$tcp_cc${NC}"
    
    # 显示当前默认队列规则
    local default_qdisc=$(sysctl net.core.default_qdisc | awk '{print $3}')
    echo -e "${YELLOW}默认队列规则: ${GREEN}$default_qdisc${NC}"
    
    # 检查BBR模块是否已加载
    if lsmod | grep -q tcp_bbr; then
        echo -e "${GREEN}BBR模块已加载。${NC}"
    else
        echo -e "${YELLOW}BBR模块未加载或不可用。${NC}"
    fi
    
    # 显示BBR当前状态
    check_bbr_status || true
}

show_help() {
    cat <<'EOF'
用法：bash bbr.sh [选项]

选项：
  --status     仅显示 BBR 状态
  --install    非交互启用 BBR（需 root）
  --uninstall  非交互禁用 BBR（需 root）
  --help       显示帮助

无参数时进入交互菜单。
EOF
}

# 主函数
main() {
    case "${1:-}" in
        --help|-h)
            show_help
            return 0
            ;;
        --status)
            show_bbr_status
            return 0
            ;;
        --install)
            check_root
            install_tools
            check_kernel || true
            install_bbr
            return 0
            ;;
        --uninstall)
            check_root
            uninstall_bbr
            return 0
            ;;
        "")
            ;;
        *)
            echo -e "${RED}未知参数: ${1}${NC}"
            show_help
            return 1
            ;;
    esac

    echo -e "${YELLOW}=============================================${NC}"
    echo -e "${YELLOW}           BBR网络优化工具                   ${NC}"
    echo -e "${YELLOW}=============================================${NC}"
    echo ""

    check_root
    install_tools
    check_kernel || true

    echo ""
    show_bbr_status
    echo ""

    echo "请选择要执行的操作:"
    echo "1. 安装/启用BBR"
    echo "2. 卸载/禁用BBR"
    echo "3. 显示BBR状态"
    echo "4. 退出"
    echo ""

    local option=""
    local confirm=""
    read -r -p "请输入选项 (1-4): " option

    case $option in
        1)
            echo ""
            echo -e "${YELLOW}注意: 安装BBR可能需要重启系统才能完全生效。${NC}"
            read -r -p "是否继续? (y/n): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                install_bbr
                echo -e "${GREEN}BBR安装完成!${NC}"
                echo -e "${YELLOW}建议重启系统以确保所有设置生效。${NC}"
            else
                echo -e "${YELLOW}操作已取消。${NC}"
            fi
            ;;
        2)
            echo ""
            read -r -p "确定要卸载BBR吗? (y/n): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                uninstall_bbr
                echo -e "${GREEN}BBR卸载完成!${NC}"
            else
                echo -e "${YELLOW}操作已取消。${NC}"
            fi
            ;;
        3)
            echo ""
            show_bbr_status
            ;;
        4)
            echo -e "${GREEN}感谢使用BBR网络优化工具!${NC}"
            return 0
            ;;
        *)
            echo -e "${RED}无效选项，操作已取消。${NC}"
            return 1
            ;;
    esac
}

# 执行主函数
main "$@"
