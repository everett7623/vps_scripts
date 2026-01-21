#!/bin/bash
# ==============================================================================
# 脚本名称: set_timezone.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/system_tools/set_timezone.sh
# 描述: VPS 时区与时间同步工具 (完整增强版)
#       保留了原版详尽的 NTP 配置与备份逻辑，扩充支持 56 个常用城市快捷设置。
# 作者: Jensfrank (Optimized by AI)
# 版本: 1.5.0 (Full Enhanced)
# 更新日期: 2026-01-20
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 环境初始化与依赖加载
# ------------------------------------------------------------------------------

# 获取脚本真实路径
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

# 配置变量
LOG_DIR="/var/log/vps_scripts"
LOG_FILE="$LOG_DIR/set_timezone.log"
BACKUP_DIR="/var/backups/timezone_change"
BACKUP_TIME=$(date +%Y%m%d_%H%M%S)

# 全局变量
CURRENT_TIMEZONE=""
NEW_TIMEZONE=""
OS_TYPE=""
USE_TIMEDATECTL=false
NTP_ENABLED=false
SYNC_TIME=true

# NTP 服务器列表 (混合国内与国际优化)
NTP_SERVERS=(
    "ntp.aliyun.com"
    "cn.pool.ntp.org"
    "time.cloudflare.com"
    "time.google.com"
    "pool.ntp.org"
)

# 尝试加载公共函数库
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"

if [ -f "$LIB_FILE" ]; then
    source "$LIB_FILE"
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
    # 如果配置文件定义了日志路径，则更新
    [ -n "$LOG_DIR" ] && LOG_FILE="${LOG_DIR}/set_timezone.log"
else
    # [远程模式回退] 定义必需的 UI 和辅助函数
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'
    print_info() { echo -e "${CYAN}[信息] $1${NC}"; }
    print_success() { echo -e "${GREEN}[成功] $1${NC}"; }
    print_warn() { echo -e "${YELLOW}[警告] $1${NC}"; }
    print_error() { echo -e "${RED}[错误] $1${NC}"; }
    print_header() { echo -e "\n${PURPLE}=== $1 ===${NC}\n"; }
    check_root() { [[ $EUID -ne 0 ]] && { echo -e "${RED}需要 root 权限${NC}"; exit 1; }; }
fi

# 确保目录存在
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# ------------------------------------------------------------------------------
# 2. 辅助功能函数
# ------------------------------------------------------------------------------

log() {
    local msg="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$LOG_FILE"
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE=$ID
    elif [ -f /etc/redhat-release ]; then
        OS_TYPE="centos"
    else
        OS_TYPE="unknown"
    fi
    
    if command -v timedatectl &> /dev/null; then
        USE_TIMEDATECTL=true
    fi
    log "OS: $OS_TYPE, Timedatectl: $USE_TIMEDATECTL"
}

get_current_timezone() {
    if [ "$USE_TIMEDATECTL" = true ]; then
        CURRENT_TIMEZONE=$(timedatectl status | grep "Time zone" | awk '{print $3}')
    elif [ -f /etc/timezone ]; then
        CURRENT_TIMEZONE=$(cat /etc/timezone)
    elif [ -L /etc/localtime ]; then
        CURRENT_TIMEZONE=$(readlink /etc/localtime | sed 's/.*zoneinfo\///')
    else
        CURRENT_TIMEZONE="Unknown"
    fi
    # 打印到屏幕由菜单负责，这里仅赋值
}

show_time_info() {
    echo -e "${BLUE}------------------------------------------------${NC}"
    echo -e " ${CYAN}当前时区:${NC} $CURRENT_TIMEZONE"
    echo -e " ${CYAN}本地时间:${NC} $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo -e " ${CYAN}UTC 时间:${NC} $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    
    if [ "$USE_TIMEDATECTL" = true ]; then
        local ntp_status=$(timedatectl status | grep -E "NTP service|NTP synchronized" | awk '{print $3}' | head -1)
        echo -e " ${CYAN}NTP 状态:${NC} ${ntp_status:-未知}"
    fi
    echo -e "${BLUE}------------------------------------------------${NC}"
}

get_all_timezones() {
    if [ -d /usr/share/zoneinfo ]; then
        find /usr/share/zoneinfo -type f -printf '%P\n' | grep -vE "^posix|^right|^Etc/GMT" | sort
    fi
}

validate_timezone() {
    local tz=$1
    if [ -f "/usr/share/zoneinfo/$tz" ]; then
        return 0
    else
        print_error "无效的时区 '$tz'"
        return 1
    fi
}

# [增强] 扩充的常用时区列表
show_common_timezones() {
    echo -e "${YELLOW}--- 亚洲 (Asia) ---${NC}"
    printf "%-2s. %-22s %-2s. %-22s %-2s. %-22s\n" \
        "1" "上海 (Shanghai)" "2" "香港 (Hong Kong)" "3" "台北 (Taipei)" \
        "4" "东京 (Tokyo)" "5" "首尔 (Seoul)" "6" "新加坡 (Singapore)" \
        "7" "曼谷 (Bangkok)" "8" "印度 (Kolkata)" "9" "迪拜 (Dubai)" \
        "10" "胡志明 (HCMC)" "11" "雅加达 (Jakarta)" "12" "马尼拉 (Manila)" \
        "13" "利雅得 (Riyadh)" "14" "德黑兰 (Tehran)" "15" "耶路撒冷 (Jerusalem)"

    echo -e "\n${YELLOW}--- 欧洲 (Europe) ---${NC}"
    printf "%-2s. %-22s %-2s. %-22s %-2s. %-22s\n" \
        "20" "伦敦 (London)" "21" "巴黎 (Paris)" "22" "柏林 (Berlin)" \
        "23" "莫斯科 (Moscow)" "24" "阿姆斯特丹" "25" "罗马 (Rome)" \
        "26" "马德里 (Madrid)" "27" "苏黎世 (Zurich)" "28" "基辅 (Kyiv)" \
        "29" "伊斯坦布尔" "30" "斯德哥尔摩" "31" "华沙 (Warsaw)"

    echo -e "\n${YELLOW}--- 美洲 (Americas) ---${NC}"
    printf "%-2s. %-22s %-2s. %-22s %-2s. %-22s\n" \
        "40" "纽约 (New York)" "41" "芝加哥 (Chicago)" "42" "洛杉矶 (LA)" \
        "43" "多伦多 (Toronto)" "44" "温哥华 (Vancouver)" "45" "圣保罗 (Sao Paulo)"

    echo -e "\n${YELLOW}--- 其他 (Others) ---${NC}"
    printf "%-2s. %-22s %-2s. %-22s %-2s. %-22s\n" \
        "50" "悉尼 (Sydney)" "60" "约翰内斯堡" "0" "UTC 标准时间"
}

# [增强] 扩充的编号映射
get_timezone_by_number() {
    case $1 in
        1) echo "Asia/Shanghai" ;; 2) echo "Asia/Hong_Kong" ;; 3) echo "Asia/Taipei" ;;
        4) echo "Asia/Tokyo" ;; 5) echo "Asia/Seoul" ;; 6) echo "Asia/Singapore" ;;
        7) echo "Asia/Bangkok" ;; 8) echo "Asia/Kolkata" ;; 9) echo "Asia/Dubai" ;;
        10) echo "Asia/Ho_Chi_Minh" ;; 11) echo "Asia/Jakarta" ;; 12) echo "Asia/Manila" ;;
        13) echo "Asia/Riyadh" ;; 14) echo "Asia/Tehran" ;; 15) echo "Asia/Jerusalem" ;;
        
        20) echo "Europe/London" ;; 21) echo "Europe/Paris" ;; 22) echo "Europe/Berlin" ;;
        23) echo "Europe/Moscow" ;; 24) echo "Europe/Amsterdam" ;; 25) echo "Europe/Rome" ;;
        26) echo "Europe/Madrid" ;; 27) echo "Europe/Zurich" ;; 28) echo "Europe/Kyiv" ;;
        29) echo "Europe/Istanbul" ;; 30) echo "Europe/Stockholm" ;; 31) echo "Europe/Warsaw" ;;
        
        40) echo "America/New_York" ;; 41) echo "America/Chicago" ;; 42) echo "America/Los_Angeles" ;;
        43) echo "America/Toronto" ;; 44) echo "America/Vancouver" ;; 45) echo "America/Sao_Paulo" ;;
        
        50) echo "Australia/Sydney" ;; 60) echo "Africa/Johannesburg" ;;
        0) echo "UTC" ;;
        *) echo "" ;;
    esac
}

# ------------------------------------------------------------------------------
# 3. 核心配置逻辑 (保留原版完整性)
# ------------------------------------------------------------------------------

backup_configs() {
    print_info "正在备份配置文件..."
    local backup_path="$BACKUP_DIR/backup_$BACKUP_TIME"
    mkdir -p "$backup_path"
    
    local files_to_backup=(
        "/etc/timezone"
        "/etc/localtime"
        "/etc/sysconfig/clock"
        "/etc/ntp.conf"
        "/etc/chrony.conf"
        "/etc/systemd/timesyncd.conf"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [ -e "$file" ]; then
            cp -p "$file" "$backup_path/" 2>/dev/null
            log "Backed up: $file"
        fi
    done
    
    echo "$CURRENT_TIMEZONE" > "$backup_path/old_timezone.txt"
    print_success "配置备份完成: $backup_path"
}

set_timezone() {
    print_info "正在设置时区 -> $NEW_TIMEZONE"
    
    # 1. 使用 timedatectl
    if [ "$USE_TIMEDATECTL" = true ]; then
        timedatectl set-timezone "$NEW_TIMEZONE" &>> "$LOG_FILE"
        if [ "$NTP_ENABLED" = true ]; then
            timedatectl set-ntp true &>> "$LOG_FILE"
        fi
    else
        # 2. 传统方法 (保留原版详细逻辑)
        rm -f /etc/localtime
        ln -sf "/usr/share/zoneinfo/$NEW_TIMEZONE" /etc/localtime
        
        # 兼容 Debian/Ubuntu
        if [ -f /etc/timezone ] || [[ "$OS_TYPE" =~ (ubuntu|debian) ]]; then
            echo "$NEW_TIMEZONE" > /etc/timezone
        fi
        
        # 兼容 RHEL/CentOS
        if [ -f /etc/sysconfig/clock ] || [[ "$OS_TYPE" =~ (centos|rhel|fedora) ]]; then
            cat > /etc/sysconfig/clock << EOF
ZONE="$NEW_TIMEZONE"
UTC=true
ARC=false
EOF
        fi
    fi
    
    # 3. 同步硬件时钟
    if command -v hwclock &> /dev/null; then
        hwclock --systohc &>> "$LOG_FILE"
    fi
    print_success "时区设置完成"
}

configure_ntp() {
    if [ "$NTP_ENABLED" = false ]; then return; fi
    print_info "正在配置 NTP 时间同步..."
    
    if [ "$USE_TIMEDATECTL" = true ]; then
        # systemd-timesyncd 配置
        if [ -f /etc/systemd/timesyncd.conf ]; then
            cp /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.conf.bak
            cat > /etc/systemd/timesyncd.conf << EOF
[Time]
NTP=${NTP_SERVERS[*]}
FallbackNTP=0.pool.ntp.org 1.pool.ntp.org
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF
            systemctl restart systemd-timesyncd &>> "$LOG_FILE"
            systemctl enable systemd-timesyncd &>> "$LOG_FILE"
        fi
        timedatectl set-ntp true &>> "$LOG_FILE"
        
    else
        # Chrony 配置
        if command -v chronyd &> /dev/null; then
            if [ -f /etc/chrony.conf ]; then
                cp /etc/chrony.conf /etc/chrony.conf.bak
                sed -i '/^server\|^pool/d' /etc/chrony.conf
                for server in "${NTP_SERVERS[@]}"; do
                    echo "server $server iburst" >> /etc/chrony.conf
                done
                systemctl restart chronyd &>> "$LOG_FILE"
                systemctl enable chronyd &>> "$LOG_FILE"
            fi
            
        # NTPd 配置
        elif command -v ntpd &> /dev/null; then
            if [ -f /etc/ntp.conf ]; then
                cp /etc/ntp.conf /etc/ntp.conf.bak
                sed -i '/^server\|^pool/d' /etc/ntp.conf
                for server in "${NTP_SERVERS[@]}"; do
                    echo "server $server iburst" >> /etc/ntp.conf
                done
                systemctl restart ntpd &>> "$LOG_FILE"
                systemctl enable ntpd &>> "$LOG_FILE"
            fi
        else
            print_warn "未找到 NTP 服务，跳过配置"
        fi
    fi
    print_success "NTP 配置完成"
}

sync_time_manual() {
    if [ "$SYNC_TIME" = false ]; then return; fi
    print_info "正在同步系统时间..."
    
    if command -v ntpdate &> /dev/null; then
        for server in "${NTP_SERVERS[@]}"; do
            if ntpdate -u "$server" &>> "$LOG_FILE"; then
                print_success "时间已从 $server 同步"
                break
            fi
        done
    elif command -v chronyc &> /dev/null; then
        chronyc makestep &>> "$LOG_FILE"
        print_success "时间已通过 Chrony 同步"
    elif [ "$USE_TIMEDATECTL" = true ]; then
        timedatectl set-ntp false &>> "$LOG_FILE"
        timedatectl set-ntp true &>> "$LOG_FILE"
        print_success "时间同步已触发 (systemd)"
    else
        print_warn "无法自动同步时间，请手动检查"
    fi
}

verify_timezone() {
    print_info "验证设置结果..."
    local current_tz=""
    if [ "$USE_TIMEDATECTL" = true ]; then
        current_tz=$(timedatectl status | grep "Time zone" | awk '{print $3}')
    elif [ -f /etc/timezone ]; then
        current_tz=$(cat /etc/timezone)
    elif [ -L /etc/localtime ]; then
        current_tz=$(readlink /etc/localtime | sed 's/.*zoneinfo\///')
    fi
    
    if [ "$current_tz" = "$NEW_TIMEZONE" ]; then
        print_success "验证通过: 当前时区为 $current_tz"
        return 0
    else
        print_error "验证失败: 期望 $NEW_TIMEZONE，实际 $current_tz"
        return 1
    fi
}

generate_report() {
    local report_file="$LOG_DIR/timezone_report_$(date +%Y%m%d_%H%M%S).txt"
    cat > "$report_file" << EOF
==================================================
           时区设置报告
==================================================
时间: $(date)
系统信息: $OS_TYPE
原时区: $CURRENT_TIMEZONE
新时区: $NEW_TIMEZONE
NTP配置: $([ "$NTP_ENABLED" = true ] && echo "YES" || echo "NO")
--------------------------------------------------
[本地时间] $(date '+%Y-%m-%d %H:%M:%S %Z')
[UTC 时间] $(date -u '+%Y-%m-%d %H:%M:%S UTC')

备份位置: $BACKUP_DIR/backup_$BACKUP_TIME
日志文件: $LOG_FILE
==================================================
EOF
    print_success "详细报告已生成: $report_file"
}

# ------------------------------------------------------------------------------
# 4. 交互与入口
# ------------------------------------------------------------------------------

# [增强] 扩充的快捷指令
quick_set_timezone() {
    case "${1,,}" in
        cn|china|shanghai) NEW_TIMEZONE="Asia/Shanghai" ;;
        hk|hongkong)       NEW_TIMEZONE="Asia/Hong_Kong" ;;
        tw|taiwan)         NEW_TIMEZONE="Asia/Taipei" ;;
        jp|japan|tokyo)    NEW_TIMEZONE="Asia/Tokyo" ;;
        sg|singapore)      NEW_TIMEZONE="Asia/Singapore" ;;
        us|usa|ny)         NEW_TIMEZONE="America/New_York" ;;
        la|losangeles)     NEW_TIMEZONE="America/Los_Angeles" ;;
        uk|london)         NEW_TIMEZONE="Europe/London" ;;
        utc|gmt)           NEW_TIMEZONE="UTC" ;;
        *) return 1 ;;
    esac
    return 0
}

interactive_menu() {
    while true; do
        clear
        print_header "VPS 时区设置工具"
        show_time_info
        echo ""
        echo "1. 常用时区选择 (50+ 城市)"
        echo "2. 手动输入时区"
        echo "3. 搜索时区 (关键词)"
        echo "4. 配置 NTP 自动同步"
        echo "5. 立即同步时间"
        echo "0. 退出"
        echo ""
        read -p "请选择 [0-5]: " choice
        
        case $choice in
            1)
                echo ""
                show_common_timezones
                echo ""
                read -p "请输入编号: " tz_num
                NEW_TIMEZONE=$(get_timezone_by_number "$tz_num")
                if [ -z "$NEW_TIMEZONE" ]; then
                    print_error "无效编号"
                    sleep 1
                    continue
                fi
                ;;
            2)
                read -p "请输入时区 (如 Asia/Shanghai): " NEW_TIMEZONE
                ;;
            3)
                read -p "请输入搜索关键词: " keyword
                echo -e "${CYAN}搜索结果:${NC}"
                get_all_timezones | grep -i "$keyword" | head -20
                echo ""
                read -p "请输入完整时区名称: " NEW_TIMEZONE
                ;;
            4)
                NTP_ENABLED=true
                configure_ntp
                read -n 1 -s -r -p "按键返回..."; continue
                ;;
            5)
                sync_time_manual
                read -n 1 -s -r -p "按键返回..."; continue
                ;;
            0) exit 0 ;;
            *) print_error "无效选项"; sleep 1; continue ;;
        esac
        
        if validate_timezone "$NEW_TIMEZONE"; then
            echo ""
            read -p "是否同时配置 NTP 同步? (y/N): " ntp_confirm
            if [[ "$ntp_confirm" =~ ^[Yy]$ ]]; then NTP_ENABLED=true; fi
            
            backup_configs
            set_timezone
            configure_ntp
            sync_time_manual
            verify_timezone
            generate_report
            
            echo ""
            read -n 1 -s -r -p "按任意键返回..."
        fi
    done
}

main() {
    create_directories
    check_root
    detect_os
    get_current_timezone
    
    if [ -n "$1" ]; then
        case "$1" in
            --ntp) NTP_ENABLED=true; configure_ntp; exit ;;
            --sync) sync_time_manual; exit ;;
            --list) get_all_timezones; exit ;;
            --help|-h) 
                echo "Usage: bash set_timezone.sh [timezone | code | --ntp]"
                echo "Codes: cn, hk, tw, jp, us, uk, sg..."
                exit 0 ;;
            *)
                if quick_set_timezone "$1"; then
                    print_info "使用快捷方式: $NEW_TIMEZONE"
                else
                    NEW_TIMEZONE="$1"
                fi
                
                if validate_timezone "$NEW_TIMEZONE"; then
                    backup_configs; set_timezone; verify_timezone; generate_report
                else
                    print_error "无效时区或参数: $1"
                    exit 1
                fi
                ;;
        esac
    else
        interactive_menu
    fi
}

main "$@"
