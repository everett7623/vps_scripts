#!/bin/bash

# ==================================================================
# 脚本名称: 公共函数库
# 脚本文件: common_functions.sh
# 脚本路径: lib/common_functions.sh
# 脚本用途: 提供VPS脚本工具集的公共函数和工具函数
# 作者: Jensfrank
# 项目地址: https://github.com/everett7623/vps_scripts/
# 版本: 1.0.0
# 更新日期: 2025-01-17
# ==================================================================

# 颜色定义（全局使用）
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[0;37m'
export NC='\033[0m' # No Color
export BOLD='\033[1m'

# 日志级别
export LOG_LEVEL_DEBUG=0
export LOG_LEVEL_INFO=1
export LOG_LEVEL_WARN=2
export LOG_LEVEL_ERROR=3

# 默认日志级别
export CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# ==================================================================
# 基础工具函数
# ==================================================================

# 打印带颜色的消息
print_msg() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 打印信息消息
print_info() {
    print_msg "${CYAN}" "[信息] $1"
}

# 打印成功消息
print_success() {
    print_msg "${GREEN}" "[成功] $1"
}

# 打印警告消息
print_warn() {
    print_msg "${YELLOW}" "[警告] $1"
}

# 打印错误消息
print_error() {
    print_msg "${RED}" "[错误] $1"
}

# 打印分隔线
print_separator() {
    local char="${1:-━}"
    local width="${2:-90}"
    local color="${3:-$BLUE}"
    echo -e "${color}$(printf '%*s' "$width" | tr ' ' "$char")${NC}"
}

# ==================================================================
# 系统检查函数
# ==================================================================

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要 root 权限运行"
        print_info "请使用 sudo -i 切换到 root 用户后重试"
        return 1
    fi
    return 0
}

# 检查命令是否存在
command_exists() {
    command -v "$1" &> /dev/null
}

# 检查并安装缺失的命令
ensure_command() {
    local cmd=$1
    local package=${2:-$1}
    
    if ! command_exists "$cmd"; then
        print_warn "命令 '$cmd' 未找到，正在安装..."
        
        # 检测包管理器并安装
        if command_exists apt-get; then
            apt-get update -qq && apt-get install -y "$package" &> /dev/null
        elif command_exists yum; then
            yum install -y "$package" &> /dev/null
        elif command_exists dnf; then
            dnf install -y "$package" &> /dev/null
        elif command_exists pacman; then
            pacman -S --noconfirm "$package" &> /dev/null
        else
            print_error "无法识别的包管理器，请手动安装 $package"
            return 1
        fi
        
        if command_exists "$cmd"; then
            print_success "$cmd 安装成功"
            return 0
        else
            print_error "$cmd 安装失败"
            return 1
        fi
    fi
    return 0
}

# ==================================================================
# 系统信息函数
# ==================================================================

# 获取系统发行版
get_os_release() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# 获取系统版本
get_os_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$VERSION_ID"
    else
        echo "unknown"
    fi
}

# 获取系统架构
get_arch() {
    uname -m
}

# 获取CPU核心数
get_cpu_cores() {
    nproc
}

# 获取总内存（单位：MB）
get_total_memory() {
    free -m | awk '/^Mem:/ {print $2}'
}

# ==================================================================
# 网络相关函数
# ==================================================================

# 获取公网IP
get_public_ip() {
    local ip_version=${1:-4}
    local timeout=${2:-5}
    
    local ip=""
    if [ "$ip_version" = "4" ]; then
        ip=$(curl -s -4 --max-time "$timeout" ifconfig.me || \
             curl -s -4 --max-time "$timeout" ip.sb || \
             curl -s -4 --max-time "$timeout" icanhazip.com)
    else
        ip=$(curl -s -6 --max-time "$timeout" ifconfig.me || \
             curl -s -6 --max-time "$timeout" ip.sb || \
             curl -s -6 --max-time "$timeout" icanhazip.com)
    fi
    
    echo "$ip"
}

# 检查端口是否开放
check_port() {
    local port=$1
    local protocol=${2:-tcp}
    
    if command_exists ss; then
        ss -tuln | grep -q ":$port "
    elif command_exists netstat; then
        netstat -tuln | grep -q ":$port "
    else
        return 2  # 无法检查
    fi
}

# 测试URL连通性
test_url() {
    local url=$1
    local timeout=${2:-5}
    
    if curl -s --max-time "$timeout" --head "$url" | grep -q "200 OK"; then
        return 0
    else
        return 1
    fi
}

# ==================================================================
# 进度条和等待函数
# ==================================================================

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local width=${3:-50}
    
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%$((width - filled))s" | tr ' ' '-'
    printf "] %3d%%" "$percent"
    
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# 带动画的等待函数
wait_with_animation() {
    local message=$1
    local duration=$2
    local spinner='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    for ((i=0; i<duration*10; i++)); do
        printf "\r${CYAN}%s %s${NC}" "$message" "${spinner:i%10:1}"
        sleep 0.1
    done
    printf "\r%s\n" "$(printf ' %.0s' {1..${#message}})"
}

# ==================================================================
# 文件和目录操作函数
# ==================================================================

# 安全创建目录
safe_mkdir() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" && print_success "目录 $dir 创建成功"
    fi
}

# 备份文件
backup_file() {
    local file=$1
    local backup_suffix=${2:-$(date +%Y%m%d_%H%M%S)}
    
    if [ -f "$file" ]; then
        cp "$file" "${file}.${backup_suffix}" && \
        print_success "文件 $file 已备份为 ${file}.${backup_suffix}"
    fi
}

# 下载文件（带重试）
download_file() {
    local url=$1
    local output=$2
    local retries=${3:-3}
    local timeout=${4:-30}
    
    for i in $(seq 1 "$retries"); do
        if curl -fsSL --max-time "$timeout" "$url" -o "$output"; then
            print_success "文件下载成功: $output"
            return 0
        else
            print_warn "下载失败 (尝试 $i/$retries)..."
            sleep 2
        fi
    done
    
    print_error "文件下载失败: $url"
    return 1
}

# ==================================================================
# 配置文件操作函数
# ==================================================================

# 读取配置值
read_config() {
    local config_file=$1
    local key=$2
    local default=$3
    
    if [ -f "$config_file" ]; then
        local value=$(grep "^${key}=" "$config_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

# 写入配置值
write_config() {
    local config_file=$1
    local key=$2
    local value=$3
    
    # 创建配置文件目录
    local config_dir=$(dirname "$config_file")
    safe_mkdir "$config_dir"
    
    # 如果配置文件不存在，创建它
    if [ ! -f "$config_file" ]; then
        touch "$config_file"
    fi
    
    # 更新或添加配置项
    if grep -q "^${key}=" "$config_file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$config_file"
    else
        echo "${key}=${value}" >> "$config_file"
    fi
}

# ==================================================================
# 用户交互函数
# ==================================================================

# 询问Yes/No问题
ask_yes_no() {
    local question=$1
    local default=${2:-n}
    
    local prompt="[y/N]"
    if [ "$default" = "y" ]; then
        prompt="[Y/n]"
    fi
    
    while true; do
        read -p "${question} ${prompt}: " answer
        answer=${answer:-$default}
        
        case ${answer,,} in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) print_warn "请输入 y 或 n" ;;
        esac
    done
}

# 选择菜单
select_option() {
    local prompt=$1
    shift
    local options=("$@")
    
    PS3="${prompt}: "
    select opt in "${options[@]}"; do
        if [ -n "$opt" ]; then
            echo "$REPLY"
            return 0
        else
            print_warn "无效选项，请重新选择"
        fi
    done
}

# 读取用户输入（带默认值）
read_input() {
    local prompt=$1
    local default=$2
    local variable_name=$3
    
    if [ -n "$default" ]; then
        read -p "${prompt} [${default}]: " input
        input=${input:-$default}
    else
        read -p "${prompt}: " input
    fi
    
    if [ -n "$variable_name" ]; then
        eval "$variable_name='$input'"
    else
        echo "$input"
    fi
}

# ==================================================================
# 服务管理函数
# ==================================================================

# 检查服务状态
check_service_status() {
    local service=$1
    
    if systemctl is-active --quiet "$service"; then
        return 0
    else
        return 1
    fi
}

# 启动服务
start_service() {
    local service=$1
    
    if systemctl start "$service"; then
        print_success "服务 $service 启动成功"
        return 0
    else
        print_error "服务 $service 启动失败"
        return 1
    fi
}

# 停止服务
stop_service() {
    local service=$1
    
    if systemctl stop "$service"; then
        print_success "服务 $service 停止成功"
        return 0
    else
        print_error "服务 $service 停止失败"
        return 1
    fi
}

# 重启服务
restart_service() {
    local service=$1
    
    if systemctl restart "$service"; then
        print_success "服务 $service 重启成功"
        return 0
    else
        print_error "服务 $service 重启失败"
        return 1
    fi
}

# ==================================================================
# 清理和退出函数
# ==================================================================

# 清理临时文件
cleanup_temp_files() {
    local temp_dir=${1:-/tmp/vps_scripts_temp}
    
    if [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
        print_info "临时文件已清理"
    fi
}

# 优雅退出
graceful_exit() {
    local exit_code=${1:-0}
    local message=$2
    
    if [ -n "$message" ]; then
        if [ "$exit_code" -eq 0 ]; then
            print_success "$message"
        else
            print_error "$message"
        fi
    fi
    
    # 执行清理操作
    cleanup_temp_files
    
    exit "$exit_code"
}

# 设置陷阱以捕获退出信号
trap 'graceful_exit 1 "脚本被中断"' INT TERM

# ==================================================================
# 导出所有函数，使其可被其他脚本使用
# ==================================================================
export -f print_msg print_info print_success print_warn print_error
export -f print_separator check_root command_exists ensure_command
export -f get_os_release get_os_version get_arch get_cpu_cores get_total_memory
export -f get_public_ip check_port test_url
export -f show_progress wait_with_animation
export -f safe_mkdir backup_file download_file
export -f read_config write_config
export -f ask_yes_no select_option read_input
export -f check_service_status start_service stop_service restart_service
export -f cleanup_temp_files graceful_exit
