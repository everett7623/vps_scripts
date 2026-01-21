#!/bin/bash
# ==============================================================================
# 脚本名称: bandwidth_test.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/network_test/bandwidth_test.sh
# 描述: VPS 带宽性能测试工具 (v1.5.1 节点修复版)
#       【更新说明】
#       1. 替换了大面积失效的中国大陆节点，精选高可用 5G 节点。
#       2. 移除了不稳定的移动节点，替换为南京/南宁等对海外友好的节点。
#       3. 保留了多线程、CDN 测速及稳定性测试功能。
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
# 2. Speedtest 节点库 (精选高可用列表)
# ------------------------------------------------------------------------------
declare -A SERVERS

# --- 中国电信 (China Telecom) ---
# 选取江苏、天津、四川等骨干节点，存活率较高
SERVERS[cn_ct_js]="5396:江苏电信 (苏州)"
SERVERS[cn_ct_tj]="17145:天津电信"
SERVERS[cn_ct_sc]="29026:四川电信 (成都)"
SERVERS[cn_ct_ah]="3633:安徽电信 (合肥)"

# --- 中国联通 (China Unicom) ---
# 上海、湖南、辽宁节点通常对海外连接较好
SERVERS[cn_cu_sh]="24447:上海联通"
SERVERS[cn_cu_hn]="4870:湖南联通 (长沙)"
SERVERS[cn_cu_ln]="16167:辽宁联通 (沈阳)"
SERVERS[cn_cu_sc]="2461:四川联通 (成都)"

# --- 中国移动 (China Mobile) ---
# 移动节点极其容易屏蔽海外，选取南京、南宁等相对宽松节点
SERVERS[cn_cm_js]="27249:江苏移动 (南京)"
SERVERS[cn_cm_gx]="15863:广西移动 (南宁)"
SERVERS[cn_cm_ln]="26656:黑龙江移动 (哈尔滨)"
# 备用：部分地区可能连不上
# SERVERS[cn_cm_zj]="25637:浙江移动" 

# --- 亚洲周边 (Asia) ---
SERVERS[hk_hgc]="32155:香港 HGC"
SERVERS[hk_stc]="13538:香港 STC"
SERVERS[tw_cht]="3417:台湾 Chunghwa (台北)"
SERVERS[jp_tokyo]="48463:日本东京 (IPA)"
SERVERS[jp_osaka]="44950:日本大阪 (Rakuten)"
SERVERS[sg_singtel]="18458:新加坡 Singtel"
SERVERS[kr_seoul]="6527:韩国首尔 (KISTI)"

# --- 美洲 (Americas) ---
SERVERS[us_la]="18531:洛杉矶 (Wave)"
SERVERS[us_sj]="35055:圣何塞 (GSL)"
SERVERS[us_ny]="5029:纽约 (AT&T)"
SERVERS[us_miami]="14232:迈阿密 (Comcast)"
SERVERS[ca_toronto]="3052:多伦多 (Rogers)"

# --- 欧洲 (Europe) ---
SERVERS[uk_london]="51838:伦敦 (Community)"
SERVERS[de_frankfurt]="31622:法兰克福 (23Media)"
SERVERS[nl_amsterdam]="26997:阿姆斯特丹"
SERVERS[fr_paris]="24215:巴黎 (Orange)"
SERVERS[ru_moscow]="11603:莫斯科 (MTS)"

# --- 澳洲 (Australia) ---
SERVERS[au_sydney]="2225:悉尼 (Telstra)"

# ------------------------------------------------------------------------------
# 3. 辅助功能
# ------------------------------------------------------------------------------

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

install_speedtest() {
    if command -v speedtest &>/dev/null; then return 0; fi
    print_info "正在安装 Speedtest CLI..."
    
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
# 4. 核心测试模块
# ------------------------------------------------------------------------------

# [模块1] 基础下载测试
test_download_single() {
    local url=$1
    local name=$2
    
    echo -ne "  测试下载: ${CYAN}$name${NC} ... "
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

# [模块2] Speedtest 标准测速 (优化显示)
run_speedtest() {
    local id=$1
    local name=$2
    local cmd="speedtest --format=json"
    [ -n "$id" ] && cmd="$cmd --server-id=$id"
    
    echo -ne "  正在连接: ${CYAN}$name${NC} ... "
    local res=$($cmd 2>/dev/null)
    
    if [ -n "$res" ]; then
        local dl=$(echo "$res" | grep -oP '"download":{"bandwidth":\K[0-9]+' | awk '{printf "%.2f", $1 * 8 / 1000000}')
        local ul=$(echo "$res" | grep -oP '"upload":{"bandwidth":\K[0-9]+' | awk '{printf "%.2f", $1 * 8 / 1000000}')
        local ping=$(echo "$res" | grep -oP '"latency":\K[0-9.]+' | head -1)
        
        # 结果格式化输出
        echo -ne "\r"
        printf "  %-16s | 延迟: ${CYAN}%-6s${NC} | 下行: ${GREEN}%-8s${NC} | 上行: ${BLUE}%-8s${NC}\n" \
            "${name:0:16}" "${ping}ms" "${dl} Mbps" "${ul} Mbps"
        echo "[$name] Ping: ${ping}ms, DL: ${dl} Mbps, UL: ${ul} Mbps" >> "$REPORT_FILE"
    else
        echo -e "\r  ${RED}[失败]${NC} $name - 节点不可用或超时"
        log "Speedtest failed for $name ($id)"
    fi
}

# [模块3] 完整批量测试 (有序遍历)
test_full_batch() {
    print_header "全球节点完整测速"
    install_speedtest
    
    # 按地理顺序定义测试列表
    local order=(
        # 中国电信
        "cn_ct_js" "cn_ct_tj" "cn_ct_sc" "cn_ct_ah"
        # 中国联通
        "cn_cu_sh" "cn_cu_hn" "cn_cu_ln" "cn_cu_sc"
        # 中国移动
        "cn_cm_js" "cn_cm_gx" "cn_cm_ln"
        # 亚洲
        "hk_hgc" "hk_stc" "tw_cht" "jp_tokyo" "jp_osaka" "sg_singtel" "kr_seoul"
        # 美洲
        "us_la" "us_sj" "us_ny" "us_miami" "ca_toronto"
        # 欧洲
        "uk_london" "de_frankfurt" "nl_amsterdam" "fr_paris" "ru_moscow"
        # 澳洲
        "au_sydney"
    )
    
    for k in "${order[@]}"; do
        if [ -n "${SERVERS[$k]}" ]; then
            IFS=':' read -r id name <<< "${SERVERS[$k]}"
            run_speedtest "$id" "$name"
        fi
    done
}

# [模块4] 多线程并发测试
test_multithread() {
    print_header "多线程极限带宽测试"
    local url="http://speed.cloudflare.com/__down?bytes=100000000" # 100MB
    local threads=(4 8 16)
    
    for t in "${threads[@]}"; do
        echo -ne "  正在进行 ${CYAN}$t 线程${NC} 并发测试... "
        local start=$(date +%s.%N)
        
        for ((i=0; i<t; i++)); do
            wget -q -O /dev/null "$url" &
        done
        wait
        
        local end=$(date +%s.%N)
        local time=$(echo "$end - $start" | bc)
        local total_size=$(echo "100 * $t" | bc)
        local speed=$(echo "scale=2; $total_size * 8 / $time" | bc)
        
        echo -e "${GREEN}${speed} Mbps${NC} (耗时 ${time}s)"
        echo "Multi-thread ($t): ${speed} Mbps" >> "$REPORT_FILE"
    done
}

# [模块5] CDN 节点测速
test_cdn_nodes() {
    print_header "CDN 节点下载测速"
    declare -A cdns
    cdns["Cloudflare"]="https://speed.cloudflare.com/__down?bytes=25000000"
    cdns["AWS SG"]="http://s3-ap-southeast-1.amazonaws.com/speedtest/10MB.zip"
    cdns["AWS JP"]="http://s3-ap-northeast-1.amazonaws.com/speedtest/10MB.zip"
    cdns["AWS US"]="http://s3-us-west-1.amazonaws.com/speedtest/10MB.zip"
    cdns["Vultr Tokyo"]="https://hnd-jp-ping.vultr.com/vultr.com.100MB.bin"
    cdns["Linode SG"]="http://speedtest.singapore.linode.com/100MB-singapore.bin"
    cdns["DO SF"]="http://speedtest-sfo3.digitalocean.com/100mb.test"
    
    for name in "${!cdns[@]}"; do
        test_download_single "${cdns[$name]}" "$name"
    done
}

# [模块6] 稳定性测试
test_stability() {
    print_header "带宽稳定性波动测试 (5次采样)"
    local url="https://speed.cloudflare.com/__down?bytes=10000000"
    local total=0; local min=99999; local max=0
    
    for i in {1..5}; do
        local start=$(date +%s.%N)
        wget -q -O /dev/null "$url"
        local end=$(date +%s.%N)
        local time=$(echo "$end - $start" | bc)
        local speed=$(echo "scale=2; 10 * 8 / $time" | bc)
        
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

# [模块7] 自定义服务器
custom_speedtest() {
    print_header "自定义 Speedtest 节点"
    install_speedtest
    echo -e "${CYAN}正在搜索附近的节点...${NC}"
    speedtest --list | head -n 10
    echo ""
    read -p "请输入 Server ID (例如 24447): " sid
    read -p "请输入备注名称 (可选): " sname
    [ -z "$sname" ] && sname="Custom-$sid"
    
    if [ -n "$sid" ]; then
        run_speedtest "$sid" "$sname"
    else
        print_error "ID 不能为空"
    fi
}

# ------------------------------------------------------------------------------
# 5. 交互菜单与入口
# ------------------------------------------------------------------------------

interactive_menu() {
    clear
    print_header "VPS 全能带宽测试工具"
    echo -e "${CYAN}请选择测试模式:${NC}"
    echo -e " 1. 简单测试 (自动选择最近节点)"
    echo -e " 2. 标准测试 (中国三网 + 亚太 + 美西)"
    echo -e " 3. 完整测试 (全球 30+ 节点，含成都/大阪/莫斯科等)"
    echo -e " 4. 多线程极限带宽测试"
    echo -e " 5. CDN 节点测速 (AWS/Cloudflare等)"
    echo -e " 6. 带宽稳定性测试 (波动率)"
    echo -e " 7. 自定义 Speedtest 节点 ID"
    echo -e " 0. 退出"
    echo ""
    read -p "请输入选项 [0-7]: " choice
    
    echo "" > "$REPORT_FILE"
    
    case $choice in
        1) 
            install_speedtest
            run_speedtest "" "自动最优"
            test_download_single "https://speed.cloudflare.com/__down?bytes=25000000" "Cloudflare"
            ;;
        2)
            install_speedtest
            print_info "正在测试核心节点..."
            # 测试标准：江苏电信/上海联通/南京移动 + 香港/东京/洛杉矶/新加坡
            for k in cn_ct_js cn_cu_sh cn_cm_js hk_hgc jp_tokyo us_la sg_singtel; do
                IFS=':' read -r id name <<< "${SERVERS[$k]}"
                run_speedtest "$id" "$name"
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
    # 命令行处理
    if [ -n "$1" ]; then
        case "$1" in
            --simple) install_speedtest; run_speedtest "" "Auto"; exit ;;
            --full) test_full_batch; exit ;;
            --help|-h) 
                echo "Usage: bash bandwidth_test.sh [--simple | --full]"
                exit 0 ;;
            *) print_error "无效参数"; exit 1 ;;
        esac
    else
        interactive_menu
    fi
}

main "$@"
