#!/bin/bash
#/scripts/network_test/ip_quality_test.sh - VPS Scripts 网络测试工具库

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

# 检测IP是否被封锁
check_ip_blocked() {
    local ip=$1
    echo -e "${BLUE}正在检测IP是否被封锁...${NC}"
    
    # Google
    if curl -s --connect-timeout 5 "https://www.google.com" > /dev/null; then
        echo -e "${GREEN}✓ Google 可访问${NC}"
    else
        echo -e "${RED}✗ Google 被封锁${NC}"
    fi
    
    # Twitter
    if curl -s --connect-timeout 5 "https://twitter.com" > /dev/null; then
        echo -e "${GREEN}✓ Twitter 可访问${NC}"
    else
        echo -e "${RED}✗ Twitter 被封锁${NC}"
    fi
    
    # Facebook
    if curl -s --connect-timeout 5 "https://facebook.com" > /dev/null; then
        echo -e "${GREEN}✓ Facebook 可访问${NC}"
    else
        echo -e "${RED}✗ Facebook 被封锁${NC}"
    fi
    
    # YouTube
    if curl -s --connect-timeout 5 "https://youtube.com" > /dev/null; then
        echo -e "${GREEN}✓ YouTube 可访问${NC}"
    else
        echo -e "${RED}✗ YouTube 被封锁${NC}"
    fi
    
    echo ""
}

# 检测IP是否被列入黑名单
check_ip_blacklist() {
    local ip=$1
    echo -e "${BLUE}正在检测IP是否被列入黑名单...${NC}"
    
    # 使用multirbl.valli.org检测多个黑名单
    local result=$(curl -s "https://multirbl.valli.org/lookup/$ip.html")
    
    # 解析结果
    if echo "$result" | grep -q "No listing found"; then
        echo -e "${GREEN}✓ IP 未被列入任何黑名单${NC}"
    else
        echo -e "${RED}✗ IP 被列入以下黑名单:${NC}"
        echo "$result" | grep -o '<td[^>]*>\([^<]*\)</td>' | grep -v "No listing found" | sed 's/<td[^>]*>\([^<]*\)<\/td>/\1/' | grep -v "^$" | uniq
    fi
    
    echo ""
}

# 检测IP的ASN信息
check_ip_asn() {
    local ip=$1
    echo -e "${BLUE}正在检测IP的ASN信息...${NC}"
    
    local asn_info=$(curl -s "https://ipinfo.io/$ip/org")
    local country=$(curl -s "https://ipinfo.io/$ip/country")
    local city=$(curl -s "https://ipinfo.io/$ip/city")
    
    echo -e "${YELLOW}ASN信息: ${GREEN}$asn_info${NC}"
    echo -e "${YELLOW}地理位置: ${GREEN}$city, $country${NC}"
    
    # 检测是否为数据中心IP
    if echo "$asn_info" | grep -qi "cloud\|datacenter\|hosting\|server\|vps\|virtual\|internet\|network\|communication\|telecom\|tech\|technology\|computing\|system\|infra\|data\|web\|server\|service\|internet\|cloud\|digital\|telecom\|host\|hosting\|cloud\|vps\|server\|datacenter\|data center\|network"; then
        echo -e "${YELLOW}IP类型: ${RED}数据中心/云服务IP${NC}"
    else
        echo -e "${YELLOW}IP类型: ${GREEN}住宅/企业IP${NC}"
    fi
    
    echo ""
}

# 检测IP的延迟和丢包率
check_ip_latency() {
    local ip=$1
    echo -e "${BLUE}正在检测IP的延迟和丢包率...${NC}"
    
    # 测试到Google的延迟
    local google_ping=$(ping -c 5 google.com 2>/dev/null)
    local google_loss=$(echo "$google_ping" | grep "packet loss" | awk '{print $6}' | sed 's/%//')
    local google_avg=$(echo "$google_ping" | grep "avg" | awk -F'/' '{print $5}')
    
    if [ -n "$google_avg" ]; then
        echo -e "${YELLOW}到 Google 的延迟: ${GREEN}$google_avg ms${NC}"
    else
        echo -e "${RED}无法连接到 Google${NC}"
    fi
    
    if [ -n "$google_loss" ]; then
        echo -e "${YELLOW}到 Google 的丢包率: ${GREEN}$google_loss%${NC}"
    fi
    
    # 测试到Cloudflare的延迟
    local cloudflare_ping=$(ping -c 5 1.1.1.1 2>/dev/null)
    local cloudflare_loss=$(echo "$cloudflare_ping" | grep "packet loss" | awk '{print $6}' | sed 's/%//')
    local cloudflare_avg=$(echo "$cloudflare_ping" | grep "avg" | awk -F'/' '{print $5}')
    
    if [ -n "$cloudflare_avg" ]; then
        echo -e "${YELLOW}到 Cloudflare 的延迟: ${GREEN}$cloudflare_avg ms${NC}"
    else
        echo -e "${RED}无法连接到 Cloudflare${NC}"
    fi
    
    if [ -n "$cloudflare_loss" ]; then
        echo -e "${YELLOW}到 Cloudflare 的丢包率: ${GREEN}$cloudflare_loss%${NC}"
    fi
    
    echo ""
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           IP质量检测工具                     ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    local ip=$(get_public_ip)
    
    check_ip_blocked "$ip"
    check_ip_blacklist "$ip"
    check_ip_asn "$ip"
    check_ip_latency "$ip"
    
    echo -e "${GREEN}IP质量检测完成!${NC}"
}

# 执行主函数
main
