#!/bin/bash
#==============================================================================
# 脚本名称: aapanel.sh
# 脚本描述: aaPanel（宝塔国际版）官方安装脚本增强版
# 脚本路径: vps_scripts/scripts/service_install/aapanel.sh
# 作者: Jensfrank
# 使用方法: bash aapanel.sh [选项]
# 选项说明:
#   --user <用户名>      自定义用户名
#   --password <密码>    自定义密码
#   --port <端口>        自定义端口 (默认: 7800)
#   --entrance <入口>    自定义安全入口
#   --install-lnmp       安装LNMP环境
#   --install-lamp       安装LAMP环境
#   --php-version        PHP版本 (7.4/8.0/8.1/8.2)
#   --mysql-version      MySQL版本 (5.7/8.0)
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
CUSTOM_USER=""
CUSTOM_PASSWORD=""
CUSTOM_PORT="7800"
CUSTOM_ENTRANCE=""
INSTALL_LNMP=false
INSTALL_LAMP=false
PHP_VERSION="7.4"
MYSQL_VERSION="5.7"
SKIP_SSL=false
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/aapanel_install_$(date +%Y%m%d_%H%M%S).log"

# 记录日志
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}  aaPanel官方安装脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
}

# 显示帮助
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash aapanel_official.sh [选项]"
    echo
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --user <用户名>      自定义用户名"
    echo "  --password <密码>    自定义密码"
    echo "  --port <端口>        自定义端口 (默认: 7800)"
    echo "  --entrance <入口>    自定义安全入口"
    echo "  --install-lnmp       安装LNMP环境"
    echo "  --install-lamp       安装LAMP环境"
    echo "  --php-version        PHP版本 (7.4/8.0/8.1/8.2)"
    echo "  --mysql-version      MySQL版本 (5.7/8.0)"
    echo "  --skip-ssl           跳过SSL配置"
    echo "  --help               显示帮助信息"
}

# 检查系统
check_system() {
    if [[ ! -f /etc/os-release ]]; then
        log "${RED}错误: 无法检测系统类型${NC}"
        exit 1
    fi
    
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
    
    log "${GREEN}检测到系统: ${OS} ${VER}${NC}"
}

# 选择安装脚本
select_install_script() {
    case $OS in
        ubuntu|debian)
            INSTALL_SCRIPT="http://www.aapanel.com/script/install-ubuntu_6.0_en.sh"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            INSTALL_SCRIPT="http://www.aapanel.com/script/install_6.0_en.sh"
            ;;
        *)
            log "${RED}错误: 不支持的系统类型${NC}"
            exit 1
            ;;
    esac
}

# 下载并执行官方安装脚本
install_aapanel() {
    log "${CYAN}开始安装aaPanel...${NC}"
    
    # 下载官方安装脚本
    if command -v curl &> /dev/null; then
        curl -ksSO "$INSTALL_SCRIPT"
    else
        wget --no-check-certificate -O install.sh "$INSTALL_SCRIPT"
    fi
    
    if [[ ! -f install.sh ]] && [[ ! -f install_6.0_en.sh ]] && [[ ! -f install-ubuntu_6.0_en.sh ]]; then
        log "${RED}错误: 下载安装脚本失败${NC}"
        exit 1
    fi
    
    # 获取正确的脚本名称
    SCRIPT_NAME=$(ls install*.sh 2>/dev/null | head -1)
    
    # 执行安装
    echo y | bash "$SCRIPT_NAME"
    
    # 清理
    rm -f "$SCRIPT_NAME"
}

# 等待面板启动
wait_panel_start() {
    log "${YELLOW}等待面板启动...${NC}"
    local count=0
    while [ $count -lt 30 ]; do
        if netstat -tlnp 2>/dev/null | grep -q ":$CUSTOM_PORT"; then
            log "${GREEN}面板已启动${NC}"
            return 0
        fi
        sleep 2
        ((count++))
    done
    log "${YELLOW}面板启动超时${NC}"
    return 1
}

# 配置面板
configure_panel() {
    log "${CYAN}配置面板设置...${NC}"
    
    # 等待面板启动
    wait_panel_start
    
    # 进入面板目录
    cd /www/server/panel
    
    # 设置用户名
    if [[ -n "$CUSTOM_USER" ]]; then
        log "${YELLOW}设置用户名: $CUSTOM_USER${NC}"
        python3 tools.py username "$CUSTOM_USER"
    fi
    
    # 设置密码
    if [[ -n "$CUSTOM_PASSWORD" ]]; then
        log "${YELLOW}设置密码${NC}"
        python3 tools.py password "$CUSTOM_PASSWORD"
    fi
    
    # 设置端口
    if [[ "$CUSTOM_PORT" != "7800" ]]; then
        log "${YELLOW}设置端口: $CUSTOM_PORT${NC}"
        echo "$CUSTOM_PORT" > /www/server/panel/data/port.pl
        /etc/init.d/bt restart
    fi
    
    # 设置安全入口
    if [[ -n "$CUSTOM_ENTRANCE" ]]; then
        log "${YELLOW}设置安全入口: /$CUSTOM_ENTRANCE${NC}"
        echo "/$CUSTOM_ENTRANCE" > /www/server/panel/data/admin_path.pl
    fi
}

# 安装LNMP
install_lnmp_env() {
    if [[ "$INSTALL_LNMP" != true ]]; then
        return
    fi
    
    log "${CYAN}安装LNMP环境...${NC}"
    cd /www/server/panel
    
    # 安装Nginx
    log "${YELLOW}安装Nginx...${NC}"
    python3 -m py_compile tools.py
    python3 tools.py install nginx
    
    # 安装MySQL
    log "${YELLOW}安装MySQL ${MYSQL_VERSION}...${NC}"
    case $MYSQL_VERSION in
        "5.7")
            python3 tools.py install mysql_5.7
            ;;
        "8.0")
            python3 tools.py install mysql_8.0
            ;;
    esac
    
    # 安装PHP
    log "${YELLOW}安装PHP ${PHP_VERSION}...${NC}"
    case $PHP_VERSION in
        "7.4")
            python3 tools.py install php_74
            ;;
        "8.0")
            python3 tools.py install php_80
            ;;
        "8.1")
            python3 tools.py install php_81
            ;;
        "8.2")
            python3 tools.py install php_82
            ;;
    esac
}

# 安装LAMP
install_lamp_env() {
    if [[ "$INSTALL_LAMP" != true ]]; then
        return
    fi
    
    log "${CYAN}安装LAMP环境...${NC}"
    cd /www/server/panel
    
    # 安装Apache
    log "${YELLOW}安装Apache...${NC}"
    python3 tools.py install apache
    
    # 安装MySQL
    log "${YELLOW}安装MySQL ${MYSQL_VERSION}...${NC}"
    case $MYSQL_VERSION in
        "5.7")
            python3 tools.py install mysql_5.7
            ;;
        "8.0")
            python3 tools.py install mysql_8.0
            ;;
    esac
    
    # 安装PHP
    log "${YELLOW}安装PHP ${PHP_VERSION}...${NC}"
    case $PHP_VERSION in
        "7.4")
            python3 tools.py install php_74
            ;;
        "8.0")
            python3 tools.py install php_80
            ;;
        "8.1")
            python3 tools.py install php_81
            ;;
        "8.2")
            python3 tools.py install php_82
            ;;
    esac
}

# 获取面板信息
get_panel_info() {
    # 获取IP地址
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    # 获取端口
    PANEL_PORT=$(cat /www/server/panel/data/port.pl 2>/dev/null || echo "7800")
    
    # 获取安全入口
    PANEL_ENTRANCE=$(cat /www/server/panel/data/admin_path.pl 2>/dev/null || echo "/")
    
    # 获取用户名
    cd /www/server/panel
    PANEL_USER=$(python3 tools.py panel_user | grep "username:" | awk '{print $2}' || echo "aapanel")
}

# 保存配置信息
save_config_info() {
    log "${CYAN}保存配置信息...${NC}"
    
    # 获取面板信息
    get_panel_info
    
    # 保存到文件
    cat > /root/aapanel_info.txt << EOF
aaPanel Installation Information
================================

Panel URL: http://${SERVER_IP}:${PANEL_PORT}${PANEL_ENTRANCE}
Username: ${PANEL_USER:-$CUSTOM_USER}
Password: ${CUSTOM_PASSWORD:-[Check installation output]}

Security Entrance: ${PANEL_ENTRANCE}
Panel Port: ${PANEL_PORT}

Installation Date: $(date)
System Version: $OS $VER

Common Commands:
- bt         # Panel CLI tool
- bt stop    # Stop panel
- bt start   # Start panel
- bt restart # Restart panel
- bt default # Show panel info

Panel Directory: /www/server/panel
Website Directory: /www/wwwroot
Backup Directory: /www/backup

Log File: $LOG_FILE
EOF
    
    chmod 600 /root/aapanel_info.txt
}

# 显示安装信息
show_install_info() {
    echo
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}aaPanel Installation Complete!${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo
    
    # 获取并显示面板信息
    get_panel_info
    
    echo -e "${CYAN}Panel Access Information:${NC}"
    echo -e "URL: ${GREEN}http://${SERVER_IP}:${PANEL_PORT}${PANEL_ENTRANCE}${NC}"
    echo -e "Username: ${GREEN}${PANEL_USER:-$CUSTOM_USER}${NC}"
    if [[ -n "$CUSTOM_PASSWORD" ]]; then
        echo -e "Password: ${GREEN}${CUSTOM_PASSWORD}${NC}"
    else
        echo -e "Password: ${YELLOW}[Check the installation output above]${NC}"
    fi
    echo
    echo -e "${YELLOW}Configuration saved to: /root/aapanel_info.txt${NC}"
    echo
    echo -e "${CYAN}Common Commands:${NC}"
    echo "- bt         # Panel CLI tool"
    echo "- bt 14      # View panel log"
    echo "- bt 22      # Show error log"
    echo
    echo -e "${YELLOW}Security Tips:${NC}"
    echo "1. Change default port and security entrance immediately"
    echo "2. Use strong password to protect panel"
    echo "3. Enable SSL for panel access"
    echo "4. Configure firewall rules"
    echo "5. Update panel regularly"
}

# 主函数
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
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
            --entrance)
                CUSTOM_ENTRANCE="$2"
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
            --php-version)
                PHP_VERSION="$2"
                shift 2
                ;;
            --mysql-version)
                MYSQL_VERSION="$2"
                shift 2
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
                echo -e "${RED}Unknown option: $1${NC}"
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
    install_aapanel
    
    # 配置面板
    configure_panel
    
    # 安装环境
    install_lnmp_env
    install_lamp_env
    
    # 保存配置
    save_config_info
    
    # 显示安装信息
    show_install_info
}

# 执行主函数
main "$@"
