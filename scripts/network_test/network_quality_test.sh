#!/bin/bash

#==============================================================================
# 脚本名称: network_quality_test.sh
# 描述: VPS综合网络质量测试脚本 - 包含延迟、丢包、端口、连通性等全面测试
# 作者: Jensfrank
# 路径: vps_scripts/scripts/network_test/network_quality_test.sh
# 使用方法: bash network_quality_test.sh [选项]
# 选项: --basic (基础测试) --full (完整测试) --port (端口扫描)
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
LOG_FILE="$LOG_DIR/network_quality_$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="/var/log/vps_scripts/reports"
REPORT_FILE="$REPORT_DIR/network_quality_$(date +%Y%m%d_%H%M%S).txt"
TEMP_DIR="/tmp/network_quality_$$"

# 测试模式
BASIC_MODE=false
FULL_MODE=false
PORT_SCAN=false

# 测试参数
PING_COUNT=10
PING_TIMEOUT=5
MTR_COUNT=20
PORT_TIMEOUT=2

# 测试目标
declare -A PING_TARGETS
PING_TARGETS[google_dns]="8.8.8.8:谷歌DNS"
PING_TARGETS[cloudflare_dns]="1.1.1.1:Cloudflare"
PING_TARGETS[cn_baidu]="baidu.com:百度"
PING_TARGETS[cn_aliyun]="223.5.5.5:阿里DNS"
PING_TARGETS[cn_dnspod]="119.29.29.29:腾讯DNS"
PING_TARGETS[jp_google]="8.8.8.8:日本谷歌"
PING_TARGETS[sg_google]="8.8.8.8:新加坡谷歌"
PING_TARGETS[us_google]="8.8.8.8:美国谷歌"
PING_TARGETS[eu_google]="8.8.8.8:欧洲谷歌"

# 常用端口列表
declare -A COMMON_PORTS
COMMON_PORTS[ssh]="22:SSH"
COMMON_PORTS[http]="80:HTTP"
COMMON_PORTS[https]="443:HTTPS"
COMMON_PORTS[ftp]="21:FTP"
COMMON_PORTS[smtp]="25:SMTP"
COMMON_PORTS[pop3]="110:POP3"
COMMON_PORTS[imap]="143:IMAP"
COMMON_PORTS[smtps]="465:SMTPS"
COMMON_PORTS[submission]="587:Submission"
COMMON_PORTS[imaps]="993:IMAPS"
COMMON_PORTS[pop3s]="995:POP3S"
COMMON_PORTS[mysql]="3306:MySQL"
COMMON_PORTS[postgresql]="5432:PostgreSQL"
COMMON_PORTS[redis]="6379:Redis"
COMMON_PORTS[mongodb]="27017:MongoDB"
COMMON_PORTS[rdp]="3389:RDP"
COMMON_PORTS[vnc]="5900:VNC"

# 创建必要目录
create_directories() {
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    [ ! -d "$REPORT_DIR" ] && mkdir -p "$REPORT_DIR"
    [ ! -d "$TEMP_DIR" ] && mkdir -p "$TEMP_DIR"
}

# 清理临时文件
cleanup() {
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

# 日志记录
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 打印消息
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
    log "$msg"
}

# 检查依赖工具
check_dependencies() {
    local deps=("ping" "nc" "nmap" "dig" "mtr" "ss" "iperf3")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_msg "$YELLOW" "缺少工具: ${missing[*]}，正在安装..."
        
        if command -v apt-get &> /dev/null; then
            apt-get update -qq
            apt-get install -y iputils-ping netcat-openbsd nmap dnsutils mtr-tiny iproute2 iperf3 &>> "$LOG_FILE"
        elif command -v yum &> /dev/null; then
            yum install -y iputils nc nmap bind-utils mtr iproute iperf3 &>> "$LOG_FILE"
        fi
    fi
}

# 获取网络信息
get_network_info() {
    print_msg "$BLUE" "========== 网络基本信息 =========="
    
    # 公网IP
    local public_ip=$(curl -s -4 --max-time 5 ip.sb 2>/dev/null)
    local public_ip6=$(curl -s -6 --max-time 5 ip.sb 2>/dev/null)
    
    echo -e "${CYAN}公网IP信息:${NC}"
    echo -e "  IPv4: ${public_ip:-未检测到}"
    echo -e "  IPv6: ${public_ip6:-未检测到}"
    
    # IP详细信息
    if [ -n "$public_ip" ]; then
        local ip_info=$(curl -s --max-time 5 "http://ip-api.com/json/${public_ip}?fields=country,regionName,city,isp,as,org" 2>/dev/null)
        if [ -n "$ip_info" ]; then
            local country=$(echo "$ip_info" | grep -oP '"country":\s*"\K[^"]+' || echo "未知")
            local city=$(echo "$ip_info" | grep -oP '"city":\s*"\K[^"]+' || echo "未知")
            local isp=$(echo "$ip_info" | grep -oP '"isp":\s*"\K[^"]+' || echo "未知")
            local org=$(echo "$ip_info" | grep -oP '"org":\s*"\K[^"]+' || echo "未知")
            
            echo -e "  位置: $country - $city"
            echo -e "  ISP: $isp"
            echo -e "  组织: $org"
        fi
    fi
    
    # 网络接口信息
    echo -e "\n${CYAN}网络接口:${NC}"
    ip -o link show | grep -v lo | while read -r line; do
        local iface=$(echo "$line" | awk -F': ' '{print $2}')
        local state=$(echo "$line" | grep -oP 'state \K\w+')
        local mtu=$(echo "$line" | grep -oP 'mtu \K\d+')
        echo -e "  $iface: 状态=$state, MTU=$mtu"
    done
    
    # DNS服务器
    echo -e "\n${CYAN}DNS服务器:${NC}"
    if [ -f /etc/resolv.conf ]; then
        grep "^nameserver" /etc/resolv.conf | awk '{print "  " $2}'
    fi
    
    # 保存到报告
    {
        echo "========== 网络基本信息 =========="
        echo "IPv4: $public_ip"
        echo "IPv6: $public_ip6"
        [ -n "$country" ] && echo "位置: $country - $city"
        [ -n "$isp" ] && echo "ISP: $isp"
        echo ""
    } >> "$REPORT_FILE"
}

# 延迟测试
latency_test() {
    print_msg "$BLUE" "\n========== 延迟测试 =========="
    
    local results=()
    
    for key in "${!PING_TARGETS[@]}"; do
        IFS=':' read -r target name <<< "${PING_TARGETS[$key]}"
        
        # 执行ping测试
        local ping_result=$(ping -c $PING_COUNT -W $PING_TIMEOUT "$target" 2>&1)
        
        if echo "$ping_result" | grep -q "min/avg/max"; then
            local stats=$(echo "$ping_result" | grep "min/avg/max" | awk -F'=' '{print $2}')
            local loss=$(echo "$ping_result" | grep -oP '\d+(?=% packet loss)')
            
            IFS='/' read -r min avg max mdev <<< "$stats"
            
            echo -e "${GREEN}$name ($target):${NC}"
            echo -e "  延迟: 最小=${min}ms 平均=${avg}ms 最大=${max}ms"
            echo -e "  丢包率: ${loss}%"
            
            # 评估延迟质量
            local quality="未知"
            local avg_num=$(echo "$avg" | cut -d'.' -f1)
            if [ "$loss" -eq 0 ] && [ "$avg_num" -lt 50 ]; then
                quality="${GREEN}优秀${NC}"
            elif [ "$loss" -lt 5 ] && [ "$avg_num" -lt 100 ]; then
                quality="${YELLOW}良好${NC}"
            elif [ "$loss" -lt 10 ] && [ "$avg_num" -lt 200 ]; then
                quality="${YELLOW}一般${NC}"
            else
                quality="${RED}较差${NC}"
            fi
            
            echo -e "  质量评估: $quality"
            echo ""
            
            # 保存结果
            results+=("$name:$avg:$loss")
            
            {
                echo "$name ($target):"
                echo "  延迟: min=$min avg=$avg max=$max"
                echo "  丢包: $loss%"
                echo ""
            } >> "$REPORT_FILE"
        else
            echo -e "${RED}$name ($target): 无法连接${NC}"
            results+=("$name:999:100")
        fi
    done
    
    # 生成延迟总结
    echo -e "${CYAN}延迟测试总结:${NC}"
    printf "%-20s %-15s %-10s\n" "目标" "平均延迟" "丢包率"
    printf "%-20s %-15s %-10s\n" "----" "--------" "------"
    
    for result in "${results[@]}"; do
        IFS=':' read -r name avg loss <<< "$result"
        printf "%-20s %-15s %-10s\n" "$name" "${avg}ms" "${loss}%"
    done
}

# MTU探测
mtu_discovery() {
    print_msg "$BLUE" "\n========== MTU探测 =========="
    
    local target="8.8.8.8"
    local max_mtu=1500
    local min_mtu=500
    local current_mtu=$max_mtu
    local optimal_mtu=0
    
    print_msg "$CYAN" "探测到 $target 的最佳MTU..."
    
    while [ $((max_mtu - min_mtu)) -gt 1 ]; do
        if ping -c 1 -W 2 -M do -s $((current_mtu - 28)) "$target" &>/dev/null; then
            min_mtu=$current_mtu
            optimal_mtu=$current_mtu
        else
            max_mtu=$current_mtu
        fi
        current_mtu=$(((max_mtu + min_mtu) / 2))
    done
    
    echo -e "${GREEN}最佳MTU: $optimal_mtu${NC}"
    echo "最佳MTU: $optimal_mtu" >> "$REPORT_FILE"
    
    # 检查巨型帧支持
    if ping -c 1 -W 2 -M do -s 8972 "$target" &>/dev/null; then
        echo -e "${GREEN}支持巨型帧 (Jumbo Frames)${NC}"
        echo "巨型帧: 支持" >> "$REPORT_FILE"
    else
        echo -e "${YELLOW}不支持巨型帧${NC}"
        echo "巨型帧: 不支持" >> "$REPORT_FILE"
    fi
}

# 端口扫描
port_scan() {
    print_msg "$BLUE" "\n========== 端口扫描 =========="
    
    # 扫描本地监听端口
    echo -e "${CYAN}本地监听端口:${NC}"
    local listening_ports=$(ss -tlnp 2>/dev/null | awk 'NR>1 {print $4}' | grep -oE '[0-9]+$' | sort -nu)
    
    for port in $listening_ports; do
        local service=""
        for key in "${!COMMON_PORTS[@]}"; do
            IFS=':' read -r p s <<< "${COMMON_PORTS[$key]}"
            if [ "$p" = "$port" ]; then
                service=" ($s)"
                break
            fi
        done
        echo "  $port$service"
    done
    
    # 端口可达性测试
    if [ "$PORT_SCAN" = true ]; then
        echo -e "\n${CYAN}常用端口可达性测试:${NC}"
        
        local test_host=${1:-"scanme.nmap.org"}
        
        for key in "${!COMMON_PORTS[@]}"; do
            IFS=':' read -r port service <<< "${COMMON_PORTS[$key]}"
            
            if timeout $PORT_TIMEOUT bash -c "echo >/dev/tcp/$test_host/$port" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $service (端口 $port): 开放"
            else
                echo -e "  ${RED}✗${NC} $service (端口 $port): 关闭"
            fi
        done
    fi
    
    # 防火墙规则检查
    echo -e "\n${CYAN}防火墙状态:${NC}"
    if command -v ufw &> /dev/null && ufw status &> /dev/null; then
        local ufw_status=$(ufw status | head -1)
        echo "  UFW: $ufw_status"
    elif command -v firewall-cmd &> /dev/null; then
        local firewalld_status=$(firewall-cmd --state 2>/dev/null || echo "未运行")
        echo "  Firewalld: $firewalld_status"
    elif command -v iptables &> /dev/null; then
        local iptables_rules=$(iptables -L -n 2>/dev/null | wc -l)
        echo "  iptables: $iptables_rules 条规则"
    else
        echo "  未检测到防火墙"
    fi
}

# DNS解析测试
dns_test() {
    print_msg "$BLUE" "\n========== DNS解析测试 =========="
    
    local test_domains=(
        "google.com"
        "baidu.com"
        "cloudflare.com"
        "github.com"
        "amazon.com"
    )
    
    local dns_servers=(
        "8.8.8.8:谷歌DNS"
        "1.1.1.1:Cloudflare"
        "223.5.5.5:阿里DNS"
        "119.29.29.29:腾讯DNS"
    )
    
    echo -e "${CYAN}DNS响应时间测试:${NC}"
    
    for dns_info in "${dns_servers[@]}"; do
        IFS=':' read -r dns name <<< "$dns_info"
        echo -e "\n${GREEN}$name ($dns):${NC}"
        
        local total_time=0
        local success=0
        
        for domain in "${test_domains[@]}"; do
            local start_time=$(date +%s.%N)
            
            if dig @"$dns" "$domain" +short +time=2 +tries=1 &>/dev/null; then
                local end_time=$(date +%s.%N)
                local query_time=$(echo "scale=2; ($end_time - $start_time) * 1000" | bc)
                printf "  %-20s: %6.2f ms\n" "$domain" "$query_time"
                total_time=$(echo "scale=2; $total_time + $query_time" | bc)
                ((success++))
            else
                printf "  %-20s: %s\n" "$domain" "失败"
            fi
        done
        
        if [ $success -gt 0 ]; then
            local avg_time=$(echo "scale=2; $total_time / $success" | bc)
            echo -e "  平均响应时间: ${avg_time} ms"
        fi
    done
    
    # DNS劫持检测
    echo -e "\n${CYAN}DNS劫持检测:${NC}"
    
    # 检测已知的DNS污染域名
    local test_result=$(dig @8.8.8.8 facebook.com +short 2>/dev/null)
    if [ -n "$test_result" ]; then
        # 检查是否返回了虚假IP
        if echo "$test_result" | grep -qE "(127\.0\.0\.1|0\.0\.0\.0|1\.1\.1\.1)"; then
            echo -e "${RED}检测到可能的DNS劫持${NC}"
        else
            echo -e "${GREEN}未检测到DNS劫持${NC}"
        fi
    fi
}

# TCP/UDP连通性测试
connectivity_test() {
    print_msg "$BLUE" "\n========== 连通性测试 =========="
    
    # TCP连通性测试
    echo -e "${CYAN}TCP连通性测试:${NC}"
    
    local tcp_targets=(
        "google.com:80:HTTP"
        "google.com:443:HTTPS"
        "1.1.1.1:53:DNS"
        "github.com:22:SSH"
    )
    
    for target_info in "${tcp_targets[@]}"; do
        IFS=':' read -r host port service <<< "$target_info"
        
        if timeout 3 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $service ($host:$port)"
        else
            echo -e "  ${RED}✗${NC} $service ($host:$port)"
        fi
    done
    
    # UDP连通性测试
    echo -e "\n${CYAN}UDP连通性测试:${NC}"
    
    # DNS查询测试UDP 53端口
    if timeout 3 dig @8.8.8.8 google.com +short &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} DNS UDP (8.8.8.8:53)"
    else
        echo -e "  ${RED}✗${NC} DNS UDP (8.8.8.8:53)"
    fi
    
    # NTP测试UDP 123端口
    if command -v ntpdate &> /dev/null; then
        if timeout 3 ntpdate -q pool.ntp.org &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} NTP UDP (pool.ntp.org:123)"
        else
            echo -e "  ${RED}✗${NC} NTP UDP (pool.ntp.org:123)"
        fi
    fi
}

# 路由路径质量分析
route_quality_test() {
    print_msg "$BLUE" "\n========== 路由质量分析 =========="
    
    local targets=(
        "8.8.8.8:谷歌DNS"
        "1.1.1.1:Cloudflare"
        "223.5.5.5:阿里云"
    )
    
    if ! command -v mtr &> /dev/null; then
        print_msg "$YELLOW" "未安装mtr，跳过路由质量分析"
        return
    fi
    
    for target_info in "${targets[@]}"; do
        IFS=':' read -r ip name <<< "$target_info"
        
        echo -e "${CYAN}到 $name ($ip) 的路由质量:${NC}"
        
        # 使用mtr进行测试
        local mtr_result=$(mtr -r -c $MTR_COUNT -n "$ip" 2>/dev/null)
        
        # 分析结果
        local hop_count=$(echo "$mtr_result" | grep -c "^[[:space:]]*[0-9]")
        local high_loss_hops=$(echo "$mtr_result" | awk '$3 > 5 {print $2 " (丢包:" $3 "%)"}')
        local high_latency_hops=$(echo "$mtr_result" | awk '$5 > 200 {print $2 " (延迟:" $5 "ms)"}')
        
        echo "  总跳数: $hop_count"
        
        if [ -n "$high_loss_hops" ]; then
            echo -e "  ${YELLOW}高丢包节点:${NC}"
            echo "$high_loss_hops" | sed 's/^/    /'
        fi
        
        if [ -n "$high_latency_hops" ]; then
            echo -e "  ${YELLOW}高延迟节点:${NC}"
            echo "$high_latency_hops" | sed 's/^/    /'
        fi
        
        echo ""
        
        # 保存到报告
        {
            echo "路由到 $name ($ip):"
            echo "$mtr_result"
            echo ""
        } >> "$REPORT_FILE"
    done
}

# 网络性能评分
calculate_network_score() {
    print_msg "$BLUE" "\n========== 网络质量评分 =========="
    
    local score=100
    local deductions=""
    
    # 分析延迟
    local avg_latency=$(grep "平均延迟" "$REPORT_FILE" 2>/dev/null | awk -F'=' '{sum+=$3; count++} END {if(count>0) print sum/count; else print 999}')
    if (( $(echo "$avg_latency > 200" | bc -l) )); then
        score=$((score - 20))
        deductions+="\n  - 高延迟 (-20分)"
    elif (( $(echo "$avg_latency > 100" | bc -l) )); then
        score=$((score - 10))
        deductions+="\n  - 中等延迟 (-10分)"
    fi
    
    # 分析丢包
    local avg_loss=$(grep "丢包:" "$REPORT_FILE" 2>/dev/null | awk -F':' '{sum+=$2; count++} END {if(count>0) print sum/count; else print 0}' | cut -d'%' -f1)
    if (( $(echo "$avg_loss > 5" | bc -l) )); then
        score=$((score - 25))
        deductions+="\n  - 严重丢包 (-25分)"
    elif (( $(echo "$avg_loss > 1" | bc -l) )); then
        score=$((score - 10))
        deductions+="\n  - 轻微丢包 (-10分)"
    fi
    
    # 显示评分
    echo -e "${CYAN}综合网络质量评分: ${score}/100${NC}"
    
    if [ -n "$deductions" ]; then
        echo -e "\n扣分项:$deductions"
    fi
    
    # 评级
    local grade=""
    if [ $score -ge 90 ]; then
        grade="${GREEN}优秀${NC} - 适合各类应用"
    elif [ $score -ge 75 ]; then
        grade="${GREEN}良好${NC} - 适合大部分应用"
    elif [ $score -ge 60 ]; then
        grade="${YELLOW}一般${NC} - 基本满足日常使用"
    else
        grade="${RED}较差${NC} - 可能影响使用体验"
    fi
    
    echo -e "\n网络等级: $grade"
    
    # 保存评分
    {
        echo ""
        echo "========== 网络质量评分 =========="
        echo "综合评分: ${score}/100"
        echo "网络等级: $(echo "$grade" | sed 's/\x1B\[[0-9;]*m//g')"
    } >> "$REPORT_FILE"
}

# 生成测试报告
generate_report() {
    print_msg "$BLUE" "\n生成测试报告..."
    
    local summary_file="$REPORT_DIR/network_quality_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "       VPS网络质量测试报告"
        echo "=========================================="
        echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "主机名: $(hostname)"
        echo ""
        
        cat "$REPORT_FILE"
        
        echo ""
        echo "详细日志: $LOG_FILE"
        echo "=========================================="
    } | tee "$summary_file"
    
    print_msg "$GREEN" "\n测试报告已保存到: $summary_file"
}

# 基础测试
basic_test() {
    get_network_info
    latency_test
    dns_test
    connectivity_test
}

# 完整测试
full_test() {
    get_network_info
    latency_test
    mtu_discovery
    dns_test
    connectivity_test
    port_scan
    route_quality_test
}

# 交互式菜单
interactive_menu() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                       VPS 综合网络质量测试工具 v1.0                        ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}请选择测试类型:${NC}"
    echo -e "${GREEN}1)${NC} 基础测试 (延迟/DNS/连通性)"
    echo -e "${GREEN}2)${NC} 标准测试 (基础+MTU+端口)"
    echo -e "${GREEN}3)${NC} 完整测试 (所有项目)"
    echo -e "${GREEN}4)${NC} 延迟测试"
    echo -e "${GREEN}5)${NC} DNS测试"
    echo -e "${GREEN}6)${NC} 端口扫描"
    echo -e "${GREEN}7)${NC} 路由质量分析"
    echo -e "${GREEN}0)${NC} 退出"
    echo ""
    
    read -p "请输入选项 [0-7]: " choice
    
    case $choice in
        1)
            BASIC_MODE=true
            basic_test
            calculate_network_score
            generate_report
            ;;
        2)
            basic_test
            mtu_discovery
            port_scan
            calculate_network_score
            generate_report
            ;;
        3)
            FULL_MODE=true
            PORT_SCAN=true
            full_test
            calculate_network_score
            generate_report
            ;;
        4)
            latency_test
            ;;
        5)
            dns_test
            ;;
        6)
            PORT_SCAN=true
            port_scan
            ;;
        7)
            route_quality_test
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

# 显示帮助
show_help() {
    cat << EOF
使用方法: $0 [选项]

选项:
  --basic     基础测试模式
  --full      完整测试模式
  --port      包含端口扫描
  --help, -h  显示此帮助信息

示例:
  $0              # 交互式菜单
  $0 --basic      # 运行基础测试
  $0 --full       # 运行完整测试

测试项目:
  - 网络延迟和丢包率
  - DNS解析性能
  - TCP/UDP连通性
  - MTU探测
  - 端口扫描
  - 路由质量分析

注意:
  - 部分测试需要root权限
  - 完整测试可能需要几分钟
  - 测试结果保存在 $REPORT_DIR
EOF
}

# 解析参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --basic)
                BASIC_MODE=true
                shift
                ;;
            --full)
                FULL_MODE=true
                PORT_SCAN=true
                shift
                ;;
            --port)
                PORT_SCAN=true
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

# 主函数
main() {
    # 初始化
    create_directories
    check_dependencies
    
    # 解析参数
    parse_arguments "$@"
    
    # 开始测试
    log "开始网络质量测试"
    
    {
        echo "========== VPS网络质量测试 =========="
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
    } > "$REPORT_FILE"
    
    if [ "$BASIC_MODE" = true ]; then
        basic_test
        calculate_network_score
        generate_report
    elif [ "$FULL_MODE" = true ]; then
        full_test
        calculate_network_score
        generate_report
    else
        interactive_menu
    fi
    
    print_msg "$GREEN" "\n网络质量测试完成！"
}

# 运行主函数
main "$@"
