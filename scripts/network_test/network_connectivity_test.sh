#!/bin/bash
#/scripts/network_test/network_connectivity_test.sh - VPS Scripts 网络测试工具库

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # 恢复默认颜色

# 检查必要的命令
check_dependencies() {
    local missing=0
    for cmd in ping curl; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}错误: 缺少必要的命令 '$cmd'${NC}"
            missing=1
        fi
    done
    [ $missing -eq 1 ] && exit 1
}

# 测试网络连通性
test_connectivity() {
    echo -e "${BLUE}正在测试网络连通性...${NC}"
    
    # 定义测试节点
    test_nodes=(
        "Google DNS" "8.8.8.8"
        "Cloudflare DNS" "1.1.1.1"
        "OpenDNS" "208.67.222.222"
        "Quad9" "9.9.9.9"
        "阿里巴巴DNS" "223.5.5.5"
        "腾讯DNS" "119.29.29.29"
        "百度DNS" "180.76.76.76"
        "Google" "www.google.com"
        "Facebook" "www.facebook.com"
        "Twitter" "www.twitter.com"
        "YouTube" "www.youtube.com"
        "GitHub" "github.com"
        "Cloudflare" "cloudflare.com"
        "Amazon" "amazon.com"
        "Microsoft" "microsoft.com"
        "Apple" "apple.com"
        "Netflix" "netflix.com"
        "BBC" "bbc.co.uk"
        "Yahoo" "yahoo.com"
        "Wikipedia" "wikipedia.org"
    )
    
    # 创建结果文件
    result_file="/tmp/connectivity_test_$(date +%Y%m%d%H%M%S).txt"
    echo "网络连通性测试结果 - $(date)" > $result_file
    echo "==============================================" >> $result_file
    
    # 初始化计数器
    total=$(( ${#test_nodes[@]} / 2 ))
    success=0
    failed=0
    
    # 测试每个节点
    for ((i=0; i<${#test_nodes[@]}; i+=2)); do
        name=${test_nodes[$i]}
        target=${test_nodes[$i+1]}
        
        echo -e "${YELLOW}正在测试 $name ($target)...${NC}"
        
        # 使用ping测试连通性
        ping_result=$(ping -c 3 -W 2 $target 2>&1)
        loss=$(echo "$ping_result" | grep -o "3 packets, [0-9]*% loss" | awk '{print $4}' | sed 's/%//')
        
        # 提取平均延迟（如果可用）
        if echo "$ping_result" | grep -q "avg"; then
            avg_time=$(echo "$ping_result" | grep -o "avg.*" | awk -F'/' '{print $5}')
        else
            avg_time="N/A"
        fi
        
        # 显示结果
        if [ "$loss" -eq 0 ]; then
            echo -e "${GREEN}✓ 可以连接到 $name ($target) - 平均延迟: ${avg_time}ms${NC}"
            echo "$name ($target): 连接成功 - 平均延迟: ${avg_time}ms" >> $result_file
            success=$((success + 1))
        else
            # 尝试使用curl
            curl_result=$(curl -s -m 5 -o /dev/null -w "%{http_code}" $target)
            if [ "$curl_result" -ge 200 ] && [ "$curl_result" -lt 400 ]; then
                echo -e "${GREEN}✓ 可以连接到 $name ($target) (HTTP)${NC}"
                echo "$name ($target): 连接成功 (HTTP)" >> $result_file
                success=$((success + 1))
            else
                echo -e "${RED}✗ 无法连接到 $name ($target)${NC}"
                echo "$name ($target): 连接失败" >> $result_file
                failed=$((failed + 1))
            fi
        fi
        
        echo "----------------------------------------------" >> $result_file
    done
    
    # 显示统计信息
    echo -e "\n${BLUE}测试统计:${NC}"
    echo -e "${GREEN}✓ 成功: $success${NC}"
    echo -e "${RED}✗ 失败: $failed${NC}"
    echo -e "${YELLOW}总数: $total${NC}"
    
    # 计算成功率
    if [ $total -gt 0 ]; then
        success_rate=$(echo "scale=2; $success * 100 / $total" | bc)
        echo -e "${BLUE}成功率: ${success_rate}%${NC}"
    fi
    
    # 添加统计信息到结果文件
    echo -e "\n测试统计:" >> $result_file
    echo "成功: $success" >> $result_file
    echo "失败: $failed" >> $result_file
    echo "总数: $total" >> $result_file
    echo "成功率: ${success_rate}%" >> $result_file
    
    echo -e "\n${GREEN}测试完成!${NC}"
    echo -e "结果已保存到: ${CYAN}$result_file${NC}"
    
    # 询问是否显示详细结果
    read -p "是否显示详细结果? (y/n): " show_detail
    if [[ $show_detail =~ ^[Yy]$ ]]; then
        cat $result_file
    fi
}

# 主函数
main() {
    echo -e "${WHITE}=============================${NC}"
    echo -e "${WHITE}      网络连通性测试工具      ${NC}"
    echo -e "${WHITE}=============================${NC}"
    echo ""
    
    # 检查依赖
    check_dependencies
    
    # 执行测试
    test_connectivity
}

# 执行主函数
main
