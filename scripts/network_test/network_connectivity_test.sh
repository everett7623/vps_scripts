
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
    total=0
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
        
        # 显示结果
        if [ "$loss" -eq 0 ]; then
            echo -e "${GREEN}✓ 可以连接到 $name ($target)${NC}"
            echo "$name ($target): 连接成功" >> $result_file
            success=$((success + 1))
        else
            # 尝试使用curl
            curl_result=$(curl -s -m 5 -o /dev/null -w "%{http_code}" $target)
            if [ "$curl_result" -ge 200 ] && [ "$curl_result" -lt 400 ]; then
                echo -e "${GREEN}✓ 可以连接到 $name ($target) (HTTP)${NC}"
