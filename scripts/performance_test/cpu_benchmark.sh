#!/bin/bash
#/scripts/performance_test/cpu_benchmark.sh - VPS Scripts 性能测试工具库

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

# 测试CPU计算性能
test_cpu_compute() {
    echo -e "${BLUE}正在测试CPU计算性能...${NC}"
    
    # 创建结果文件
    result_file="/tmp/cpu_compute_benchmark_$(date +%Y%m%d%H%M%S).txt"
    echo "CPU计算性能测试结果 - $(date)" > $result_file
    echo "==============================================" >> $result_file
    
    # 显示CPU信息
    cpu_info=$(cat /proc/cpuinfo | grep "model name" | head -1)
    cpu_cores=$(nproc)
    
    echo -e "${YELLOW}CPU信息: ${GREEN}$cpu_info${NC}"
    echo -e "${YELLOW}CPU核心数: ${GREEN}$cpu_cores${NC}"
    
    echo "CPU信息: $cpu_info" >> $result_file
    echo "CPU核心数: $cpu_cores" >> $result_file
    
    # 测试整数运算性能
    echo -e "${YELLOW}正在测试整数运算性能...${NC}"
    int_result=$(sysbench --test=cpu --cpu-max-prime=20000 --num-threads=$cpu_cores run | grep "total time" | awk '{print $3}')
    
    echo -e "${GREEN}✓ 整数运算性能: ${int_result}s${NC}"
    echo "整数运算性能: ${int_result}s" >> $result_file
    
    # 测试浮点运算性能
    echo -e "${YELLOW}正在测试浮点运算性能...${NC}"
    float_result=$(sysbench --test=cpu --cpu-max-prime=20000 --num-threads=$cpu_cores --cpu-method=fpu run | grep "total time" | awk '{print $3}')
    
    echo -e "${GREEN}✓ 浮点运算性能: ${float_result}s${NC}"
    echo "浮点运算性能: ${float_result}s" >> $result_file
    
    # 测试多线程性能
    echo -e "${YELLOW}正在测试多线程性能...${NC}"
    threads=(1 2 4 8)
    for t in "${threads[@]}"; do
        if [ $t -le $cpu_cores ]; then
            thread_result=$(sysbench --test=cpu --cpu-max-prime=20000 --num-threads=$t run | grep "events per second" | awk '{print $4}')
            echo -e "${GREEN}✓ $t线程性能: ${thread_result} ops/sec${NC}"
            echo "$t线程性能: ${thread_result} ops/sec" >> $result_file
        fi
    done
    
    echo -e "${GREEN}CPU计算性能测试完成。${NC}"
    echo ""
    echo -e "${YELLOW}测试结果已保存到: $result_file${NC}"
    echo ""
}

# 测试CPU稳定性
test_cpu_stability() {
    echo -e "${BLUE}正在测试CPU稳定性...${NC}"
    
    # 创建结果文件
    result_file="/tmp/cpu_stability_benchmark_$(date +%Y%m%d%H%M%S).txt"
    echo "CPU稳定性测试结果 - $(date)" > $result_file
    echo "==============================================" >> $result_file
    
    # 显示CPU信息
    cpu_info=$(cat /proc/cpuinfo | grep "model name" | head -1)
    cpu_cores=$(nproc)
    
    echo -e "${YELLOW}CPU信息: ${GREEN}$cpu_info${NC}"
    echo -e "${YELLOW}CPU核心数: ${GREEN}$cpu_cores${NC}"
    
    echo "CPU信息: $cpu_info" >> $result_file
    echo "CPU核心数: $cpu_cores" >> $result_file
    
    # 测试CPU稳定性
    echo -e "${YELLOW}正在进行CPU稳定性测试 (5分钟)...${NC}"
    
    # 使用stress-ng进行测试
    timeout 300 stress-ng --cpu $cpu_cores --cpu-method all --metrics-brief | tee -a $result_file
    
    # 测试结束后的CPU温度
    if command -v sensors &>/dev/null; then
        echo -e "${YELLOW}测试结束后的CPU温度:${NC}"
        sensors | tee -a $result_file
    fi
    
    echo -e "${GREEN}CPU稳定性测试完成。${NC}"
    echo ""
    echo -e "${YELLOW}测试结果已保存到: $result_file${NC}"
    echo ""
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           CPU性能测试工具                   ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    # 检查是否已安装必要工具
    if ! command -v sysbench &>/dev/null || ! command -v stress-ng &>/dev/null; then
        install_tools
    fi
    
    # 显示测试选项菜单
    echo "请选择要执行的CPU测试项目:"
    echo "1. 全部测试"
    echo "2. 仅测试CPU计算性能"
    echo "3. 仅测试CPU稳定性"
    echo ""
    
    read -p "请输入选项 (1-3): " option
    
    case $option in
        1)
            test_cpu_compute
            test_cpu_stability
            ;;
        2) test_cpu_compute ;;
        3) test_cpu_stability ;;
        *)
            echo -e "${RED}无效选项，操作已取消。${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}CPU性能测试完成!${NC}"
}

# 执行主函数
main
