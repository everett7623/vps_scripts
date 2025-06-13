#!/bin/bash
#/scripts/network_test/bandwidth_test.sh - VPS Scripts 网络测试工具库

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

# 测试本地网络带宽
test_local_bandwidth() {
    echo -e "${BLUE}正在测试本地网络带宽...${NC}"
    
    # 创建结果文件
    result_file="/tmp/local_bandwidth_test_$(date +%Y%m%d%H%M%S).txt"
    echo "本地网络带宽测试结果 - $(date)" > $result_file
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
    
    # 测试TCP带宽
    echo -e "${YELLOW}正在测试TCP带宽...${NC}"
    tcp_result=$(iperf3 -c $local_ip -t 10 -P 4)
    
    # 提取结果
    tcp_bandwidth=$(echo "$tcp_result" | grep "receiver" | awk '{print $7 " " $8}')
    echo -e "${GREEN}✓ TCP带宽: $tcp_bandwidth${NC}"
    echo "TCP带宽: $tcp_bandwidth" >> $result_file
    
    # 测试UDP带宽
    echo -e "${YELLOW}正在测试UDP带宽...${NC}"
    udp_result=$(iperf3 -c $local_ip -u -b 0 -t 10 -P 4)
    
    # 提取结果
    udp_bandwidth=$(echo "$udp_result" | grep "receiver" | awk '{print $7 " " $8}')
    echo -e "${GREEN}✓ UDP带宽: $udp_bandwidth${NC}"
    echo "UDP带宽: $udp_bandwidth" >> $result_file
    
    # 停止iperf3服务器
    pkill iperf3
    
    echo -e "${GREEN}本地网络带宽测试完成。${NC}"
    echo ""
    echo -e "${YELLOW}测试结果已保存到: $result_file${NC}"
    echo ""
}

# 测试远程网络带宽
test_remote_bandwidth() {
    echo -e "${BLUE}正在测试远程网络带宽...${NC}"
    
    # 创建结果文件
    result_file="/tmp/remote_bandwidth_test_$(date +%Y%m%d%H%M%S).txt"
    echo "远程网络带宽测试结果 - $(date)" > $result_file
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
        echo -e "${YELLOW}正在测试到 $server 的带宽...${NC}"
        
        # 测试TCP带宽
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
            echo -e "${RED}✗ 无法获取到 $server 的带宽${NC}"
            echo "$server: 测试失败" >> $result_file
        else
            echo -e "${GREEN}✓ 到 $server 的TCP带宽: $tcp_bandwidth${NC}"
            echo "$server: TCP带宽 $tcp_bandwidth" >> $result_file
        fi
    done
    
    # 使用speedtest-cli进行测试
    echo -e "${YELLOW}正在使用speedtest-cli进行测试...${NC}"
    speedtest_result=$(speedtest-cli --simple)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ speedtest-cli测试结果:${NC}"
        echo "$speedtest_result"
        echo "speedtest-cli测试结果:" >> $result_file
        echo "$speedtest_result" >> $result_file
    else
        echo -e "${RED}✗ speedtest-cli测试失败${NC}"
        echo "speedtest-cli测试失败" >> $result_file
    fi
    
    echo -e "${GREEN}远程网络带宽测试完成。${NC}"
    echo ""
    echo -e "${YELLOW}测试结果已保存到: $result_file${NC}"
    echo ""
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           网络带宽测试工具                   ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    # 检查是否已安装必要工具
    if ! command -v iperf3 &>/dev/null || ! command -v speedtest-cli &>/dev/null; then
        install_tools
    fi
    
    # 显示测试选项菜单
    echo "请选择要执行的带宽测试项目:"
    echo "1. 全部测试"
    echo "2. 仅测试本地网络带宽"
    echo "3. 仅测试远程网络带宽"
    echo ""
    
    read -p "请输入选项 (1-3): " option
    
    case $option in
        1)
            test_local_bandwidth
            test_remote_bandwidth
            ;;
        2) test_local_bandwidth ;;
        3) test_remote_bandwidth ;;
        *)
            echo -e "${RED}无效选项，操作已取消。${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}网络带宽测试完成!${NC}"
}

# 执行主函数
main
