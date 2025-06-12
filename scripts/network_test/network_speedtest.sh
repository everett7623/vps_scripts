#!/bin/bash
#/scripts/network_test/network_speedtest.sh - VPS Scripts 网络测试工具库

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

# 安装speedtest-cli（如果需要）
install_speedtest_cli() {
    if ! command -v speedtest &>/dev/null; then
        echo -e "${BLUE}正在安装speedtest-cli...${NC}"
        
        # 根据不同系统安装
        if command -v apt &>/dev/null; then
            sudo apt install -y python3 python3-pip
            sudo pip3 install speedtest-cli
        elif command -v yum &>/dev/null; then
            sudo yum install -y python3 python3-pip
            sudo pip3 install speedtest-cli
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm python python-pip
            sudo pip install speedtest-cli
        else
            echo -e "${RED}无法安装speedtest-cli，请手动安装。${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}speedtest-cli安装完成。${NC}"
    fi
}

# 测试到中国电信的速度
test_telecom() {
    echo -e "${BLUE}正在测试到中国电信的速度...${NC}"
    
    # 使用speedtest-cli测试到中国电信的速度
    echo -e "${YELLOW}正在测试下载速度...${NC}"
    telecom_download=$(speedtest --server 21286 --simple | grep "Download" | awk '{print $2 " " $3}')
    
    echo -e "${YELLOW}正在测试上传速度...${NC}"
    telecom_upload=$(speedtest --server 21286 --simple | grep "Upload" | awk '{print $2 " " $3}')
    
    echo -e "${YELLOW}正在测试延迟...${NC}"
    telecom_ping=$(speedtest --server 21286 --simple | grep "Ping" | awk '{print $2 " " $3}')
    
    echo -e "${GREEN}✓ 中国电信测试完成${NC}"
    echo -e "${YELLOW}下载速度: ${GREEN}$telecom_download${NC}"
    echo -e "${YELLOW}上传速度: ${GREEN}$telecom_upload${NC}"
    echo -e "${YELLOW}延迟: ${GREEN}$telecom_ping${NC}"
    
    echo ""
}

# 测试到中国移动的速度
test_mobile() {
    echo -e "${BLUE}正在测试到中国移动的速度...${NC}"
    
    # 使用speedtest-cli测试到中国移动的速度
    echo -e "${YELLOW}正在测试下载速度...${NC}"
    mobile_download=$(speedtest --server 21287 --simple | grep "Download" | awk '{print $2 " " $3}')
    
    echo -e "${YELLOW}正在测试上传速度...${NC}"
    mobile_upload=$(speedtest --server 21287 --simple | grep "Upload" | awk '{print $2 " " $3}')
    
    echo -e "${YELLOW}正在测试延迟...${NC}"
    mobile_ping=$(speedtest --server 21287 --simple | grep "Ping" | awk '{print $2 " " $3}')
    
    echo -e "${GREEN}✓ 中国移动测试完成${NC}"
    echo -e "${YELLOW}下载速度: ${GREEN}$mobile_download${NC}"
    echo -e "${YELLOW}上传速度: ${GREEN}$mobile_upload${NC}"
    echo -e "${YELLOW}延迟: ${GREEN}$mobile_ping${NC}"
    
    echo ""
}

# 测试到中国联通的速度
test_unicom() {
    echo -e "${BLUE}正在测试到中国联通的速度...${NC}"
    
    # 使用speedtest-cli测试到中国联通的速度
    echo -e "${YELLOW}正在测试下载速度...${NC}"
    unicom_download=$(speedtest --server 21288 --simple | grep "Download" | awk '{print $2 " " $3}')
    
    echo -e "${YELLOW}正在测试上传速度...${NC}"
    unicom_upload=$(speedtest --server 21288 --simple | grep "Upload" | awk '{print $2 " " $3}')
    
    echo -e "${YELLOW}正在测试延迟...${NC}"
    unicom_ping=$(speedtest --server 21288 --simple | grep "Ping" | awk '{print $2 " " $3}')
    
    echo -e "${GREEN}✓ 中国联通测试完成${NC}"
    echo -e "${YELLOW}下载速度: ${GREEN}$unicom_download${NC}"
    echo -e "${YELLOW}上传速度: ${GREEN}$unicom_upload${NC}"
    echo -e "${YELLOW}延迟: ${GREEN}$unicom_ping${NC}"
    
    echo ""
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           三网测速工具                       ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    local ip=$(get_public_ip)
    
    install_speedtest_cli
    
    echo -e "${YELLOW}请注意: 测速过程可能需要几分钟时间，请耐心等待...${NC}"
    echo ""
    
    test_telecom
    test_mobile
    test_unicom
    
    echo -e "${GREEN}三网测速完成!${NC}"
    read -n 1 -s -r -p "按任意键返回..."
}

# 执行主函数
main
