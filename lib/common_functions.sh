#!/bin/bash
# lib/common_functions.sh - VPS脚本核心功能库
# 提供通用的函数和变量定义

# 版本信息
LIB_VERSION="1.0.0"

# 颜色定义
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[1;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export NC='\033[0m' # No Color

# 渐变颜色数组
export colors=(
    '\033[38;2;0;255;0m'    # 绿色
    '\033[38;2;64;255;0m'
    '\033[38;2;128;255;0m'
    '\033[38;2;192;255;0m'
    '\033[38;2;255;255;0m'  # 黄色
)

# 项目路径定义
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LIB_DIR="${SCRIPT_DIR}/lib"
export CONFIG_DIR="${SCRIPT_DIR}/config"
export SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
export LOG_DIR="${SCRIPT_DIR}/logs"

# 创建必要的目录
init_directories() {
    mkdir -p "$LOG_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$SCRIPTS_DIR"
}

# 日志函数
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        INFO)
            echo -e "${GREEN}[INFO]${NC} ${message}"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} ${message}"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} ${message}"
            ;;
        DEBUG)
            [[ "${DEBUG:-0}" -eq 1 ]] && echo -e "${BLUE}[DEBUG]${NC} ${message}"
            ;;
    esac
    
    # 写入日志文件
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_DIR}/vps_scripts.log"
}

# 错误处理函数
handle_error() {
    local error_code=$1
    local error_msg="$2"
    log ERROR "$error_msg (错误代码: $error_code)"
    return $error_code
}

# 检查命令是否存在
command_exists() {
    command -v "$1" &>/dev/null
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log ERROR "此脚本需要root权限运行"
        exit 1
    fi
}

# 检查系统类型
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_TYPE=$ID
        OS_VERSION=$VERSION_ID
        OS_PRETTY_NAME="$PRETTY_NAME"
    elif command_exists lsb_release; then
        OS_TYPE=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        OS_VERSION=$(lsb_release -sr)
        OS_PRETTY_NAME=$(lsb_release -sd)
    elif [[ -f /etc/debian_version ]]; then
        OS_TYPE="debian"
        OS_VERSION=$(cat /etc/debian_version)
        OS_PRETTY_NAME="Debian $OS_VERSION"
    else
        OS_TYPE="unknown"
        OS_VERSION="unknown"
        OS_PRETTY_NAME="Unknown"
    fi
    
    export OS_TYPE
    export OS_VERSION
    export OS_PRETTY_NAME
    
    log INFO "检测到操作系统: $OS_PRETTY_NAME"
}

# 获取包管理器
get_package_manager() {
    if command_exists apt-get; then
        PKG_MANAGER="apt-get"
        PKG_INSTALL="apt-get install -y"
        PKG_UPDATE="apt-get update"
        PKG_UPGRADE="apt-get upgrade -y"
    elif command_exists yum; then
        PKG_MANAGER="yum"
        PKG_INSTALL="yum install -y"
        PKG_UPDATE="yum check-update"
        PKG_UPGRADE="yum upgrade -y"
    elif command_exists dnf; then
        PKG_MANAGER="dnf"
        PKG_INSTALL="dnf install -y"
        PKG_UPDATE="dnf check-update"
        PKG_UPGRADE="dnf upgrade -y"
    elif command_exists pacman; then
        PKG_MANAGER="pacman"
        PKG_INSTALL="pacman -S --noconfirm"
        PKG_UPDATE="pacman -Sy"
        PKG_UPGRADE="pacman -Syu --noconfirm"
    elif command_exists zypper; then
        PKG_MANAGER="zypper"
        PKG_INSTALL="zypper install -y"
        PKG_UPDATE="zypper refresh"
        PKG_UPGRADE="zypper update -y"
    else
        log ERROR "未找到支持的包管理器"
        return 1
    fi
    
    export PKG_MANAGER PKG_INSTALL PKG_UPDATE PKG_UPGRADE
}

# 安装依赖包
install_package() {
    local package="$1"
    if ! command_exists "$package"; then
        log INFO "正在安装 $package..."
        $PKG_INSTALL "$package" || handle_error $? "安装 $package 失败"
    else
        log INFO "$package 已安装"
    fi
}

# 检查并安装基础依赖
install_dependencies() {
    log INFO "检查并安装必要的依赖..."
    
    get_package_manager || return 1
    
    # 更新包列表
    log INFO "更新包列表..."
    $PKG_UPDATE
    
    # 基础依赖列表
    local deps=("curl" "wget" "git" "jq" "bc" "lsof" "net-tools")
    
    for dep in "${deps[@]}"; do
        install_package "$dep"
    done
    
    log INFO "依赖安装完成"
}

# 下载文件函数
download_file() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if command_exists wget; then
            wget -q --show-progress -O "$output" "$url" && return 0
        elif command_exists curl; then
            curl -# -L -o "$output" "$url" && return 0
        else
            log ERROR "没有找到wget或curl"
            return 1
        fi
        
        retry_count=$((retry_count + 1))
        log WARN "下载失败，重试 $retry_count/$max_retries..."
        sleep 2
    done
    
    return 1
}

# 执行脚本函数
run_script() {
    local script_name="$1"
    shift
    local args="$@"
    local script_path="${SCRIPTS_DIR}/${script_name}"
    
    if [[ ! -f "$script_path" ]]; then
        log ERROR "脚本不存在: $script_path"
        return 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        chmod +x "$script_path"
    fi
    
    log INFO "执行脚本: $script_name"
    "$script_path" $args
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log INFO "脚本执行成功: $script_name"
    else
        log ERROR "脚本执行失败: $script_name (退出码: $exit_code)"
    fi
    
    return $exit_code
}

# 获取系统信息
get_system_info() {
    # CPU信息
    if [[ "$(uname -m)" == "x86_64" ]]; then
        CPU_INFO=$(cat /proc/cpuinfo | grep 'model name' | uniq | sed -e 's/model name[[:space:]]*: //')
    else
        CPU_INFO=$(lscpu | grep 'Model name' | sed -e 's/Model name[[:space:]]*: //')
    fi
    
    # CPU核心数
    CPU_CORES=$(nproc)
    
    # 内存信息
    MEM_TOTAL=$(free -b | awk 'NR==2{printf "%.2f", $2/1024/1024}')
    MEM_USED=$(free -b | awk 'NR==2{printf "%.2f", $3/1024/1024}')
    MEM_PERCENT=$(free -b | awk 'NR==2{printf "%.2f", $3*100/$2}')
    
    # 磁盘信息
    DISK_INFO=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')
    
    # 系统运行时间
    UPTIME=$(uptime -p 2>/dev/null || uptime | awk -F'up' '{print $2}' | awk -F',' '{print $1}')
    
    export CPU_INFO CPU_CORES MEM_TOTAL MEM_USED MEM_PERCENT DISK_INFO UPTIME
}

# 获取IP地址
get_ip_address() {
    # IPv4地址
    IPV4_ADDRESS=$(curl -s --max-time 5 ipv4.ip.sb 2>/dev/null)
    if [[ -z "$IPV4_ADDRESS" ]]; then
        IPV4_ADDRESS=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)
    fi
    
    # IPv6地址
    IPV6_ADDRESS=$(curl -s --max-time 5 ipv6.ip.sb 2>/dev/null)
    if [[ -z "$IPV6_ADDRESS" ]]; then
        IPV6_ADDRESS=$(ip -6 addr show | grep -oP '(?<=inet6\s)[\da-f:]+' | grep -v '^::1' | grep -v '^fe80' | head -n1)
    fi
    
    export IPV4_ADDRESS IPV6_ADDRESS
}

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf "%$((width - completed))s" | tr ' ' '-'
    printf "] %d%%" $percentage
}

# 按任意键继续
press_any_key() {
    echo ""
    read -n 1 -s -r -p "按任意键返回主菜单..."
    echo ""
}

# 确认操作
confirm_action() {
    local prompt="${1:-确定要继续吗？}"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -r -p "$prompt" response
    
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        [nN][oO]|[nN])
            return 1
            ;;
        "")
            [[ "$default" == "y" ]] && return 0 || return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# 加载配置文件
load_config() {
    local config_file="${CONFIG_DIR}/vps_scripts.conf"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        log DEBUG "加载配置文件: $config_file"
    else
        log WARN "配置文件不存在: $config_file"
    fi
}

# 保存配置
save_config() {
    local key="$1"
    local value="$2"
    local config_file="${CONFIG_DIR}/vps_scripts.conf"
    
    if grep -q "^${key}=" "$config_file" 2>/dev/null; then
        sed -i "s/^${key}=.*/${key}=${value}/" "$config_file"
    else
        echo "${key}=${value}" >> "$config_file"
    fi
}

# 初始化
init_directories
log INFO "加载核心功能库 v${LIB_VERSION}"
