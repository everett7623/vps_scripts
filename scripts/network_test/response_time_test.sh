#!/bin/bash
#/scripts/network_test/response_time_test.sh - VPS Scripts 网络测试工具库

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # 恢复默认颜色

# 定义全球主要节点列表
nodes=(
    # 亚洲节点
    "日本东京" "114.112.111.110"
    "韩国首尔" "114.112.111.111"
    "新加坡" "114.112.111.112"
    "中国香港" "114.112.111.113"
    "中国台湾" "114.112.111.114"
    "中国北京" "202.106.0.20"
    "中国上海" "202.96.209.5"
    "中国广州" "202.96.128.86"
    
    # 欧洲节点
    "英国伦敦" "114.112.111.120"
    "德国法兰克福" "114.112.111.121"
    "法国巴黎" "114.112.111.122"
    "荷兰阿姆斯特丹" "114.112.111.123"
    "俄罗斯莫斯科" "114.112.111.124"
    
    # 北美节点
    "美国洛杉矶" "114.112.111.130"
    "美国旧金山" "114.112.111.131"
    "美国西雅图" "114.112.111.132"
    "美国纽约" "114.112.111.133"
    "加拿大多伦多" "114.112.111.134"
    
    # 南美节点
    "巴西圣保罗" "114.112.111.140"
    "阿根廷布宜诺斯艾利斯" "114.112.111.141"
    
    # 大洋洲节点
    "澳大利亚悉尼" "114.112.111.150"
    "澳大利亚墨尔本" "114.112.111.151"
    
    # 非洲节点
    "南非约翰内斯堡" "114.112.111.160"
)

# 安装fping（如果需要）
install_fping() {
    if ! command -v fping &>/dev/null; then
        echo -e "${BLUE}正在安装fping...${NC}"
        
        # 根据不同系统安装
        if command -v apt &>/dev/null; then
            sudo apt install -y fping
        elif command -v yum &>/dev/null; then
            sudo yum install -y fping
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm fping
        else
            echo -e "${RED}无法安装fping，请手动安装。${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}fping安装完成。${NC}"
    fi
}

# 测试单个节点的响应时间
test_node() {
    local name=$1
    local ip=$2
    
    echo -e "${YELLOW}正在测试到 $name ($ip) 的响应时间...${NC}"
    
    # 使用fping测试响应时间
    local result=$(fping -c 10 -q $ip 2>&1)
    local loss=$(echo "$result" | grep -o "10 packets, [0-9]*% loss" | awk '{print $4}' | sed 's/%//')
    local min=$(echo "$result" | grep -o "min/avg/max" | awk '{print $1}' | sed 's/\/.*//')
    local avg=$(echo "$result" | grep -o "min/avg/max" | awk '{print $2}' | sed 's/\/.*//')
    local max=$(echo "$result" | grep -o "min/avg/max" | awk '{print $3}')
    
    # 显示结果
    if [ -z "$avg" ]; then
        echo -e "${RED}✗ $name ($ip): 无法连接${NC}"
        echo "$name|$ip|无法连接|0|0|0" >> /tmp/response_time_results.txt
    else
        # 根据延迟设置颜色
        if [ $(echo "$avg < 100" | bc -l) -eq 1 ]; then
            color=$GREEN
        elif [ $(echo "$avg < 200" | bc -l) -eq 1 ]; then
            color=$YELLOW
        else
            color=$RED
        fi
        
        echo -e "${color}✓ $name ($ip): 最小 $min ms, 平均 $avg ms, 最大 $max ms, 丢包率 $loss%${NC}"
        echo "$name|$ip|$min|$avg|$max|$loss" >> /tmp/response_time_results.txt
    fi
}

# 生成响应时间图表
generate_chart() {
    echo -e "${BLUE}正在生成响应时间图表...${NC}"
    
    # 创建临时文件
    touch /tmp/response_time_chart.txt
    
    # 添加图表标题
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}              响应时间图表                   ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}节点名称\t\t平均延迟(ms)\t丢包率(%)${NC}"
    echo -e "${WHITE}---------------------------------------------${NC}"
    
    # 按平均延迟排序并显示结果
    sort -t '|' -k4 -n /tmp/response_time_results.txt | while IFS='|' read -r name ip min avg max loss; do
        # 根据延迟设置颜色
        if [ "$avg" = "无法连接" ]; then
            color=$RED
            bar=""
        else
            if [ $(echo "$avg < 100" | bc -l) -eq 1 ]; then
                color=$GREEN
            elif [ $(echo "$avg < 200" | bc -l) -eq 1 ]; then
                color=$YELLOW
            else
                color=$RED
            fi
            
            # 生成进度条
            bar_width=$(( $(echo "$avg/5" | bc) ))
            if [ $bar_width -gt 40 ]; then
                bar_width=40
            fi
            bar=$(printf "%-${bar_width}s" "#" | tr ' ' '#')
        fi
        
        # 显示结果
        printf "${color}%-20s\t%-10s\t%-6s${NC} %s\n" "$name" "$avg" "$loss%" "$bar"
    done
    
    echo -e "${WHITE}---------------------------------------------${NC}"
    echo -e "${GREEN}绿色: < 100ms${NC} | ${YELLOW}黄色: 100-200ms${NC} | ${RED}红色: > 200ms${NC}"
    echo -e "${WHITE}=============================================${NC}"
    
    # 删除临时文件
    rm -f /tmp/response_time_results.txt
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           全球节点响应时间测试               ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    # 安装必要工具
    install_fping
    
    # 创建结果文件
    echo "节点名称|IP地址|最小延迟|平均延迟|最大延迟|丢包率" > /tmp/response_time_results.txt
    
    # 显示测试选项菜单
    echo "请选择要测试的节点区域:"
    echo "1. 测试所有节点"
    echo "2. 仅测试亚洲节点"
    echo "3. 仅测试欧洲节点"
    echo "4. 仅测试北美节点"
    echo "5. 仅测试南美节点"
    echo "6. 仅测试大洋洲节点"
    echo "7. 仅测试非洲节点"
    echo ""
    
    read -p "请输入选项 (1-7): " option
    
    # 根据用户选择测试节点
    case $option in
        1)
            # 测试所有节点
            for ((i=0; i<${#nodes[@]}; i+=2)); do
                test_node "${nodes[$i]}" "${nodes[$i+1]}"
            done
            ;;
        2)
            # 仅测试亚洲节点
            for ((i=0; i<16; i+=2)); do
                test_node "${nodes[$i]}" "${nodes[$i+1]}"
            done
            ;;
        3)
            # 仅测试欧洲节点
            for ((i=16; i<26; i+=2)); do
                test_node "${nodes[$i]}" "${nodes[$i+1]}"
            done
            ;;
        4)
            # 仅测试北美节点
            for ((i=26; i<36; i+=2)); do
                test_node "${nodes[$i]}" "${nodes[$i+1]}"
            done
            ;;
        5)
            # 仅测试南美节点
            for ((i=36; i<40; i+=2)); do
                test_node "${nodes[$i]}" "${nodes[$i+1]}"
            done
            ;;
        6)
            # 仅测试大洋洲节点
            for ((i=40; i<44; i+=2)); do
                test_node "${nodes[$i]}" "${nodes[$i+1]}"
            done
            ;;
        7)
            # 仅测试非洲节点
            for ((i=44; i<48; i+=2)); do
                test_node "${nodes[$i]}" "${nodes[$i+1]}"
            done
            ;;
        *)
            echo -e "${RED}无效选项，操作已取消。${NC}"
            exit 1
            ;;
    esac
    
    # 生成响应时间图表
    generate_chart
    
    echo -e "${GREEN}响应时间测试完成!${NC}"
}

# 执行主函数
main
