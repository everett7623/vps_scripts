#!/bin/bash
# ==============================================================================
# 脚本名称: install_deps.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/system_tools/install_deps.sh
# 描述: VPS 依赖安装管理器
#       自动检测系统包管理器，支持批量安装基础、开发、监控及安全工具包。
# 作者: Jensfrank (Optimized by AI)
# 版本: 1.2.0 (Architecture Ready)
# 更新日期: 2026-01-20
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 环境初始化与依赖加载
# ------------------------------------------------------------------------------

# 获取脚本真实路径
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

# 日志文件 (优先使用配置，否则使用临时路径)
LOG_FILE="/tmp/install_deps_$(date +%Y%m%d_%H%M%S).log"

# 加载公共函数库
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"

if [ -f "$LIB_FILE" ]; then
    source "$LIB_FILE"
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
    # 如果配置文件定义了日志路径，则更新
    [ -n "$LOG_DIR" ] && LOG_FILE="${LOG_DIR}/install_deps.log"
else
    # [远程模式回退] 定义必需的 UI 和辅助函数
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'
    print_info() { echo -e "${CYAN}[信息] $1${NC}"; }
    print_success() { echo -e "${GREEN}[成功] $1${NC}"; }
    print_warn() { echo -e "${YELLOW}[警告] $1${NC}"; }
    print_error() { echo -e "${RED}[错误] $1${NC}"; }
    print_header() { echo -e "\n${PURPLE}=== $1 ===${NC}\n"; }
    check_root() { [[ $EUID -ne 0 ]] && { echo -e "${RED}需要 root 权限${NC}"; exit 1; }; }
    get_os_release() { [ -f /etc/os-release ] && . /etc/os-release && echo "$ID" || echo "unknown"; }
fi

# ------------------------------------------------------------------------------
# 2. 默认配置定义 (如果配置文件未加载)
# ------------------------------------------------------------------------------

# 基础工具
[ -z "$BASIC_PACKAGES" ] && BASIC_PACKAGES="curl wget git vim nano htop iotop iftop net-tools dnsutils mtr traceroute tcpdump telnet openssh-server ca-certificates gnupg lsb-release software-properties-common unzip zip tar gzip bzip2 screen tmux tree jq bc rsync cron logrotate"

# 开发工具
[ -z "$DEV_PACKAGES" ] && DEV_PACKAGES="build-essential gcc g++ make cmake automake autoconf libtool pkg-config python3 python3-pip python3-dev nodejs npm golang default-jdk maven ruby perl php-cli composer docker.io docker-compose ansible terraform"

# 监控工具 (仅脚本内部定义)
MONITOR_PACKAGES="sysstat iostat vmstat dstat nmon glances nethogs iptraf-ng nload speedtest-cli sysbench stress fio"

# 安全工具 (仅脚本内部定义)
SECURITY_PACKAGES="fail2ban ufw iptables-persistent rkhunter chkrootkit lynis aide clamav clamav-daemon"

# ------------------------------------------------------------------------------
# 3. 核心功能函数
# ------------------------------------------------------------------------------

# 检测包管理器
detect_package_manager() {
    OS_TYPE=$(get_os_release)
    case $OS_TYPE in
        ubuntu|debian|kali)
            PKG_MANAGER="apt"
            UPDATE_CMD="apt-get update -qq"
            INSTALL_CMD="DEBIAN_FRONTEND=noninteractive apt-get install -y -qq"
            ;;
        centos|rhel|fedora|rocky|almalinux|amzn)
            if command -v dnf &>/dev/null; then
                PKG_MANAGER="dnf"
                UPDATE_CMD="dnf makecache -q"
                INSTALL_CMD="dnf install -y -q"
            else
                PKG_MANAGER="yum"
                UPDATE_CMD="yum makecache -q"
                INSTALL_CMD="yum install -y -q"
            fi
            ;;
        alpine)
            PKG_MANAGER="apk"
            UPDATE_CMD="apk update -q"
            INSTALL_CMD="apk add -q"
            ;;
        *)
            print_error "不支持的操作系统: $OS_TYPE"
            exit 1
            ;;
    esac
    print_info "检测到系统: $OS_TYPE (包管理器: $PKG_MANAGER)"
}

# 适配不同系统的包名
adjust_package_names() {
    local list="$1"
    case $OS_TYPE in
        centos|rhel|fedora|rocky|almalinux|amzn)
            list=${list//dnsutils/bind-utils}
            list=${list//software-properties-common/}
            list=${list//apt-transport-https/}
            list=${list//lsb-release/redhat-lsb-core}
            list=${list//build-essential/gcc-c++ kernel-devel kernel-headers}
            list=${list//default-jdk/java-11-openjdk-devel}
            list=${list//docker.io/docker-ce}
            list=${list//ufw/firewalld}
            ;;
        alpine)
            list=${list//dnsutils/bind-tools}
            list=${list//build-essential/build-base}
            ;;
    esac
    echo "$list"
}

# 配置额外软件源
configure_extra_repos() {
    print_info "检查并配置额外软件源..."
    case $OS_TYPE in
        ubuntu|debian)
            # 配置 Docker 源
            if ! command -v docker &>/dev/null; then
                curl -fsSL https://download.docker.com/linux/$OS_TYPE/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS_TYPE $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
            fi
            # 配置 NodeSource
            if ! command -v node &>/dev/null; then
                curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - >> "$LOG_FILE" 2>&1
            fi
            ;;
        centos|rhel|rocky|almalinux)
            # EPEL 源
            if ! rpm -q epel-release &>/dev/null; then
                $INSTALL_CMD epel-release >> "$LOG_FILE" 2>&1
            fi
            # Docker 源
            if ! command -v docker &>/dev/null; then
                if command -v yum-config-manager &>/dev/null; then
                    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >> "$LOG_FILE" 2>&1
                fi
            fi
            ;;
    esac
}

# 更新缓存
update_cache() {
    print_info "正在更新软件包缓存..."
    if eval "$UPDATE_CMD" >> "$LOG_FILE" 2>&1; then
        print_success "缓存更新完成"
    else
        print_warn "缓存更新遇到问题，尝试继续..."
    fi
}

# 执行批量安装
install_pkg_list() {
    local raw_list="$1"
    # 调整包名
    local packages=$(adjust_package_names "$raw_list")
    # 转换为数组
    local pkg_array=($packages)
    local total=${#pkg_array[@]}
    local current=0
    local failed=()

    print_info "准备安装 $total 个软件包..."
    
    for pkg in "${pkg_array[@]}"; do
        ((current++))
        # 简单进度显示
        echo -ne "\r${CYAN}[进度: $current/$total]${NC} 正在安装: $pkg ..."
        
        if eval "$INSTALL_CMD $pkg" >> "$LOG_FILE" 2>&1; then
            # 成功不换行，覆盖显示
            : 
        else
            echo ""
            print_error "安装失败: $pkg"
            failed+=("$pkg")
        fi
    done
    echo -e "\n"
    
    if [ ${#failed[@]} -eq 0 ]; then
        print_success "所有软件包安装成功！"
    else
        print_warn "以下软件包安装失败 (详情见日志):"
        echo "${failed[*]}"
    fi
}

# 安装后配置
post_install_setup() {
    print_info "执行服务自启配置..."
    local services=("ssh" "sshd" "cron" "crond" "docker")
    
    for svc in "${services[@]}"; do
        if systemctl list-unit-files "$svc.service" &>/dev/null; then
            systemctl enable "$svc" >> "$LOG_FILE" 2>&1
            systemctl start "$svc" >> "$LOG_FILE" 2>&1
        fi
    done
    
    # Git 配置
    if command -v git &>/dev/null; then
        git config --global init.defaultBranch main
        git config --global color.ui auto
    fi
}

# ------------------------------------------------------------------------------
# 4. 交互菜单与入口
# ------------------------------------------------------------------------------

custom_menu() {
    clear
    print_header "自定义安装模式"
    echo -e "${CYAN}请选择要附加的组件包:${NC}"
    echo "1. 基础运维包 (Basic)"
    echo "2. 开发编译包 (Dev)"
    echo "3. 系统监控包 (Monitor)"
    echo "4. 安全加固包 (Security)"
    echo ""
    read -p "请输入数字组合 (如 1 3): " selections
    
    local install_list=""
    [[ "$selections" =~ "1" ]] && install_list="$install_list $BASIC_PACKAGES"
    [[ "$selections" =~ "2" ]] && install_list="$install_list $DEV_PACKAGES"
    [[ "$selections" =~ "3" ]] && install_list="$install_list $MONITOR_PACKAGES"
    [[ "$selections" =~ "4" ]] && install_list="$install_list $SECURITY_PACKAGES"
    
    if [ -n "$install_list" ]; then
        configure_extra_repos
        update_cache
        install_pkg_list "$install_list"
        post_install_setup
    else
        print_warn "未选择任何内容。"
    fi
}

interactive_menu() {
    clear
    print_header "依赖安装向导"
    echo -e "${CYAN}当前系统:${NC} $OS_TYPE ($PKG_MANAGER)"
    echo -e "${CYAN}日志路径:${NC} $LOG_FILE"
    echo ""
    echo "1. 安装基础工具 (推荐)"
    echo "2. 安装开发环境 (含 Docker, Python, Go)"
    echo "3. 安装监控与安全工具"
    echo "4. 全量安装 (All-in-One)"
    echo "5. 自定义选择"
    echo "0. 退出"
    echo ""
    read -p "请选择 [0-5]: " choice
    
    case $choice in
        1)
            update_cache
            install_pkg_list "$BASIC_PACKAGES"
            ;;
        2)
            configure_extra_repos
            update_cache
            install_pkg_list "$DEV_PACKAGES"
            ;;
        3)
            update_cache
            install_pkg_list "$MONITOR_PACKAGES $SECURITY_PACKAGES"
            ;;
        4)
            configure_extra_repos
            update_cache
            install_pkg_list "$BASIC_PACKAGES $DEV_PACKAGES $MONITOR_PACKAGES $SECURITY_PACKAGES"
            ;;
        5)
            custom_menu
            return
            ;;
        0) exit 0 ;;
        *) print_error "无效输入"; sleep 1; interactive_menu ;;
    esac
    
    # 统一安装后处理
    if [[ "$choice" =~ [1-4] ]]; then
        post_install_setup
        echo ""
        print_success "任务完成。"
        read -n 1 -s -r -p "按任意键返回..."
    fi
}

main() {
    check_root
    detect_package_manager
    
    # 命令行参数支持
    if [ -n "$1" ]; then
        case "$1" in
            --basic)
                update_cache
                install_pkg_list "$BASIC_PACKAGES"
                post_install_setup
                ;;
            --dev)
                configure_extra_repos
                update_cache
                install_pkg_list "$DEV_PACKAGES"
                post_install_setup
                ;;
            --all)
                configure_extra_repos
                update_cache
                install_pkg_list "$BASIC_PACKAGES $DEV_PACKAGES $MONITOR_PACKAGES $SECURITY_PACKAGES"
                post_install_setup
                ;;
            --help|-h)
                echo "Usage: bash install_deps.sh [--basic | --dev | --all]"
                ;;
            *)
                print_error "未知参数: $1"
                exit 1
                ;;
        esac
    else
        interactive_menu
    fi
}

main "$@"
