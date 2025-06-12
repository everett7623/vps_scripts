#!/bin/bash
#/scripts/performance_test/network_throughput_test.sh - VPS Scripts 性能测试工具库

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # 恢复默认颜色

# 安装必要工具
install_tools() {
    echo -e "${BLUE}正在安装必要的工具...${NC}"
    
    if command -v apt &>/dev/null; then
        sudo apt install -y iperf3 speedtest-cli
    elif command -v yum &>/dev/null; then
        sudo yum install -y iperf3 speedtest-cli
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm iperf3 speedtest-cli
    else
        echo -e "${RED}无法安装必要的工具，请手动安装。${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}工具安装完成。${NC}"
}

# 测试本地网络吞吐量
test_local_network() {
    echo -e "${BLUE}正在测试本地网络吞吐量...${NC}"
    
    # 创建结果文件
    result_file="/tmp/local_network_throughput_$(date +%Y%m%d%H%M%S).txt"
    echo "本地网络吞吐量测试结果 - $(date)" > $result_file
    echo "==============================================" >> $result_file
    
    # 获取本地IP地址
    local_ip=$(hostname -I | awk '{print $1}')
    echo -e "${YELLOW}本地IP地址: ${GREEN}$local_ip${NC}"
    echo "本地IP地址: $local_ip" >> $result_file
    
    # 启动iperf3服务器
    echo -e "${YELLOW}正在启动iperf3服务器...${NC}"
    iperf3 -s -D
    
    # 等待服务器启动
    sleep 2
    
    # 测试TCP吞吐量
    echo -e "${YELLOW}正在测试TCP吞吐量...${NC}"
    tcp_result=$(iperf3 -c $local_ip -t 10 -P 4)
    
    # 提取结果
    tcp_bandwidth=$(echo "$tcp_result" | grep "receiver" | awk '{print $7 " " $8}')
    echo -e "${GREEN}✓ TCP吞吐量: $tcp_bandwidth${NC}"
    echo "TCP吞吐量: $tcp_bandwidth" >> $result_file
    
    # 测试UDP吞吐量
    echo -e "${YELLOW}正在测试UDP吞吐量...${NC}"
    udp_result=$(iperf3 -c $local_ip -u -b 0 -t 10 -P 4)
    
    # 提取结果
    udp_bandwidth=$(echo "$udp_result" | grep "receiver" | awk '{print $7 " " $8}')
    echo -e "${GREEN}✓ UDP吞吐量: $udp_bandwidth${NC}"
    echo "UDP吞吐量: $udp_bandwidth" >> $result_file
    
    # 停止iperf3服务器
    pkill iperf3
    
    echo -e "${GREEN}本地网络吞吐量测试完成。${NC}"
    echo ""
    echo -e "${YELLOW}测试结果已保存到: $result_file${NC}"
    echo ""
}

# 测试远程网络吞吐量
test_remote_network() {
    echo -e "${BLUE}正在测试远程网络吞吐量...${NC}"
    
    # 创建结果文件
    result_file="/tmp/remote_network_throughput_$(date +%Y%m%d%H%M%S).txt"
    echo "远程网络吞吐量测试结果 - $(date)" > $result_file
    echo "==============================================" >> $result_file
    
    # 获取本地IP地址
    local_ip=$(hostname -I | awk '{print $1}')
    echo -e "${YELLOW}本地IP地址: ${GREEN}$local_ip${NC}"
    echo "本地IP地址: $local_ip" >> $result_file
    
    # 定义测试服务器
    test_servers=(
        "iperf.scottlinux.com"
        "iperf.he.net"
        "ping.online.net"
        "speedtest-sfo1.digitalocean.com"
        "speedtest-nyc1.digitalocean.com"
        "speedtest-lon1.digitalocean.com"
        "speedtest-sgp1.digitalocean.com"
    )
    
    # 测试每个服务器
    for server in "${test_servers[@]}"; do
        echo -e "${YELLOW}正在测试到 $server 的吞吐量...${NC}"
        
        # 测试TCP吞吐量
        tcp_result=$(iperf3 -c $server -t 10 2>&1)
        
        # 检查连接是否成功
        if echo "$tcp_result" | grep -q "iperf3: error"; then
            echo -e "${RED}✗ 无法连接到 $server${NC}"
            echo "$server: 连接失败" >> $result_file
            continue
        fi
        
        # 提取结果
        tcp_bandwidth=$(echo "$tcp_result" | grep "receiver" | awk '{print $7 " " $8}')
        if [ -z "$tcp_bandwidth" ]; then
            echo -e "${RED}✗ 无法获取到 $server 的吞吐量${NC}"
            echo "$server: 测试失败" >> $result_file
        else
            echo -e "${GREEN}✓ 到 $server 的TCP吞吐量: $tcp_bandwidth${NC}"
            echo "$server: TCP吞吐量 $tcp_bandwidth" >> $result_file
        fi
    done
    
    # 使用speedtest-cli进行测试
