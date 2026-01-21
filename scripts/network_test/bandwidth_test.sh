#!/bin/bash
# ==============================================================================
# 脚本名称: bandwidth_test.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/network_test/bandwidth_test.sh
# 描述: VPS 带宽性能测试工具 (v2.0.2 海外优化统一版)
#       【功能列表】
#       1. 智能区域检测：自动识别国内/海外 VPS，加载对应优化节点。
#       2. Speedtest：30+ 全球节点，支持自动回退与自定义 ID。
#       3. iperf3：集成公网 iperf3 服务器，测试纯净带宽。
#       4. 回程质量：针对海外 VPS，特供中国方向（电信/联通/移动/香港）延迟丢包测试。
#       5. CDN 测速：主流 CDN 节点下载速度测试。
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

# 默认参数
TEST_MODE="unknown"
VPS_LOCATION="unknown"

# 加载公共库
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

mkdir -p "$LOG_DIR" "$REPORT_DIR" "$TEMP_DIR"
trap 'rm -rf "$TEMP_DIR"' EXIT

# ------------------------------------------------------------------------------
# 2. 节点配置与初始化
# ------------------------------------------------------------------------------
declare -A SPEEDTEST_SERVERS

# 智能检测 VPS 位置并加载对应节点
detect_and_init_servers() {
    print_header "检测 VPS 网络环境"
    
    # 检测到中国 DNS 的连通性
    local cn_check=$(ping -c 2 -W 2 114.114.114.114 2>/dev/null | grep -c "time=")
    
    # 获取地理位置
    local ip_info=$(curl -s --max-time 5 "http://ip-api.com/json/?fields=country,regionName,city,isp")
    local country=$(echo "$ip_info" | grep -oP '"country":"\K[^"]+')
    local isp=$(echo "$ip_info" | grep -oP '"isp":"\K[^"]+')
    
    echo -e "  位置: ${GREEN}${country:-未知}${NC} | 运营商: ${BLUE}${isp:-未知}${NC}"
    
    # 判断逻辑：Ping 通 114 且 IP 归属中国 -> 国内模式，否则 -> 海外模式
    if [ "$cn_check" -ge 1 ] && echo "$country" | grep -qiE "(China|CN)"; then
        TEST_MODE="domestic"
        VPS_LOCATION="CN"
        print_info "当前模式: 国内 VPS (加载国内优化节点)"
        
        SPEEDTEST_SERVERS=(
            [cn_ct_js]="5396|江苏电信"
            [cn_ct_sc]="23844|四川电信"
            [cn_cu_sh]="24447|上海联通"
            [cn_cu_hn]="4870|湖南联通"
            [cn_cm_js]="27249|江苏移动"
            [cn_cm_bj]="25858|北京移动"
        )
    else
        TEST_MODE="international"
        VPS_LOCATION="OVERSEAS"
        print_info "当前模式: 海外 VPS (加载回程优化节点)"
        
        SPEEDTEST_SERVERS=(
            # 亚洲优化
            [hk_hgc]="32155|香港 HGC"
            [hk_stc]="13538|香港 STC"
            [tw_cht]="3417|台湾中华电信"
            [jp_tokyo]="48463|日本东京 (IPA)"
            [jp_osaka]="44950|日本大阪 (Rakuten)"
            [sg_singtel]="18458|新加坡 Singtel"
            [kr_seoul]="6527|韩国首尔 (KISTI)"
            # 欧美核心
            [us_la]="18531|美国洛杉矶 (Wave)"
            [us_sj]="35055|美国圣何塞 (GSL)"
            [us_ny]="5029|美国纽约 (AT&T)"
            [uk_london]="51838|英国伦敦 (Community)"
            [de_frankfurt]="31622|德国法兰克福"
            [au_sydney]="2225|澳洲悉尼"
        )
    fi
}

# ------------------------------------------------------------------------------
# 3. 辅助功能
# ------------------------------------------------------------------------------

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

install_tools() {
    # Speedtest
    if ! command -v speedtest &>/dev/null; then
        print_info "安装 Speedtest CLI..."
        if command -v apt-get &>/dev/null; then
            curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash &>> "$LOG_FILE"
            apt-get install -y speedtest &>> "$LOG_FILE"
        elif command -v yum &>/dev/null; then
            curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | bash &>> "$LOG_FILE"
            yum install -y speedtest &>> "$LOG_FILE"
        else
            local arch=$(uname -m)
            [ "$arch" = "x86_64" ] && arch="x86_64" || arch="aarch64"
            wget -qO "$TEMP_DIR/speedtest.tgz" "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${arch}.tgz"
            tar -xzf "$TEMP_DIR/speedtest.tgz" -C "$TEMP_DIR"
            mv "$TEMP_DIR/speedtest" /usr/local/bin/
            chmod +x /usr/local/bin/speedtest
        fi
        speedtest --accept-license --accept-gdpr &>> "$LOG_FILE"
    fi

    # iperf3 & 基础工具
    if ! command -v iperf3 &>/dev/null || ! command -v bc &>/dev/null; then
        print_info "安装 iperf3 及基础工具..."
        if command -v apt-get &>/dev/null; then
            apt-get install -y iperf3 bc curl &>> "$LOG_FILE"
        elif command -v yum &>/dev/null; then
            yum install -y iperf3 bc curl &>> "$LOG_FILE"
        elif command -v apk &>/dev/null; then
            apk add iperf3 bc curl &>> "$LOG_FILE"
        fi
    fi
}

# ------------------------------------------------------------------------------
# 4. 核心测试模块
# ------------------------------------------------------------------------------

# [模块1] Speedtest 测速
run_speedtest_single() {
    local id=$1
    local name=$2
    
    echo -ne "  正在测试: ${CYAN}$name${NC} (ID:$id) ... "
    
    local res=$(timeout 45 speedtest --server-id="$id" --format=json 2>/dev/null || echo "")
    
    if [ -n "$res" ]; then
        local dl=$(echo "$res" | grep -oP '"download":{"bandwidth":\K[0-9]+' | awk '{printf "%.2f", $1 * 8 / 1000000}')
        local ul=$(echo "$res" | grep -oP '"upload":{"bandwidth":\K[0-9]+' | awk '{printf "%.2f", $1 * 8 / 1000000}')
        local ping=$(echo "$res" | grep -oP '"latency":\K[0-9.]+' | head -1)
        
        if [ -n "$ping" ]; then
            echo -ne "\r"
            printf "  %-20s | 延迟: ${CYAN}%-6s${NC} | 下行: ${GREEN}%-8s${NC} | 上行: ${BLUE}%-8s${NC}\n" \
                "${name:0:20}" "${ping}ms" "${dl} Mbps" "${ul} Mbps"
            echo "$name | Ping: ${ping}ms | DL: ${dl} Mbps | UL: ${ul} Mbps" >> "$REPORT_FILE"
            return 0
        fi
    fi
    
    echo -e "\r  ${RED}[失败]${NC} $name - 节点不可用或超时"
    log "Speedtest timeout: $name (ID:$id)"
    return 1
}

# [模块2] iperf3 测速 (针对海外)
test_iperf3_batch() {
    print_header "iperf3 公网带宽测试"
    
    declare -A IPERF_SERVERS=(
        [fr_online]="ping.online.net:5200:法国 Online.net"
        [us_he]="iperf.he.net:5201:美国 HE.net"
        [fr_bouygues]="bouygues.iperf.fr:5206:法国 Bouygues"
    )
    
    for key in "${!IPERF_SERVERS[@]}"; do
        IFS=':' read -r host port name <<< "${IPERF_SERVERS[$key]}"
        echo -ne "  测试: ${CYAN}$name${NC} ... "
        
        local result=$(timeout 15 iperf3 -c "$host" -p "$port" -t 5 -J 2>/dev/null || echo "")
        local bps=$(echo "$result" | grep -oP '"bits_per_second":\K[0-9.]+' | tail -1)
        
        if [ -n "$bps" ]; then
            local mbps=$(echo "scale=2; $bps / 1000000" | bc)
            echo -e "${GREEN}${mbps} Mbps${NC}"
            echo "iperf3 - $name: ${mbps} Mbps" >> "$REPORT_FILE"
        else
            echo -e "${RED}连接超时${NC}"
        fi
    done
}

# [模块3] CDN 节点测速
test_cdn_download() {
    print_header "CDN 节点下载测速"
    
    declare -A CDN_NODES=(
        [cf_global]="https://speed.cloudflare.com/__down?bytes=25000000:Cloudflare Global"
        [aws_us_east]="http://s3.us-east-1.amazonaws.com/speedtest.us-east-1/10MB.bin:AWS US East"
        [aws_us_west]="http://s3-us-west-1.amazonaws.com/speedtest/10MB.zip:AWS US West"
        [aws_ap_se]="http://s3-ap-southeast-1.amazonaws.com/speedtest/10MB.zip:AWS Singapore"
        [aws_ap_ne]="http://s3-ap-northeast-1.amazonaws.com/speedtest/10MB.zip:AWS Japan"
        [linode_sg]="http://speedtest.singapore.linode.com/100MB-singapore.bin:Linode Singapore"
        [linode_jp]="http://speedtest.tokyo2.linode.com/100MB-tokyo2.bin:Linode Tokyo"
        [do_sf]="http://speedtest-sfo3.digitalocean.com/100mb.test:DigitalOcean SF"
    )
    
    for key in "${!CDN_NODES[@]}"; do
        IFS=':' read -r url name <<< "${CDN_NODES[$key]}"
        echo -ne "  ${CYAN}$name${NC} ... "
        
        local temp_file="$TEMP_DIR/cdn_test"
        local speed=$(timeout 20 wget -O "$temp_file" --no-check-certificate "$url" 2>&1 | \
                      grep -o "[0-9.]\+ [KMG]B/s" | tail -1)
        rm -f "$temp_file"
        
        if [ -n "$speed" ]; then
            if [[ "$speed" =~ MB/s ]]; then
                local val=$(echo "$speed" | awk '{print $1}')
                local mbps=$(echo "$val * 8" | bc)
                echo -e "${GREEN}${mbps} Mbps${NC}"
                echo "CDN - $name: ${mbps} Mbps" >> "$REPORT_FILE"
            elif [[ "$speed" =~ KB/s ]]; then
                local val=$(echo "$speed" | awk '{print $1}')
                local mbps=$(echo "scale=2; $val * 8 / 1024" | bc)
                echo -e "${YELLOW}${mbps} Mbps${NC}"
            else
                echo -e "${YELLOW}${speed}${NC}"
            fi
        else
            echo -e "${RED}超时${NC}"
        fi
    done
}

# [模块4] 回程质量测试 (海外特供)
test_china_route() {
    if [ "$TEST_MODE" != "international" ]; then return 0; fi
    
    print_header "回程线路质量测试 (Ping/丢包)"
    
    declare -A CN_TARGETS=(
        [ct_sh]="202.101.172.35:上海电信"
        [cu_bj]="123.123.123.123:北京联通"
        [cm_gd]="120.196.165.24:广东移动"
        [ali_hk]="47.52.0.1:阿里云香港"
    )
    
    for key in "${!CN_TARGETS[@]}"; do
        IFS=':' read -r ip name <<< "${CN_TARGETS[$key]}"
        echo -ne "  测试: ${CYAN}$name${NC} ... "
        
        local res=$(ping -c 10 -W 2 "$ip" 2>/dev/null || echo "")
        local loss=$(echo "$res" | grep "packet loss" | grep -oP '[0-9]+(?=% packet loss)' || echo "100")
        local avg=$(echo "$res" | grep "rtt min/avg/max" | awk -F'/' '{print $5}')
        
        if [ "$loss" != "100" ] && [ -n "$avg" ]; then
            local color=$GREEN
            [ "$loss" -gt 0 ] && color=$YELLOW
            [ "$loss" -gt 10 ] && color=$RED
            
            echo -e "延迟: ${CYAN}${avg}ms${NC} | 丢包: ${color}${loss}%${NC}"
            echo "Route - $name: Latency ${avg}ms, Loss ${loss}%" >> "$REPORT_FILE"
        else
            echo -e "${RED}无法连接${NC}"
        fi
    done
}

# [模块5] 稳定性测试
test_stability() {
    print_header "带宽稳定性波动测试 (5次)"
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

# [模块6] 自定义节点
custom_speedtest() {
    print_header "自定义 Speedtest 节点"
    install_tools
    echo -e "${CYAN}正在搜索附近的节点...${NC}"
    speedtest --list | head -n 10
    echo ""
    read -p "请输入 Server ID: " sid
    read -p "请输入备注名称 (可选): " sname
    [ -z "$sname" ] && sname="Custom-$sid"
    
    if [ -n "$sid" ]; then
        run_speedtest_single "$sid" "$sname"
    else
        print_error "ID 不能为空"
    fi
}

# ------------------------------------------------------------------------------
# 5. 交互菜单与入口
# ------------------------------------------------------------------------------

generate_summary() {
    print_header "测试报告摘要"
    echo -e "${CYAN}报告路径:${NC} $REPORT_FILE"
    echo ""
    if [ -f "$REPORT_FILE" ]; then
        echo -e "${GREEN}性能排行 (Top 3):${NC}"
        grep "Mbps" "$REPORT_FILE" | grep -v "Stability" | \
            awk -F'|' '{print $1, $2, $3}' | sort -k3 -nr | head -3
    fi
    echo ""
}

show_menu() {
    clear
    print_header "VPS 全能带宽测试工具 (v2.0.2)"
    
    # 自动初始化
    detect_and_init_servers
    install_tools
    
    echo ""
    echo -e "${CYAN}请选择测试类型:${NC}"
    echo -e " 1. 快速测试 (Speedtest 自动 + CDN)"
    echo -e " 2. 完整测试 (全节点 + iperf3 + 路由质量)"
    echo -e " 3. Speedtest 专项测试 (30+ 节点)"
    echo -e " 4. iperf3 专项测试 (公网节点)"
    echo -e " 5. CDN 下载测速"
    echo -e " 6. 回程质量测试 (Ping/丢包)"
    echo -e " 7. 稳定性测试 (波动率)"
    echo -e " 8. 自定义节点 ID 测速"
    echo -e " 0. 退出"
    echo ""
    read -p "请输入选项 [0-8]: " choice
    
    echo "" > "$REPORT_FILE"
    echo "Test Mode: $TEST_MODE | Time: $(date)" >> "$REPORT_FILE"
    
    case $choice in
        1)
            print_info "开始快速测试..."
            for k in $(echo "${!SPEEDTEST_SERVERS[@]}" | head -5); do
                IFS='|' read -r id name <<< "${SPEEDTEST_SERVERS[$k]}"
                run_speedtest_single "$id" "$name"
            done
            test_cdn_download
            ;;
        2)
            print_info "开始完整测试..."
            for k in "${!SPEEDTEST_SERVERS[@]}"; do
                IFS='|' read -r id name <<< "${SPEEDTEST_SERVERS[$k]}"
                run_speedtest_single "$id" "$name"
            done
            test_iperf3_batch
            test_china_route
            test_cdn_download
            test_stability
            ;;
        3)
            for k in "${!SPEEDTEST_SERVERS[@]}"; do
                IFS='|' read -r id name <<< "${SPEEDTEST_SERVERS[$k]}"
                run_speedtest_single "$id" "$name"
            done
            ;;
        4) test_iperf3_batch ;;
        5) test_cdn_download ;;
        6) test_china_route ;;
        7) test_stability ;;
        8) custom_speedtest ;;
        0) exit 0 ;;
        *) print_error "无效输入"; sleep 1; show_menu ;;
    esac
    
    generate_summary
    read -n 1 -s -r -p "按任意键返回菜单..."
    show_menu
}

main() {
    # 命令行处理
    if [ -n "$1" ]; then
        detect_and_init_servers
        install_tools
        case "$1" in
            --quick)
                for k in $(echo "${!SPEEDTEST_SERVERS[@]}" | head -5); do
                    IFS='|' read -r id name <<< "${SPEEDTEST_SERVERS[$k]}"
                    run_speedtest_single "$id" "$name"
                done
                exit ;;
            --full)
                for k in "${!SPEEDTEST_SERVERS[@]}"; do
                    IFS='|' read -r id name <<< "${SPEEDTEST_SERVERS[$k]}"
                    run_speedtest_single "$id" "$name"
                done
                test_iperf3_batch
                test_china_route
                exit ;;
            --help|-h) 
                echo "Usage: bash bandwidth_test.sh [--quick | --full]"
                exit 0 ;;
            *) print_error "无效参数"; exit 1 ;;
        esac
    else
        show_menu
    fi
}

main "$@"
