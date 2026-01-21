#!/bin/bash

#==============================================================================
# 脚本名称: set_timezone.sh
# 描述: VPS时区设置脚本 - 安全设置系统时区、同步时间、配置NTP
# 作者: Jensfrank
# 路径: vps_scripts/scripts/system_tools/set_timezone.sh
# 使用方法: bash set_timezone.sh [时区|选项]
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

# 配置变量
LOG_DIR="/var/log/vps_scripts"
LOG_FILE="$LOG_DIR/set_timezone_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/var/backups/timezone_change"
BACKUP_TIME=$(date +%Y%m%d_%H%M%S)

# 全局变量
CURRENT_TIMEZONE=""
NEW_TIMEZONE=""
OS_TYPE=""
OS_VERSION=""
USE_TIMEDATECTL=false
NTP_ENABLED=false
SYNC_TIME=true

# NTP服务器列表
NTP_SERVERS=(
    "ntp.aliyun.com"
    "cn.pool.ntp.org"
    "time.cloudflare.com"
    "time.google.com"
    "pool.ntp.org"
)

# 创建必要目录
create_directories() {
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    [ ! -d "$BACKUP_DIR" ] && mkdir -p "$BACKUP_DIR"
}

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
    local level=$1
    shift
    local message="$@"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# 打印带颜色的消息
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
    log "INFO" "$msg"
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS_TYPE="centos"
        OS_VERSION=$(rpm -q --queryformat '%{VERSION}' centos-release)
    else
        OS_TYPE="unknown"
    fi
    
    # 检查是否有timedatectl命令
    if command -v timedatectl &> /dev/null; then
        USE_TIMEDATECTL=true
    fi
    
    print_msg "$GREEN" "检测到系统: $OS_TYPE $OS_VERSION"
}

# 获取当前时区
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
    
    print_msg "$CYAN" "当前时区: $CURRENT_TIMEZONE"
}

# 显示时间信息
show_time_info() {
    echo -e "${PURPLE}════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}系统时间信息:${NC}"
    echo -e "  当前时区: $CURRENT_TIMEZONE"
    echo -e "  本地时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo -e "  UTC时间: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo -e "  时区偏移: $(date '+%z')"
    
    if [ "$USE_TIMEDATECTL" = true ]; then
        local ntp_status=$(timedatectl status | grep "NTP synchronized" | awk '{print $3}')
        echo -e "  NTP同步: ${ntp_status:-未知}"
    fi
    
    # 显示硬件时钟
    if command -v hwclock &> /dev/null; then
        echo -e "  硬件时钟: $(hwclock -r 2>/dev/null || echo '无法读取')"
    fi
    
    echo -e "${PURPLE}════════════════════════════════════════════════════════${NC}"
}

# 获取所有可用时区
get_all_timezones() {
    local timezones=()
    
    if [ -d /usr/share/zoneinfo ]; then
        # 获取所有时区文件
        while IFS= read -r tz; do
            # 排除一些特殊文件
            if [[ ! "$tz" =~ (posix|right|Etc/GMT) ]] && [ -f "/usr/share/zoneinfo/$tz" ]; then
                timezones+=("$tz")
            fi
        done < <(find /usr/share/zoneinfo -type f -printf '%P\n' | sort)
    fi
    
    printf '%s\n' "${timezones[@]}"
}

# 验证时区
validate_timezone() {
    local tz=$1
    
    # 检查时区文件是否存在
    if [ -f "/usr/share/zoneinfo/$tz" ]; then
        return 0
    else
        print_msg "$RED" "错误: 无效的时区 '$tz'"
        return 1
    fi
}

# 显示常用时区
show_common_timezones() {
    echo -e "${CYAN}常用时区:${NC}"
    echo ""
    echo -e "${GREEN}亚洲地区:${NC}"
    echo "  1) Asia/Shanghai     (中国上海 UTC+8)"
    echo "  2) Asia/Hong_Kong    (中国香港 UTC+8)"
    echo "  3) Asia/Tokyo        (日本东京 UTC+9)"
    echo "  4) Asia/Singapore    (新加坡 UTC+8)"
    echo "  5) Asia/Seoul        (韩国首尔 UTC+9)"
    echo "  6) Asia/Bangkok      (泰国曼谷 UTC+7)"
    echo "  7) Asia/Dubai        (阿联酋迪拜 UTC+4)"
    echo "  8) Asia/Kolkata      (印度加尔各答 UTC+5:30)"
    echo ""
    echo -e "${GREEN}欧洲地区:${NC}"
    echo "  9) Europe/London     (英国伦敦 UTC+0/+1)"
    echo " 10) Europe/Paris      (法国巴黎 UTC+1/+2)"
    echo " 11) Europe/Berlin     (德国柏林 UTC+1/+2)"
    echo " 12) Europe/Moscow     (俄罗斯莫斯科 UTC+3)"
    echo " 13) Europe/Amsterdam  (荷兰阿姆斯特丹 UTC+1/+2)"
    echo ""
    echo -e "${GREEN}美洲地区:${NC}"
    echo " 14) America/New_York  (美国纽约 UTC-5/-4)"
    echo " 15) America/Chicago   (美国芝加哥 UTC-6/-5)"
    echo " 16) America/Los_Angeles (美国洛杉矶 UTC-8/-7)"
    echo " 17) America/Toronto   (加拿大多伦多 UTC-5/-4)"
    echo " 18) America/Sao_Paulo (巴西圣保罗 UTC-3)"
    echo ""
    echo -e "${GREEN}其他地区:${NC}"
    echo " 19) Australia/Sydney  (澳大利亚悉尼 UTC+10/+11)"
    echo " 20) Pacific/Auckland  (新西兰奥克兰 UTC+12/+13)"
    echo " 21) UTC              (协调世界时 UTC+0)"
    echo ""
}

# 根据编号获取时区
get_timezone_by_number() {
    local num=$1
    
    case $num in
        1) echo "Asia/Shanghai" ;;
        2) echo "Asia/Hong_Kong" ;;
        3) echo "Asia/Tokyo" ;;
        4) echo "Asia/Singapore" ;;
        5) echo "Asia/Seoul" ;;
        6) echo "Asia/Bangkok" ;;
        7) echo "Asia/Dubai" ;;
        8) echo "Asia/Kolkata" ;;
        9) echo "Europe/London" ;;
        10) echo "Europe/Paris" ;;
        11) echo "Europe/Berlin" ;;
        12) echo "Europe/Moscow" ;;
        13) echo "Europe/Amsterdam" ;;
        14) echo "America/New_York" ;;
        15) echo "America/Chicago" ;;
        16) echo "America/Los_Angeles" ;;
        17) echo "America/Toronto" ;;
        18) echo "America/Sao_Paulo" ;;
        19) echo "Australia/Sydney" ;;
        20) echo "Pacific/Auckland" ;;
        21) echo "UTC" ;;
        *) echo "" ;;
    esac
}

# 备份配置文件
backup_configs() {
    print_msg "$BLUE" "备份配置文件..."
    
    local backup_path="$BACKUP_DIR/backup_$BACKUP_TIME"
    mkdir -p "$backup_path"
    
    # 备份相关文件
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
            log "INFO" "备份文件: $file"
        fi
    done
    
    # 保存当前时区信息
    echo "$CURRENT_TIMEZONE" > "$backup_path/old_timezone.txt"
    
    print_msg "$GREEN" "配置备份完成: $backup_path"
}

# 设置时区
set_timezone() {
    print_msg "$BLUE" "\n开始设置时区..."
    
    # 1. 使用timedatectl（如果可用）
    if [ "$USE_TIMEDATECTL" = true ]; then
        print_msg "$CYAN" "使用timedatectl设置时区..."
        timedatectl set-timezone "$NEW_TIMEZONE" &>> "$LOG_FILE"
        
        # 确保NTP同步
        if [ "$NTP_ENABLED" = true ]; then
            timedatectl set-ntp true &>> "$LOG_FILE"
        fi
    else
        # 2. 传统方法设置时区
        print_msg "$CYAN" "使用传统方法设置时区..."
        
        # 创建localtime链接
        rm -f /etc/localtime
        ln -sf "/usr/share/zoneinfo/$NEW_TIMEZONE" /etc/localtime
        
        # 更新/etc/timezone（Debian/Ubuntu）
        if [ -f /etc/timezone ] || [ "$OS_TYPE" = "ubuntu" ] || [ "$OS_TYPE" = "debian" ]; then
            echo "$NEW_TIMEZONE" > /etc/timezone
        fi
        
        # 更新/etc/sysconfig/clock（RHEL/CentOS）
        if [ -f /etc/sysconfig/clock ] || [[ "$OS_TYPE" =~ ^(centos|rhel|fedora)$ ]]; then
            cat > /etc/sysconfig/clock << EOF
ZONE="$NEW_TIMEZONE"
UTC=true
ARC=false
EOF
        fi
    fi
    
    # 3. 同步硬件时钟
    if command -v hwclock &> /dev/null; then
        print_msg "$CYAN" "同步硬件时钟..."
        hwclock --systohc &>> "$LOG_FILE"
    fi
    
    print_msg "$GREEN" "时区设置完成"
}

# 配置NTP
configure_ntp() {
    if [ "$NTP_ENABLED" = false ]; then
        return
    fi
    
    print_msg "$BLUE" "\n配置NTP时间同步..."
    
    # 根据系统选择NTP服务
    if [ "$USE_TIMEDATECTL" = true ]; then
        # 使用systemd-timesyncd
        if [ -f /etc/systemd/timesyncd.conf ]; then
            print_msg "$CYAN" "配置systemd-timesyncd..."
            
            # 备份原配置
            cp /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.conf.bak
            
            # 配置NTP服务器
            cat > /etc/systemd/timesyncd.conf << EOF
[Time]
NTP=${NTP_SERVERS[*]}
FallbackNTP=0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF
            
            # 重启服务
            systemctl restart systemd-timesyncd &>> "$LOG_FILE"
            systemctl enable systemd-timesyncd &>> "$LOG_FILE"
        fi
        
        # 启用NTP
        timedatectl set-ntp true &>> "$LOG_FILE"
        
    else
        # 使用ntpd或chrony
        if command -v chronyd &> /dev/null; then
            print_msg "$CYAN" "配置chrony..."
            
            if [ -f /etc/chrony.conf ]; then
                cp /etc/chrony.conf /etc/chrony.conf.bak
                
                # 清除旧的服务器配置
                sed -i '/^server\|^pool/d' /etc/chrony.conf
                
                # 添加新的NTP服务器
                for server in "${NTP_SERVERS[@]}"; do
                    echo "server $server iburst" >> /etc/chrony.conf
                done
                
                systemctl restart chronyd &>> "$LOG_FILE"
                systemctl enable chronyd &>> "$LOG_FILE"
            fi
            
        elif command -v ntpd &> /dev/null; then
            print_msg "$CYAN" "配置ntpd..."
            
            if [ -f /etc/ntp.conf ]; then
                cp /etc/ntp.conf /etc/ntp.conf.bak
                
                # 清除旧的服务器配置
                sed -i '/^server\|^pool/d' /etc/ntp.conf
                
                # 添加新的NTP服务器
                for server in "${NTP_SERVERS[@]}"; do
                    echo "server $server iburst" >> /etc/ntp.conf
                done
                
                systemctl restart ntpd &>> "$LOG_FILE"
                systemctl enable ntpd &>> "$LOG_FILE"
            fi
        else
            print_msg "$YELLOW" "未找到NTP服务，跳过配置"
        fi
    fi
    
    print_msg "$GREEN" "NTP配置完成"
}

# 手动同步时间
sync_time_manual() {
    if [ "$SYNC_TIME" = false ]; then
        return
    fi
    
    print_msg "$BLUE" "\n同步系统时间..."
    
    # 尝试不同的时间同步方法
    if command -v ntpdate &> /dev/null; then
        for server in "${NTP_SERVERS[@]}"; do
            if ntpdate -u "$server" &>> "$LOG_FILE"; then
                print_msg "$GREEN" "时间已从 $server 同步"
                break
            fi
        done
    elif command -v chronyd &> /dev/null; then
        chronyc makestep &>> "$LOG_FILE"
        print_msg "$GREEN" "时间已通过chrony同步"
    elif [ "$USE_TIMEDATECTL" = true ]; then
        # 强制同步
        timedatectl set-ntp false &>> "$LOG_FILE"
        timedatectl set-ntp true &>> "$LOG_FILE"
        print_msg "$GREEN" "时间同步已触发"
    else
        print_msg "$YELLOW" "无法自动同步时间，请手动检查"
    fi
}

# 验证时区设置
verify_timezone() {
    print_msg "$BLUE" "\n验证时区设置..."
    
    local current_tz=""
    
    # 获取当前时区
    if [ "$USE_TIMEDATECTL" = true ]; then
        current_tz=$(timedatectl status | grep "Time zone" | awk '{print $3}')
    elif [ -f /etc/timezone ]; then
        current_tz=$(cat /etc/timezone)
    elif [ -L /etc/localtime ]; then
        current_tz=$(readlink /etc/localtime | sed 's/.*zoneinfo\///')
    fi
    
    if [ "$current_tz" = "$NEW_TIMEZONE" ]; then
        print_msg "$GREEN" "时区设置验证成功"
        return 0
    else
        print_msg "$RED" "时区设置验证失败"
        print_msg "$YELLOW" "期望: $NEW_TIMEZONE, 实际: $current_tz"
        return 1
    fi
}

# 生成设置报告
generate_report() {
    local report_file="$LOG_DIR/timezone_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
================================================================================
                          时区设置报告
================================================================================
设置时间: $(date '+%Y-%m-%d %H:%M:%S')
系统信息: $OS_TYPE $OS_VERSION
原时区: $CURRENT_TIMEZONE
新时区: $NEW_TIMEZONE
--------------------------------------------------------------------------------

设置详情:
✓ 时区文件更新
$([ "$USE_TIMEDATECTL" = true ] && echo "✓ timedatectl配置")
$([ -f /etc/timezone ] && echo "✓ /etc/timezone更新")
$([ -f /etc/sysconfig/clock ] && echo "✓ /etc/sysconfig/clock更新")
$([ "$NTP_ENABLED" = true ] && echo "✓ NTP服务配置")
✓ 硬件时钟同步

当前时间:
本地时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
UTC时间: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

备份位置: $BACKUP_DIR/backup_$BACKUP_TIME
日志文件: $LOG_FILE

================================================================================
EOF
    
    print_msg "$GREEN" "\n设置报告已生成: $report_file"
}

# 交互式菜单
interactive_menu() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                          VPS 时区设置工具 v1.0                             ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 显示当前时间信息
    show_time_info
    
    echo ""
    echo -e "${CYAN}请选择操作:${NC}"
    echo -e "${GREEN}1)${NC} 选择常用时区"
    echo -e "${GREEN}2)${NC} 手动输入时区"
    echo -e "${GREEN}3)${NC} 搜索时区"
    echo -e "${GREEN}4)${NC} 配置NTP时间同步"
    echo -e "${GREEN}5)${NC} 立即同步时间"
    echo -e "${GREEN}0)${NC} 退出"
    echo ""
    
    read -p "请输入选项 [0-5]: " choice
    
    case $choice in
        1)
            echo ""
            show_common_timezones
            echo ""
            read -p "请输入时区编号 (1-21) 或直接输入时区名称: " tz_input
            
            # 判断是数字还是时区名称
            if [[ "$tz_input" =~ ^[0-9]+$ ]]; then
                NEW_TIMEZONE=$(get_timezone_by_number "$tz_input")
                if [ -z "$NEW_TIMEZONE" ]; then
                    print_msg "$RED" "无效的编号"
                    sleep 2
                    interactive_menu
                    return
                fi
            else
                NEW_TIMEZONE="$tz_input"
            fi
            ;;
        2)
            echo ""
            read -p "请输入时区名称 (如 Asia/Shanghai): " NEW_TIMEZONE
            ;;
        3)
            echo ""
            read -p "请输入搜索关键词: " keyword
            echo ""
            echo -e "${CYAN}搜索结果:${NC}"
            get_all_timezones | grep -i "$keyword" | head -20
            echo ""
            read -p "请输入完整的时区名称: " NEW_TIMEZONE
            ;;
        4)
            NTP_ENABLED=true
            configure_ntp
            echo ""
            read -p "按回车键继续..."
            interactive_menu
            return
            ;;
        5)
            sync_time_manual
            echo ""
            read -p "按回车键继续..."
            interactive_menu
            return
            ;;
        0)
            print_msg "$YELLOW" "退出程序"
            exit 0
            ;;
        *)
            print_msg "$RED" "无效选项"
            sleep 2
            interactive_menu
            return
            ;;
    esac
    
    # 验证时区
    if ! validate_timezone "$NEW_TIMEZONE"; then
        sleep 2
        interactive_menu
        return
    fi
    
    # 确认设置
    echo ""
    echo -e "${YELLOW}确认设置:${NC}"
    echo -e "  当前时区: $CURRENT_TIMEZONE"
    echo -e "  新时区: $NEW_TIMEZONE"
    echo ""
    read -p "是否同时配置NTP时间同步？(Y/n): " ntp_confirm
    if [[ ! "$ntp_confirm" =~ ^[Nn]$ ]]; then
        NTP_ENABLED=true
    fi
    
    echo ""
    read -p "确认修改时区？(y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_msg "$YELLOW" "操作已取消"
        exit 0
    fi
}

# 快速设置常用时区
quick_set_timezone() {
    local quick_tz=$1
    
    case "$quick_tz" in
        cn|china|shanghai)
            NEW_TIMEZONE="Asia/Shanghai"
            ;;
        hk|hongkong)
            NEW_TIMEZONE="Asia/Hong_Kong"
            ;;
        jp|japan|tokyo)
            NEW_TIMEZONE="Asia/Tokyo"
            ;;
        sg|singapore)
            NEW_TIMEZONE="Asia/Singapore"
            ;;
        us|usa|newyork|ny)
            NEW_TIMEZONE="America/New_York"
            ;;
        la|losangeles)
            NEW_TIMEZONE="America/Los_Angeles"
            ;;
        uk|london)
            NEW_TIMEZONE="Europe/London"
            ;;
        utc|gmt)
            NEW_TIMEZONE="UTC"
            ;;
        *)
            return 1
            ;;
    esac
    
    return 0
}

# 显示帮助信息
show_help() {
    cat << EOF
使用方法: $0 [选项] [时区]

选项:
  时区            设置指定的时区（如 Asia/Shanghai）
  --list          列出所有可用时区
  --common        显示常用时区
  --ntp           配置NTP时间同步
  --sync          立即同步系统时间
  --info          显示当前时间信息
  --help, -h      显示此帮助信息

快捷时区:
  cn, china       中国上海 (Asia/Shanghai)
  hk, hongkong    中国香港 (Asia/Hong_Kong)
  jp, japan       日本东京 (Asia/Tokyo)
  sg, singapore   新加坡 (Asia/Singapore)
  us, usa, ny     美国纽约 (America/New_York)
  la              美国洛杉矶 (America/Los_Angeles)
  uk, london      英国伦敦 (Europe/London)
  utc, gmt        协调世界时 (UTC)

示例:
  $0                      # 交互式设置
  $0 Asia/Shanghai        # 设置为上海时区
  $0 cn                   # 快速设置为中国时区
  $0 --ntp                # 配置NTP时间同步
  $0 --list | grep Asia   # 查找亚洲时区

注意:
  - 此脚本需要root权限运行
  - 设置前会自动备份相关配置
  - 建议同时配置NTP以保持时间准确
EOF
}

# 主函数
main() {
    # 初始化
    create_directories
    check_root
    detect_os
    get_current_timezone
    
    # 解析参数
    if [ $# -eq 0 ]; then
        # 无参数，进入交互模式
        interactive_menu
    else
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --list)
                get_all_timezones
                exit 0
                ;;
            --common)
                show_common_timezones
                exit 0
                ;;
            --ntp)
                NTP_ENABLED=true
                configure_ntp
                exit 0
                ;;
            --sync)
                sync_time_manual
                exit 0
                ;;
            --info)
                show_time_info
                exit 0
                ;;
            -*)
                print_msg "$RED" "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                # 尝试快速设置
                if quick_set_timezone "$1"; then
                    print_msg "$CYAN" "使用快捷方式设置时区: $NEW_TIMEZONE"
                else
                    NEW_TIMEZONE="$1"
                fi
                
                # 验证时区
                if ! validate_timezone "$NEW_TIMEZONE"; then
                    exit 1
                fi
                ;;
        esac
    fi
    
    # 开始设置流程
    log "INFO" "开始设置时区: $CURRENT_TIMEZONE -> $NEW_TIMEZONE"
    
    backup_configs
    set_timezone
    
    if [ "$NTP_ENABLED" = true ]; then
        configure_ntp
    fi
    
    sync_time_manual
    
    # 验证设置结果
    if verify_timezone; then
        generate_report
        echo ""
        show_time_info
        echo ""
        print_msg "$GREEN" "时区设置成功！"
        
        if [ "$NTP_ENABLED" = true ]; then
            print_msg "$GREEN" "NTP时间同步已配置"
        fi
    else
        print_msg "$RED" "时区设置可能未完全成功，请检查日志: $LOG_FILE"
        exit 1
    fi
}

# 运行主函数
main "$@"
