#!/bin/bash
# ==============================================================================
# 脚本名称: 公共函数库 (Common Functions Library)
# 脚本文件: lib/common_functions.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 描述: 提供 VPS 脚本工具集的公共 UI、日志、系统检测及服务管理函数。
#       本库被设计为可被其他脚本 source 加载，以复用代码。
# 作者: Jensfrank (Optimized by AI)
# 版本: 1.0.2 (Color Optimized)
# 更新日期: 2026-01-21
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 全局配置与颜色定义
# ------------------------------------------------------------------------------

# 基础颜色定义 (亮色系/加粗优化，适配深色背景)
export RED='\033[1;91m'       # 亮红
export GREEN='\033[1;92m'     # 亮绿
export YELLOW='\033[1;93m'    # 亮黄
export BLUE='\033[1;94m'      # 亮蓝
export PURPLE='\033[1;95m'    # 亮紫
export CYAN='\033[1;96m'      # 亮青
export WHITE='\033[1;97m'     # 亮白
export NC='\033[0m'           # 重置
export BOLD='\033[1m'         # 加粗

# 日志级别配置
export LOG_LEVEL_DEBUG=0
export LOG_LEVEL_INFO=1
export LOG_LEVEL_WARN=2
export LOG_LEVEL_ERROR=3

# 默认日志级别
export CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}

# ------------------------------------------------------------------------------
# 2. 基础 UI 与日志函数
# ------------------------------------------------------------------------------

# 打印带颜色的基础消息
print_msg() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 标准状态消息封装
print_info()    { print_msg "${CYAN}" "[信息] $1"; }
print_success() { print_msg "${GREEN}" "[成功] $1"; }
print_warn()    { print_msg "${YELLOW}" "[警告] $1"; }
print_error()   { print_msg "${RED}" "[错误] $1"; }

# 打印分隔线 (自适应宽度，默认为 80 字符)
print_separator() {
    local char="${1:-━}"
    local width="${2:-80}"
    local color="${3:-$BLUE}"
    # 使用 printf 生成指定长度的分隔线
    echo -e "${color}$(printf '%*s' "$width" | tr ' ' "$char")${NC}"
}

# 打印大标题 (用于脚本启动时)
print_header() {
    local title=" $1 "
    local width=80
    echo ""
    print_separator "=" "$width" "$CYAN"
    local padding=$(( (width - ${#title}) / 2 ))
    echo -e "${BOLD}${WHITE}$(printf '%*s' "$padding" '')${title}${NC}"
    print_separator "=" "$width" "$CYAN"
    echo ""
}

# 打印小节标题 (用于功能区块)
print_title() {
    local title="$1"
    echo ""
    echo -e "${BOLD}${YELLOW}▶ $title${NC}"
    print_separator "-" 80 "$BLUE"
}

# 显示进度条 (Visual Progress Bar)
show_progress() {
    local current=$1
    local total=$2
    local width=${3:-50}
    
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}[$(printf '%*s' "$filled" | tr ' ' '=')>$(printf '%*s' "$empty" | tr ' ' ' ')] ${percent}%%${NC}"
    
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# 带动画的等待函数 (Loading Spinner)
wait_with_animation() {
    local message="$1"
    local duration=${2:-3} # 默认等待3秒，或者传入PID
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    # 逻辑: 如果 duration 是一个存在的 PID，则一直等待直到进程结束
    # 否则，仅仅作为延时动画展示
    if [[ "$duration" =~ ^[0-9]+$ ]] && [ "$duration" -gt 1000 ] && kill -0 "$duration" 2>/dev/null; then
        # PID 模式
        while kill -0 "$duration" 2>/dev/null; do
            i=$(( (i + 1) % 10 ))
            printf "\r${CYAN}%s %s${NC}" "${spin:$i:1}" "$message"
            sleep 0.1
        done
    else
        # 时间模式
        for ((k=0; k<duration*10; k++)); do
            i=$(( (i + 1) % 10 ))
            printf "\r${CYAN}%s %s${NC}" "${spin:$i:1}" "$message"
            sleep 0.1
        done
    fi
    printf "\r${GREEN}✓ %s 完成        ${NC}\n" "$message"
}

# ------------------------------------------------------------------------------
# 3. 系统检查与环境探测函数
# ------------------------------------------------------------------------------

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要 root 权限运行"
        print_info "请使用 'sudo -i' 切换到 root 用户后重试"
        return 1
    fi
    return 0
}

# 检查命令是否存在
command_exists() {
    command -v "$1" &> /dev/null
}

# 检查并安装缺失的命令 (自动适配包管理器)
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
        else
            print_error "无法识别的包管理器，请手动安装 $package"
            return 1
        fi
        
        if eval "$install_cmd" &> /dev/null; then
            print_success "$package 安装成功"
            return 0
        else
            print_error "$package 安装失败"
            return 1
        fi
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 4. 系统信息获取函数
# ------------------------------------------------------------------------------

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

# ------------------------------------------------------------------------------
# 5. 网络相关函数
# ------------------------------------------------------------------------------

# 获取公网 IP (包含重试逻辑)
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
    echo "${ip:-获取失败}"
}

# 检查端口占用情况
check_port() {
    local port=$1
    if command_exists ss; then
        ss -tuln | grep -q ":$port "
    elif command_exists netstat; then
        netstat -tuln | grep -q ":$port "
    else
        return 2  # 无法检查
    fi
}

# 测试 URL 连通性
test_url() {
    local url=$1
    local timeout=${2:-5}
    if curl -s --max-time "$timeout" --head "$url" | grep -q "200 OK"; then
        return 0
    else
        return 1
    fi
}

# ------------------------------------------------------------------------------
# 6. 文件与目录操作函数
# ------------------------------------------------------------------------------

# 安全创建目录
safe_mkdir() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" && print_success "目录 $dir 创建成功"
    fi
}

# 备份文件 (自动添加时间戳)
backup_file() {
    local file=$1
    local backup_suffix=${2:-$(date +%Y%m%d_%H%M%S)}
    
    if [ -f "$file" ]; then
        cp "$file" "${file}.${backup_suffix}" && \
        print_success "文件 $file 已备份为 ${file}.${backup_suffix}"
    fi
}

# 下载文件 (带重试机制)
download_file() {
    local url=$1
    local output=$2
    local retries=${3:-3}
    local timeout=${4:-30}
    
    for i in $(seq 1 "$retries"); do
        if curl -fsSL --max-time "$timeout" "$url" -o "$output"; then
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

# ------------------------------------------------------------------------------
# 7. 配置文件操作函数
# ------------------------------------------------------------------------------

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

write_config() {
    local config_file=$1
    local key=$2
    local value=$3
    
    local config_dir=$(dirname "$config_file")
    safe_mkdir "$config_dir"
    
    if [ ! -f "$config_file" ]; then touch "$config_file"; fi
    
    if grep -q "^${key}=" "$config_file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$config_file"
    else
        echo "${key}=${value}" >> "$config_file"
    fi
}

# ------------------------------------------------------------------------------
# 8. 用户交互函数
# ------------------------------------------------------------------------------

ask_yes_no() {
    local question=$1
    local default=${2:-n}
    local prompt="[y/N]"
    [ "$default" = "y" ] && prompt="[Y/n]"
    
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

# ------------------------------------------------------------------------------
# 9. 服务管理函数
# ------------------------------------------------------------------------------

check_service_status() {
    local service=$1
    if systemctl is-active --quiet "$service"; then
        return 0
    else
        return 1
    fi
}

start_service() {
    systemctl start "$1" && print_success "服务 $1 启动成功" || print_error "服务 $1 启动失败"
}

stop_service() {
    systemctl stop "$1" && print_success "服务 $1 停止成功" || print_error "服务 $1 停止失败"
}

restart_service() {
    systemctl restart "$1" && print_success "服务 $1 重启成功" || print_error "服务 $1 重启失败"
}

# ------------------------------------------------------------------------------
# 10. 清理与退出函数
# ------------------------------------------------------------------------------

cleanup_temp_files() {
    local temp_dir=${1:-/tmp/vps_scripts_temp}
    if [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
        # print_info "临时文件已清理" # 静默清理，避免刷屏
    fi
}

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
    cleanup_temp_files
    exit "$exit_code"
}

# 捕获退出信号 (Ctrl+C, Termination)
trap 'graceful_exit 1 "脚本被强制中断"' INT TERM

# ------------------------------------------------------------------------------
# 11. 导出函数 (使其在子脚本中可用)
# ------------------------------------------------------------------------------
export -f print_msg print_info print_success print_warn print_error
export -f print_separator print_header print_title
export -f check_root command_exists ensure_command
export -f get_os_release get_os_version get_arch get_cpu_cores get_total_memory
export -f get_public_ip check_port test_url
export -f show_progress wait_with_animation
export -f safe_mkdir backup_file download_file
export -f read_config write_config
export -f ask_yes_no select_option read_input
export -f check_service_status start_service stop_service restart_service
export -f cleanup_temp_files graceful_exit
