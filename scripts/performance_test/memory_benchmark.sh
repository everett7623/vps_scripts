#!/bin/bash
#/scripts/performance_test/memory_benchmark.sh - VPS Scripts 性能测试工具库

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
        sudo apt install -y sysbench stress-ng
    elif command -v yum &>/dev/null; then
        sudo yum install -y sysbench stress-ng
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm sysbench stress-ng
    else
        echo -e "${RED}无法安装必要的工具，请手动安装。${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}工具安装完成。${NC}"
}

# 测试内存读写性能
test_memory_performance() {
    echo -e "${BLUE}正在测试内存读写性能...${NC}"
    
    # 创建结果文件
    result_file="/tmp/memory_performance_benchmark_$(date +%Y%m%d%H%M%S).txt"
    echo "内存读写性能测试结果 - $(date)" > $result_file
    echo "==============================================" >> $result_file
    
    # 显示内存信息
    mem_total=$(free -h | grep Mem | awk '{print $2}')
    mem_type=$(cat /proc/meminfo | grep MemType | head -1)
    
    echo -e "${YELLOW}总内存: ${GREEN}$mem_total${NC}"
    if [ -n "$mem_type" ]; then
        echo -e "${YELLOW}内存类型: ${GREEN}$mem_type${NC}"
    fi
    
    echo "总内存: $mem_total" >> $result_file
    if [ -n "$mem_type" ]; then
        echo "内存类型: $mem_type" >> $result_file
    fi
    
    # 测试内存读写性能
    block_sizes=(4K 16K 64K 256K 1M)
    mem_size=$(free -m | grep Mem | awk '{print $2}')
    test_size=$((mem_size / 2))M
    
    for bs in "${block_sizes[@]}"; do
        echo -e "${YELLOW}正在测试块大小为 $bs 的内存读取性能...${NC}"
        read_result=$(sysbench --test=memory --memory-block-size=$bs --memory-total-size=$test_size --memory-oper=read run | grep "transferred" | awk '{print $4 " " $5}')
        
        echo -e "${GREEN}✓ 读取性能 ($bs): $read_result/sec${NC}"
        echo "读取性能 ($bs): $read_result/sec" >> $result_file
        
        echo -e "${YELLOW}正在测试块大小为 $bs 的内存写入性能...${NC}"
        write_result=$(sysbench --test=memory --memory-block-size=$bs --memory-total-size=$test_size --memory-oper=write run | grep "transferred" | awk '{print $4 " " $5}')
        
        echo -e "${GREEN}✓ 写入性能 ($bs): $write_result/sec${NC}"
        echo "写入性能 ($bs): $write_result/sec" >> $result_file
    done
    
    echo -e "${GREEN}内存读写性能测试完成。${NC}"
    echo ""
    echo -e "${YELLOW}测试结果已保存到: $result_file${NC}"
    echo ""
}

# 测试内存带宽
test_memory_bandwidth() {
    echo -e "${BLUE}正在测试内存带宽...${NC}"
    
    # 创建结果文件
    result_file="/tmp/memory_bandwidth_benchmark_$(date +%Y%m%d%H%M%S).txt"
    echo "内存带宽测试结果 - $(date)" > $result_file
    echo "==============================================" >> $result_file
    
    # 显示内存信息
    mem_total=$(free -h | grep Mem | awk '{print $2}')
    mem_type=$(cat /proc/meminfo | grep MemType | head -1)
    
    echo -e "${YELLOW}总内存: ${GREEN}$mem_total${NC}"
    if [ -n "$mem_type" ]; then
        echo -e "${YELLOW}内存类型: ${GREEN}$mem_type${NC}"
    fi
    
    echo "总内存: $mem_total" >> $result_file
    if [ -n "$mem_type" ]; then
        echo "内存类型: $mem_type" >> $result_file
    fi
    
    # 测试内存带宽
    echo -e "${YELLOW}正在测试内存带宽...${NC}"
    bandwidth_result=$(stress-ng --vm 1 --vm-bytes $(free -m | grep Mem | awk '{print $2}')M --vm-method all --metrics-brief --timeout 30s | grep "Copy" | awk '{print $2 " " $3}')
    
    echo -e "${GREEN}✓ 内存带宽: $bandwidth_result${NC}"
    echo "内存带宽: $bandwidth_result" >> $result_file
    
    echo -e "${GREEN}内存带宽测试完成。${NC}"
    echo ""
    echo -e "${YELLOW}测试结果已保存到: $result_file${NC}"
    echo ""
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           内存性能测试工具                   ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    # 检查是否已安装必要工具
    if ! command -v sysbench &>/dev/null || ! command -v stress-ng &>/dev/null; then
        install_tools
    fi
    
    # 显示测试选项菜单
    echo "请选择要执行的内存测试项目:"
    echo "1. 全部测试"
    echo "2. 仅测试内存读写性能"
    echo "3. 仅测试内存带宽"
    echo ""
    
    read -p "请输入选项 (1-3): " option
    
    case $option in
        1)
            test_memory_performance
            test_memory_bandwidth
            ;;
        2) test_memory_performance ;;
        3) test_memory_bandwidth ;;
        *)
            echo -e "${RED}无效选项，操作已取消。${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}内存性能测试完成!${NC}"
    read -n 1 -s -r -p "按任意键返回..."
}

# 执行主函数
main
