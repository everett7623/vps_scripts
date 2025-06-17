#!/bin/bash

#==============================================================================
# 脚本名称: install_deps.sh
# 描述: VPS常用依赖安装脚本 - 自动检测系统并安装常用软件包和开发工具
# 作者: Jensfrank
# 路径: vps_scripts/scripts/system_tools/install_deps.sh
# 使用方法: bash install_deps.sh [选项]
# 选项: --basic (仅基础包) --dev (开发工具) --all (全部安装)
# 更新日期: 2024-06-17
#==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# 日志文件
LOG_FILE="/tmp/install_deps_$(date +%Y%m%d_%H%M%S).log"

# 全局变量
OS_TYPE=""
OS_VERSION=""
PKG_MANAGER=""
INSTALL_MODE="interactive"  # interactive, basic, dev, all

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}"
        echo -e "${YELLOW}请使用 sudo bash $0 或切换到root用户${NC}"
        exit 1
    fi
}

# 日志记录函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 打印带颜色的消息
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
    log "$msg"
}

# 打印进度
print_progress() {
    local current=$1
    local total=$2
    local pkg=$3
    local percent=$((current * 100 / total))
    echo -ne "\r${CYAN}[${percent}%]${NC} 正在安装: ${pkg}..."
}

# 检测操作系统
detect_os() {
    print_msg "$BLUE" "正在检测操作系统..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS_TYPE="centos"
        OS_VERSION=$(rpm -q --queryformat '%{VERSION}' centos-release)
    else
        print_msg "$RED" "错误: 无法识别的操作系统"
        exit 1
    fi
    
    # 确定包管理器
    case $OS_TYPE in
        ubuntu|debian)
            PKG_MANAGER="apt"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            PKG_MANAGER="yum"
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
            fi
            ;;
        alpine)
            PKG_MANAGER="apk"
            ;;
        *)
            print_msg "$RED" "错误: 不支持的操作系统 $OS_TYPE"
            exit 1
            ;;
    esac
    
    print_msg "$GREEN" "检测到系统: $OS_TYPE $OS_VERSION (包管理器: $PKG_MANAGER)"
}

# 更新包管理器缓存
update_package_cache() {
    print_msg "$BLUE" "正在更新软件包缓存..."
    
    case $PKG_MANAGER in
        apt)
            apt-get update -qq >> "$LOG_FILE" 2>&1
            ;;
        yum|dnf)
            $PKG_MANAGER makecache -q >> "$LOG_FILE" 2>&1
            ;;
        apk)
            apk update -q >> "$LOG_FILE" 2>&1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        print_msg "$GREEN" "软件包缓存更新成功"
    else
        print_msg "$RED" "软件包缓存更新失败，请检查网络连接"
        exit 1
    fi
}

# 定义软件包列表
define_packages() {
    # 基础工具包
    BASIC_PACKAGES=(
        "curl"
        "wget"
        "git"
        "vim"
        "nano"
        "htop"
        "iotop"
        "iftop"
        "net-tools"
        "dnsutils"
        "mtr"
        "traceroute"
        "tcpdump"
        "telnet"
        "openssh-server"
        "ca-certificates"
        "gnupg"
        "lsb-release"
        "software-properties-common"
        "apt-transport-https"
        "unzip"
        "zip"
        "tar"
        "gzip"
        "bzip2"
        "screen"
        "tmux"
        "tree"
        "jq"
        "bc"
        "rsync"
        "cron"
        "logrotate"
    )
    
    # 开发工具包
    DEV_PACKAGES=(
        "build-essential"
        "gcc"
        "g++"
        "make"
        "cmake"
        "automake"
        "autoconf"
        "libtool"
        "pkg-config"
        "python3"
        "python3-pip"
        "python3-dev"
        "nodejs"
        "npm"
        "golang"
        "default-jdk"
        "maven"
        "ruby"
        "perl"
        "php-cli"
        "composer"
        "docker.io"
        "docker-compose"
        "ansible"
        "terraform"
    )
    
    # 监控和性能工具
    MONITOR_PACKAGES=(
        "sysstat"
        "iostat"
        "vmstat"
        "dstat"
        "nmon"
        "glances"
        "nethogs"
        "iptraf-ng"
        "nload"
        "speedtest-cli"
        "sysbench"
        "stress"
        "fio"
    )
    
    # 安全工具
    SECURITY_PACKAGES=(
        "fail2ban"
        "ufw"
        "iptables-persistent"
        "rkhunter"
        "chkrootkit"
        "lynis"
        "aide"
        "clamav"
        "clamav-daemon"
    )
}

# 调整包名以适应不同发行版
adjust_package_names() {
    case $OS_TYPE in
        centos|rhel|fedora|rocky|almalinux)
            # CentOS/RHEL 系列的包名调整
            BASIC_PACKAGES=(${BASIC_PACKAGES[@]/dnsutils/bind-utils})
            BASIC_PACKAGES=(${BASIC_PACKAGES[@]/net-tools/net-tools})
            BASIC_PACKAGES=(${BASIC_PACKAGES[@]/software-properties-common/})
            BASIC_PACKAGES=(${BASIC_PACKAGES[@]/apt-transport-https/})
            BASIC_PACKAGES=(${BASIC_PACKAGES[@]/lsb-release/redhat-lsb-core})
            
            DEV_PACKAGES=(${DEV_PACKAGES[@]/build-essential/})
            DEV_PACKAGES+=("gcc-c++" "kernel-devel" "kernel-headers")
            DEV_PACKAGES=(${DEV_PACKAGES[@]/default-jdk/java-11-openjdk-devel})
            DEV_PACKAGES=(${DEV_PACKAGES[@]/docker.io/docker-ce})
            DEV_PACKAGES=(${DEV_PACKAGES[@]/golang/golang})
            
            MONITOR_PACKAGES=(${MONITOR_PACKAGES[@]/sysstat/sysstat})
            SECURITY_PACKAGES=(${SECURITY_PACKAGES[@]/ufw/firewalld})
            ;;
        alpine)
            # Alpine 的包名调整
            BASIC_PACKAGES=(${BASIC_PACKAGES[@]/dnsutils/bind-tools})
            BASIC_PACKAGES=(${BASIC_PACKAGES[@]/net-tools/net-tools})
            DEV_PACKAGES=(${DEV_PACKAGES[@]/build-essential/build-base})
            ;;
    esac
}

# 检查包是否存在
check_package_exists() {
    local pkg=$1
    case $PKG_MANAGER in
        apt)
            apt-cache show "$pkg" &> /dev/null
            ;;
        yum|dnf)
            $PKG_MANAGER list "$pkg" &> /dev/null
            ;;
        apk)
            apk info -e "$pkg" &> /dev/null
            ;;
    esac
    return $?
}

# 安装单个包
install_package() {
    local pkg=$1
    
    # 检查包是否已安装
    case $PKG_MANAGER in
        apt)
            dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" && return 0
            ;;
        yum|dnf)
            rpm -q "$pkg" &> /dev/null && return 0
            ;;
        apk)
            apk info -e "$pkg" &> /dev/null && return 0
            ;;
    esac
    
    # 检查包是否存在于仓库
    if ! check_package_exists "$pkg"; then
        print_msg "$YELLOW" "警告: 包 $pkg 在当前系统仓库中不存在，跳过..."
        return 1
    fi
    
    # 安装包
    case $PKG_MANAGER in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" >> "$LOG_FILE" 2>&1
            ;;
        yum|dnf)
            $PKG_MANAGER install -y -q "$pkg" >> "$LOG_FILE" 2>&1
            ;;
        apk)
            apk add -q "$pkg" >> "$LOG_FILE" 2>&1
            ;;
    esac
    
    return $?
}

# 批量安装包
install_packages() {
    local packages=("$@")
    local total=${#packages[@]}
    local current=0
    local failed_packages=()
    
    print_msg "$BLUE" "开始安装 $total 个软件包..."
    echo ""
    
    for pkg in "${packages[@]}"; do
        ((current++))
        print_progress $current $total "$pkg"
        
        if install_package "$pkg"; then
            echo -e "\r${GREEN}[$current/$total]${NC} ✓ $pkg 安装成功"
        else
            echo -e "\r${RED}[$current/$total]${NC} ✗ $pkg 安装失败"
            failed_packages+=("$pkg")
        fi
    done
    
    echo ""
    
    # 显示失败的包
    if [ ${#failed_packages[@]} -gt 0 ]; then
        print_msg "$YELLOW" "以下软件包安装失败或不可用:"
        for pkg in "${failed_packages[@]}"; do
            echo "  - $pkg"
        done
    fi
}

# 配置特殊软件源
configure_special_repos() {
    print_msg "$BLUE" "配置额外软件源..."
    
    case $OS_TYPE in
        ubuntu|debian)
            # Docker 官方源
            if [[ " ${DEV_PACKAGES[@]} " =~ " docker.io " ]] || [[ " ${DEV_PACKAGES[@]} " =~ " docker-ce " ]]; then
                curl -fsSL https://download.docker.com/linux/$OS_TYPE/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS_TYPE $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
                apt-get update -qq >> "$LOG_FILE" 2>&1
            fi
            
            # Node.js 官方源
            if [[ " ${DEV_PACKAGES[@]} " =~ " nodejs " ]]; then
                curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - >> "$LOG_FILE" 2>&1
            fi
            ;;
        centos|rhel|fedora|rocky|almalinux)
            # EPEL 源
            if ! rpm -q epel-release &> /dev/null; then
                $PKG_MANAGER install -y epel-release >> "$LOG_FILE" 2>&1
            fi
            
            # Docker 官方源
            if [[ " ${DEV_PACKAGES[@]} " =~ " docker-ce " ]]; then
                $PKG_MANAGER config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >> "$LOG_FILE" 2>&1
            fi
            ;;
    esac
}

# 安装后配置
post_install_config() {
    print_msg "$BLUE" "执行安装后配置..."
    
    # 启动并启用重要服务
    local services=("ssh" "sshd" "cron" "crond")
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}.service"; then
            systemctl enable "$service" >> "$LOG_FILE" 2>&1
            systemctl start "$service" >> "$LOG_FILE" 2>&1
        fi
    done
    
    # 配置 Docker
    if command -v docker &> /dev/null; then
        if ! getent group docker &> /dev/null; then
            groupadd docker >> "$LOG_FILE" 2>&1
        fi
        systemctl enable docker >> "$LOG_FILE" 2>&1
        systemctl start docker >> "$LOG_FILE" 2>&1
    fi
    
    # 配置 Git
    if command -v git &> /dev/null; then
        git config --global init.defaultBranch main
        git config --global color.ui auto
    fi
    
    print_msg "$GREEN" "安装后配置完成"
}

# 显示安装摘要
show_summary() {
    print_msg "$PURPLE" "\n========== 安装摘要 =========="
    
    # 统计已安装的工具
    local installed_tools=0
    local tools_to_check=("curl" "wget" "git" "vim" "htop" "docker" "python3" "node" "go")
    
    for tool in "${tools_to_check[@]}"; do
        if command -v "$tool" &> /dev/null; then
            ((installed_tools++))
            print_msg "$GREEN" "✓ $tool 已安装"
        fi
    done
    
    print_msg "$CYAN" "\n已安装工具数: $installed_tools"
    print_msg "$CYAN" "日志文件: $LOG_FILE"
}

# 交互式菜单
interactive_menu() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                         VPS 常用依赖安装工具 v1.0                          ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}请选择安装选项:${NC}"
    echo ""
    echo -e "${GREEN}1)${NC} 安装基础工具包 (推荐)"
    echo -e "${GREEN}2)${NC} 安装开发工具包"
    echo -e "${GREEN}3)${NC} 安装监控工具包"
    echo -e "${GREEN}4)${NC} 安装安全工具包"
    echo -e "${GREEN}5)${NC} 安装所有工具包"
    echo -e "${GREEN}6)${NC} 自定义选择安装"
    echo -e "${GREEN}0)${NC} 退出"
    echo ""
    read -p "请输入选项 [0-6]: " choice
    
    case $choice in
        1)
            install_packages "${BASIC_PACKAGES[@]}"
            ;;
        2)
            configure_special_repos
            install_packages "${DEV_PACKAGES[@]}"
            ;;
        3)
            install_packages "${MONITOR_PACKAGES[@]}"
            ;;
        4)
            install_packages "${SECURITY_PACKAGES[@]}"
            ;;
        5)
            configure_special_repos
            install_packages "${BASIC_PACKAGES[@]}" "${DEV_PACKAGES[@]}" "${MONITOR_PACKAGES[@]}" "${SECURITY_PACKAGES[@]}"
            ;;
        6)
            custom_install_menu
            ;;
        0)
            print_msg "$YELLOW" "退出安装程序"
            exit 0
            ;;
        *)
            print_msg "$RED" "无效选项，请重新选择"
            sleep 2
            interactive_menu
            ;;
    esac
}

# 自定义安装菜单
custom_install_menu() {
    local selected_packages=()
    local all_packages=("${BASIC_PACKAGES[@]}" "${DEV_PACKAGES[@]}" "${MONITOR_PACKAGES[@]}" "${SECURITY_PACKAGES[@]}")
    
    # 去重
    all_packages=($(printf "%s\n" "${all_packages[@]}" | sort -u))
    
    clear
    echo -e "${CYAN}自定义安装 - 选择要安装的软件包${NC}"
    echo -e "${YELLOW}提示: 输入软件包编号，多个编号用空格分隔，输入 'all' 选择全部，输入 'done' 完成选择${NC}"
    echo ""
    
    # 显示所有可用包
    local i=1
    for pkg in "${all_packages[@]}"; do
        printf "${GREEN}%3d)${NC} %-20s" $i "$pkg"
        if (( i % 3 == 0 )); then
            echo ""
        fi
        ((i++))
    done
    echo -e "\n"
    
    while true; do
        read -p "请输入选择: " input
        
        if [ "$input" = "done" ]; then
            break
        elif [ "$input" = "all" ]; then
            selected_packages=("${all_packages[@]}")
            break
        else
            for num in $input; do
                if [[ "$num" =~ ^[0-9]+$ ]] && [ $num -ge 1 ] && [ $num -le ${#all_packages[@]} ]; then
                    selected_packages+=("${all_packages[$((num-1))]}")
                fi
            done
        fi
    done
    
    if [ ${#selected_packages[@]} -gt 0 ]; then
        # 去重
        selected_packages=($(printf "%s\n" "${selected_packages[@]}" | sort -u))
        print_msg "$BLUE" "将安装以下软件包:"
        printf '%s\n' "${selected_packages[@]}"
        echo ""
        read -p "确认安装？(y/n): " confirm
        
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            install_packages "${selected_packages[@]}"
        fi
    else
        print_msg "$YELLOW" "未选择任何软件包"
    fi
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --basic)
                INSTALL_MODE="basic"
                shift
                ;;
            --dev)
                INSTALL_MODE="dev"
                shift
                ;;
            --all)
                INSTALL_MODE="all"
                shift
                ;;
            --help|-h)
                echo "使用方法: $0 [选项]"
                echo "选项:"
                echo "  --basic    仅安装基础工具包"
                echo "  --dev      仅安装开发工具包"
                echo "  --all      安装所有工具包"
                echo "  --help     显示此帮助信息"
                exit 0
                ;;
            *)
                print_msg "$RED" "未知选项: $1"
                exit 1
                ;;
        esac
    done
}

# 主函数
main() {
    # 检查权限
    check_root
    
    # 解析参数
    parse_arguments "$@"
    
    # 检测系统
    detect_os
    
    # 定义软件包
    define_packages
    
    # 调整包名
    adjust_package_names
    
    # 更新包缓存
    update_package_cache
    
    # 根据模式执行安装
    case $INSTALL_MODE in
        basic)
            install_packages "${BASIC_PACKAGES[@]}"
            ;;
        dev)
            configure_special_repos
            install_packages "${DEV_PACKAGES[@]}"
            ;;
        all)
            configure_special_repos
            install_packages "${BASIC_PACKAGES[@]}" "${DEV_PACKAGES[@]}" "${MONITOR_PACKAGES[@]}" "${SECURITY_PACKAGES[@]}"
            ;;
        interactive)
            interactive_menu
            ;;
    esac
    
    # 安装后配置
    post_install_config
    
    # 显示摘要
    show_summary
    
    print_msg "$GREEN" "\n安装完成！"
}

# 运行主函数
main "$@"
