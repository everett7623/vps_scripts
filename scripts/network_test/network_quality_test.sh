#!/bin/bash
#/scripts/network_test/network_quality_test.sh - VPS Scripts 网络测试工具库

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
        sudo apt install -y iperf3 fping traceroute
    elif command -v yum &>/dev/null; then
        sudo yum install -y iperf3 fping traceroute
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm iperf3 fping traceroute
    else
        echo -e "${RED}无法安装必要的工具，请手动安装。${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}工具安装完成。${NC}"
}

# 测试网络延迟和丢包率
test_latency() {
    echo -e "${BLUE}正在测试网络延迟和丢包率...${NC}"
    
    # 定义测试节点
    test_nodes=(
        "8.8.8.8 Google DNS"
        "1.1.1.1 Cloudflare DNS"
        "208.67.222.222 OpenDNS"
        "114.114.114.114 中国DNS"
        "202.106.0.20 北京联通"
        "202.96.209.5 上海电信"
        "211.136.25.153 上海移动"
    )
    
    # 创建结果文件
    result_file="/tmp/latency_test_$(date +%Y%m%d%H%M%S).txt"
    echo "网络延迟和丢包率测试结果 - $(date)" > $result_file
    echo "==============================================" >> $result_file
    
    # 测试每个节点
    for node in "${test_nodes[@]}"; do
        ip=$(echo $node | awk '{print $1}')
        name=$(echo $node | awk '{$1=""; print $0}' | sed 's/^ //')
        
        echo -e "${YELLOW}正在测试 $name ($ip)...${NC}"
        
        # 使用fping测试延迟和丢包率
        fping_result=$(fping -c 10 -q $ip 2>&1)
        loss=$(echo "$fping_result" | grep -o "10 packets, [0-9]*% loss" | awk '{print $4}' | sed 's/%//')
        avg=$(echo "$fping_result" | grep -o "min/avg/max" | awk '{print $3}' | sed 's/\/.*//')
        
        # 显示结果
        if [ -z "$avg" ]; then
            echo -e "${RED}✗ 无法连接到 $name ($ip)${NC}"
            echo "$name ($ip): 无法连接" >> $result_file
        else
            if [ "$loss" -eq 0 ]; then
                echo -e "${GREEN}✓ $name ($ip): 平均延迟 $avg ms, 丢包率 $loss%${NC}"
            else
                echo -e "${YELLOW}⚠ $name ($ip): 平均延迟 $avg ms, 丢包率 $loss%${NC}"
            fi
            echo "$name ($ip): 平均延迟 $avg ms, 丢包率 $loss%" >> $result_file
        fi
    done
    
    echo -e "${GREEN}延迟和丢包率测试完成。${NC}"
    echo ""
    echo -e "${YELLOW}测试结果已保存到: $result_file${NC}"
    echo ""
}

# 测试网络带宽
test_bandwidth() {
    echo -e "${BLUE}正在测试网络带宽...${NC}"
    
    # 定义iperf3服务器
    iperf_servers=(
        "iperf.scottlinux.com"
        "iperf.he.net"
        "ping.online.net"
    )
    
    # 创建结果文件
    result_file="/tmp/bandwidth_test_$(date +%Y%m%d%H%M%S).txt"
    echo "网络带宽测试结果 - $(date)" > $result_file
    echo "==============================================" >> $result_file
    
    # 测试每个服务器
    for server in "${iperf_servers[@]}"; do
        echo -e "${YELLOW}正在测试到 $server 的带宽...${NC}"
        
        # 使用iperf3测试带宽
        iperf_result=$(iperf3 -c $server -t 10 2>&1)
        
        # 提取下载速度
        download=$(echo "$iperf_result" | grep -o "receiver" | tail -1 | awk '{print $6 " " $7}')
        
        # 显示结果
        if [ -z "$download" ]; then
            echo -e "${RED}✗ 无法测试到 $server 的带宽${NC}"
            echo "$server: 测试失败" >> $result_file
        else
            echo -e "${GREEN}✓ 到 $server 的下载带宽: $download${NC}"
            echo "$server: 下载带宽 $download" >> $result_file
        fi
    done
    
    echo -e "${GREEN}带宽测试完成。${NC}"
    echo ""
    echo -e "${YELLOW}测试结果已保存到: $result_file${NC}"
    echo ""
}

# 测试网络抖动
test_jitter() {
    echo -e "${BLUE}正在测试网络抖动...${NC}"
    
    # 定义测试节点
    test_nodes=(
        "8.8.8.8 Google DNS"
        "1.1.1.1 Cloudflare DNS"
        "208.67.222.222 OpenDNS"
        "114.114.114.114 中国DNS"
    )
    
    # 创建结果文件
    result_file="/tmp/jitter_test_$(date +%Y%m%d%H%M%S).txt"
    echo "网络抖动测试结果 - $(date)" > $result_file
    echo "==============================================" >> $result_file
    
    # 测试每个节点
    for node in "${test_nodes[@]}"; do
        ip=$(echo $node | awk '{print $1}')
        name=$(echo $node | awk '{$1=""; print $0}' | sed 's/^ //')
        
        echo -e "${YELLOW}正在测试到 $name ($ip) 的抖动...${NC}"
        
        # 使用ping测试抖动
        ping_result=$(ping -c 30 -i 0.2 $ip 2>&1)
        min=$(echo "$ping_result" | grep -o "min/avg/max/mdev = [0-9.]*" | awk '{print $4}' | sed 's/\/.*//')
        avg=$(echo "$ping_result" | grep -o "min/avg/max/mdev = [0-9.]*" | awk '{print $4}' | sed 's/.*\///; s/\/.*//')
        max=$(echo "$ping_result" | grep -o "min/avg/max/mdev = [0-9.]*" | awk '{print $4}' | sed 's/.*\///; s/\/.*//')
        mdev=$(echo "$ping_result" | grep -o "min/avg/max/mdev = [0-9.]*" | awk '{print $4}' | sed 's/.*\///')
        
        # 显示结果
        if [ -z "$avg" ]; then
            echo -e "${RED}✗ 无法测试到 $name ($ip) 的抖动${NC}"
            echo "$name ($ip): 测试失败" >> $result_file
        else
            echo -e "${GREEN}✓ 到 $name ($ip) 的抖动: 最小 $min ms, 平均 $avg ms, 最大 $max ms, 标准差 $mdev ms${NC}"
            echo "$name ($ip): 最小 $min ms, 平均 $avg ms, 最大 $max ms, 标准差 $mdev ms" >> $result_file
        fi
    done
    
    echo -e "${GREEN}抖动测试完成。${NC}"
    echo ""
    echo -e "${YELLOW}测试结果已保存到: $result_file${NC}"
    echo ""
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           网络质量综合测试工具               ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    # 检查是否已安装必要工具
    if ! command -v iperf3 &>/dev/null || ! command -v fping &>/dev/null || ! command -v traceroute &>/dev/null; then
        install_tools
    fi
    
    # 显示测试选项菜单
    echo "请选择要执行的测试项目:"
    echo "1. 全部测试"
    echo "2. 仅测试网络延迟和丢包率"
    echo "3. 仅测试网络带宽"
    echo "4. 仅测试网络抖动"
    echo ""
    
    read -p "请输入选项 (1-4): " option
    
    case $option in
        1)
            test_latency
            test_bandwidth
            test_jitter
            ;;
        2) test_latency ;;
        3) test_bandwidth ;;
        4) test_jitter ;;
        *)
            echo -e "${RED}无效选项，操作已取消。${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}网络质量综合测试完成!${NC}"
}

# 执行主函数
main
