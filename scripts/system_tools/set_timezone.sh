#!/bin/bash
# ==============================================================================
# 脚本名称: set_timezone.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/system_tools/set_timezone.sh
# 描述: VPS 时区与时间同步工具 (完美复刻版)
#       包含全球时区选择、关键词搜索、NTP 自动配置、严格验证及报告生成。
# 作者: Jensfrank (Optimized by AI)
# 版本: 1.3.1 (Full Restoration)
# 更新日期: 2026-01-21
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 环境初始化
# ------------------------------------------------------------------------------

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

LOG_FILE="/var/log/vps_scripts/set_timezone.log"
BACKUP_DIR="/var/backups/timezone_change"
BACKUP_TIME=$(date +%Y%m%d_%H%M%S)

# NTP 服务器池
NTP_SERVERS=("pool.ntp.org" "time.google.com" "time.cloudflare.com" "ntp.aliyun.com")

# 加载公共库
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"

if [ -f "$LIB_FILE" ]; then
    source "$LIB_FILE"
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
else
    # Fallback UI
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'
    print_info() { echo -e "${CYAN}[信息] $1${NC}"; }
    print_success() { echo -e "${GREEN}[成功] $1${NC}"; }
    print_warn() { echo -e "${YELLOW}[警告] $1${NC}"; }
    print_error() { echo -e "${RED}[错误] $1${NC}"; }
    print_header() { echo -e "\n${PURPLE}=== $1 ===${NC}\n"; }
    check_root() { [[ $EUID -ne 0 ]] && { echo -e "${RED}需要 root 权限${NC}"; exit 1; }; }
fi

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# ------------------------------------------------------------------------------
# 2. 核心功能函数
# ------------------------------------------------------------------------------

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

# 获取当前时区
get_current_timezone() {
    if command -v timedatectl &>/dev/null; then
        timedatectl status | grep "Time zone" | awk '{print $3}'
    elif [ -f /etc/timezone ]; then
        cat /etc/timezone
    elif [ -L /etc/localtime ]; then
        readlink /etc/localtime | sed 's/.*zoneinfo\///'
    else
        echo "Unknown"
    fi
}

# 显示详细信息
show_time_info() {
    print_header "系统时间状态"
    echo -e "${CYAN}当前时区:${NC} $(get_current_timezone)"
    echo -e "${CYAN}本地时间:${NC} $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo -e "${CYAN}UTC 时间:${NC} $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    
    if command -v timedatectl &>/dev/null; then
        local ntp_status=$(timedatectl status | grep -E "NTP service|NTP synchronized" | awk '{print $3}' | head -1)
        echo -e "${CYAN}NTP 状态:${NC} ${ntp_status:-未知}"
    fi
}

# 验证时区有效性
validate_timezone() {
    if [ -f "/usr/share/zoneinfo/$1" ]; then return 0; else print_error "无效的时区: $1"; return 1; fi
}

# 搜索时区 (原版功能找回!)
search_timezones() {
    local keyword=$1
    echo -e "${BLUE}--- 搜索结果 '$keyword' ---${NC}"
    # 查找 zoneinfo 下的文件，过滤掉 Posix/Right 等干扰项
    find /usr/share/zoneinfo -type f | grep -i "$keyword" | sed 's|/usr/share/zoneinfo/||' | grep -vE "^posix|^right|^Etc/GMT" | head -20 | sort
    echo -e "${BLUE}-------------------------${NC}"
}

# 备份配置
backup_configs() {
    print_info "备份时间配置..."
    local backup_path="$BACKUP_DIR/backup_$BACKUP_TIME"
    mkdir -p "$backup_path"
    
    local files=("/etc/timezone" "/etc/localtime" "/etc/sysconfig/clock" "/etc/ntp.conf" "/etc/chrony.conf" "/etc/systemd/timesyncd.conf")
    for f in "${files[@]}"; do [ -e "$f" ] && cp -p "$f" "$backup_path/"; done
    get_current_timezone > "$backup_path/old_timezone.txt"
}

# 设置时区逻辑
set_system_timezone() {
    local target_tz=$1
    print_info "应用时区: $target_tz"
    
    if command -v timedatectl &>/dev/null; then
        timedatectl set-timezone "$target_tz"
    else
        rm -f /etc/localtime
        ln -sf "/usr/share/zoneinfo/$target_tz" /etc/localtime
        [ -f /etc/timezone ] && echo "$target_tz" > /etc/timezone
        if [ -f /etc/sysconfig/clock ]; then
            echo "ZONE=\"$target_tz\"" > /etc/sysconfig/clock
            echo "UTC=true" >> /etc/sysconfig/clock
        fi
    fi
    
    if command -v hwclock &>/dev/null; then hwclock --systohc; fi
}

# 配置 NTP
configure_ntp() {
    print_info "正在配置 NTP..."
    if command -v timedatectl &>/dev/null; then
        timedatectl set-ntp true
        if [ -f /etc/systemd/timesyncd.conf ]; then
            # 简单的配置替换
            sed -i 's/^#NTP=.*/NTP=pool.ntp.org time.google.com/' /etc/systemd/timesyncd.conf
            systemctl restart systemd-timesyncd 2>/dev/null
        fi
    elif command -v chronyd &>/dev/null; then
        systemctl enable --now chronyd; chronyc makestep
    elif command -v ntpd &>/dev/null; then
        systemctl enable --now ntpd
    elif command -v ntpdate &>/dev/null; then
        ntpdate pool.ntp.org
    else
        print_warn "未找到 NTP 服务，建议安装 chrony。"
    fi
    print_success "NTP 配置已更新。"
}

# 验证结果 (原版功能找回!)
verify_timezone() {
    local target=$1
    local current=$(get_current_timezone)
    if [ "$current" == "$target" ]; then
        print_success "验证通过: 当前时区已变为 $current"
        return 0
    else
        print_error "验证失败: 期望 $target，实际 $current"
        return 1
    fi
}

# 生成报告 (原版功能找回!)
generate_report() {
    local report_file="$LOG_DIR/timezone_report_$(date +%Y%m%d_%H%M%S).txt"
    cat > "$report_file" <<EOF
==================================================
           时区设置报告
==================================================
时间: $(date)
目标时区: $1
当前状态: $(get_current_timezone)
本地时间: $(date)
UTC 时间: $(date -u)
日志文件: $LOG_FILE
==================================================
EOF
    print_info "报告已生成: $report_file"
}

# ------------------------------------------------------------------------------
# 4. 交互与菜单
# ------------------------------------------------------------------------------

# 快捷转换
resolve_alias() {
    case "${1,,}" in
        cn|china|shanghai) echo "Asia/Shanghai" ;;
        hk|hongkong)       echo "Asia/Hong_Kong" ;;
        tw|taiwan)         echo "Asia/Taipei" ;;
        jp|tokyo)          echo "Asia/Tokyo" ;;
        kr|seoul)          echo "Asia/Seoul" ;;
        sg|singapore)      echo "Asia/Singapore" ;;
        us|ny|newyork)     echo "America/New_York" ;;
        la|losangeles)     echo "America/Los_Angeles" ;;
        uk|london)         echo "Europe/London" ;;
        utc|gmt)           echo "UTC" ;;
        *)                 echo "$1" ;;
    esac
}

# 常用时区菜单
menu_common_zones() {
    echo ""
    echo -e "${YELLOW}--- 亚洲 ---${NC}"
    echo " 1. 上海 (Shanghai)    2. 香港 (Hong Kong)    3. 台北 (Taipei)"
    echo " 4. 东京 (Tokyo)       5. 首尔 (Seoul)        6. 新加坡 (Singapore)"
    echo -e "${YELLOW}--- 美洲 ---${NC}"
    echo " 7. 纽约 (New York)    8. 洛杉矶 (Los Angeles) 9. 圣保罗 (Sao Paulo)"
    echo -e "${YELLOW}--- 欧洲 ---${NC}"
    echo "10. 伦敦 (London)     11. 巴黎 (Paris)       12. 柏林 (Berlin)"
    echo "13. 莫斯科 (Moscow)   14. 法兰克福 (Frankfurt)"
    echo -e "${YELLOW}--- 其他 ---${NC}"
    echo "15. 悉尼 (Sydney)     16. 迪拜 (Dubai)       0. UTC 标准时间"
    echo ""
    read -p "请选择编号: " num
    case $num in
        1) echo "Asia/Shanghai" ;; 2) echo "Asia/Hong_Kong" ;; 3) echo "Asia/Taipei" ;;
        4) echo "Asia/Tokyo" ;; 5) echo "Asia/Seoul" ;; 6) echo "Asia/Singapore" ;;
        7) echo "America/New_York" ;; 8) echo "America/Los_Angeles" ;; 9) echo "America/Sao_Paulo" ;;
        10) echo "Europe/London" ;; 11) echo "Europe/Paris" ;; 12) echo "Europe/Berlin" ;;
        13) echo "Europe/Moscow" ;; 14) echo "Europe/Berlin" ;;
        15) echo "Australia/Sydney" ;; 16) echo "Asia/Dubai" ;;
        0) echo "UTC" ;;
        *) echo "" ;;
    esac
}

interactive_menu() {
    while true; do
        clear
        print_header "VPS 时区设置工具"
        show_time_info
        echo ""
        echo "1. 选择常用时区 (推荐)"
        echo "2. 手动输入时区"
        echo "3. 搜索时区 (关键词)"
        echo "4. 配置 NTP 同步"
        echo "5. 立即同步时间"
        echo "0. 退出"
        echo ""
        read -p "请选择 [0-5]: " choice
        
        local tz=""
        case $choice in
            1)
                tz=$(menu_common_zones)
                if [ -z "$tz" ]; then print_error "无效选择"; sleep 1; continue; fi
                ;;
            2)
                read -p "请输入时区 (如 Asia/Shanghai): " tz
                ;;
            3)
                read -p "请输入搜索关键词 (如 China 或 York): " key
                search_timezones "$key"
                echo ""
                read -p "请输入完整的时区名称: " tz
                ;;
            4) configure_ntp; read -n 1 -s -r -p "按键返回..."; continue ;;
            5) 
               if command -v ntpdate &>/dev/null; then ntpdate pool.ntp.org; 
               elif command -v chronyc &>/dev/null; then chronyc makestep;
               else print_warn "需安装 NTP 服务"; fi
               read -n 1 -s -r -p "按键返回..."; continue
               ;;
            0) exit 0 ;;
            *) print_error "无效输入"; sleep 1; continue ;;
        esac
        
        if [ -n "$tz" ]; then
            if validate_timezone "$tz"; then
                backup_configs
                set_system_timezone "$tz"
                if verify_timezone "$tz"; then
                    generate_report "$tz"
                    echo ""
                    read -p "是否同时配置 NTP 同步? (y/N): " ntp
                    [[ "$ntp" =~ ^[Yy]$ ]] && configure_ntp
                fi
                read -n 1 -s -r -p "按任意键返回..."
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# 5. 主程序
# ------------------------------------------------------------------------------

main() {
    check_root
    
    if [ -n "$1" ]; then
        case "$1" in
            --ntp) configure_ntp; exit ;;
            --help|-h) 
                echo "Usage: bash set_timezone.sh [timezone | --ntp | --help]"
                echo "Example: bash set_timezone.sh cn"
                exit 0 ;;
            *)
                local target_tz=$(resolve_alias "$1")
                if validate_timezone "$target_tz"; then
                    backup_configs
                    set_system_timezone "$target_tz"
                    verify_timezone "$target_tz"
                else
                    print_error "无效参数: $1"
                    exit 1
                fi
                ;;
        esac
    else
        interactive_menu
    fi
}

main "$@"
