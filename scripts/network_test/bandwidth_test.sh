#!/bin/bash
# ==============================================================================
# 脚本名称: bandwidth_test.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/network_test/bandwidth_test.sh
# 描述: VPS 带宽性能测试工具 (v1.6.0 智能回退修复版)
#       【核心修复】
#       1. 针对节点大面积失效问题，增加了 [指定ID -> 关键词搜索] 的自动回退机制。
#       2. 如果指定 ID 无法连接，脚本将自动搜索该地区的其他可用节点进行测试。
#       3. 更新了 2025 年高可用节点列表 (侧重于对海外友好的 5G 节点)。
# 作者: Jensfrank (Optimized by AI)
# 更新日期: 2026-01-21
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 环境初始化
# ------------------------------------------------------------------------------

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

LOG_DIR="/var/log/vps_scripts"
LOG_FILE="$LOG_DIR/bandwidth_test.log"
REPORT_DIR="/var/log/vps_scripts/reports"
REPORT_FILE="$REPORT_DIR/bandwidth_report_$(date +%Y%m%d_%H%M%S).txt"
TEMP_DIR="/tmp/bandwidth_test_$$"

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

mkdir -p "$LOG_DIR" "$REPORT_DIR" "$TEMP_DIR"
trap 'rm -rf "$TEMP_DIR"' EXIT

# ------------------------------------------------------------------------------
# 2. Speedtest 节点配置 (格式: ID|搜索关键词|显示名称)
# ------------------------------------------------------------------------------
declare -A SERVERS

# --- 中国电信 (China Telecom) ---
# 优先使用 5G 节点，存活率更高
SERVERS[cn_ct_js]="5396|China Telecom Jiangsu|江苏电信 (苏州)"
SERVERS[cn_ct_sh]="24012|China Telecom Shanghai|上海电信"
SERVERS[cn_ct_sc]="23844|China Telecom Chengdu|四川电信 (成都)"
SERVERS[cn_ct_tj]="17145|China Telecom Tianjin|天津电信"

# --- 中国联通 (China Unicom) ---
SERVERS[cn_cu_sh]="24447|China Unicom Shanghai|上海联通"
SERVERS[cn_cu_hn]="4870|China Unicom Changsha|湖南联通"
SERVERS[cn_cu_ln]="16167|China Unicom Shenyang|辽宁联通"
SERVERS[cn_cu_sc]="4690|China Unicom Chengdu|四川联通"

# --- 中国移动 (China Mobile) ---
# 移动屏蔽严重，改用相对宽松的节点，并增加搜索关键词回退
SERVERS[cn_cm_js]="27249|China Mobile Nanjing|江苏移动 (南京)"
SERVERS[cn_cm_gx]="15863|China Mobile Nanning|广西移动 (南宁)"
SERVERS[cn_cm_bj]="25858|China Mobile Beijing|北京移动"
SERVERS[cn_cm_cd]="4575|China Mobile Chengdu|四川移动 (成都)"

# --- 亚洲周边 (Asia) ---
SERVERS[hk_hgc]="32155|HGC Global Communications|香港 HGC"
SERVERS[hk_stc]="13538|STC|香港 STC"
SERVERS[tw_cht]="3417|Chunghwa Telecom|台湾中华电信"
SERVERS[jp_tokyo]="48463|IPA CyberLab|日本东京 (IPA)"
SERVERS[jp_osaka]="44950|Rakuten Mobile|日本大阪 (Rakuten)"
SERVERS[sg_singtel]="18458|Singtel|新加坡 Singtel"
SERVERS[kr_seoul]="6527|KISTI|韩国首尔 (KISTI)"

# --- 欧美澳 (Global) ---
SERVERS[us_la]="18531|Wave|美国洛杉矶"
SERVERS[us_sj]="35055|GSL Networks|美国圣何塞"
SERVERS[uk_london]="51838|Community Fibre|英国伦敦"
SERVERS[de_frankfurt]="31622|23M GmbH|德国法兰克福"
SERVERS[ru_moscow]="11603|MTS|俄罗斯莫斯科"
SERVERS[au_sydney]="2225|Telstra|澳洲悉尼"

# ------------------------------------------------------------------------------
# 3. 辅助功能
# ------------------------------------------------------------------------------

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

install_speedtest() {
    if command -v speedtest &>/dev/null; then return 0; fi
    print_info "正在安装 Speedtest CLI..."
    
    # 尝试官方源安装
    if command -v apt-get &>/dev/null; then
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash &>> "$LOG_FILE"
        apt-get install -y speedtest &>> "$LOG_FILE"
    elif command -v yum &>/dev/null; then
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | bash &>> "$LOG_FILE"
        yum install -y speedtest &>> "$LOG_FILE"
    else
        # 二进制回退安装
        wget -qO "$TEMP_DIR/speedtest.tgz" "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-$(uname -m).tgz"
        tar -xzf "$TEMP_DIR/speedtest.tgz" -C "$TEMP_DIR"
        mv "$TEMP_DIR/speedtest" /usr/local/bin/
        chmod +x /usr/local/bin/speedtest
    fi
    speedtest --accept-license --accept-gdpr &>> "$LOG_FILE"
}

# ------------------------------------------------------------------------------
# 4. 核心测试模块 (智能回退逻辑)
# ------------------------------------------------------------------------------

# 解析 JSON 结果并输出
parse_speedtest_result() {
    local json=$1
    local name=$2
    local extra_tag=$3 # 标记是 ID 测试还是搜索测试
    
    local dl=$(echo "$json" | grep -oP '"download":{"bandwidth":\K[0-9]+' | awk '{printf "%.2f", $1 * 8 / 1000000}')
    local ul=$(echo "$json" | grep -oP '"upload":{"bandwidth":\K[0-9]+' | awk '{printf "%.2f", $1 * 8 / 1000000}')
    local ping=$(echo "$json" | grep -oP '"latency":\K[0-9.]+' | head -1)
    local server_name=$(echo "$json" | grep -oP '"name":"\K[^"]+' | head -1)
    
    if [ -n "$ping" ]; then
        echo -ne "\r"
        # 格式化输出：对齐显示
        printf "  %-20s | 延迟: ${CYAN}%-7s${NC} | 下行: ${GREEN}%-9s${NC} | 上行: ${BLUE}%-9s${NC} %s\n" \
            "${name:0:20}" "${ping}ms" "${dl} Mbps" "${ul} Mbps" "${extra_tag}"
        echo "[$name] Ping: ${ping}ms, DL: ${dl} Mbps, UL: ${ul} Mbps ($server_name)" >> "$REPORT_FILE"
        return 0
    else
        return 1
    fi
}

# 智能测速函数
run_smart_speedtest() {
    local config=$1
    
    # 拆分配置字符串 ID|Keywords|Name
    IFS='|' read -r id keyword name <<< "$config"
    
    echo -ne "  正在测试: ${CYAN}$name${NC} (ID:$id) ... "
    
    # 1. 尝试指定 ID 测速
    local res=$(speedtest --server-id=$id --format=json 2>/dev/null)
    
    if parse_speedtest_result "$res" "$name" ""; then
        return 0
    fi
    
    # 2. 如果 ID 失败，尝试关键词搜索 (自动回退)
    echo -ne "\r  ${YELLOW}[重试]${NC} ID失效，正在搜索附近节点: ${CYAN}$keyword${NC} ... "
    
    # 获取搜索列表的第一个可用 ID
    # speedtest -L 搜索有时候不准，这里直接让 speedtest 自动选择最近的匹配项
    # 注意：CLI 没有直接按关键词测速的参数，我们需要先 search 拿到 ID
    local new_id=$(speedtest --search "$keyword" --format=json 2>/dev/null | grep -oP '"id":\K[0-9]+' | head -1)
    
    if [ -n "$new_id" ] && [ "$new_id" != "$id" ]; then
        local res_search=$(speedtest --server-id=$new_id --format=json 2>/dev/null)
        if parse_speedtest_result "$res_search" "$name" "(自动匹配: $new_id)"; then
            return 0
        fi
    fi
    
    # 3. 彻底失败
    echo -e "\r  ${RED}[失败]${NC} $name - 节点不可用或被墙"
    log "Speedtest failed for $name (ID:$id, Keyword:$keyword)"
}

test_download_single() {
    local url=$1
    local name=$2
    echo -ne "  CDN 下载: ${CYAN}$name${NC} ... "
    local temp_file="$TEMP_DIR/dl_test"
    local speed=$(timeout 15 wget -O "$temp_file" --no-check-certificate "$url" 2>&1 | grep -o "[0-9.]\+ [KM]B/s" | tail -1)
    rm -f "$temp_file"
    
    if [[ "$speed" =~ MB/s ]]; then
        local val=$(echo "$speed" | awk '{print $1}')
        local mbps=$(echo "$val * 8" | bc)
        echo -e "${GREEN}$mbps Mbps${NC} ($speed)"
        echo "$name: $mbps Mbps" >> "$REPORT_FILE"
    else
        echo -e "${YELLOW}${speed:-失败}${NC}"
    fi
}

test_full_batch() {
    print_header "全球节点智能测速 (含自动回退)"
    install_speedtest
    
    # 定义有序列表
    local order=(
        # 中国
        "cn_ct_js" "cn_ct_sh" "cn_ct_sc" "cn_ct_tj"
        "cn_cu_sh" "cn_cu_hn" "cn_cu_ln" "cn_cu_sc"
        "cn_cm_js" "cn_cm_gx" "cn_cm_bj" "cn_cm_cd"
        # 亚洲
        "hk_hgc" "hk_stc" "tw_cht" "jp_tokyo" "jp_osaka" "sg_singtel" "kr_seoul"
        # 欧美澳
        "us_la" "us_sj" "us_ny" "us_miami" "ca_toronto"
        "uk_london" "de_frankfurt" "ru_moscow" "au_sydney"
    )
    
    for k in "${order[@]}"; do
        if [ -n "${SERVERS[$k]}" ]; then
            run_smart_speedtest "${SERVERS[$k]}"
        fi
    done
}

test_multithread() {
    print_header "多线程极限带宽测试"
    local url="http://speed.cloudflare.com/__down?bytes=100000000"
    local threads=(4 8 16)
    for t in "${threads[@]}"; do
        echo -ne "  ${CYAN}$t 线程${NC} 并发测试... "
        local start=$(date +%s.%N)
        for ((i=0; i<t; i++)); do wget -q -O /dev/null "$url" & done
        wait
        local end=$(date +%s.%N)
        local time=$(echo "$end - $start" | bc)
        local speed=$(echo "scale=2; 800 / $time" | bc) # 100MB * 8 = 800Mb
        echo -e "${GREEN}${speed} Mbps${NC} (耗时 ${time}s)"
        echo "Multi-thread ($t): ${speed} Mbps" >> "$REPORT_FILE"
    done
}

test_cdn_nodes() {
    print_header "CDN 节点下载测速"
    declare -A cdns
    cdns["Cloudflare"]="https://speed.cloudflare.com/__down?bytes=25000000"
    cdns["AWS SG"]="http://s3-ap-southeast-1.amazonaws.com/speedtest/10MB.zip"
    cdns["AWS JP"]="http://s3-ap-northeast-1.amazonaws.com/speedtest/10MB.zip"
    cdns["AWS US"]="http://s3-us-west-1.amazonaws.com/speedtest/10MB.zip"
    cdns["Linode SG"]="http://speedtest.singapore.linode.com/100MB-singapore.bin"
    cdns["DO SF"]="http://speedtest-sfo3.digitalocean.com/100mb.test"
    
    for name in "${!cdns[@]}"; do test_download_single "${cdns[$name]}" "$name"; done
}

test_stability() {
    print_header "带宽稳定性测试 (5次)"
    local url="https://speed.cloudflare.com/__down?bytes=10000000"
    local total=0; local min=99999; local max=0
    for i in {1..5}; do
        local start=$(date +%s.%N)
        wget -q -O /dev/null "$url"
        local end=$(date +%s.%N)
        local time=$(echo "$end - $start" | bc)
        local speed=$(echo "scale=2; 80 / $time" | bc) # 10MB*8
        printf "  [%d/5] 采样: ${CYAN}%s Mbps${NC}\n" "$i" "$speed"
        total=$(echo "$total + $speed" | bc)
        if (( $(echo "$speed < $min" | bc -l) )); then min=$speed; fi
        if (( $(echo "$speed > $max" | bc -l) )); then max=$speed; fi
    done
    local avg=$(echo "scale=2; $total / 5" | bc)
    local jitter=$(echo "scale=2; ($max - $min) / $avg * 100" | bc)
    echo -e "\n  平均: ${GREEN}$avg Mbps${NC} | 抖动: ${YELLOW}$jitter%${NC}"
    echo "Stability: Avg $avg Mbps, Jitter $jitter%" >> "$REPORT_FILE"
}

custom_speedtest() {
    print_header "自定义节点测速"
    install_speedtest
    echo -e "${CYAN}搜索节点...${NC}"
    speedtest --list | head -n 10
    echo ""
    read -p "请输入 Server ID: " sid
    [ -n "$sid" ] && run_smart_speedtest "$sid|custom|自定义节点($sid)"
}

# ------------------------------------------------------------------------------
# 5. 交互菜单
# ------------------------------------------------------------------------------

interactive_menu() {
    clear
    print_header "VPS 全能带宽测试工具 (智能修复版)"
    echo -e "${CYAN}请选择测试模式:${NC}"
    echo -e " 1. 简单测试 (自动选择 + Cloudflare)"
    echo -e " 2. 标准测试 (中国三网核心 + 亚太)"
    echo -e " 3. 完整测试 (全球 30+ 节点，含自动回退)"
    echo -e " 4. 多线程极限带宽测试"
    echo -e " 5. CDN 节点测速"
    echo -e " 6. 带宽稳定性测试"
    echo -e " 7. 自定义 Speedtest ID"
    echo -e " 0. 退出"
    echo ""
    read -p "请输入选项 [0-7]: " choice
    
    echo "" > "$REPORT_FILE"
    
    case $choice in
        1) 
            install_speedtest
            run_smart_speedtest "|auto|自动最优节点"
            test_download_single "https://speed.cloudflare.com/__down?bytes=25000000" "Cloudflare"
            ;;
        2)
            install_speedtest
            print_info "正在测试核心节点..."
            for k in cn_ct_sh cn_cu_sh cn_cm_js hk_hgc us_la jp_tokyo; do
                run_smart_speedtest "${SERVERS[$k]}"
            done
            ;;
        3) test_full_batch ;;
        4) test_multithread ;;
        5) test_cdn_nodes ;;
        6) test_stability ;;
        7) custom_speedtest ;;
        0) exit 0 ;;
        *) print_error "无效输入"; sleep 1; interactive_menu ;;
    esac
    
    print_success "测试完成，报告已生成: $REPORT_FILE"
    read -n 1 -s -r -p "按任意键返回菜单..."
    interactive_menu
}

main() {
    if [ -n "$1" ]; then
        case "$1" in
            --simple) install_speedtest; run_smart_speedtest "|auto|Auto"; exit ;;
            --full) test_full_batch; exit ;;
            --help|-h) echo "Usage: bash bandwidth_test.sh [--simple | --full]"; exit ;;
            *) print_error "无效参数"; exit 1 ;;
        esac
    else
        interactive_menu
    fi
}

main "$@"
