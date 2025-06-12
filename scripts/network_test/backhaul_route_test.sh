#!/bin/bash
#/scripts/network_test/backhaul_route_test.sh - VPS Scripts 网络测试工具库

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # 恢复默认颜色

# 获取公网IP
get_public_ip() {
    local ipv4=$(curl -s https://api.ipify.org)
    local ipv6=$(curl -s https://api64.ipify.org 2>/dev/null || echo "N/A")
    echo -e "${YELLOW}公网IPv4: ${GREEN}$ipv4${NC}"
    if [ "$ipv6" != "N/A" ]; then
        echo -e "${YELLOW}公网IPv6: ${GREEN}$ipv6${NC}"
    fi
    echo ""
    echo "$ipv4"
}

# 测试到中国电信的回程路由
test_telecom_backhaul() {
    echo -e "${BLUE}正在测试到中国电信的回程路由...${NC}"
    
    # 使用mtr测试到中国电信的回程路由
    echo -e "${YELLOW}正在测试到上海电信的回程路由...${NC}"
    mtr -r -c 5 -n 202.96.209.5 | tee /tmp/mtr_telecom_shanghai.txt
    
    echo -e "${YELLOW}正在测试到北京电信的回程路由...${NC}"
    mtr -r -c 5 -n 202.96.199.132 | tee /tmp/mtr_telecom_beijing.txt
    
    echo -e "${YELLOW}正在测试到广州电信的回程路由...${NC}"
    mtr -r -c 5 -n 202.96.128.86 | tee /tmp/mtr_telecom_guangzhou.txt
    
    echo ""
}

# 测试到中国移动的回程路由
test_mobile_backhaul() {
    echo -e "${BLUE}正在测试到中国移动的回程路由...${NC}"
    
    # 使用mtr测试到中国移动的回程路由
    echo -e "${YELLOW}正在测试到上海移动的回程路由...${NC}"
    mtr -r -c 5 -n 211.136.25.153 | tee /tmp/mtr_mobile_shanghai.txt
    
    echo -e "${YELLOW}正在测试到北京移动的回程路由...${NC}"
    mtr -r -c 5 -n 211.136.25.152 | tee /tmp/mtr_mobile_beijing.txt
    
    echo -e "${YELLOW}正在测试到广州移动的回程路由...${NC}"
    mtr -r -c 5 -n 211.136.25.154 | tee /tmp/mtr_mobile_guangzhou.txt
    
    echo ""
}

# 测试到中国联通的回程路由
test_unicom_backhaul() {
    echo -e "${BLUE}正在测试到中国联通的回程路由...${NC}"
    
    # 使用mtr测试到中国联通的回程路由
    echo -e "${YELLOW}正在测试到上海联通的回程路由...${NC}"
    mtr -r -c 5 -n 210.22.97.1 | tee /tmp/mtr_unicom_shanghai.txt
    
    echo -e "${YELLOW}正在测试到北京联通的回程路由...${NC}"
    mtr -r -c 5 -n 202.106.196.115 | tee /tmp/mtr_unicom_beijing.txt
    
    echo -e "${YELLOW}正在测试到广州联通的回程路由...${NC}"
    mtr -r -c 5 -n 210.21.4.130 | tee /tmp/mtr_unicom_guangzhou.txt
    
    echo ""
}

# 安装mtr（如果需要）
install_mtr() {
    if ! command -v mtr &>/dev/null; then
        echo -e "${BLUE}正在安装mtr...${NC}"
        
        # 根据不同系统安装
        if command -v apt &>/dev/null; then
            sudo apt install -y mtr
        elif command -v yum &>/dev/null; then
            sudo yum install -y mtr
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm mtr
        else
            echo -e "${RED}无法安装mtr，请手动安装。${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}mtr安装完成。${NC}"
    fi
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           回程路由测试工具                   ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    local ip=$(get_public_ip)
    
    install_mtr
    
    echo -e "${YELLOW}请注意: 回程路由测试可能需要几分钟时间，请耐心等待...${NC}"
    echo ""
    
    # 显示测试选项菜单
    echo "请选择要测试的回程路由:"
    echo "1. 测试所有回程路由"
    echo "2. 仅测试中国电信回程路由"
    echo "3. 仅测试中国移动回程路由"
    echo "4. 仅测试中国联通回程路由"
    echo ""
    
    read -p "请输入选项 (1-4): " option
    
    case $option in
        1)
            test_telecom_backhaul
            test_mobile_backhaul
            test_unicom_backhaul
            ;;
        2) test_telecom_backhaul ;;
        3) test_mobile_backhaul ;;
        4) test_unicom_backhaul ;;
        *)
            echo -e "${RED}无效选项，操作已取消。${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}回程路由测试完成!${NC}"
    echo -e "${YELLOW}测试结果已保存到/tmp目录下。${NC}"
    read -n 1 -s -r -p "按任意键返回..."
}

# 执行主函数
main
