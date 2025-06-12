#!/bin/bash
#/scripts/system_tools/system_update.sh - VPS Scripts 系统工具库

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
        *rocky*) os_type="rocky" ;;
        *almalinux*) os_type="almalinux" ;;
        *openeuler*) os_type="openeuler" ;;
        *arch*) os_type="arch" ;;
        *manjaro*) os_type="manjaro" ;;
        *linuxmint*) os_type="linuxmint" ;;
        *elementary*) os_type="elementary" ;;
        *pop*) os_type="pop" ;;
    esac
}

# 更新系统
update_system() {
    detect_os
    echo -e "${YELLOW}检测到操作系统: ${os_type}${NC}"
    
    case "${os_type,,}" in
        ubuntu|debian|linuxmint|elementary|pop)
            update_cmd="apt-get update"
            upgrade_cmd="apt-get upgrade -y"
            clean_cmd="apt-get autoremove -y"
            ;;
        centos|rhel|fedora|rocky|almalinux|openeuler)
            if command -v dnf &>/dev/null; then
                update_cmd="dnf check-update"
                upgrade_cmd="dnf upgrade -y"
                clean_cmd="dnf autoremove -y"
            else
                update_cmd="yum check-update"
                upgrade_cmd="yum upgrade -y"
                clean_cmd="yum autoremove -y"
            fi
            ;;
        arch|manjaro)
            update_cmd="pacman -Sy"
            upgrade_cmd="pacman -Syu --noconfirm"
            clean_cmd="pacman -Sc --noconfirm"
            ;;
        *)
            echo -e "${RED}不支持的 Linux 发行版: $os_type${NC}"
            return 1
            ;;
    esac
    
    echo -e "${BLUE}正在执行: ${update_cmd}${NC}"
    sudo $update_cmd
    if [ $? -eq 0 ]; then
        echo -e "${BLUE}正在执行: ${upgrade_cmd}${NC}"
        sudo $upgrade_cmd
        if [ $? -eq 0 ]; then
            echo -e "${BLUE}正在执行: ${clean_cmd}${NC}"
            sudo $clean_cmd
            echo -e "${GREEN}系统更新完成。${NC}"
        else
            echo -e "${RED}升级失败。${NC}"
            return 1
        fi
    else
        echo -e "${RED}更新失败。${NC}"
        return 1
    fi
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}         VPS 系统更新工具                     ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    read -p "确定要更新系统吗? (y/n): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        update_system
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}系统更新成功完成!${NC}"
        else
            echo -e "${RED}系统更新过程中出现错误。${NC}"
        fi
    else
        echo -e "${YELLOW}操作已取消。${NC}"
    fi
    
    read -n 1 -s -r -p "按任意键返回..."
}

# 执行主函数
main
