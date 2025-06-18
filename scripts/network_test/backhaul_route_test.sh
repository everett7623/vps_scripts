#!/bin/bash

#==============================================================================
# 脚本名称: backhaul_route_test.sh
# 描述: VPS回程路由测试脚本 - 测试VPS到各地的回程路由路径
# 作者: Jensfrank
# 路径: vps_scripts/scripts/network_test/backhaul_route_test.sh
# 使用方法: bash backhaul_route_test.sh [选项]
# 选项: --all (测试所有地区) --cn (仅中国) --fast (快速模式)
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
LOG_FILE="$LOG_DIR/backhaul_route_$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="/var/log/vps_scripts/reports"
REPORT_FILE="$REPORT_DIR/backhaul_route_$(date +%Y%m%d_%H%M%S).txt"

# 测试模式
TEST_ALL=false
TEST_CN_ONLY=false
FAST_MODE=false
MAX_HOPS=30
TRACE_METHOD="icmp"  # icmp, tcp, udp

# 测试目标定义
declare -A TEST_TARGETS

# 中国大陆测试点
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

# 国际测试点
TEST_TARGETS[asia_hk]="1.1.1.1:香港Cloudflare"
TEST_TARGETS[asia_jp]="1.0.0.1:日本Cloudflare"
TEST_TARGETS[asia_sg]="8.8.8.8:新加坡Google"
TEST_TARGETS[asia_kr]="168.126.63.1:韩国KT"

TEST_TARGETS[na_us_west]="4.2.2.1:美国西部Level3"
TEST_TARGETS[na_us_east]="4.2.2.2:美国东部Level3"
TEST_TARGETS[na_ca]="4.4.4.4:加拿大"

TEST_TARGETS[eu_uk]="8.8.4.4:英国Google"
TEST_TARGETS[eu_de]="217.79.181.1:德国Hetzner"
TEST_TARGETS[eu_fr]="91.121.161.184:法国OVH"

TEST_TARGETS[au_sydney]="1.1.1.3:澳大利亚Cloudflare"

# 创建必要目录
create_directories() {
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    [ ! -d "$REPORT_DIR" ] && mkdir -p "$REPORT_DIR"
}

# 检查依赖
check_dependencies() {
    local deps=("traceroute" "mtr" "ping" "host" "bc")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}缺少以下依赖工具: ${missing_deps[*]}${NC}"
        echo -e "${CYAN}正在尝试安装...${NC}"
        
        # 检测包管理器并安装
        if command -v apt-get &> /dev/null; then
            apt-get update -qq
            apt-get install -y traceroute mtr-tiny iputils-ping dnsutils bc &>> "$LOG_FILE"
        elif command -v yum &> /dev/null; then
            yum install -y traceroute mtr iputils bind-utils bc &>> "$LOG_FILE"
        elif command -v apk &> /dev/null; then
            apk add --no-cache traceroute mtr iputils bind-tools bc &>> "$LOG_FILE"
        fi
        
        # 再次检查
        for dep in "${missing_deps[@]}"; do
            if ! command -v "$dep" &> /dev/null; then
                echo -e "${RED}错误: 无法安装 $dep${NC}"
                exit 1
            fi
        done
    fi
}

# 日志记录函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 打印带颜色的消息
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
    log "$msg"
}

# 获取本机信息
get_local_info() {
    print_msg "$BLUE" "获取本机网络信息..."
    
    # 获取公网IP
    local public_ip=$(curl -s -4 --max-time 5 ip.sb 2>/dev/null || curl -s -4 --max-time 5 ifconfig.me 2>/dev/null)
    local public_ip_info=$(curl -s --max-time 5 "http://ip-api.com/json/${public_ip}?fields=country,regionName,city,isp,as" 2>/dev/null)
    
    # 解析IP信息
    local country=$(echo "$public_ip_info" | grep -oP '"country":\s*"\K[^"]+' 2>/dev/null || echo "未知")
    local region=$(echo "$public_ip_info" | grep -oP '"regionName":\s*"\K[^"]+' 2>/dev/null || echo "未知")
    local city=$(echo "$public_ip_info" | grep -oP '"city":\s*"\K[^"]+' 2>/dev/null || echo "未知")
    local isp=$(echo "$public_ip_info" | grep -oP '"isp":\s*"\K[^"]+' 2>/dev/null || echo "未知")
    local as_info=$(echo "$public_ip_info" | grep -oP '"as":\s*"\K[^"]+' 2>/dev/null || echo "未知")
    
    echo -e "${CYAN}本机IP信息:${NC}"
    echo -e "  公网IP: $public_ip"
    echo -e "  位置: $country - $region - $city"
    echo -e "  运营商: $isp"
    echo -e "  AS信息: $as_info"
    echo ""
    
    # 保存到报告
    {
        echo "========== 本机信息 =========="
        echo "公网IP: $public_ip"
        echo "位置: $country - $region - $city"
        echo "运营商: $isp"
        echo "AS信息: $as_info"
        echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
    } >> "$REPORT_FILE"
}

# 执行traceroute测试
perform_traceroute() {
    local target_ip=$1
    local target_name=$2
    local method=$3
    
    print_msg "$CYAN" "测试路由到 $target_name ($target_ip)..."
    
    local trace_cmd=""
    case $method in
        tcp)
            trace_cmd="traceroute -T -n -w 2 -m $MAX_HOPS $target_ip"
            ;;
        udp)
            trace_cmd="traceroute -U -n -w 2 -m $MAX_HOPS $target_ip"
            ;;
        *)
            trace_cmd="traceroute -I -n -w 2 -m $MAX_HOPS $target_ip"
            ;;
    esac
    
    # 执行traceroute
    local trace_output=$($trace_cmd 2>&1)
    local trace_success=$?
    
    # 分析路由结果
    if [ $trace_success -eq 0 ]; then
        analyze_route "$trace_output" "$target_name" "$target_ip"
    else
        print_msg "$RED" "路由测试失败: $target_name"
        echo "错误信息: $trace_output" >> "$LOG_FILE"
    fi
}

# 分析路由路径
analyze_route() {
    local trace_output=$1
    local target_name=$2
    local target_ip=$3
    
    # 保存原始输出
    {
        echo "========== $target_name ($target_ip) =========="
        echo "$trace_output"
        echo ""
    } >> "$REPORT_FILE"
    
    # 统计跳数
    local total_hops=$(echo "$trace_output" | grep -E "^[[:space:]]*[0-9]+" | wc -l)
    local timeout_hops=$(echo "$trace_output" | grep -c "\* \* \*")
    
    # 识别关键节点
    local key_nodes=()
    
    # 检测是否经过中国电信
    if echo "$trace_output" | grep -qE "(202\.97\.|59\.43\.|219\.158\.|221\.4\.)"; then
        key_nodes+=("中国电信")
    fi
    
    # 检测是否经过中国联通
    if echo "$trace_output" | grep -qE "(219\.158\.|221\.6\.|210\.51\.|202\.106\.)"; then
        key_nodes+=("中国联通")
    fi
    
    # 检测是否经过中国移动
    if echo "$trace_output" | grep -qE "(221\.183\.|221\.176\.|211\.136\.|120\.196\.)"; then
        key_nodes+=("中国移动")
    fi
    
    # 检测国际线路
    if echo "$trace_output" | grep -qE "(ntt|telia|cogent|level3|gtt|tata|pccw|singtel)"; then
        key_nodes+=("国际线路")
    fi
    
    # 计算平均延迟（只计算有效跳数）
    local avg_latency=$(echo "$trace_output" | grep -oE "[0-9]+\.[0-9]+ ms" | \
                       awk '{sum+=$1; count++} END {if(count>0) printf "%.2f", sum/count; else print "N/A"}')
    
    # 检测路由类型
    local route_type="未知"
    if echo "$trace_output" | grep -qE "(59\.43\.|202\.97\.|219\.158\.)" && \
       echo "$trace_output" | grep -qE "(163|cn2|gia)"; then
        route_type="CN2线路"
    elif echo "$trace_output" | grep -qE "(59\.43\.|202\.97\.)"; then
        route_type="163骨干网"
    elif echo "$trace_output" | grep -qE "(cmi|移动|mobile)"; then
        route_type="CMI线路"
    elif echo "$trace_output" | grep -qE "(联通|unicom|169)"; then
        route_type="联通AS4837"
    fi
    
    # 显示分析结果
    echo -e "${GREEN}路由分析结果:${NC}"
    echo -e "  目标: $target_name"
    echo -e "  总跳数: $total_hops (超时: $timeout_hops)"
    echo -e "  平均延迟: ${avg_latency}ms"
    echo -e "  路由类型: $route_type"
    [ ${#key_nodes[@]} -gt 0 ] && echo -e "  经过网络: ${key_nodes[*]}"
    echo ""
}

# 执行MTR测试
perform_mtr() {
    local target_ip=$1
    local target_name=$2
    
    if ! command -v mtr &> /dev/null; then
        return
    fi
    
    print_msg "$CYAN" "执行MTR测试到 $target_name..."
    
    # MTR测试（10个包）
    local mtr_output=$(mtr -r -n -c 10 "$target_ip" 2>&1)
    
    {
        echo "========== MTR测试: $target_name =========="
        echo "$mtr_output"
        echo ""
    } >> "$REPORT_FILE"
    
    # 分析丢包情况
    local loss_nodes=$(echo "$mtr_output" | awk '$3 > 0 {print $2 " (丢包:" $3 "%)"}')
    if [ -n "$loss_nodes" ]; then
        echo -e "${YELLOW}发现丢包节点:${NC}"
        echo "$loss_nodes"
        echo ""
    fi
}

# 测试到特定地区
test_region() {
    local region=$1
    local region_name=$2
    
    print_msg "$PURPLE" "\n========== 测试到${region_name}的回程路由 =========="
    
    for key in "${!TEST_TARGETS[@]}"; do
        if [[ $key == ${region}* ]]; then
            IFS=':' read -r ip name <<< "${TEST_TARGETS[$key]}"
            
            # 基础延迟测试
            local ping_result=$(ping -c 3 -W 2 "$ip" 2>&1 | grep -oE "min/avg/max.*=" | cut -d'=' -f2)
            if [ -n "$ping_result" ]; then
                echo -e "${CYAN}到 $name 的延迟:${NC} $ping_result"
            fi
            
            # Traceroute测试
            if [ "$FAST_MODE" = false ]; then
                perform_traceroute "$ip" "$name" "$TRACE_METHOD"
                
                # MTR测试（可选）
                perform_mtr "$ip" "$name"
            fi
            
            sleep 1
        fi
    done
}

# 生成测试摘要
generate_summary() {
    print_msg "$BLUE" "\n生成测试摘要..."
    
    local summary_file="$REPORT_DIR/backhaul_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "       VPS回程路由测试摘要"
        echo "=========================================="
        echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        # 统计各运营商线路质量
        echo "中国电信线路:"
        grep -A5 "北京电信\|上海电信\|广州电信" "$REPORT_FILE" | grep -E "路由类型|平均延迟" || echo "  无数据"
        
        echo ""
        echo "中国联通线路:"
        grep -A5 "北京联通\|上海联通\|广州联通" "$REPORT_FILE" | grep -E "路由类型|平均延迟" || echo "  无数据"
        
        echo ""
        echo "中国移动线路:"
        grep -A5 "北京移动\|上海移动\|广州移动" "$REPORT_FILE" | grep -E "路由类型|平均延迟" || echo "  无数据"
        
        echo ""
        echo "国际线路:"
        grep -A5 "香港\|日本\|新加坡\|美国" "$REPORT_FILE" | grep -E "路由类型|平均延迟" || echo "  无数据"
        
        echo ""
        echo "详细报告: $REPORT_FILE"
        echo "=========================================="
    } | tee "$summary_file"
    
    print_msg "$GREEN" "\n测试摘要已保存到: $summary_file"
}

# 批量测试
batch_test() {
    # 获取本机信息
    get_local_info
    
    if [ "$TEST_CN_ONLY" = true ]; then
        # 仅测试中国大陆
        test_region "cn_telecom" "中国电信"
        test_region "cn_unicom" "中国联通"
        test_region "cn_mobile" "中国移动"
        test_region "cn_edu" "教育网"
    elif [ "$TEST_ALL" = true ]; then
        # 测试所有地区
        test_region "cn_telecom" "中国电信"
        test_region "cn_unicom" "中国联通"
        test_region "cn_mobile" "中国移动"
        test_region "cn_edu" "教育网"
        test_region "asia" "亚太地区"
        test_region "na" "北美地区"
        test_region "eu" "欧洲地区"
        test_region "au" "大洋洲"
    fi
}

# 交互式菜单
interactive_menu() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                         VPS 回程路由测试工具 v1.0                          ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    get_local_info
    
    echo -e "${CYAN}请选择测试选项:${NC}"
    echo -e "${GREEN}1)${NC} 测试到中国大陆 (电信/联通/移动)"
    echo -e "${GREEN}2)${NC} 测试到亚太地区 (香港/日本/新加坡/韩国)"
    echo -e "${GREEN}3)${NC} 测试到欧美地区"
    echo -e "${GREEN}4)${NC} 测试所有地区 (完整测试)"
    echo -e "${GREEN}5)${NC} 自定义目标测试"
    echo -e "${GREEN}6)${NC} 快速模式 (仅ping延迟)"
    echo -e "${GREEN}0)${NC} 退出"
    echo ""
    
    read -p "请输入选项 [0-6]: " choice
    
    case $choice in
        1)
            TEST_CN_ONLY=true
            batch_test
            generate_summary
            ;;
        2)
            test_region "asia" "亚太地区"
            generate_summary
            ;;
        3)
            test_region "na" "北美地区"
            test_region "eu" "欧洲地区"
            generate_summary
            ;;
        4)
            TEST_ALL=true
            batch_test
            generate_summary
            ;;
        5)
            custom_test
            ;;
        6)
            FAST_MODE=true
            TEST_CN_ONLY=true
            batch_test
            ;;
        0)
            print_msg "$YELLOW" "退出程序"
            exit 0
            ;;
        *)
            print_msg "$RED" "无效选项"
            sleep 2
            interactive_menu
            ;;
    esac
}

# 自定义测试
custom_test() {
    echo ""
    read -p "请输入目标IP或域名: " target
    read -p "请输入备注名称 (可选): " name
    
    [ -z "$name" ] && name="自定义目标"
    
    # 解析域名
    if ! [[ "$target" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local resolved_ip=$(host "$target" 2>/dev/null | grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | head -1)
        if [ -n "$resolved_ip" ]; then
            print_msg "$GREEN" "域名解析: $target -> $resolved_ip"
            target=$resolved_ip
        else
            print_msg "$RED" "无法解析域名: $target"
            return
        fi
    fi
    
    # 执行测试
    perform_traceroute "$target" "$name" "$TRACE_METHOD"
    perform_mtr "$target" "$name"
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                TEST_ALL=true
                shift
                ;;
            --cn)
                TEST_CN_ONLY=true
                shift
                ;;
            --fast)
                FAST_MODE=true
                shift
                ;;
            --tcp)
                TRACE_METHOD="tcp"
                shift
                ;;
            --udp)
                TRACE_METHOD="udp"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_msg "$RED" "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 显示帮助信息
show_help() {
    cat << EOF
使用方法: $0 [选项]

选项:
  --all       测试所有地区
  --cn        仅测试中国大陆
  --fast      快速模式(仅ping)
  --tcp       使用TCP方式追踪
  --udp       使用UDP方式追踪
  --help, -h  显示此帮助信息

示例:
  $0              # 交互式菜单
  $0 --cn         # 仅测试中国大陆回程
  $0 --all --fast # 快速测试所有地区

注意:
  - 此脚本需要root权限以使用ICMP
  - 完整测试可能需要较长时间
  - 测试结果保存在 $REPORT_DIR
EOF
}

# 主函数
main() {
    # 初始化
    create_directories
    
    # 检查权限（ICMP需要root）
    if [ "$TRACE_METHOD" = "icmp" ] && [ $EUID -ne 0 ]; then
        print_msg "$YELLOW" "提示: ICMP追踪需要root权限，将使用UDP方式"
        TRACE_METHOD="udp"
    fi
    
    # 检查依赖
    check_dependencies
    
    # 解析参数
    parse_arguments "$@"
    
    # 开始测试
    log "开始回程路由测试"
    
    if [ "$TEST_ALL" = true ] || [ "$TEST_CN_ONLY" = true ]; then
        batch_test
        generate_summary
    else
        interactive_menu
    fi
    
    print_msg "$GREEN" "\n回程路由测试完成！"
    print_msg "$CYAN" "详细报告: $REPORT_FILE"
}

# 运行主函数
main "$@"
