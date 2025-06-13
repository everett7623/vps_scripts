
#!/bin/bash
#/scripts/network_test/network_traceroute.sh - VPS Scripts 网络测试工具库

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
        sudo apt install -y traceroute mtr whois
    elif command -v yum &>/dev/null; then
        sudo yum install -y traceroute mtr whois
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm traceroute mtr whois
    else
        echo -e "${RED}无法安装必要的工具，请手动安装。${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}工具安装完成。${NC}"
}

# 路由追踪
traceroute_target() {
    local target=$1
    local method=$2
    
    echo -e "${BLUE}正在追踪到 $target 的路由...${NC}"
    
    # 创建结果文件
    result_file="/tmp/traceroute_${target}_$(date +%Y%m%d%H%M%S).txt"
    echo "到 $target 的路由追踪结果 - $(date)" > $result_file
    echo "追踪方法: $method" >> $result_file
    echo "==============================================" >> $result_file
    
    # 使用选定的方法进行路由追踪
    case "$method" in
        "traceroute")
            echo -e "${YELLOW}正在使用traceroute进行路由追踪...${NC}"
            traceroute_result=$(traceroute -n -m 30 $target)
            ;;
        "mtr")
            echo -e "${YELLOW}正在使用mtr进行路由追踪...${NC}"
            traceroute_result=$(mtr -r -c 5 -n $target)
            ;;
    esac
    
    # 显示结果
    echo "$traceroute_result" >> $result_file
    
    # 分析结果
    hops=$(echo "$traceroute_result" | grep -v "traceroute to" | grep -v "HOST" | grep -v "^$" | wc -l)
    last_hop=$(echo "$traceroute_result" | grep -v "traceroute to" | grep -v "HOST" | grep -v "^$" | tail -1)
    
    echo -e "${YELLOW}路由追踪结果:${NC}"
    echo "$traceroute_result"
    
    echo -e "${YELLOW}总跳数: ${GREEN}$hops${NC}"
    echo "总跳数: $hops" >> $result_file
    
    if echo "$last_hop" | grep -q "$target"; then
        echo -e "${GREEN}✓ 成功追踪到目标地址${NC}"
        echo "成功追踪到目标地址" >> $result_file
    else
        echo -e "${YELLOW}⚠ 未完全追踪到目标地址${NC}"
        echo "未完全追踪到目标地址" >> $result_file
    fi
    
    echo -e "${GREEN}路由追踪完成。${NC}"
    echo ""
    echo -e "${YELLOW}追踪结果已保存到: $result_file${NC}"
    echo ""
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           网络路由追踪工具                   ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    # 检查是否已安装必要工具
    if ! command -v traceroute &>/dev/null || ! command -v mtr &>/dev/null; then
        install_tools
    fi
    
    # 获取目标地址
    read -p "请输入目标IP地址或域名: " target
    
    # 验证目标地址
    if ! ping -c 1 -W 2 $target &>/dev/null; then
        echo -e "${RED}✗ 目标地址不可达，请检查输入${NC}"
        exit 1
    fi
    
    # 显示追踪方法选项
    echo "请选择路由追踪方法:"
    echo "1. traceroute (标准追踪)"
    echo "2. mtr (更详细的追踪)"
    echo ""
    
    read -p "请输入选项 (1-2): " method_option
    
    case $method_option in
        1)
            method="traceroute"
            ;;
        2)
            method="mtr"
            ;;
        *)
            echo -e "${RED}无效选项，使用默认方法: traceroute${NC}"
            method="traceroute"
            ;;
    esac
    
    traceroute_target $target $method
    
    echo -e "${GREEN}网络路由追踪完成!${NC}"
}

# 执行主函数
main
