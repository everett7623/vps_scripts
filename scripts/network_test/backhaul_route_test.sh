#!/bin/bash
# ==============================================================================
# 脚本名称: backhaul_route_test.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/network_test/backhaul_route_test.sh
# 描述: VPS 回程路由测试工具
#       测试 VPS 到中国大陆及全球主要地区的回程路由，支持 MTR/Traceroute 分析。
# 作者: Jensfrank (Optimized by AI)
# 版本: 1.2.0 (Architecture Ready)
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
LOG_FILE="$LOG_DIR/backhaul_route_$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="/var/log/vps_scripts/reports"
REPORT_FILE="$REPORT_DIR/backhaul_report_$(date +%Y%m%d_%H%M%S).txt"

# 默认参数
TEST_ALL=false
TEST_CN_ONLY=false
FAST_MODE=false
MAX_HOPS=30
TRACE_METHOD="icmp" # icmp, tcp, udp

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
mkdir -p "$LOG_DIR" "$REPORT_DIR"

# ------------------------------------------------------------------------------
# 2. 测试目标定义 (IP库)
# ------------------------------------------------------------------------------
declare -A TEST_TARGETS

# 中国大陆
TEST_TARGETS[cn_telecom_bj]="219.141.136.12:北京电信"
TEST_TARGETS[cn_telecom_sh]="202.96.209.133:上海电信"
TEST_TARGETS[cn_telecom_gz]="58.60.188.222:广州电信"
TEST_TARGETS[cn_unicom_bj]="202.106.50.1:北京联通"
TEST_TARGETS[cn_unicom_sh]="210.22.97.1:上海联通"
TEST_TARGETS[cn_unicom_gz]="221.5.203.98:广州联通"
TEST_TARGETS[cn_mobile_bj]="221.179.155.161:北京移动"
TEST_TARGETS[cn_mobile_sh]="211.136.112.200:上海移动"
TEST_TARGETS[cn_mobile_gz]="120.196.165.24:广州移动"
TEST_TARGETS[cn_edu]="202.112.0.36:教育网CERNET"

# 国际地区
TEST_TARGETS[asia_hk]="1.1.1.1:香港 Cloudflare"
TEST_TARGETS[asia_jp]="1.0.0.1:日本 Cloudflare"
TEST_TARGETS[asia_sg]="8.8.8.8:新加坡 Google"
TEST_TARGETS[asia_kr]="168.126.63.1:韩国 KT"
TEST_TARGETS[na_us_west]="4.2.2.1:美西 Level3"
TEST_TARGETS[na_us_east]="4.2.2.2:美东 Level3"
TEST_TARGETS[eu_de]="217.79.181.1:德国 Hetzner"
TEST_TARGETS[eu_uk]="8.8.4.4:英国 Google"
TEST_TARGETS[au_sydney]="1.1.1.3:澳洲 Cloudflare"

# ------------------------------------------------------------------------------
# 3. 辅助功能函数
# ------------------------------------------------------------------------------

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

check_dependencies() {
    print_info "检查依赖工具..."
    local deps=("traceroute" "mtr" "ping" "host" "bc" "curl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then missing+=("$dep"); fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_warn "正在安装缺失依赖: ${missing[*]}"
        if command -v apt-get &>/dev/null; then
            apt-get update -qq && apt-get install -y traceroute mtr-tiny iputils-ping dnsutils bc curl &>> "$LOG_FILE"
        elif command -v yum &>/dev/null; then
            yum install -y traceroute mtr iputils bind-utils bc curl &>> "$LOG_FILE"
        elif command -v apk &>/dev/null; then
            apk add --no-cache traceroute mtr iputils bind-tools bc curl &>> "$LOG_FILE"
        else
            print_error "无法自动安装依赖，请手动安装: ${missing[*]}"
            exit 1
        fi
    fi
}

get_local_info() {
    print_info "获取本机网络信息..."
    local ip=$(curl -s -4 --max-time 5 ip.sb 2>/dev/null)
    local info=$(curl -s --max-time 5 "http://ip-api.com/json/${ip}?fields=country,regionName,city,isp,as" 2>/dev/null)
    
    # 简单的 JSON 解析
    local country=$(echo "$info" | grep -oP '"country":"\K[^"]+')
    local isp=$(echo "$info" | grep -oP '"isp":"\K[^"]+')
    
    echo -e "${CYAN}本机 IP:${NC} $ip"
    echo -e "${CYAN}地理位置:${NC} $country"
    echo -e "${CYAN}运营商 :${NC} $isp"
    echo ""
    
    {
        echo "========== 本机信息 =========="
        echo "IP: $ip"
        echo "Location: $country"
        echo "ISP: $isp"
        echo "Time: $(date)"
        echo ""
    } >> "$REPORT_FILE"
}

# ------------------------------------------------------------------------------
# 4. 核心测试逻辑
# ------------------------------------------------------------------------------

analyze_route_output() {
    local output="$1"
    local type="普通线路"
    
    # 关键词匹配路由类型
    if echo "$output" | grep -qE "59.43.|202.97.*59.43"; then type="${PURPLE}CN2 GIA/GT${NC}";
    elif echo "$output" | grep -q "202.97."; then type="${BLUE}电信 163${NC}";
    elif echo "$output" | grep -qE "219.158.|210.78."; then type="${GREEN}联通 4837/9929${NC}";
    elif echo "$output" | grep -qE "223.5.|223.6.|221.176.|221.183."; then type="${YELLOW}移动 CMI${NC}";
    fi
    echo "$type"
}

perform_traceroute() {
    local ip=$1
    local name=$2
    local method=$3
    
    print_info "正在测试 -> $name ($ip)"
    
    # 构建命令
    local cmd="traceroute -I -n -w 2 -m $MAX_HOPS $ip" # Default ICMP
    [ "$method" == "tcp" ] && cmd="traceroute -T -n -w 2 -m $MAX_HOPS $ip"
    [ "$method" == "udp" ] && cmd="traceroute -U -n -w 2 -m $MAX_HOPS $ip"
    
    local result=$($cmd 2>&1)
    
    # 提取关键数据
    local hops=$(echo "$result" | tail -n 1 | awk '{print $1}')
    local last_hop=$(echo "$result" | tail -n 1 | awk '{print $2}')
    local latency=$(echo "$result" | tail -n 1 | awk '{print $3 " ms"}')
    
    # 路由类型分析
    local route_type=$(analyze_route_output "$result")
    
    # 输出结果
    echo -e "  跳数: ${CYAN}$hops${NC} | 延迟: ${GREEN}$latency${NC} | 线路: $route_type"
    echo ""
    
    # 写入报告
    {
        echo "--- $name ($ip) ---"
        echo "Hops: $hops, Latency: $latency"
        echo "$result"
        echo ""
    } >> "$REPORT_FILE"
}

perform_mtr() {
    local ip=$1
    local name=$2
    if ! command -v mtr &>/dev/null; then return; fi
    
    print_info "正在进行 MTR 丢包测试..."
    local mtr_res=$(mtr -r -n -c 10 "$ip" 2>&1)
    local loss=$(echo "$mtr_res" | tail -n 1 | awk '{print $3}')
    
    echo -e "  丢包率: ${RED}$loss%${NC}"
    echo ""
    
    {
        echo "--- MTR: $name ---"
        echo "$mtr_res"
        echo ""
    } >> "$REPORT_FILE"
}

run_test_batch() {
    local filter=$1
    local title=$2
    
    print_header "测试组: $title"
    
    # 排序并遍历目标
    for key in "${!TEST_TARGETS[@]}"; do
        if [[ $key == ${filter}* ]]; then
            IFS=':' read -r ip name <<< "${TEST_TARGETS[$key]}"
            
            # Ping 预检
            local ping_res=$(ping -c 3 -W 1 "$ip" 2>&1 | grep "min/avg" | cut -d'/' -f5)
            if [ -z "$ping_res" ]; then
                echo -e "${RED}[超时]${NC} $name ($ip)"
                continue
            fi
            
            echo -e "目标: ${YELLOW}$name${NC} | Ping: ${GREEN}${ping_res}ms${NC}"
            
            if [ "$FAST_MODE" == "false" ]; then
                perform_traceroute "$ip" "$name" "$TRACE_METHOD"
                # perform_mtr "$ip" "$name" # MTR 耗时较长，默认可注释
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# 5. 交互菜单与入口
# ------------------------------------------------------------------------------

interactive_menu() {
    clear
    print_header "VPS 回程路由测试工具"
    get_local_info
    
    echo -e "${CYAN}请选择测试模式:${NC}"
    echo -e " 1. 中国大陆 (电信/联通/移动/教育网)"
    echo -e " 2. 亚太地区 (HK/JP/SG/KR)"
    echo -e " 3. 欧美地区 (US/DE/UK)"
    echo -e " 4. 完整测试 (所有地区)"
    echo -e " 5. 自定义 IP 测试"
    echo -e " 6. 快速 Ping 模式 (不跑路由)"
    echo -e " 0. 退出"
    echo ""
    read -p "请输入选项 [0-6]: " choice
    
    case $choice in
        1) run_test_batch "cn" "中国大陆方向" ;;
        2) run_test_batch "asia" "亚太地区方向" ;;
        3) 
           run_test_batch "na" "北美方向"
           run_test_batch "eu" "欧洲方向" 
           ;;
        4) 
           run_test_batch "cn" "中国大陆"
           run_test_batch "asia" "亚太"
           run_test_batch "na" "北美"
           run_test_batch "eu" "欧洲"
           ;;
        5)
           read -p "请输入目标 IP 或域名: " target
           read -p "备注名称 (可选): " name
           [ -z "$name" ] && name="Custom Target"
           perform_traceroute "$target" "$name" "$TRACE_METHOD"
           perform_mtr "$target" "$name"
           ;;
        6)
           FAST_MODE=true
           run_test_batch "cn" "中国大陆 (Ping Only)"
           ;;
        0) exit 0 ;;
        *) print_error "无效输入"; sleep 1; interactive_menu ;;
    esac
    
    print_success "测试完成！详细报告已生成: $REPORT_FILE"
}

main() {
    # 权限检查 (ICMP Traceroute 需要 root，UDP/TCP 不需要但建议 root)
    if [ "$TRACE_METHOD" == "icmp" ]; then check_root; fi
    
    check_dependencies
    
    # 命令行处理
    if [ -n "$1" ]; then
        case "$1" in
            --cn) run_test_batch "cn" "中国大陆"; exit ;;
            --all) 
                run_test_batch "cn" "China"
                run_test_batch "asia" "Asia"
                run_test_batch "na" "North America"
                run_test_batch "eu" "Europe"
                exit ;;
            --fast) FAST_MODE=true; run_test_batch "cn" "China (Fast)"; exit ;;
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
