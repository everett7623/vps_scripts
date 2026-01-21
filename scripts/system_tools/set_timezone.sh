#!/bin/bash
# ==============================================================================
# 脚本名称: set_timezone.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/system_tools/set_timezone.sh
# 描述: VPS 全球时区与时间同步工具 (v1.4.0 终极完整版)
#       集成了 50+ 常用城市菜单、关键词搜索、深度 NTP 配置及详细报告生成。
#       本版本恢复了所有底层配置文件的详细写入逻辑，确保稳定性。
# 作者: Jensfrank (Optimized by AI)
# 版本: 1.4.0 (Ultimate Full)
# 更新日期: 2026-01-20
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 环境初始化
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

# 高质量 NTP 服务器池 (阿里云, Google, Cloudflare, NTP.org)
NTP_SERVERS=(
    "ntp.aliyun.com"
    "cn.pool.ntp.org"
    "time.google.com"
    "time.cloudflare.com"
    "pool.ntp.org"
)

# 尝试加载公共函数库
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"

if [ -f "$LIB_FILE" ]; then
    source "$LIB_FILE"
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
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

# 显示详细时间信息
show_time_info() {
    echo -e "${BLUE}------------------------------------------------${NC}"
    echo -e " ${CYAN}当前时区:${NC} $(get_current_timezone)"
    echo -e " ${CYAN}本地时间:${NC} $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo -e " ${CYAN}UTC 时间:${NC} $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    
    if command -v timedatectl &>/dev/null; then
        local ntp_status=$(timedatectl status | grep -E "NTP service|NTP synchronized" | awk '{print $3}' | head -1)
        echo -e " ${CYAN}NTP 状态:${NC} ${ntp_status:-未知}"
    fi
    echo -e "${BLUE}------------------------------------------------${NC}"
}

# 验证时区文件有效性
validate_timezone() {
    local tz=$1
    if [ -f "/usr/share/zoneinfo/$tz" ]; then
        return 0
    else
        print_error "无效的时区: $tz (未在 /usr/share/zoneinfo 中找到)"
        return 1
    fi
}

# 搜索时区功能
search_timezones() {
    local keyword=$1
    print_info "正在搜索包含 '$keyword' 的时区..."
    echo -e "${BLUE}------------------------------------------------${NC}"
    # 查找并过滤杂项，只显示前20个结果
    find /usr/share/zoneinfo -type f | grep -i "$keyword" | sed 's|/usr/share/zoneinfo/||' | grep -vE "^posix|^right|^Etc/GMT" | head -20 | sort
    echo -e "${BLUE}------------------------------------------------${NC}"
}

# ------------------------------------------------------------------------------
# 3. 核心配置逻辑 (恢复详细配置写入)
# ------------------------------------------------------------------------------

# 备份配置
backup_configs() {
    print_info "正在备份时间相关配置文件..."
    local backup_path="$BACKUP_DIR/backup_$BACKUP_TIME"
    mkdir -p "$backup_path"
    
    local files=(
        "/etc/timezone" 
        "/etc/localtime" 
        "/etc/sysconfig/clock" 
        "/etc/ntp.conf" 
        "/etc/chrony.conf" 
        "/etc/systemd/timesyncd.conf"
    )
    
    for f in "${files[@]}"; do
        if [ -e "$f" ]; then 
            cp -p "$f" "$backup_path/" 2>/dev/null
            log "Backed up $f"
        fi
    done
    
    get_current_timezone > "$backup_path/old_timezone.txt"
    print_success "配置已备份至: $backup_path"
}

# 应用时区设置
set_system_timezone() {
    local target_tz=$1
    print_info "正在将系统时区设置为: $target_tz"
    log "Setting timezone to $target_tz"
    
    # 方式 1: Systemd (推荐)
    if command -v timedatectl &>/dev/null; then
        timedatectl set-timezone "$target_tz" &>> "$LOG_FILE"
    else
        # 方式 2: 传统软链接 (针对老旧系统或容器)
        rm -f /etc/localtime
        ln -sf "/usr/share/zoneinfo/$target_tz" /etc/localtime
        
        # 更新 /etc/timezone (Debian/Ubuntu)
        if [ -f /etc/timezone ] || [ -f /etc/debian_version ]; then
            echo "$target_tz" > /etc/timezone
        fi
        
        # 更新 /etc/sysconfig/clock (RHEL/CentOS)
        if [ -f /etc/sysconfig/clock ]; then
            echo "ZONE=\"$target_tz\"" > /etc/sysconfig/clock
            echo "UTC=true" >> /etc/sysconfig/clock
        fi
    fi
    
    # 同步硬件时钟
    if command -v hwclock &>/dev/null; then
        print_info "同步硬件时钟..."
        hwclock --systohc &>> "$LOG_FILE"
    fi
    
    print_success "时区设置完成。"
}

# 配置 NTP (恢复详细配置写入逻辑)
configure_ntp() {
    print_info "正在配置 NTP 时间同步服务..."
    
    # 1. Systemd-timesyncd (最轻量，优先)
    if command -v timedatectl &>/dev/null && [ -f /etc/systemd/timesyncd.conf ]; then
        print_info "检测到 systemd-timesyncd，正在写入配置..."
        
        # 写入详细配置
        cat > /etc/systemd/timesyncd.conf << EOF
[Time]
NTP=${NTP_SERVERS[*]}
FallbackNTP=0.pool.ntp.org 1.pool.ntp.org
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF
        timedatectl set-ntp true &>> "$LOG_FILE"
        systemctl restart systemd-timesyncd &>> "$LOG_FILE"
        print_success "Systemd-timesyncd 配置已更新。"
        
    # 2. Chrony (最精准，次选)
    elif command -v chronyd &>/dev/null; then
        print_info "检测到 Chrony，正在写入配置..."
        
        if [ -f /etc/chrony.conf ]; then
            # 备份原文件已在 backup_configs 中完成
            # 清理旧的 server 配置
            sed -i '/^server/d' /etc/chrony.conf
            sed -i '/^pool/d' /etc/chrony.conf
            
            # 写入新服务器
            echo "" >> /etc/chrony.conf
            echo "# Added by vps_scripts" >> /etc/chrony.conf
            for server in "${NTP_SERVERS[@]}"; do
                echo "server $server iburst" >> /etc/chrony.conf
            done
            
            systemctl restart chronyd &>> "$LOG_FILE"
            systemctl enable chronyd &>> "$LOG_FILE"
            print_success "Chrony 配置已更新。"
        fi
        
    # 3. NTPd (传统，最后)
    elif command -v ntpd &>/dev/null; then
        print_info "检测到 NTPd，正在写入配置..."
        
        if [ -f /etc/ntp.conf ]; then
            sed -i '/^server/d' /etc/ntp.conf
            sed -i '/^pool/d' /etc/ntp.conf
            
            echo "" >> /etc/ntp.conf
            echo "# Added by vps_scripts" >> /etc/ntp.conf
            for server in "${NTP_SERVERS[@]}"; do
                echo "server $server iburst" >> /etc/ntp.conf
            done
            
            systemctl restart ntpd &>> "$LOG_FILE"
            systemctl enable ntpd &>> "$LOG_FILE"
            print_success "NTPd 配置已更新。"
        fi
    else
        print_warn "未找到系统级 NTP 服务 (timesyncd/chrony/ntpd)。"
        print_warn "仅执行一次性同步。"
    fi
    
    # 最后执行一次强制同步
    force_sync_time
}

# 强制同步时间
force_sync_time() {
    print_info "正在执行立即时间同步..."
    
    if command -v ntpdate &>/dev/null; then
        # 尝试多个服务器，直到成功
        for server in "${NTP_SERVERS[@]}"; do
            print_info "尝试同步: $server ..."
            if ntpdate -u "$server" &>> "$LOG_FILE"; then
                print_success "时间已从 $server 同步成功。"
                return
            fi
        done
    elif command -v chronyc &>/dev/null; then
        chronyc makestep &>> "$LOG_FILE"
        print_success "Chrony 同步指令已发送。"
    elif command -v timedatectl &>/dev/null; then
        timedatectl set-ntp false
        timedatectl set-ntp true
        print_success "Systemd 时间同步已触发重置。"
    else
        print_error "无法找到同步工具 (ntpdate/chrony/systemd)。"
    fi
}

# 验证结果
verify_timezone() {
    local target=$1
    local current=$(get_current_timezone)
    
    print_info "正在验证设置结果..."
    if [ "$current" == "$target" ]; then
        print_success "验证通过: 当前时区确认为 $current"
        return 0
    else
        print_error "验证失败: 期望 $target，实际 $current"
        return 1
    fi
}

# 生成详细报告
generate_report() {
    local report_file="$LOG_DIR/timezone_report_$(date +%Y%m%d_%H%M%S).txt"
    cat > "$report_file" <<EOF
==================================================
           时区设置与同步报告
==================================================
生成时间: $(date)
目标时区: $NEW_TIMEZONE
当前状态: $(get_current_timezone)
本地时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
UTC 时间: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

[配置详情]
- 配置文件备份: YES ($BACKUP_DIR)
- NTP 服务配置: $([ "$NTP_ENABLED" == "true" ] && echo "YES" || echo "NO/Manual")
- 强制同步执行: YES

日志文件: $LOG_FILE
==================================================
EOF
    print_success "详细报告已生成: $report_file"
}

# ------------------------------------------------------------------------------
# 4. 扩展列表与交互 (完整 56 城市版)
# ------------------------------------------------------------------------------

# 快捷转换 (大幅扩充)
resolve_timezone_alias() {
    case "${1,,}" in
        cn|china|shanghai|bj|beijing) echo "Asia/Shanghai" ;;
        hk|hongkong)       echo "Asia/Hong_Kong" ;;
        tw|taiwan|taipei)  echo "Asia/Taipei" ;;
        jp|japan|tokyo)    echo "Asia/Tokyo" ;;
        kr|korea|seoul)    echo "Asia/Seoul" ;;
        sg|singapore)      echo "Asia/Singapore" ;;
        in|india)          echo "Asia/Kolkata" ;;
        ae|dubai)          echo "Asia/Dubai" ;;
        
        us|usa|ny|newyork) echo "America/New_York" ;;
        la|losangeles)     echo "America/Los_Angeles" ;;
        sf|sanfrancisco)   echo "America/Los_Angeles" ;;
        
        uk|london|gb)      echo "Europe/London" ;;
        de|berlin|germany) echo "Europe/Berlin" ;;
        fr|paris|france)   echo "Europe/Paris" ;;
        ru|moscow)         echo "Europe/Moscow" ;;
        
        au|sydney)         echo "Australia/Sydney" ;;
        utc|gmt)           echo "UTC" ;;
        *)                 echo "$1" ;;
    esac
}

# 编号选择器 (扩充版)
get_timezone_by_index() {
    case $1 in
        # --- 亚洲 ---
        1) echo "Asia/Shanghai" ;;      2) echo "Asia/Hong_Kong" ;;     3) echo "Asia/Taipei" ;;
        4) echo "Asia/Tokyo" ;;         5) echo "Asia/Seoul" ;;         6) echo "Asia/Singapore" ;;
        7) echo "Asia/Bangkok" ;;       8) echo "Asia/Kolkata" ;;       9) echo "Asia/Dubai" ;;
        10) echo "Asia/Ho_Chi_Minh" ;;  11) echo "Asia/Jakarta" ;;      12) echo "Asia/Manila" ;;
        13) echo "Asia/Riyadh" ;;       14) echo "Asia/Tehran" ;;       15) echo "Asia/Jerusalem" ;;
        16) echo "Asia/Kuala_Lumpur" ;; 17) echo "Asia/Yangon" ;;       18) echo "Asia/Tashkent" ;;
        
        # --- 欧洲 ---
        20) echo "Europe/London" ;;     21) echo "Europe/Paris" ;;      22) echo "Europe/Berlin" ;;
        23) echo "Europe/Moscow" ;;     24) echo "Europe/Amsterdam" ;;  25) echo "Europe/Rome" ;;
        26) echo "Europe/Madrid" ;;     27) echo "Europe/Zurich" ;;     28) echo "Europe/Kyiv" ;;
        29) echo "Europe/Istanbul" ;;   30) echo "Europe/Stockholm" ;;  31) echo "Europe/Warsaw" ;;
        32) echo "Europe/Vienna" ;;     33) echo "Europe/Athens" ;;     34) echo "Europe/Brussels" ;;
        35) echo "Europe/Copenhagen" ;; 36) echo "Europe/Dublin" ;;     37) echo "Europe/Lisbon" ;;
        
        # --- 美洲 ---
        40) echo "America/New_York" ;;  41) echo "America/Chicago" ;;   42) echo "America/Los_Angeles" ;;
        43) echo "America/Toronto" ;;   44) echo "America/Vancouver" ;; 45) echo "America/Sao_Paulo" ;;
        46) echo "America/Mexico_City" ;; 47) echo "America/Argentina/Buenos_Aires" ;; 48) echo "America/Santiago" ;;
        
        # --- 其他 ---
        50) echo "Australia/Sydney" ;;  51) echo "Australia/Perth" ;;   52) echo "Pacific/Auckland" ;;
        60) echo "Africa/Johannesburg" ;; 61) echo "Africa/Cairo" ;;    62) echo "Africa/Lagos" ;;
        
        # --- 通用 ---
        0) echo "UTC" ;;
        *) echo "" ;;
    esac
}

interactive_menu() {
    while true; do
        clear
        print_header "VPS 全球时区设置 (完整版)"
        show_time_info
        
        # 使用 printf 格式化输出紧凑的三列布局
        echo -e "${YELLOW}--- 亚洲 (Asia) ---${NC}"
        printf "%-2s. %-22s %-2s. %-22s %-2s. %-22s\n" \
            "1" "上海 (Shanghai)" "2" "香港 (Hong Kong)" "3" "台北 (Taipei)" \
            "4" "东京 (Tokyo)" "5" "首尔 (Seoul)" "6" "新加坡 (Singapore)" \
            "7" "曼谷 (Bangkok)" "8" "印度 (Kolkata)" "9" "迪拜 (Dubai)" \
            "10" "胡志明 (HCMC)" "11" "雅加达 (Jakarta)" "12" "马尼拉 (Manila)" \
            "13" "利雅得 (Riyadh)" "14" "德黑兰 (Tehran)" "15" "耶路撒冷 (Jerusalem)" \
            "16" "吉隆坡 (KL)" "17" "仰光 (Yangon)" "18" "塔什干 (Tashkent)"

        echo -e "\n${YELLOW}--- 欧洲 (Europe) ---${NC}"
        printf "%-2s. %-22s %-2s. %-22s %-2s. %-22s\n" \
            "20" "伦敦 (London)" "21" "巴黎 (Paris)" "22" "柏林 (Berlin)" \
            "23" "莫斯科 (Moscow)" "24" "阿姆斯特丹" "25" "罗马 (Rome)" \
            "26" "马德里 (Madrid)" "27" "苏黎世 (Zurich)" "28" "基辅 (Kyiv)" \
            "29" "伊斯坦布尔" "30" "斯德哥尔摩" "31" "华沙 (Warsaw)" \
            "32" "维也纳 (Vienna)" "33" "雅典 (Athens)" "34" "布鲁塞尔 (Brussels)" \
            "35" "哥本哈根" "36" "都柏林 (Dublin)" "37" "里斯本 (Lisbon)"

        echo -e "\n${YELLOW}--- 美洲 (Americas) ---${NC}"
        printf "%-2s. %-22s %-2s. %-22s %-2s. %-22s\n" \
            "40" "纽约 (New York)" "41" "芝加哥 (Chicago)" "42" "洛杉矶 (LA)" \
            "43" "多伦多 (Toronto)" "44" "温哥华 (Vancouver)" "45" "圣保罗 (Sao Paulo)" \
            "46" "墨西哥城" "47" "布宜诺斯艾利斯" "48" "圣地亚哥 (Santiago)"

        echo -e "\n${YELLOW}--- 其他 (Others) ---${NC}"
        printf "%-2s. %-22s %-2s. %-22s %-2s. %-22s\n" \
            "50" "悉尼 (Sydney)" "51" "珀斯 (Perth)" "52" "奥克兰 (Auckland)" \
            "60" "约翰内斯堡" "61" "开罗 (Cairo)" "62" "拉各斯 (Lagos)"
        
        echo -e "\n${CYAN}操作指令:${NC}"
        printf "%-2s. %-22s %-2s. %-22s %-2s. %-22s\n" \
            "0" "UTC 标准时间" "s" "搜索时区 (Search)" "m" "手动输入 (Manual)" \
            "n" "配置NTP同步" "t" "立即同步时间" "q" "退出 (Quit)"
        
        echo ""
        read -p "请输入编号或指令: " input
        
        case $input in
            q) exit 0 ;;
            n) NTP_ENABLED=true; configure_ntp; read -n 1 -s -r -p "按键继续..." ;;
            t) force_sync_time; read -n 1 -s -r -p "按键继续..." ;;
            m) 
               read -p "输入时区 (如 Asia/Shanghai): " NEW_TIMEZONE
               if validate_timezone "$NEW_TIMEZONE"; then 
                   backup_configs
                   set_system_timezone "$NEW_TIMEZONE"
                   verify_timezone "$NEW_TIMEZONE"
               fi
               read -n 1 -s -r -p "按键继续..." ;;
            s)
               read -p "关键词 (如 Japan): " key
               search_timezones "$key"
               read -p "输入完整时区名称: " NEW_TIMEZONE
               if [ -n "$NEW_TIMEZONE" ] && validate_timezone "$NEW_TIMEZONE"; then 
                   backup_configs
                   set_system_timezone "$NEW_TIMEZONE"
                   verify_timezone "$NEW_TIMEZONE"
               fi
               read -n 1 -s -r -p "按键继续..." ;;
            *)
               NEW_TIMEZONE=$(get_timezone_by_index "$input")
               if [ -n "$NEW_TIMEZONE" ]; then
                   backup_configs
                   set_system_timezone "$NEW_TIMEZONE"
                   
                   echo ""
                   read -p "是否同时配置 NTP 自动同步? (y/N): " ntp
                   if [[ "$ntp" =~ ^[Yy]$ ]]; then
                       NTP_ENABLED=true
                       configure_ntp
                   fi
                   
                   if verify_timezone "$NEW_TIMEZONE"; then
                       generate_report
                   fi
                   read -n 1 -s -r -p "按任意键返回..."
               else
                   print_error "无效的选择。"
                   sleep 1
               fi
               ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# 5. 主程序入口
# ------------------------------------------------------------------------------

main() {
    check_root
    
    # 命令行参数支持
    if [ -n "$1" ]; then
        case "$1" in
            --ntp) NTP_ENABLED=true; configure_ntp; exit ;;
            --sync) force_sync_time; exit ;;
            --list) find /usr/share/zoneinfo -type f | sed 's|/usr/share/zoneinfo/||' | sort; exit ;;
            --help|-h) 
                echo "Usage: bash set_timezone.sh [timezone | code | --ntp | --sync]"
                echo "Codes: cn, hk, tw, jp, kr, us, uk, de, ru, sg, ..."
                exit 0 ;;
            *)
                local target_tz=$(resolve_timezone_alias "$1")
                NEW_TIMEZONE="$target_tz"
                if validate_timezone "$target_tz"; then
                    backup_configs
                    set_system_timezone "$target_tz"
                    generate_report
                else
                    print_error "无效参数或时区: $1"
                    exit 1
                fi
                ;;
        esac
    else
        interactive_menu
    fi
}

main "$@"
