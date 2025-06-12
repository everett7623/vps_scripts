#!/bin/bash
# lib/common.sh - VPS Scripts 公共函数库

# 防止重复加载
if [ -n "$VPS_SCRIPTS_COMMON_LOADED" ]; then
    return 0
fi
VPS_SCRIPTS_COMMON_LOADED=1

# 颜色定义
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[1;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export NC='\033[0m' # No Color

# 日志级别
export LOG_LEVEL_DEBUG=0
export LOG_LEVEL_INFO=1
export LOG_LEVEL_WARN=2
export LOG_LEVEL_ERROR=3

# 当前日志级别
export CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}

# 错误处理函数
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    echo -e "${RED}[ERROR] $message${NC}" >&2
    exit "$exit_code"
}

# 警告信息
warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}" >&2
}

# 成功信息
success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# 信息输出
info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# 调试信息
debug() {
    if [ "$CURRENT_LOG_LEVEL" -le "$LOG_LEVEL_DEBUG" ]; then
        echo -e "${CYAN}[DEBUG] $1${NC}"
    fi
}

# 日志记录函数
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="${LOG_FILE:-$HOME/.vps_scripts.log}"
    
    case $level in
        DEBUG)
            [ "$CURRENT_LOG_LEVEL" -le "$LOG_LEVEL_DEBUG" ] && echo -e "${CYAN}[$timestamp] [DEBUG] $message${NC}"
            ;;
        INFO)
            [ "$CURRENT_LOG_LEVEL" -le "$LOG_LEVEL_INFO" ] && echo -e "${GREEN}[$timestamp] [INFO] $message${NC}"
            ;;
        WARN)
            [ "$CURRENT_LOG_LEVEL" -le "$LOG_LEVEL_WARN" ] && echo -e "${YELLOW}[$timestamp] [WARN] $message${NC}"
            ;;
        ERROR)
            [ "$CURRENT_LOG_LEVEL" -le "$LOG_LEVEL_ERROR" ] && echo -e "${RED}[$timestamp] [ERROR] $message${NC}" >&2
            ;;
        *)
            echo "[$timestamp] $message"
            ;;
    esac
    
    # 写入日志文件
    echo "[$timestamp] [$level] $message" >> "$log_file"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查是否为root用户
is_root() {
    [ "$(id -u)" -eq 0 ]
}

# 获取sudo权限
get_sudo() {
    if ! is_root; then
        if ! sudo -v; then
            error_exit "无法获取sudo权限"
        fi
    fi
}

# 确认操作
confirm() {
    local prompt="${1:-确定要继续吗？}"
    local default="${2:-n}"
    
    if [ "$default" = "y" ] || [ "$default" = "Y" ]; then
        prompt="$prompt [Y/n]: "
        local default_response=0
    else
        prompt="$prompt [y/N]: "
        local default_response=1
    fi
    
    echo -ne "${YELLOW}$prompt${NC}"
    read -r response
    
    if [ -z "$response" ]; then
        return $default_response
    fi
    
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local width=${3:-50}
    local title="${4:-进度}"
    
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r%s: [" "$title"
    printf "%${completed}s" | tr ' ' '='
    printf ">"
    printf "%${remaining}s" | tr ' ' ' '
    printf "] %d%%" "$percentage"
    
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# 旋转进度指示器
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# 检查网络连接
check_network() {
    local test_url="${1:-https://www.google.com}"
    local timeout="${2:-5}"
    
    if curl -s --head --connect-timeout "$timeout" "$test_url" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 下载文件
download_file() {
    local url="$1"
    local output="$2"
    local description="${3:-文件}"
    
    info "正在下载 $description..."
    
    if command_exists wget; then
        wget -q --show-progress -O "$output" "$url" || return 1
    elif command_exists curl; then
        curl -# -L -o "$output" "$url" || return 1
    else
        error_exit "需要 wget 或 curl 来下载文件"
    fi
    
    success "$description 下载完成"
    return 0
}

# 执行命令并捕获输出
run_command() {
    local cmd="$1"
    local description="${2:-命令}"
    local output_file=$(mktemp)
    local error_file=$(mktemp)
    
    debug "执行: $cmd"
    
    eval "$cmd" > "$output_file" 2> "$error_file"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        cat "$output_file"
        rm -f "$output_file" "$error_file"
        return 0
    else
        warning "$description 执行失败 (退出码: $exit_code)"
        if [ -s "$error_file" ]; then
            echo "错误信息:" >&2
            cat "$error_file" >&2
        fi
        rm -f "$output_file" "$error_file"
        return $exit_code
    fi
}

# 安全执行函数
safe_exec() {
    local cmd="$1"
    local error_msg="${2:-命令执行失败}"
    
    if ! eval "$cmd"; then
        error_exit "$error_msg"
    fi
}

# 获取脚本绝对路径
get_script_path() {
    local source="${BASH_SOURCE[0]}"
    while [ -h "$source" ]; do
        local dir="$(cd -P "$(dirname "$source")" >/dev/null 2>&1 && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    echo "$(cd -P "$(dirname "$source")" >/dev/null 2>&1 && pwd)"
}

# 创建临时目录
create_temp_dir() {
    local prefix="${1:-vps_scripts}"
    local temp_dir=$(mktemp -d -t "${prefix}.XXXXXX")
    echo "$temp_dir"
}

# 清理函数
cleanup() {
    local temp_files=("$@")
    for file in "${temp_files[@]}"; do
        if [ -e "$file" ]; then
            rm -rf "$file"
            debug "已清理: $file"
        fi
    done
}

# 设置陷阱清理
setup_cleanup_trap() {
    local temp_files=("$@")
    trap "cleanup ${temp_files[*]}" EXIT INT TERM
}

# 格式化文件大小
format_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [ $size -gt 1024 ] && [ $unit -lt 4 ]; do
        size=$((size / 1024))
        unit=$((unit + 1))
    done
    
    echo "$size ${units[$unit]}"
}

# 格式化时间
format_duration() {
    local seconds=$1
    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    local result=""
    [ $days -gt 0 ] && result="${days}天 "
    [ $hours -gt 0 ] && result="${result}${hours}小时 "
    [ $minutes -gt 0 ] && result="${result}${minutes}分钟 "
    [ $secs -gt 0 ] || [ -z "$result" ] && result="${result}${secs}秒"
    
    echo "$result"
}

# 获取系统信息
get_system_info() {
    local key="$1"
    
    case "$key" in
        "cpu_model")
            if [ -f /proc/cpuinfo ]; then
                grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs
            else
                echo "Unknown"
            fi
            ;;
        "cpu_cores")
            nproc 2>/dev/null || echo "1"
            ;;
        "memory_total")
            free -b | awk 'NR==2{print $2}'
            ;;
        "memory_used")
            free -b | awk 'NR==2{print $3}'
            ;;
        "disk_total")
            df -B1 / | awk 'NR==2{print $2}'
            ;;
        "disk_used")
            df -B1 / | awk 'NR==2{print $3}'
            ;;
        "kernel_version")
            uname -r
            ;;
        "hostname")
            hostname
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# 检查端口是否开放
check_port() {
    local port=$1
    local host="${2:-localhost}"
    local timeout="${3:-3}"
    
    if command_exists nc; then
        nc -z -w"$timeout" "$host" "$port" 2>/dev/null
    elif command_exists telnet; then
        timeout "$timeout" telnet "$host" "$port" 2>&1 | grep -q "Connected"
    else
        # 使用 /dev/tcp 作为备选
        timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null
    fi
}

# 生成随机字符串
generate_random_string() {
    local length="${1:-16}"
    local charset="${2:-A-Za-z0-9}"
    
    tr -dc "$charset" < /dev/urandom | head -c "$length"
}

# 备份文件
backup_file() {
    local file="$1"
    local backup_suffix="${2:-.bak}"
    
    if [ -f "$file" ]; then
        local backup_file="${file}${backup_suffix}.$(date +%Y%m%d_%H%M%S)"
        cp -a "$file" "$backup_file"
        info "已备份: $file -> $backup_file"
        echo "$backup_file"
    else
        warning "文件不存在: $file"
        return 1
    fi
}

# 还原文件
restore_file() {
    local backup_file="$1"
    local target_file="${2:-${backup_file%.bak.*}}"
    
    if [ -f "$backup_file" ]; then
        cp -a "$backup_file" "$target_file"
        success "已还原: $backup_file -> $target_file"
    else
        error_exit "备份文件不存在: $backup_file"
    fi
}

# 比较版本号
version_compare() {
    local version1="$1"
    local version2="$2"
    
    if [ "$version1" = "$version2" ]; then
        return 0
    fi
    
    local IFS=.
    local i ver1=($version1) ver2=($version2)
    
    # 填充空字段
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=${#ver2[@]}; i<${#ver1[@]}; i++)); do
        ver2[i]=0
    done
    
    for ((i=0; i<${#ver1[@]}; i++)); do
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2
        fi
    done
    
    return 0
}

# 等待进程结束
wait_for_process() {
    local pid=$1
    local timeout="${2:-0}"
    local interval="${3:-1}"
    local elapsed=0
    
    while kill -0 "$pid" 2>/dev/null; do
        if [ "$timeout" -gt 0 ] && [ "$elapsed" -ge "$timeout" ]; then
            warning "等待进程 $pid 超时"
            return 1
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    return 0
}

# 并行执行函数
parallel_exec() {
    local max_jobs="${1:-4}"
    shift
    local commands=("$@")
    local pids=()
    
    for cmd in "${commands[@]}"; do
        # 等待有空闲位置
        while [ ${#pids[@]} -ge "$max_jobs" ]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                    unset pids[$i]
                fi
            done
            pids=("${pids[@]}")  # 重新索引数组
            sleep 0.1
        done
        
        # 启动新任务
        eval "$cmd" &
        pids+=($!)
    done
    
    # 等待所有任务完成
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
}

# 导出所有函数
export -f error_exit warning success info debug log
export -f command_exists is_root get_sudo confirm
export -f show_progress spinner check_network
export -f download_file run_command safe_exec
export -f get_script_path create_temp_dir cleanup
export -f setup_cleanup_trap format_size format_duration
export -f get_system_info check_port generate_random_string
export -f backup_file restore_file version_compare
export -f wait_for_process parallel_exec
