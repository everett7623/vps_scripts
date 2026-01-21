#!/bin/bash
# ==============================================================================
# 脚本名称: backhaul_route_test.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/network_test/backhaul_route_test.sh
# 描述: VPS 回程路由深度测试工具 (表格化增强版)
#       集成 MTR/Traceroute，支持 CN2/9929/CMI 线路智能识别，输出可视化表格报告。
# 作者: Jensfrank (Optimized by AI)
# 版本: 1.3.0 (Table View & Full Logic)
# 更新日期: 2026-01-21
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 环境初始化
# ------------------------------------------------------------------------------

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

LOG_DIR="/var/log/vps_scripts"
REPORT_DIR="$LOG_DIR/reports"
CURRENT_TIME=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/backhaul_${CURRENT_TIME}.log"
REPORT_FILE="$REPORT_DIR/backhaul_report_${CURRENT_TIME}.txt"

# 默认开关
TEST_MODE="standard" # standard, fast(ping only), full(include mtr)
TRACE_METHOD="icmp"  # icmp, tcp, udp
MAX_HOPS=30

# 尝试加载公共库
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"

if [ -f "$LIB_FILE" ]; then
    source "$LIB_FILE"
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
else
    # [Fallback UI]
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'
    print_info() { echo -e "${CYAN}[信息] $1${NC}"; }
    print_warn() { echo -e "${YELLOW}[警告] $1${NC}"; }
    print_error() { echo -e "${RED}[错误] $1${NC}"; }
    print_header() { echo -e "\n${PURPLE}=== $1 ===${NC}\n"; }
    check_root() { [[ $EUID -ne 0 ]] && { echo -e "${RED}需要 root 权限${NC}"; exit 1; }; }
fi

mkdir -p "$LOG_DIR" "$REPORT_DIR"

# ------------------------------------------------------------------------------
# 2. 测试目标库 (完整保留)
# ------------------------------------------------------------------------------
declare -A TARGETS

# 中国大陆 (核心骨干网)
TARGETS[cn_telecom_bj]="219.141.136.12|北京电信"
TARGETS[cn_telecom_sh]="202.96.209.133|上海电信"
TARGETS[cn_telecom_gz]="58.60.188.222|广州电信"
TARGETS[cn_unicom_bj]="202.106.50.1|北京联通"
TARGETS[cn_unicom_sh]="210.22.97.1|上海联通"
TARGETS[cn_unicom_gz]="221.5.203.98|广州联通"
TARGETS[cn_mobile_bj]="221.179.155.161|北京移动"
TARGETS[cn_mobile_sh]="211.136.112.200|上海移动"
TARGETS[cn_mobile_gz]="120.196.165.24|广州移动"
TARGETS[cn_edu]="202.112.0.36|教育网(CERNET)"

# 国际热门
TARGETS[asia_hk]="1.1.1.1|香港 (Cloudflare)"
TARGETS[asia_jp]="1.0.0.1|日本 (Cloudflare)"
TARGETS[asia_sg]="8.8.8.8|新加坡 (Google)"
TARGETS[asia_kr]="168.126.63.1|韩国 (KT)"
TARGETS[na_us_la]="4.2.2.1|美国洛杉矶 (Level3)"
TARGETS[na_us_ny]="4.2.2.2|美国纽约 (Level3)"
TARGETS[eu_de]="217.79.181.1|德国 (Hetzner)"
TARGETS[eu_uk]="8.8.4.4|英国 (Google)"

# ------------------------------------------------------------------------------
# 3. 辅助函数
# ------------------------------------------------------------------------------

log() { echo "[$(date '+%F %T')] $1" >> "$LOG_FILE"; }

check_dependencies() {
    local deps=("traceroute" "mtr" "ping" "host" "bc" "curl" "jq")
    local missing=()
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then missing+=("$dep"); fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_warn "安装缺失依赖: ${missing[*]}"
        if command -v apt-get &>/dev/null; then
            apt-get update -qq && apt-get install -y traceroute mtr-tiny iputils-ping dnsutils bc curl jq &>> "$LOG_FILE"
        elif command -v yum &>/dev/null; then
            yum install -y traceroute mtr iputils bind-utils bc curl jq &>> "$LOG_FILE"
        elif command -v apk &>/dev/null; then
            apk add --no-cache traceroute mtr iputils bind-tools bc curl jq &>> "$LOG_FILE"
        fi
    fi
}

get_local_info() {
    print_info "获取本机网络信息..."
    local ip=$(curl -s -4 --max-time 3 ip.sb 2>/dev/null)
    local info=$(curl -s --max-time 3 "http://ip-api.com/json/${ip}?lang=zh-CN" 2>/dev/null)
    
    local country=$(echo "$info" | grep -oP '"country":"\K[^"]+')
    local isp=$(echo "$info" | grep -oP '"isp":"\K[^"]+')
    local as_info=$(echo "$info" | grep -oP '"as":"\K[^"]+')
    
    echo -e "${CYAN}本机 IP:${NC} $ip ($country)"
    echo -e "${CYAN}运营商 :${NC} $isp"
    echo -e "${CYAN}AS 信息:${NC} $as_info"
    echo ""
    
    {
        echo "=== 本机信息 ==="
        echo "IP: $ip"
        echo "位置: $country"
        echo "ISP: $isp / $as_info"
        echo "时间: $(date)"
        echo ""
    } >> "$REPORT_FILE"
}

# ------------------------------------------------------------------------------
# 4. 核心路由分析 (深度复刻原版逻辑)
# ------------------------------------------------------------------------------

# 智能识别线路类型
analyze_route_type() {
    local trace_output="$1"
    local type="普通线路"
    local color=$NC
    
    # 电信 CN2
    if echo "$trace_output" | grep -qE "59.43"; then
        if echo "$trace_output" | grep -qE "202.97"; then
            type="电信 CN2 GT"
            color=$PURPLE
        else
            type="电信 CN2 GIA"
            color=$GREEN
        fi
    # 电信 163
    elif echo "$trace_output" | grep -qE "202.97"; then
        type="电信 163骨干"
        color=$BLUE
    
    # 联通 9929/10099
    elif echo "$trace_output" | grep -qE "(218.105|210.78|9929)"; then
        type="联通 9929 (AS9929)"
        color=$GREEN
    # 联通 4837
    elif echo "$trace_output" | grep -qE "(219.158|4837)"; then
        type="联通 4837 (AS4837)"
        color=$BLUE
        
    # 移动 CMI
    elif echo "$trace_output" | grep -qE "(223.5|223.6|CMI|cmi)"; then
        type="移动 CMI"
        color=$YELLOW
    fi
    
    echo -e "${color}${type}${NC}"
}

# 单个目标测试函数
test_single_target() {
    local ip=$1
    local name=$2
    local trace_cmd=""
    
    # 1. Ping 测试 (优先)
    local ping_res=$(ping -c 4 -W 1 "$ip" 2>&1)
    local loss=$(echo "$ping_res" | grep -oP '\d+(?=% packet loss)')
    local latency=$(echo "$ping_res" | grep "min/avg" | awk -F '/' '{print $5}')
    
    # 如果 Ping 不通，直接返回
    if [ -z "$latency" ]; then
        printf "%-16s | %-15s | ${RED}%-6s${NC} | ${RED}%-8s${NC} | %-6s | %-15s\n" \
            "${name:0:16}" "$ip" "100%" "超时" "-" "-"
        return
    fi
    
    # 快速模式跳过路由追踪
    if [ "$TEST_MODE" == "fast" ]; then
        printf "%-16s | %-15s | %-6s | %-8s | %-6s | %-15s\n" \
            "${name:0:16}" "$ip" "$loss%" "${latency}ms" "-" "跳过"
        return
    fi
    
    # 2. 路由追踪 (Traceroute)
    case $TRACE_METHOD in
        tcp) trace_cmd="traceroute -T -n -w 1 -q 1 -m $MAX_HOPS $ip" ;;
        udp) trace_cmd="traceroute -U -n -w 1 -q 1 -m $MAX_HOPS $ip" ;;
        *)   trace_cmd="traceroute -I -n -w 1 -q 1 -m $MAX_HOPS $ip" ;; # Default ICMP
    esac
    
    local trace_out=$($trace_cmd 2>&1)
    local hops=$(echo "$trace_out" | tail -n 1 | awk '{print $1}')
    local route_type=$(analyze_route_type "$trace_out")
    
    # 3. MTR 测试 (仅在 Full 模式或高丢包时触发)
    if [ "$TEST_MODE" == "full" ]; then
        mtr -r -n -c 10 "$ip" >> "$REPORT_FILE" 2>&1
    fi
    
    # 输出表格行
    # 格式化颜色输出 (根据延迟变色)
    local lat_color=$GREEN
    if (( $(echo "$latency > 150" | bc -l) )); then lat_color=$YELLOW; fi
    if (( $(echo "$latency > 300" | bc -l) )); then lat_color=$RED; fi
    
    printf "%-16s | %-15s | %-6s | ${lat_color}%-8s${NC} | %-6s | %b\n" \
        "${name:0:16}" "$ip" "$loss%" "${latency}ms" "$hops" "$route_type"
        
    # 保存详细路由到报告
    {
        echo "--- $name ($ip) ---"
        echo "Loss: $loss%, Latency: $latency ms"
        echo "$trace_out"
        echo ""
    } >> "$REPORT_FILE"
}

# ------------------------------------------------------------------------------
# 5. 批量测试逻辑
# ------------------------------------------------------------------------------

run_batch_test() {
    local filter=$1
    local title=$2
    
    echo ""
    print_header "测试组: $title"
    echo "---------------------------------------------------------------------------------"
    printf "%-16s | %-15s | %-6s | %-8s | %-6s | %-15s\n" "目标" "IP地址" "丢包" "延迟" "跳数" "线路类型"
    echo "---------------------------------------------------------------------------------"
    
    # 排序处理
    for key in $(echo "${!TARGETS[@]}" | tr ' ' '\n' | sort); do
        if [[ $key == ${filter}* ]]; then
            IFS='|' read -r ip name <<< "${TARGETS[$key]}"
            test_single_target "$ip" "$name"
        fi
    done
    echo "---------------------------------------------------------------------------------"
    echo ""
}

# 自定义测试
custom_test() {
    echo ""
    read -p "请输入目标 IP 或域名: " target
    read -p "请输入备注名称 (可选): " name
    [ -z "$name" ] && name="Custom"
    
    # 域名解析
    if ! [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_info "正在解析域名 $target ..."
        local resolved=$(host "$target" | grep "has address" | head -1 | awk '{print $4}')
        if [ -n "$resolved" ]; then
            print_info "解析成功: $resolved"
            target=$resolved
        else
            print_error "解析失败"
            return
        fi
    fi
    
    echo "---------------------------------------------------------------------------------"
    printf "%-16s | %-15s | %-6s | %-8s | %-6s | %-15s\n" "目标" "IP地址" "丢包" "延迟" "跳数" "线路类型"
    echo "---------------------------------------------------------------------------------"
    test_single_target "$target" "$name"
    echo "---------------------------------------------------------------------------------"
    
    # MTR 强制执行
    if command -v mtr &>/dev/null; then
        print_info "正在执行 MTR 深度测试 (10秒)..."
        mtr -r -n -c 10 "$target"
    fi
}

# ------------------------------------------------------------------------------
# 6. 交互菜单与入口
# ------------------------------------------------------------------------------

interactive_menu() {
    clear
    print_header "VPS 回程路由可视化测试"
    get_local_info
    
    echo -e "${CYAN}请选择测试模式:${NC}"
    echo -e " 1. 中国大陆三网 (电信/联通/移动)"
    echo -e " 2. 亚太地区 (HK/JP/SG/KR)"
    echo -e " 3. 欧美地区 (US/DE/UK)"
    echo -e " 4. 完整全量测试 (耗时较长)"
    echo -e " 5. 自定义 IP 测试 (含 MTR)"
    echo -e " 6. 快速 Ping 模式 (不跑路由)"
    echo -e " 0. 退出"
    echo ""
    read -p "请输入选项 [0-6]: " choice
    
    case $choice in
        1) run_batch_test "cn" "中国大陆方向" ;;
        2) run_batch_test "asia" "亚太地区" ;;
        3) 
           run_batch_test "na" "北美地区"
           run_batch_test "eu" "欧洲地区" 
           ;;
        4) 
           run_batch_test "cn" "中国大陆"
           run_batch_test "asia" "亚太"
           run_batch_test "na" "北美"
           run_batch_test "eu" "欧洲"
           ;;
        5) custom_test ;;
        6) 
           TEST_MODE="fast"
           run_batch_test "cn" "中国大陆 (Ping Only)"
           ;;
        0) exit 0 ;;
        *) print_error "无效输入"; sleep 1; interactive_menu ;;
    esac
    
    print_success "测试结束！"
    print_info "详细追踪日志已保存至: $REPORT_FILE"
}

main() {
    if [ "$TRACE_METHOD" == "icmp" ]; then check_root; fi
    check_dependencies
    
    # 命令行处理
    if [ -n "$1" ]; then
        case "$1" in
            --cn) run_batch_test "cn" "China"; exit ;;
            --all) 
                run_batch_test "cn" "China"
                run_batch_test "asia" "Asia"
                run_batch_test "na" "North America"
                run_batch_test "eu" "Europe"
                exit ;;
            --fast) TEST_MODE="fast"; run_batch_test "cn" "China (Fast)"; exit ;;
            --help|-h) 
                echo "Usage: bash backhaul_route_test.sh [--cn | --all | --fast]"
                exit 0 ;;
            *) print_error "无效参数"; exit 1 ;;
        esac
    else
        interactive_menu
    fi
}

main "$@"
