
#!/bin/bash
#/scripts/network_test/cdn_latency_test.sh - VPS Scripts 网络测试工具库

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # 恢复默认颜色

# 测试CDN延迟
test_cdn_latency() {
    echo -e "${BLUE}正在测试CDN延迟...${NC}"
    
    # 定义CDN节点
    cdn_nodes=(
        "Cloudflare" "1.1.1.1"
        "Google" "8.8.8.8"
        "Akamai" "23.235.39.47"
        "Fastly" "151.101.1.69"
        "EdgeCast" "205.188.175.230"
        "阿里云" "203.107.1.1"
        "腾讯云" "119.29.29.29"
        "百度云" "180.76.76.76"
        "华为云" "117.78.253.112"
        "CloudFront" "13.224.156.155"
    )
    
    # 创建结果文件
    result_file="/tmp/cdn_latency_test_$(date +%Y%m%d%H%M%S).txt"
    echo "CDN延迟测试结果 - $(date)" > $result_file
    echo "==============================================" >> $result_file
    
    # 测试每个CDN节点
    for ((i=0; i<${#cdn_nodes[@]}; i+=2)); do
        name=${cdn_nodes[$i]}
        ip=${cdn_nodes[$i+1]}
        
        echo -e "${YELLOW}正在测试 $name ($ip)...${NC}"
        
        # 使用ping测试延迟
        ping_result=$(ping -c 10 -q $ip 2>&1)
        loss=$(echo "$ping_result" | grep -o "10 packets, [0-9]*% loss" | awk '{print $4}' | sed 's/%//')
        min=$(echo "$ping_result" | grep -o "min/avg/max/mdev = [0-9.]*" | awk '{print $4}' | sed 's/\/.*//')
        avg=$(echo "$ping_result" | grep -o "min/avg/max/mdev = [0-9.]*" | awk '{print $4}' | sed 's/.*\///; s/\/.*//')
        max=$(echo "$ping_result" | grep -o "min/avg/max/mdev = [0-9.]*" | awk '{print $4}' | sed 's/.*\///; s/\/.*//')
        
        # 显示结果
        if [ -z "$avg" ]; then
            echo -e "${RED}✗ 无法连接到 $name ($ip)${NC}"
            echo "$name ($ip): 无法连接" >> $result_file
        else
            if [ "$loss" -eq 0 ]; then
                echo -e "${GREEN}✓ $name ($ip): 最小 $min ms, 平均 $avg ms, 最大 $max ms, 丢包率 $loss%${NC}"
            else
                echo -e "${YELLOW}⚠ $name ($ip): 最小 $min ms, 平均 $avg ms, 最大 $max ms, 丢包率 $loss%${NC}"
            fi
            echo "$name ($ip): 最小 $min ms, 平均 $avg ms, 最大 $max ms, 丢包率 $loss%" >> $result_file
        fi
    done
    
    echo -e "${GREEN}CDN延迟测试完成。${NC}"
    echo ""
    echo -e "${YELLOW}测试结果已保存到: $result_file${NC}"
    echo ""
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           CDN延迟测试工具                     ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    test_cdn_latency
    
    echo -e "${GREEN}CDN延迟测试完成!${NC}"
}

# 执行主函数
main
