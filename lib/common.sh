#!/bin/bash

# ===================================================================
# 文件名: lib/common.sh
# 描述: VPS Scripts 公共函数库
# 作者: everett7623
# 版本: 1.0.0
# 更新日期: 2025-01-10
# ===================================================================

# 定义全局颜色变量
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[1;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export NC='\033[0m' # No Color

# 定义全局路径变量
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LIB_DIR="${SCRIPT_DIR}/lib"
export CONFIG_DIR="${SCRIPT_DIR}/config"
export SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
export LOG_DIR="/var/log/vps_scripts"

# 确保日志目录存在
[[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"

# ===================================================================
# 日志函数
# ===================================================================

# 记录日志
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 写入日志文件
    echo "[$timestamp] [$level] $message" >> "${LOG_DIR}/vps_scripts.log"
    
    # 根据级别输出到控制台
    case "$level" in
        ERROR)
            echo -e "${RED}[错误]${NC} $message" >&2
            ;;
        WARN)
            echo -e "${YELLOW}[警告]${NC} $message"
            ;;
        INFO)
            echo -e "${BLUE}[信息]${NC} $message"
            ;;
        SUCCESS)
            echo -e "${GREEN}[成功]${NC} $message"
            ;;
        DEBUG)
            [[ "$DEBUG" == "true" ]] && echo -e "${CYAN}[调试]${NC} $message"
            ;;
    esac
}

# 便捷日志函数
log_error() { log ERROR "$@"; }
log_warn() { log WARN "$@"; }
log_info() { log INFO "$@"; }
log_success() { log SUCCESS "$@"; }
log_debug() { log DEBUG "$@"; }

# ===================================================================
# 输入输出函数
# ===================================================================

# 显示标题
show_title() {
    local title="$1"
    local width=70
    local padding=$(( (width - ${#title}) / 2 ))
    
    echo ""
    echo -e "${YELLOW}$(printf '=%.0s' {1..70})${NC}"
    printf "%*s%s%*s\n" $padding "" "$title" $padding ""
    echo -e "${YELLOW}$(printf '=%.0s' {1..70})${NC}"
    echo ""
}

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    
    printf "\r进度: ["
    printf "%${completed}s" | tr ' ' '='
    printf "%$((width - completed))s" | tr ' ' ' '
    printf "] %3d%%" $percentage
    
    [[ $current -eq $total ]] && echo ""
}

# 显示旋转加载动画
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# 确认操作
confirm() {
    local prompt="${1:-确定要继续吗？}"
    local default="${2:-n}"
    
    local answer
    if [[ "$default" == "y" ]]; then
        read -p "$prompt [Y/n]: " answer
        [[ -z "$answer" ]] && answer="y"
    else
        read -p "$prompt [y/N]: " answer
        [[ -z "$answer" ]] && answer="n"
    fi
    
    [[ "$answer" =~ ^[Yy]$ ]]
}

# 选择菜单
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    
    echo -e "${BLUE}$prompt${NC}"
    for i in "${!options[@]}"; do
        echo "  $((i+1))) ${options[$i]}"
    done
    
    local choice
    while true; do
        read -p "请选择 [1-${#options[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            return $((choice-1))
        else
            echo -e "${RED}无效选择，请重试${NC}"
        fi
    done
}

# ===================================================================
# 错误处理函数
# ===================================================================

# 错误退出
die() {
    log_error "$@"
    exit 1
}

# 设置错误处理
set_error_handling() {
    set -euo pipefail
    trap 'handle_error $? $LINENO' ERR
}

# 处理错误
handle_error() {
    local exit_code=$1
    local line_number=$2
    log_error "脚本在第 $line_number 行发生错误，退出码: $exit_code"
    exit $exit_code
}

# ===================================================================
# 系统检查函数
# ===================================================================

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "此脚本需要 root 权限运行"
    fi
}

# 检查命令是否存在
command_exists() {
    command -v "$1" &>/dev/null
}

# 检查并安装包
ensure_package() {
    local package="$1"
    
    if ! command_exists "$package"; then
        log_info "正在安装 $package..."
        if command_exists apt-get; then
            apt-get update -qq && apt-get install -y "$package"
        elif command_exists yum; then
            yum install -y "$package"
        elif command_exists dnf; then
            dnf install -y "$package"
        else
            die "无法安装 $package，不支持的包管理器"
        fi
        
        if command_exists "$package"; then
            log_success "$package 安装成功"
        else
            die "$package 安装失败"
        fi
    fi
}

# ===================================================================
# 工具函数
# ===================================================================

# 获取系统信息
get_system_info() {
    local key="$1"
    
    case "$key" in
        os)
            if [[ -f /etc/os-release ]]; then
                source /etc/os-release
                echo "${ID,,}"
            else
                echo "unknown"
            fi
            ;;
        version)
            if [[ -f /etc/os-release ]]; then
                source /etc/os-release
                echo "$VERSION_ID"
            else
                echo "unknown"
            fi
            ;;
        arch)
            uname -m
            ;;
        kernel)
            uname -r
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# 生成随机字符串
generate_random_string() {
    local length="${1:-16}"
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# 备份文件
backup_file() {
    local file="$1"
    local backup_dir="${2:-/var/backups/vps_scripts}"
    
    if [[ -f "$file" ]]; then
        [[ ! -d "$backup_dir" ]] && mkdir -p "$backup_dir"
        
        local filename=$(basename "$file")
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_file="${backup_dir}/${filename}.${timestamp}.bak"
        
        cp "$file" "$backup_file"
        log_info "已备份: $file -> $backup_file"
    fi
}

# 下载文件
download_file() {
    local url="$1"
    local output="$2"
    local timeout="${3:-30}"
    
    log_info "正在下载: $url"
    
    if command_exists curl; then
        curl -fsSL --connect-timeout "$timeout" -o "$output" "$url"
    elif command_exists wget; then
        wget -q --timeout="$timeout" -O "$output" "$url"
    else
        die "需要 curl 或 wget 来下载文件"
    fi
    
    if [[ -f "$output" ]]; then
        log_success "下载完成: $output"
        return 0
    else
        log_error "下载失败: $url"
        return 1
    fi
}

# ===================================================================
# 性能监控函数
# ===================================================================

# 获取CPU使用率
get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
}

# 获取内存使用率
get_memory_usage() {
    free | grep Mem | awk '{print ($3/$2) * 100.0}'
}

# 获取磁盘使用率
get_disk_usage() {
    local path="${1:-/}"
    df -h "$path" | awk 'NR==2 {print $5}' | sed 's/%//'
}

# 测量命令执行时间
measure_time() {
    local start_time=$(date +%s.%N)
    "$@"
    local exit_code=$?
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    log_info "执行时间: ${duration}秒"
    return $exit_code
}

# ===================================================================
# 清理函数
# ===================================================================

# 清理临时文件
cleanup_temp_files() {
    local temp_dir="${1:-/tmp/vps_scripts}"
    
    if [[ -d "$temp_dir" ]]; then
        rm -rf "$temp_dir"
        log_info "已清理临时文件: $temp_dir"
    fi
}

# 设置退出时清理
set_cleanup_on_exit() {
    trap 'cleanup_temp_files' EXIT
}

# ===================================================================
# 导出所有函数
# ===================================================================

export -f log log_error log_warn log_info log_success log_debug
export -f show_title show_progress show_spinner confirm select_option
export -f die set_error_handling handle_error
export -f check_root command_exists ensure_package
export -f get_system_info generate_random_string backup_file download_file
export -f get_cpu_usage get_memory_usage get_disk_usage measure_time
export -f cleanup_temp_files set_cleanup_on_exit
