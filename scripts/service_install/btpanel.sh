#!/bin/bash
#==============================================================================
# 脚本名称: btpanel.sh
# 脚本描述: BT宝塔面板官方安装脚本 - 基于官方脚本的增强版
# 脚本路径: vps_scripts/scripts/service_install/btpanel.sh
# 作者: Jensfrank
# 使用方法: bash btpanel.sh [选项]
# 选项说明:
#   --version <版本>     面板版本 (stable/beta)
#   --user <用户名>      自定义用户名
#   --password <密码>    自定义密码
#   --port <端口>        自定义端口 (默认: 8888)
#   --safe-path <路径>   自定义安全入口
#   --install-lnmp       安装LNMP环境
#   --install-lamp       安装LAMP环境
#   --install-docker     安装Docker
#   --skip-ssl           跳过SSL配置
#   --help               显示帮助信息
# 更新日期: 2025-06-22
#==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 全局变量
PANEL_VERSION="stable"
CUSTOM_USER=""
CUSTOM_PASSWORD=""
CUSTOM_PORT=""
SAFE_PATH=""
INSTALL_LNMP=false
INSTALL_LAMP=false
INSTALL_DOCKER=false
SKIP_SSL=false
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/btpanel_install_$(date +%Y%m%d_%H%M%S).log"

# 记录日志
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}  BT宝塔面板官方安装脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
}

# 显示帮助
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash btpanel.sh [选项]"
    echo
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --version <版本>     面板版本 (stable/beta)"
    echo "  --user <用户名>      自定义用户名"
    echo "  --password <密码>    自定义密码"
    echo "  --port <端口>        自定义端口"
    echo "  --safe-path <路径>   自定义安全入口"
    echo "  --install-lnmp       安装LNMP环境"
    echo "  --install-lamp       安装LAMP环境"
    echo "  --install-docker     安装Docker"
    echo "  --skip-ssl           跳过SSL配置"
    echo "  --help               显示帮助信息"
}

# 检查系统
check_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        log "${RED}错误: 无法检测系统类型${NC}"
        exit 1
    fi
    
    log "${GREEN}检测到系统: ${OS} ${VER}${NC}"
}

# 选择安装脚本
select_install_script() {
    case $OS in
        ubuntu|debian)
            if [[ "$PANEL_VERSION" == "beta" ]]; then
                INSTALL_SCRIPT="http://io.bt.sy/install/install-ubuntu_6.0.sh"
            else
                INSTALL_SCRIPT="http://download.bt.cn/install/install-ubuntu_6.0.sh"
            fi
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if [[ "$PANEL_VERSION" == "beta" ]]; then
                INSTALL_SCRIPT="http://io.bt.sy/install/install_6.0.sh"
            else
                INSTALL_SCRIPT="http://download.bt.cn/install/install_6.0.sh"
            fi
            ;;
        *)
            log "${RED}错误: 不支持的系统类型${NC}"
            exit 1
            ;;
    esac
}

# 下载并执行官方安装脚本
install_btpanel() {
    log "${CYAN}开始安装宝塔面板...${NC}"
    
    # 下载官方安装脚本
    wget -O install.sh "$INSTALL_SCRIPT"
    
    if [[ ! -f install.sh ]]; then
        log "${RED}错误: 下载安装脚本失败${NC}"
        exit 1
    fi
    
    # 执行安装
    echo y | bash install.sh
    
    # 清理
    rm -f install.sh
}

# 配置面板
configure_panel() {
    log "${CYAN}配置面板设置...${NC}"
    
    # 等待面板安装完成
    sleep 5
    
    # 设置用户名
    if [[ -n "$CUSTOM_USER" ]]; then
        log "${YELLOW}设置用户名: $CUSTOM_USER${NC}"
        bt default | grep username || bt default
        echo "$CUSTOM_USER" | bt 6
    fi
    
    # 设置密码
    if [[ -n "$CUSTOM_PASSWORD" ]]; then
        log "${YELLOW}设置密码${NC}"
        echo "$CUSTOM_PASSWORD" | bt 5
    fi
    
    # 设置端口
    if [[ -n "$CUSTOM_PORT" ]]; then
        log "${YELLOW}设置端口: $CUSTOM_PORT${NC}"
        echo "$CUSTOM_PORT" | bt 8
    fi
    
    # 设置安全入口
    if [[ -n "$SAFE_PATH" ]]; then
        log "${YELLOW}设置安全入口: /$SAFE_PATH${NC}"
        echo "/$SAFE_PATH" | bt 9
    fi
}

# 安装LNMP
install_lnmp_env() {
    if [[ "$INSTALL_LNMP" != true ]]; then
        return
    fi
    
    log "${CYAN}安装LNMP环境...${NC}"
    
    # 创建自动安装脚本
    cat > /tmp/install_lnmp.sh << 'EOF'
#!/bin/bash
echo "正在安装LNMP环境..."

# 安装Nginx
echo "1" | bt 1

# 安装MySQL 5.7
echo "2" | bt 1

# 安装PHP 7.4
echo "4" | bt 1

echo "LNMP环境安装完成"
EOF
    
    chmod +x /tmp/install_lnmp.sh
    /tmp/install_lnmp.sh
    rm -f /tmp/install_lnmp.sh
}

# 安装LAMP
install_lamp_env() {
    if [[ "$INSTALL_LAMP" != true ]]; then
        return
    fi
    
    log "${CYAN}安装LAMP环境...${NC}"
    
    # 创建自动安装脚本
    cat > /tmp/install_lamp.sh << 'EOF'
#!/bin/bash
echo "正在安装LAMP环境..."

# 安装Apache
echo "7" | bt 1

# 安装MySQL 5.7
echo "2" | bt 1

# 安装PHP 7.4
echo "4" | bt 1

echo "LAMP环境安装完成"
EOF
    
    chmod +x /tmp/install_lamp.sh
    /tmp/install_lamp.sh
    rm -f /tmp/install_lamp.sh
}

# 安装Docker
install_docker_env() {
    if [[ "$INSTALL_DOCKER" != true ]]; then
        return
    fi
    
    log "${CYAN}安装Docker...${NC}"
    
    # 通过宝塔安装Docker
    echo "22" | bt 1
}

# 保存配置信息
save_config_info() {
    log "${CYAN}保存配置信息...${NC}"
    
    # 获取面板信息
    PANEL_INFO=$(bt default)
    
    # 保存到文件
    cat > /root/btpanel_info.txt << EOF
宝塔面板安装信息
================

$PANEL_INFO

安装日期: $(date)
系统版本: $OS $VER
面板版本: $PANEL_VERSION

常用命令:
- bt         # 宝塔面板命令
- bt stop    # 停止面板
- bt start   # 启动面板
- bt restart # 重启面板
- bt default # 查看面板信息

日志文件: $LOG_FILE
EOF
    
    chmod 600 /root/btpanel_info.txt
}

# 显示安装信息
show_install_info() {
    echo
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}宝塔面板安装完成!${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo
    
    # 显示面板信息
    bt default
    
    echo
    echo -e "${YELLOW}配置信息已保存到: /root/btpanel_info.txt${NC}"
    echo
    echo -e "${CYAN}常用命令:${NC}"
    echo "- bt         # 宝塔面板命令"
    echo "- bt 14      # 查看面板日志"
    echo "- bt 22      # 显示面板错误日志"
    echo
    echo -e "${YELLOW}安全提示:${NC}"
    echo "1. 请立即修改默认端口和安全入口"
    echo "2. 使用强密码保护面板"
    echo "3. 定期更新面板版本"
    echo "4. 配置防火墙规则"
}

# 主函数
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                PANEL_VERSION="$2"
                shift 2
                ;;
            --user)
                CUSTOM_USER="$2"
                shift 2
                ;;
            --password)
                CUSTOM_PASSWORD="$2"
                shift 2
                ;;
            --port)
                CUSTOM_PORT="$2"
                shift 2
                ;;
            --safe-path)
                SAFE_PATH="$2"
                shift 2
                ;;
            --install-lnmp)
                INSTALL_LNMP=true
                shift
                ;;
            --install-lamp)
                INSTALL_LAMP=true
                shift
                ;;
            --install-docker)
                INSTALL_DOCKER=true
                shift
                ;;
            --skip-ssl)
                SKIP_SSL=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 显示标题
    show_title
    
    # 检查系统
    check_system
    
    # 选择安装脚本
    select_install_script
    
    # 安装面板
    install_btpanel
    
    # 配置面板
    configure_panel
    
    # 安装环境
    install_lnmp_env
    install_lamp_env
    install_docker_env
    
    # 保存配置
    save_config_info
    
    # 显示安装信息
    show_install_info
}

# 执行主函数
main "$@"