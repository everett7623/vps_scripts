#!/bin/bash
# ==============================================================================
# 脚本名称: 公共函数库 (Common Functions Library)
# 脚本文件: lib/common_functions.sh
# 脚本用途: 提供VPS脚本工具集的公共函数、UI交互、网络工具及服务管理
# 作者: Jensfrank (Optimized by AI)
# 版本: 2.3.0 (Full Feature Set)
# 更新日期: 2026-01-20
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 全局颜色与样式定义 (ANSI Colors)
# ------------------------------------------------------------------------------
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[0;37m'
export BOLD='\033[1m'
export NC='\033[0m' # No Color (Reset)

# ------------------------------------------------------------------------------
# 2. 日志与调试配置
# ------------------------------------------------------------------------------
export LOG_LEVEL_DEBUG=0
export LOG_LEVEL_INFO=1
export LOG_LEVEL_WARN=2
export LOG_LEVEL_ERROR=3

# 默认日志级别
export CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}

# ------------------------------------------------------------------------------
# 3. UI 交互与打印函数 (UI/UX)
# ------------------------------------------------------------------------------

# 基础打印函数
print_msg() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 标准状态消息
print_info() { print_msg "${CYAN}" "[信息] $1"; }
print_success() { print_msg "${GREEN}" "[成功] $1"; }
print_warn() { print_msg "${YELLOW}" "[警告] $1"; }
print_error() { print_msg "${RED}" "[错误] $1"; }

# 打印分隔线 (自适应宽度)
print_separator() {
    local char="${1:-━}"
    local width="${2:-80}"
    local color="${3:-$BLUE}"
    echo -e "${color}$(printf '%*s' "$width" | tr ' ' "$char")${NC}"
}

# [新] 打印大标题 (用于脚本启动时)
print_header() {
    local title=" $1 "
    local width=80
    print_separator "=" "$width" "$PURPLE"
    local padding=$(( (width - ${#title}) / 2 ))
    echo -e "${BOLD}${PURPLE}$(printf '%*s' "$padding" '')${title}${NC}"
    print_separator "=" "$width" "$PURPLE"
    echo ""
}

# [新] 打印小节标题 (用于功能区块)
print_title() {
    local title="$1"
    echo ""
    echo -e "${BOLD}${GREEN}▶ $title${NC}"
    print_separator "-" 80 "$BLUE"
}

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local width=${3:-50}
    
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${BLUE}[$(printf '%*s' "$filled" | tr ' ' '=')>$(printf '%*s' "$empty" | tr ' ' ' ')] ${percent}%%${NC}"
    
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# 动画等待
wait_with_animation() {
    local message="$1"
    local duration=${2:-3} # 默认等待3秒，或者传入PID
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    # 如果第二个参数是数字且较小，当做时间；如果是大数字，当做PID
    if [[ "$duration" =~ ^[0-9]+$ ]] && [ "$duration" -gt 1000 ]; then
        # PID 模式
        while kill -0 "$duration" 2>/dev/null; do
            local i=$(( (i + 1) % 10 ))
            printf "\r${CYAN}%s %s${NC}" "${spin:$i:1}" "$message"
            sleep 0.1
        done
    else
        # 时间模式
        for ((i=0; i<duration*10; i++)); do
            printf "\r${CYAN}%s %s${NC}" "$message" "${spin:$i%10:1}"
            sleep 0.1
        done
    fi
    printf "\r${GREEN}✓ %s 完成        ${NC}\n" "$message"
}

# ------------------------------------------------------------------------------
# 4. 系统环境检测函数
# ------------------------------------------------------------------------------

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此操作需要 Root 权限"
        print_info "请使用 'sudo -i' 切换用户后重试"
        return 1
    fi
    return 0
}

get_os_release() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

get_os_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$VERSION_ID"
    else
        echo "unknown"
    fi
}

get_arch() { uname -m; }
get_cpu_cores() { nproc --all; }
get_total_memory() { free -m | awk '/^Mem:/ {print $2}'; }

command_exists() { command -v "$1" &> /dev/null; }

# 确保命令存在，不存在则安装
ensure_command() {
    local cmd=$1
    local package=${2:-$1}
    
    if ! command_exists "$cmd"; then
        print_warn "命令 '$cmd' 未找到，正在安装..."
        local install_cmd=""
        
        if command_exists apt-get; then
            install_cmd="apt-get update -qq && apt-get install -y $package"
        elif command_exists yum; then
            install_cmd="yum install -y $package"
        elif command_exists dnf; then
            install_cmd="dnf install -y $package"
        elif command_exists apk; then
            install_cmd="apk add $package"
        elif command_exists pacman; then
            install_cmd="pacman -S --noconfirm $package"
        fi
        
        if [ -n "$install_cmd" ] && eval "$install_cmd" &> /dev/null; then
            print_success "$package 安装成功"
            return 0
        else
            print_error "$package 安装失败，请手动安装"
            return 1
        fi
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 5. 网络工具函数
# ------------------------------------------------------------------------------

get_public_ip() {
    local version=${1:-4}
    local timeout=${2:-5}
    local ip=""
    
    if [ "$version" -eq 4 ]; then
        ip=$(curl -s -4 --max-time "$timeout" https://api.ip.sb/ip 2>/dev/null || \
             curl -s -4 --max-time "$timeout" https://ifconfig.me 2>/dev/null || \
             curl -s -4 --max-time "$timeout" https://icanhazip.com 2>/dev/null)
    else
        ip=$(curl -s -6 --max-time "$timeout" https://api.ip.sb/ip 2>/dev/null || \
             curl -s -6 --max-time "$timeout" https://ifconfig.me 2>/dev/null)
    fi
    echo "${ip:-获取失败}"
}

check_port() {
    local port=$1
    if command_exists ss; then
        ss -tuln | grep -q ":$port "
    elif command_exists netstat; then
        netstat -tuln | grep -q ":$port "
    else
        return 2
    fi
}

test_url() {
    local url=$1
    local timeout=${2:-5}
    if curl -s --head --max-time "$timeout" "$url" | grep -q "200 OK"; then
        return 0
    else
        return 1
    fi
}

# ------------------------------------------------------------------------------
# 6. 文件与配置管理 (之前遗漏的关键部分)
# ------------------------------------------------------------------------------

safe_mkdir() {
    local dir="$1"
    [ ! -d "$dir" ] && mkdir -p "$dir" && print_success "目录 $dir 创建成功"
}

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        cp "$file" "${file}.bak.${timestamp}"
        print_info "已备份文件: ${file}.bak.${timestamp}"
    fi
}

# [关键] 下载文件 (带重试)
download_file() {
    local url=$1
    local output=$2
    local retries=${3:-3}
    
    for i in $(seq 1 "$retries"); do
        if curl -fsSL --max-time 60 "$url" -o "$output"; then
            print_success "下载成功: $(basename "$output")"
            return 0
        else
            print_warn "下载失败 (尝试 $i/$retries)..."
            sleep 2
        fi
    done
    print_error "下载彻底失败: $url"
    return 1
}

read_config() {
    local file="$1"
    local key="$2"
    local default="$3"
    if [ -f "$file" ]; then
        local value=$(grep "^${key}=" "$file" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

# [关键] 写入配置 (之前遗漏)
write_config() {
    local file="$1"
    local key="$2"
    local value="$3"
    
    safe_mkdir "$(dirname "$file")"
    [ ! -f "$file" ] && touch "$file"
    
    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        echo "${key}=${value}" >> "$file"
    fi
}

# ------------------------------------------------------------------------------
# 7. 用户交互与服务管理
# ------------------------------------------------------------------------------

ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local choice_str="[y/N]"
    [ "$default" = "y" ] && choice_str="[Y/n]"
    
    while true; do
        read -p "${prompt} ${choice_str}: " input
        input=${input:-$default}
        case "${input,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     print_warn "请输入 y 或 n" ;;
        esac
    done
}

# [关键] 菜单选择 (之前遗漏)
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
            print_warn "无效选项，请重试"
        fi
    done
}

# [关键] 读取输入 (之前遗漏)
read_input() {
    local prompt=$1
    local default=$2
    local var_name=$3
    
    if [ -n "$default" ]; then
        read -p "${prompt} [${default}]: " input
        input=${input:-$default}
    else
        read -p "${prompt}: " input
    fi
    
    if [ -n "$var_name" ]; then
        eval "$var_name='$input'"
    else
        echo "$input"
    fi
}

# 服务管理
check_service_status() { systemctl is-active --quiet "$1"; }
start_service() { systemctl start "$1" && print_success "服务 $1 已启动" || print_error "启动 $1 失败"; }
stop_service() { systemctl stop "$1" && print_success "服务 $1 已停止" || print_error "停止 $1 失败"; }
restart_service() { systemctl restart "$1" && print_success "服务 $1 已重启" || print_error "重启 $1 失败"; }

# ------------------------------------------------------------------------------
# 8. 清理与退出 (Cleanup)
# ------------------------------------------------------------------------------

cleanup_temp_files() {
    local temp_dir=${1:-/tmp/vps_scripts_temp}
    if [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
        # print_info "临时文件已清理" # 避免太啰嗦，注释掉
    fi
}

graceful_exit() {
    local exit_code=${1:-0}
    local message=$2
    [ -n "$message" ] && ([ "$exit_code" -eq 0 ] && print_success "$message" || print_error "$message")
    cleanup_temp_files
    exit "$exit_code"
}

# 捕获退出信号 (Ctrl+C)
trap 'graceful_exit 1 "脚本被中断"' INT TERM

# 导出所有函数
export -f print_msg print_info print_success print_warn print_error
export -f print_header print_title print_separator
export -f check_root ensure_command command_exists
export -f get_os_release get_os_version get_arch get_cpu_cores get_total_memory
export -f get_public_ip check_port test_url
export -f show_progress wait_with_animation
export -f safe_mkdir backup_file download_file read_config write_config
export -f ask_yes_no select_option read_input
export -f check_service_status start_service stop_service restart_service
export -f cleanup_temp_files graceful_exit
