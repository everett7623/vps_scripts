#!/bin/bash
#/vps_scripts/scripts/other_tools/bbr.sh - VPS Scripts BBR网络加速工具

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 恢复默认颜色

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
            sudo apt update && sudo apt install -y bc
        elif command -v yum &> /dev/null; then
            sudo yum install -y bc
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm bc
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
    local bbr_status=$(sysctl net.ipv4.tcp_congestion_control | grep -o "bbr")
    local fq_status=$(sysctl net.core.default_qdisc | grep -o "fq")
    
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
    
    # 备份原配置文件
    if [ -f /etc/sysctl.conf ]; then
        cp /etc/sysctl.conf /etc/sysctl.conf.bak
        echo -e "${YELLOW}已备份原配置文件到 /etc/sysctl.conf.bak${NC}"
    fi
    
    # 写入BBR配置
    cat > /etc/sysctl.conf << EOF
fs.file-max = 6815744
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=33554432
net.core.wmem_max=33554432
net.ipv4.tcp_rmem=4096 87380 33554432
net.ipv4.tcp_wmem=4096 16384 33554432
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.ip_forward=1
net.ipv4.conf.all.route_localnet=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
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
    
    # 恢复备份配置
    if [ -f /etc/sysctl.conf.bak ]; then
        cp /etc/sysctl.conf.bak /etc/sysctl.conf
        echo -e "${YELLOW}已恢复原配置文件。${NC}"
    else
        # 如果没有备份，则重置BBR相关配置
        sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
        echo -e "${YELLOW}已移除BBR相关配置。${NC}"
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
    check_bbr_status
}

# 主函数
main() {
    echo -e "${YELLOW}=============================================${NC}"
    echo -e "${YELLOW}           BBR网络优化工具                   ${NC}"
    echo -e "${YELLOW}=============================================${NC}"
    echo ""
    
    # 检查root权限
    check_root
    
    # 安装必要工具
    install_tools
    
    # 检查内核版本
    check_kernel
    
    echo ""
    
    # 显示状态
    show_bbr_status
    
    echo ""
    
    # 显示选项菜单
    echo "请选择要执行的操作:"
    echo "1. 安装/启用BBR"
    echo "2. 卸载/禁用BBR"
    echo "3. 显示BBR状态"
    echo "4. 退出"
    echo ""
    
    read -p "请输入选项 (1-4): " option
    
    case $option in
        1)
            echo ""
            echo -e "${YELLOW}注意: 安装BBR可能需要重启系统才能完全生效。${NC}"
            read -p "是否继续? (y/n): " confirm
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
            read -p "确定要卸载BBR吗? (y/n): " confirm
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
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项，操作已取消。${NC}"
            exit 1
            ;;
    esac
}

# 执行主函数
main
