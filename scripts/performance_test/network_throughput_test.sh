#!/bin/bash

#==============================================================================
# 脚本名称: network_throughput_test.sh
# 描述: VPS网络吞吐量测试脚本 - 测试TCP/UDP吞吐量、包转发率、并发连接等
# 作者: Jensfrank
# 路径: vps_scripts/scripts/performance_test/network_throughput_test.sh
# 使用方法: bash network_throughput_test.sh [选项]
# 选项: --server (服务器模式) --client <IP> (客户端模式) --local (本地测试)
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
LOG_FILE="$LOG_DIR/network_throughput_$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="/var/log/vps_scripts/reports"
REPORT_FILE="$REPORT_DIR/network_throughput_$(date +%Y%m%d_%H%M%S).txt"
TEMP_DIR="/tmp/network_throughput_$$"

# 测试模式
SERVER_MODE=false
CLIENT_MODE=false
LOCAL_MODE=false
SERVER_IP=""

# 测试参数
TEST_DURATION=30        # 测试时长(秒)
IPERF_PORT=5201        # iperf3默认端口
PARALLEL_STREAMS=5     # 并行流数量
BUFFER_SIZE="128K"     # 缓冲区大小
TEST_PROTOCOLS=("tcp" "udp")  # 测试协议

# 创建目录
create_directories() {
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    [ ! -d "$REPORT_DIR" ] && mkdir -p "$REPORT_DIR"
    [ ! -d "$TEMP_DIR" ] && mkdir -p "$TEMP_DIR"
}

# 清理
cleanup() {
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
    # 停止可能运行的iperf3服务器
    pkill -f "iperf3.*server" 2>/dev/null
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

# 检查依赖
check_dependencies() {
    local deps=("iperf3" "netperf" "nuttcp" "sockperf" "ethtool" "ss")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_msg "$YELLOW" "缺少依赖工具，正在安装..."
        
        if command -v apt-get &> /dev/null; then
            apt-get update -qq
            apt-get install -y iperf3 netperf nuttcp ethtool iproute2 &>> "$LOG_FILE"
            # sockperf可能需要从源编译
        elif command -v yum &> /dev/null; then
            yum install -y epel-release &>> "$LOG_FILE"
            yum install -y iperf3 netperf nuttcp ethtool iproute &>> "$LOG_FILE"
        elif command -v apk &> /dev/null; then
            apk add --no-cache iperf3 ethtool iproute2 &>> "$LOG_FILE"
        fi
    fi
}

# 获取网络信息
get_network_info() {
    print_msg "$BLUE" "========== 网络接口信息 =========="
    
    # 获取主要网络接口
    local primary_iface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    if [ -n "$primary_iface" ]; then
        echo -e "${CYAN}主接口:${NC} $primary_iface"
        
        # 获取接口信息
        local ip_addr=$(ip addr show "$primary_iface" | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        local mac_addr=$(ip link show "$primary_iface" | grep "link/ether" | awk '{print $2}')
        local mtu=$(ip link show "$primary_iface" | grep -oP 'mtu \K\d+')
        
        echo -e "${CYAN}IP地址:${NC} $ip_addr"
        echo -e "${CYAN}MAC地址:${NC} $mac_addr"
        echo -e "${CYAN}MTU:${NC} $mtu"
        
        # 使用ethtool获取更多信息
        if command -v ethtool &> /dev/null; then
            local speed=$(ethtool "$primary_iface" 2>/dev/null | grep "Speed:" | awk '{print $2}')
            local duplex=$(ethtool "$primary_iface" 2>/dev/null | grep "Duplex:" | awk '{print $2}')
            
            [ -n "$speed" ] && echo -e "${CYAN}链路速度:${NC} $speed"
            [ -n "$duplex" ] && echo -e "${CYAN}双工模式:${NC} $duplex"
            
            # 获取网卡特性
            local features=$(ethtool -k "$primary_iface" 2>/dev/null | grep -E "tcp-segmentation-offload|generic-receive-offload|large-receive-offload" | grep ": on")
            if [ -n "$features" ]; then
                echo -e "${CYAN}启用的特性:${NC}"
                echo "$features" | sed 's/^/  /'
            fi
        fi
        
        # 获取公网IP
        local public_ip=$(curl -s -4 --max-time 5 ip.sb 2>/dev/null)
        [ -n "$public_ip" ] && echo -e "${CYAN}公网IP:${NC} $public_ip"
        
        # 保存信息
        {
            echo "========== 网络信息 =========="
            echo "主接口: $primary_iface"
            echo "内网IP: $ip_addr"
            echo "公网IP: $public_ip"
            echo "MTU: $mtu"
            [ -n "$speed" ] && echo "链路速度: $speed"
            echo ""
        } >> "$REPORT_FILE"
    else
        print_msg "$RED" "无法检测到网络接口"
    fi
}

# iperf3测试
iperf3_test() {
    if ! command -v iperf3 &> /dev/null; then
        print_msg "$YELLOW" "iperf3未安装，跳过测试"
        return
    fi
    
    print_msg "$BLUE" "\n========== iperf3吞吐量测试 =========="
    
    if [ "$SERVER_MODE" = true ]; then
        # 服务器模式
        print_msg "$CYAN" "启动iperf3服务器 (端口: $IPERF_PORT)..."
        iperf3 -s -p $IPERF_PORT --logfile "$TEMP_DIR/iperf3_server.log" &
        local server_pid=$!
        
        print_msg "$GREEN" "iperf3服务器已启动 (PID: $server_pid)"
        print_msg "$YELLOW" "等待客户端连接..."
        print_msg "$YELLOW" "按Ctrl+C退出服务器模式"
        
        # 等待直到用户中断
        wait $server_pid
        
    elif [ "$CLIENT_MODE" = true ]; then
        # 客户端模式
        print_msg "$CYAN" "连接到服务器: $SERVER_IP:$IPERF_PORT"
        
        # TCP测试
        print_msg "$CYAN" "\nTCP吞吐量测试..."
        iperf3 -c "$SERVER_IP" -p $IPERF_PORT -t $TEST_DURATION -P $PARALLEL_STREAMS -f m > "$TEMP_DIR/iperf3_tcp.txt" 2>&1
        
        if [ $? -eq 0 ]; then
            # 提取结果
            local tcp_send=$(grep "sender" "$TEMP_DIR/iperf3_tcp.txt" | tail -1 | awk '{print $(NF-1)" "$NF}')
            local tcp_recv=$(grep "receiver" "$TEMP_DIR/iperf3_tcp.txt" | tail -1 | awk '{print $(NF-1)" "$NF}')
            
            echo -e "${GREEN}TCP发送: $tcp_send${NC}"
            echo -e "${GREEN}TCP接收: $tcp_recv${NC}"
            
            # 保存结果
            {
                echo "========== iperf3 TCP测试 =========="
                echo "服务器: $SERVER_IP"
                echo "并行流: $PARALLEL_STREAMS"
                echo "发送速率: $tcp_send"
                echo "接收速率: $tcp_recv"
                echo ""
            } >> "$REPORT_FILE"
        else
            print_msg "$RED" "TCP测试失败"
        fi
        
        # UDP测试
        print_msg "$CYAN" "\nUDP吞吐量测试..."
        iperf3 -c "$SERVER_IP" -p $IPERF_PORT -u -t $TEST_DURATION -b 1G -f m > "$TEMP_DIR/iperf3_udp.txt" 2>&1
        
        if [ $? -eq 0 ]; then
            # 提取结果
            local udp_speed=$(grep "0.00-$TEST_DURATION" "$TEMP_DIR/iperf3_udp.txt" | tail -1 | awk '{print $(NF-3)" "$NF}')
            local udp_loss=$(grep "0.00-$TEST_DURATION" "$TEMP_DIR/iperf3_udp.txt" | tail -1 | grep -oP '\(\K[^)]+' | grep -oP '[0-9.]+%')
            
            echo -e "${GREEN}UDP速率: $udp_speed${NC}"
            echo -e "${GREEN}UDP丢包: ${udp_loss:-0%}${NC}"
            
            # 保存结果
            {
                echo "========== iperf3 UDP测试 =========="
                echo "UDP速率: $udp_speed"
                echo "UDP丢包: ${udp_loss:-0%}"
                echo ""
            } >> "$REPORT_FILE"
        else
            print_msg "$RED" "UDP测试失败"
        fi
        
    elif [ "$LOCAL_MODE" = true ]; then
        # 本地回环测试
        print_msg "$CYAN" "执行本地回环测试..."
        
        # 启动本地服务器
        iperf3 -s -p $IPERF_PORT --one-off > /dev/null 2>&1 &
        local server_pid=$!
        sleep 2
        
        # 运行客户端
        iperf3 -c 127.0.0.1 -p $IPERF_PORT -t 10 -f m > "$TEMP_DIR/iperf3_local.txt" 2>&1
        
        if [ $? -eq 0 ]; then
            local local_speed=$(grep "receiver" "$TEMP_DIR/iperf3_local.txt" | tail -1 | awk '{print $(NF-1)" "$NF}')
            echo -e "${GREEN}本地回环速度: $local_speed${NC}"
            
            {
                echo "========== 本地回环测试 =========="
                echo "回环速度: $local_speed"
                echo ""
            } >> "$REPORT_FILE"
        fi
        
        kill $server_pid 2>/dev/null
    fi
}

# 网络延迟抖动测试
jitter_test() {
    print_msg "$BLUE" "\n========== 网络延迟抖动测试 =========="
    
    local test_hosts=("8.8.8.8" "1.1.1.1" "223.5.5.5")
    
    for host in "${test_hosts[@]}"; do
        print_msg "$CYAN" "测试到 $host 的延迟抖动..."
        
        # ping测试收集数据
        local ping_output=$(ping -c 100 -i 0.2 "$host" 2>&1)
        
        if echo "$ping_output" | grep -q "min/avg/max/mdev"; then
            local stats=$(echo "$ping_output" | grep "min/avg/max/mdev")
            local mdev=$(echo "$stats" | grep -oP 'mdev = \K[0-9.]+')
            local avg=$(echo "$stats" | grep -oP 'avg = \K[0-9.]+')
            local loss=$(echo "$ping_output" | grep -oP '[0-9]+(?=% packet loss)')
            
            echo -e "${GREEN}  平均延迟: ${avg}ms${NC}"
            echo -e "${GREEN}  抖动(mdev): ${mdev}ms${NC}"
            echo -e "${GREEN}  丢包率: ${loss}%${NC}"
            
            # 评估网络质量
            local quality="未知"
            if [ "$loss" -eq 0 ] && (( $(echo "$mdev < 5" | bc -l) )); then
                quality="${GREEN}优秀${NC}"
            elif [ "$loss" -lt 1 ] && (( $(echo "$mdev < 20" | bc -l) )); then
                quality="${YELLOW}良好${NC}"
            elif [ "$loss" -lt 5 ] && (( $(echo "$mdev < 50" | bc -l) )); then
                quality="${YELLOW}一般${NC}"
            else
                quality="${RED}较差${NC}"
            fi
            
            echo -e "  网络质量: $quality"
            echo ""
            
            # 保存结果
            {
                echo "延迟抖动测试 - $host:"
                echo "  平均延迟: ${avg}ms"
                echo "  抖动: ${mdev}ms"
                echo "  丢包率: ${loss}%"
                echo ""
            } >> "$REPORT_FILE"
        else
            echo -e "${RED}  测试失败${NC}"
        fi
    done
}

# 并发连接测试
concurrent_connection_test() {
    print_msg "$BLUE" "\n========== 并发连接测试 =========="
    
    # 检查当前系统限制
    local max_files=$(ulimit -n)
    local tcp_mem=$(cat /proc/sys/net/ipv4/tcp_mem 2>/dev/null | awk '{print $2}')
    
    echo -e "${CYAN}系统限制:${NC}"
    echo -e "  最大文件描述符: $max_files"
    [ -n "$tcp_mem" ] && echo -e "  TCP内存限制: $tcp_mem pages"
    
    # 使用ss统计当前连接
    print_msg "$CYAN" "\n当前连接状态:"
    
    local established=$(ss -s | grep "estab" | grep -oP '\d+' | head -1)
    local time_wait=$(ss -s | grep "timewait" | grep -oP '\d+' | head -1)
    local total_sockets=$(ss -s | grep "Total:" | awk '{print $2}')
    
    echo -e "  已建立连接: ${established:-0}"
    echo -e "  TIME_WAIT: ${time_wait:-0}"
    echo -e "  总socket数: ${total_sockets:-0}"
    
    # 测试并发连接能力
    if command -v nuttcp &> /dev/null; then
        print_msg "$CYAN" "\n测试并发连接能力..."
        
        # 使用nuttcp测试多连接
        for i in {1..5}; do
            echo -ne "\r测试 $i 个并发连接..."
            nuttcp -T 5 -P $i 127.0.0.1 > "$TEMP_DIR/concurrent_$i.txt" 2>&1 &
        done
        
        wait
        echo ""
        
        # 分析结果
        local total_throughput=0
        for i in {1..5}; do
            if [ -f "$TEMP_DIR/concurrent_$i.txt" ]; then
                local throughput=$(grep -oP '\d+\.\d+ Mbps' "$TEMP_DIR/concurrent_$i.txt" | tail -1 | awk '{print $1}')
                [ -n "$throughput" ] && total_throughput=$(echo "$total_throughput + $throughput" | bc)
            fi
        done
        
        echo -e "${GREEN}5个并发连接总吞吐量: ${total_throughput} Mbps${NC}"
    fi
    
    # 保存结果
    {
        echo "========== 并发连接测试 =========="
        echo "系统限制: $max_files"
        echo "当前连接: $established"
        echo "TIME_WAIT: $time_wait"
        [ -n "$total_throughput" ] && echo "并发吞吐量: ${total_throughput} Mbps"
        echo ""
    } >> "$REPORT_FILE"
}

# 包转发率测试
packet_rate_test() {
    print_msg "$BLUE" "\n========== 包转发率测试 =========="
    
    # 使用hping3测试小包性能（如果可用）
    if command -v hping3 &> /dev/null; then
        print_msg "$CYAN" "测试小包转发性能..."
        
        # 64字节包测试
        local small_packet_test=$(timeout 10 hping3 -c 10000 -d 20 -S -w 64 -p 80 --fast 127.0.0.1 2>&1)
        local pps=$(echo "$small_packet_test" | grep -oP '\d+ packets transmitted' | awk '{print $1/10 " pps"}')
        
        if [ -n "$pps" ]; then
            echo -e "${GREEN}小包转发率: $pps${NC}"
        fi
    fi
    
    # 使用iperf3测试不同包大小
    if command -v iperf3 &> /dev/null; then
        print_msg "$CYAN" "\n测试不同包大小的性能..."
        
        # 启动本地服务器
        iperf3 -s -p $((IPERF_PORT + 1)) --one-off > /dev/null 2>&1 &
        local server_pid=$!
        sleep 2
        
        local packet_sizes=("64" "128" "256" "512" "1024" "1400")
        
        for size in "${packet_sizes[@]}"; do
            echo -ne "\r测试 ${size}字节 包..."
            
            iperf3 -c 127.0.0.1 -p $((IPERF_PORT + 1)) -u -l $size -t 5 -f k > "$TEMP_DIR/packet_$size.txt" 2>&1
            
            if [ -f "$TEMP_DIR/packet_$size.txt" ]; then
                local rate=$(grep -oP '\d+\.\d+ Kbits/sec' "$TEMP_DIR/packet_$size.txt" | tail -1)
                echo -e "\r${GREEN}${size}字节包: $rate${NC}"
            fi
        done
        
        kill $server_pid 2>/dev/null
    fi
}

# 网络栈性能测试
network_stack_test() {
    print_msg "$BLUE" "\n========== 网络栈性能测试 =========="
    
    # TCP参数检查
    print_msg "$CYAN" "TCP优化参数:"
    
    local tcp_params=(
        "net.ipv4.tcp_congestion_control"
        "net.core.rmem_max"
        "net.core.wmem_max"
        "net.ipv4.tcp_rmem"
        "net.ipv4.tcp_wmem"
        "net.core.netdev_max_backlog"
    )
    
    for param in "${tcp_params[@]}"; do
        local value=$(sysctl -n "$param" 2>/dev/null)
        if [ -n "$value" ]; then
            echo -e "  $param = $value"
        fi
    done
    
    # 检查网卡队列
    local primary_iface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -n "$primary_iface" ]; then
        print_msg "$CYAN" "\n网卡队列配置:"
        
        # RX/TX队列数
        local rx_queues=$(ls /sys/class/net/$primary_iface/queues/ 2>/dev/null | grep -c "rx-")
        local tx_queues=$(ls /sys/class/net/$primary_iface/queues/ 2>/dev/null | grep -c "tx-")
        
        echo -e "  RX队列数: $rx_queues"
        echo -e "  TX队列数: $tx_queues"
        
        # 中断分布
        if [ -f /proc/interrupts ]; then
            local irq_count=$(grep "$primary_iface" /proc/interrupts 2>/dev/null | wc -l)
            echo -e "  中断数: $irq_count"
        fi
    fi
}

# HTTP性能测试
http_performance_test() {
    print_msg "$BLUE" "\n========== HTTP性能测试 =========="
    
    # 使用curl测试HTTP性能
    local test_urls=(
        "http://www.google.com"
        "http://www.cloudflare.com"
        "http://www.baidu.com"
    )
    
    for url in "${test_urls[@]}"; do
        print_msg "$CYAN" "测试 $url..."
        
        # 测试连接性能
        local curl_output=$(curl -o /dev/null -s -w '%{time_namelookup} %{time_connect} %{time_starttransfer} %{time_total} %{speed_download}\n' "$url" 2>&1)
        
        if [ $? -eq 0 ]; then
            local dns_time=$(echo "$curl_output" | awk '{print $1}')
            local connect_time=$(echo "$curl_output" | awk '{print $2}')
            local ttfb=$(echo "$curl_output" | awk '{print $3}')
            local total_time=$(echo "$curl_output" | awk '{print $4}')
            local speed=$(echo "$curl_output" | awk '{print $5}')
            
            # 转换为毫秒
            dns_time=$(echo "$dns_time * 1000" | bc)
            connect_time=$(echo "$connect_time * 1000" | bc)
            ttfb=$(echo "$ttfb * 1000" | bc)
            total_time=$(echo "$total_time * 1000" | bc)
            
            # 转换速度为Mbps
            speed=$(echo "scale=2; $speed * 8 / 1000000" | bc)
            
            echo -e "  DNS解析: ${dns_time}ms"
            echo -e "  建立连接: ${connect_time}ms"
            echo -e "  首字节时间: ${ttfb}ms"
            echo -e "  总时间: ${total_time}ms"
            echo -e "  下载速度: ${speed} Mbps"
            echo ""
            
            # 保存结果
            {
                echo "HTTP测试 - $url:"
                echo "  DNS: ${dns_time}ms"
                echo "  连接: ${connect_time}ms"
                echo "  TTFB: ${ttfb}ms"
                echo "  速度: ${speed} Mbps"
                echo ""
            } >> "$REPORT_FILE"
        else
            echo -e "${RED}  测试失败${NC}"
        fi
    done
}

# 计算性能评分
calculate_score() {
    print_msg "$BLUE" "\n========== 网络性能评分 =========="
    
    # 提取测试数据进行评分
    local tcp_speed=$(grep "TCP发送:" "$REPORT_FILE" | grep -oP '\d+\.?\d*' | head -1)
    local udp_speed=$(grep "UDP速率:" "$REPORT_FILE" | grep -oP '\d+\.?\d*' | head -1)
    local local_speed=$(grep "回环速度:" "$REPORT_FILE" | grep -oP '\d+\.?\d*' | head -1)
    
    # 简单评分系统
    local score=0
    local level=""
    local color=""
    
    # TCP速度评分（假设单位是Mbps）
    if [ -n "$tcp_speed" ]; then
        if (( $(echo "$tcp_speed > 5000" | bc -l) )); then
            score=$((score + 40))
        elif (( $(echo "$tcp_speed > 1000" | bc -l) )); then
            score=$((score + 30))
        elif (( $(echo "$tcp_speed > 100" | bc -l) )); then
            score=$((score + 20))
        else
            score=$((score + 10))
        fi
    fi
    
    # 本地回环速度评分
    if [ -n "$local_speed" ]; then
        if (( $(echo "$local_speed > 20000" | bc -l) )); then
            score=$((score + 30))
        elif (( $(echo "$local_speed > 10000" | bc -l) )); then
            score=$((score + 20))
        else
            score=$((score + 10))
        fi
    fi
    
    # 确定性能等级
    if [ $score -ge 60 ]; then
        level="企业级网络"
        color=$GREEN
    elif [ $score -ge 40 ]; then
        level="高性能网络"
        color=$GREEN
    elif [ $score -ge 20 ]; then
        level="标准网络"
        color=$YELLOW
    else
        level="基础网络"
        color=$RED
    fi
    
    echo -e "${CYAN}网络性能等级: ${color}${level}${NC}"
    echo -e "${CYAN}综合评分: ${score}/100${NC}"
    
    # 应用场景建议
    echo -e "\n${CYAN}推荐应用场景:${NC}"
    
    case $level in
        "企业级网络")
            echo -e "${GREEN}  ✓ 高频交易系统${NC}"
            echo -e "${GREEN}  ✓ 实时视频流媒体${NC}"
            echo -e "${GREEN}  ✓ 大规模API服务${NC}"
            echo -e "${GREEN}  ✓ 分布式数据库集群${NC}"
            ;;
        "高性能网络")
            echo -e "${GREEN}  ✓ Web应用服务器${NC}"
            echo -e "${GREEN}  ✓ 游戏服务器${NC}"
            echo -e "${GREEN}  ✓ CDN节点${NC}"
            echo -e "${GREEN}  ✓ 中型数据库${NC}"
            ;;
        "标准网络")
            echo -e "${YELLOW}  ✓ 企业网站${NC}"
            echo -e "${YELLOW}  ✓ 博客系统${NC}"
            echo -e "${YELLOW}  ✓ 小型应用${NC}"
            echo -e "${YELLOW}  ⚡ 轻量级API${NC}"
            ;;
        "基础网络")
            echo -e "${RED}  ✓ 静态网站${NC}"
            echo -e "${RED}  ✓ 个人项目${NC}"
            echo -e "${RED}  ✗ 不适合高并发${NC}"
            echo -e "${RED}  ✗ 避免实时应用${NC}"
            ;;
    esac
}

# 生成报告
generate_report() {
    print_msg "$BLUE" "\n生成测试报告..."
    
    local summary_file="$REPORT_DIR/network_throughput_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "       网络吞吐量测试报告"
        echo "=========================================="
        echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "测试主机: $(hostname)"
        echo ""
        
        cat "$REPORT_FILE"
        
        echo ""
        echo "=========================================="
        echo "测试说明:"
        echo "1. TCP/UDP测试反映实际传输能力"
        echo "2. 延迟抖动影响实时应用性能"
        echo "3. 并发连接反映服务器处理能力"
        echo "4. 本地回环测试反映系统性能上限"
        echo ""
        echo "详细日志: $LOG_FILE"
        echo "=========================================="
    } | tee "$summary_file"
    
    print_msg "$GREEN" "\n测试报告已保存到: $summary_file"
}

# 交互式菜单
interactive_menu() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                      VPS 网络吞吐量测试工具 v1.0                          ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}请选择测试模式:${NC}"
    echo -e "${GREEN}1)${NC} 服务器模式 (等待客户端连接)"
    echo -e "${GREEN}2)${NC} 客户端模式 (连接到服务器)"
    echo -e "${GREEN}3)${NC} 本地测试 (推荐)"
    echo -e "${GREEN}4)${NC} 网络性能综合测试"
    echo -e "${GREEN}5)${NC} 单项测试"
    echo -e "${GREEN}0)${NC} 退出"
    echo ""
    
    read -p "请输入选项 [0-5]: " choice
    
    case $choice in
        1)
            SERVER_MODE=true
            iperf3_test
            ;;
        2)
            read -p "请输入服务器IP地址: " SERVER_IP
            if [[ "$SERVER_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                CLIENT_MODE=true
                get_network_info
                iperf3_test
                jitter_test
                generate_report
            else
                print_msg "$RED" "无效的IP地址"
                sleep 2
                interactive_menu
            fi
            ;;
        3)
            LOCAL_MODE=true
            get_network_info
            iperf3_test
            jitter_test
            concurrent_connection_test
            packet_rate_test
            network_stack_test
            http_performance_test
            calculate_score
            generate_report
            ;;
        4)
            get_network_info
            jitter_test
            concurrent_connection_test
            network_stack_test
            http_performance_test
            calculate_score
            generate_report
            ;;
        5)
            single_test_menu
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

# 单项测试菜单
single_test_menu() {
    clear
    echo -e "${CYAN}选择要进行的测试:${NC}"
    echo -e "${GREEN}1)${NC} iperf3吞吐量测试"
    echo -e "${GREEN}2)${NC} 延迟抖动测试"
    echo -e "${GREEN}3)${NC} 并发连接测试"
    echo -e "${GREEN}4)${NC} 包转发率测试"
    echo -e "${GREEN}5)${NC} HTTP性能测试"
    echo -e "${GREEN}0)${NC} 返回主菜单"
    echo ""
    
    read -p "请输入选项 [0-5]: " test_choice
    
    case $test_choice in
        1) 
            LOCAL_MODE=true
            iperf3_test 
            ;;
        2) jitter_test ;;
        3) concurrent_connection_test ;;
        4) packet_rate_test ;;
        5) http_performance_test ;;
        0) interactive_menu ;;
        *)
            print_msg "$RED" "无效选项"
            sleep 2
            single_test_menu
            ;;
    esac
}

# 显示帮助
show_help() {
    cat << EOF
使用方法: $0 [选项]

选项:
  --server            服务器模式
  --client <IP>       客户端模式
  --local             本地测试模式
  --help, -h          显示此帮助信息

示例:
  $0                  # 交互式菜单
  $0 --server         # 启动iperf3服务器
  $0 --client 1.2.3.4 # 连接到指定服务器
  $0 --local          # 执行本地测试

测试项目:
  - TCP/UDP吞吐量测试
  - 网络延迟和抖动测试
  - 并发连接能力测试
  - 包转发率测试
  - HTTP性能测试
  - 网络栈参数检查

注意:
  - 服务器模式需要开放相应端口
  - 客户端模式需要服务器端配合
  - 本地测试可独立运行
EOF
}

# 解析参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --server)
                SERVER_MODE=true
                shift
                ;;
            --client)
                CLIENT_MODE=true
                SERVER_IP=$2
                shift 2
                ;;
            --local)
                LOCAL_MODE=true
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
    log "开始网络吞吐量测试"
    
    {
        echo "========== 网络吞吐量测试 =========="
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
    } > "$REPORT_FILE"
    
    if [ "$SERVER_MODE" = true ]; then
        iperf3_test
    elif [ "$CLIENT_MODE" = true ]; then
        if [ -z "$SERVER_IP" ]; then
            print_msg "$RED" "客户端模式需要指定服务器IP"
            show_help
            exit 1
        fi
        get_network_info
        iperf3_test
        jitter_test
        generate_report
    elif [ "$LOCAL_MODE" = true ]; then
        get_network_info
        iperf3_test
        jitter_test
        concurrent_connection_test
        packet_rate_test
        network_stack_test
        http_performance_test
        calculate_score
        generate_report
    else
        interactive_menu
    fi
    
    print_msg "$GREEN" "\n网络吞吐量测试完成！"
}

# 运行主函数
main "$@"
