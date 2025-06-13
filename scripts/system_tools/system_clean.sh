#!/bin/bash
#/scripts/system_tools/system_clean.sh - VPS Scripts 系统工具库

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # 恢复默认颜色

# 检测操作系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        # 大多数现代Linux发行版使用此文件
        . /etc/os-release
        os_type="$ID"
    elif type lsb_release >/dev/null 2>&1; then
        # lsb_release命令
        os_type=$(lsb_release -si)
    elif [ -f /etc/debian_version ]; then
        # Debian系统
        os_type="debian"
    elif [ -f /etc/redhat-release ]; then
        # Red Hat系统
        os_type="redhat"
    else
        # 尝试使用uname
        os_type=$(uname -s)
    fi
    
    # 转换为小写
    os_type=$(echo "$os_type" | tr '[:upper:]' '[:lower:]')
    
    # 处理一些特殊情况
    case "$os_type" in
        *ubuntu*) os_type="ubuntu" ;;
        *debian*) os_type="debian" ;;
        *centos*) os_type="centos" ;;
        *rhel*) os_type="rhel" ;;
        *fedora*) os_type="fedora" ;;
        *arch*) os_type="arch" ;;
        *manjaro*) os_type="manjaro" ;;
        *linuxmint*) os_type="linuxmint" ;;
        *elementary*) os_type="elementary" ;;
        *pop*) os_type="pop" ;;
    esac
}

# 清理系统
clean_system() {
    detect_os
    echo -e "${YELLOW}检测到操作系统: ${os_type}${NC}"
    
    case "${os_type,,}" in
        ubuntu|debian|linuxmint|elementary|pop)
            echo -e "${BLUE}正在清理系统缓存和无用包...${NC}"
            apt autoremove --purge -y && apt clean -y && apt autoclean -y
            apt remove --purge $(dpkg -l | awk '/^rc/ {print $2}') -y
            journalctl --vacuum-time=1s
            ;;
        centos|rhel|fedora|rocky|almalinux|openeuler)
            echo -e "${BLUE}正在清理系统缓存和无用包...${NC}"
            if command -v dnf &>/dev/null; then
                dnf autoremove -y && dnf clean all
            else
                yum autoremove -y && yum clean all
            fi
            journalctl --vacuum-time=1s
            ;;
        arch|manjaro)
            echo -e "${BLUE}正在清理系统缓存和无用包...${NC}"
            pacman -Rns $(pacman -Qtdq) --noconfirm 2>/dev/null || echo "没有可移除的孤立包"
            pacman -Sc --noconfirm
            ;;
        *)
            echo -e "${RED}不支持的 Linux 发行版: $os_type${NC}"
            return 1
            ;;
    esac
    
    # 清理临时文件
    echo -e "${BLUE}正在清理临时文件...${NC}"
    rm -rf /tmp/*
    rm -rf /var/tmp/*
    
    echo -e "${GREEN}系统清理完成。${NC}"
    return 0
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}         VPS 系统清理工具                     ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    read -p "确定要清理系统吗? (y/n): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        clean_system
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}系统清理成功完成!${NC}"
        else
            echo -e "${RED}系统清理过程中出现错误。${NC}"
        fi
    else
        echo -e "${YELLOW}操作已取消。${NC}"
    fi
    
}

# 执行主函数
main
