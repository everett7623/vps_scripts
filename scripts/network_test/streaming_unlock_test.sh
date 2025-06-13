#!/bin/bash
#/scripts/network_test/streaming_unlock_test.sh - VPS Scripts 网络测试工具库

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

# 测试Netflix解锁
test_netflix() {
    echo -e "${BLUE}正在测试Netflix解锁...${NC}"
    
    # 测试Netflix US
    local netflix_us=$(curl -s -m 10 "https://www.netflix.com/title/70143836" | grep -o "page-404" | wc -l)
    if [ "$netflix_us" -eq 0 ]; then
        echo -e "${GREEN}✓ Netflix US 解锁${NC}"
    else
        echo -e "${RED}✗ Netflix US 未解锁${NC}"
    fi
    
    # 测试Netflix Japan
    local netflix_jp=$(curl -s -m 10 "https://www.netflix.com/jp/title/80117401" | grep -o "page-404" | wc -l)
    if [ "$netflix_jp" -eq 0 ]; then
        echo -e "${GREEN}✓ Netflix Japan 解锁${NC}"
    else
        echo -e "${RED}✗ Netflix Japan 未解锁${NC}"
    fi
    
    # 测试Netflix UK
    local netflix_uk=$(curl -s -m 10 "https://www.netflix.com/gb/title/80117401" | grep -o "page-404" | wc -l)
    if [ "$netflix_uk" -eq 0 ]; then
        echo -e "${GREEN}✓ Netflix UK 解锁${NC}"
    else
        echo -e "${RED}✗ Netflix UK 未解锁${NC}"
    fi
    
    echo ""
}

# 测试HBO Max解锁
test_hbo_max() {
    echo -e "${BLUE}正在测试HBO Max解锁...${NC}"
    
    local hbo_max=$(curl -s -m 10 "https://play.hbomax.com" | grep -o "Access Denied" | wc -l)
    if [ "$hbo_max" -eq 0 ]; then
        echo -e "${GREEN}✓ HBO Max 解锁${NC}"
    else
        echo -e "${RED}✗ HBO Max 未解锁${NC}"
    fi
    
    echo ""
}

# 测试Disney+解锁
test_disney_plus() {
    echo -e "${BLUE}正在测试Disney+解锁...${NC}"
    
    local disney_plus=$(curl -s -m 10 "https://www.disneyplus.com" | grep -o "page-not-found" | wc -l)
    if [ "$disney_plus" -eq 0 ]; then
        echo -e "${GREEN}✓ Disney+ 解锁${NC}"
    else
        echo -e "${RED}✗ Disney+ 未解锁${NC}"
    fi
    
    echo ""
}

# 测试Amazon Prime Video解锁
test_amazon_prime() {
    echo -e "${BLUE}正在测试Amazon Prime Video解锁...${NC}"
    
    local amazon_prime=$(curl -s -m 10 "https://www.amazon.com/Prime-Video/b?node=2676882011" | grep -o "We're sorry" | wc -l)
    if [ "$amazon_prime" -eq 0 ]; then
        echo -e "${GREEN}✓ Amazon Prime Video 解锁${NC}"
    else
        echo -e "${RED}✗ Amazon Prime Video 未解锁${NC}"
    fi
    
    echo ""
}

# 测试Spotify解锁
test_spotify() {
    echo -e "${BLUE}正在测试Spotify解锁...${NC}"
    
    local spotify=$(curl -s -m 10 "https://open.spotify.com" | grep -o "blocked" | wc -l)
    if [ "$spotify" -eq 0 ]; then
        echo -e "${GREEN}✓ Spotify 解锁${NC}"
    else
        echo -e "${RED}✗ Spotify 未解锁${NC}"
    fi
    
    echo ""
}

# 测试Youtube Premium解锁
test_youtube_premium() {
    echo -e "${BLUE}正在测试Youtube Premium解锁...${NC}"
    
    local youtube_premium=$(curl -s -m 10 "https://www.youtube.com/premium" | grep -o "Not available" | wc -l)
    if [ "$youtube_premium" -eq 0 ]; then
        echo -e "${GREEN}✓ Youtube Premium 解锁${NC}"
    else
        echo -e "${RED}✗ Youtube Premium 未解锁${NC}"
    fi
    
    echo ""
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}         流媒体解锁测试工具                   ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    local ip=$(get_public_ip)
    
    test_netflix
    test_hbo_max
    test_disney_plus
    test_amazon_prime
    test_spotify
    test_youtube_premium
    
    echo -e "${GREEN}流媒体解锁测试完成!${NC}"
}

# 执行主函数
main
