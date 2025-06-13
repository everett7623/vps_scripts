#!/bin/bash
#/scripts/system_tools/set_timezone.sh - VPS Scripts 系统工具库

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # 恢复默认颜色

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}错误: 此脚本需要root权限运行${NC}" 1>&2
   exit 1
fi

echo -e "${WHITE}时区设置工具${NC}"
echo "------------------------"

# 获取当前时区
current_timezone=$(timedatectl | grep "Time zone" | awk '{print $3}')
echo -e "${WHITE}当前时区: ${YELLOW}$current_timezone${NC}"
echo -e "${WHITE}当前系统时间: ${YELLOW}$(date)${NC}"
echo ""

# 列出常用时区
echo -e "${WHITE}常用时区列表:${NC}"
echo "------------------------"
echo "1. Asia/Shanghai (中国上海)"
echo "2. Asia/Tokyo (日本东京)"
echo "3. Asia/Singapore (新加坡)"
echo "4. Asia/Hong_Kong (中国香港)"
echo "5. Asia/Seoul (韩国首尔)"
echo "6. Europe/London (英国伦敦)"
echo "7. Europe/Paris (法国巴黎)"
echo "8. Europe/Berlin (德国柏林)"
echo "9. America/New_York (美国纽约)"
echo "10. America/Los_Angeles (美国洛杉矶)"
echo "11. Australia/Sydney (澳大利亚悉尼)"
echo "12. 手动输入时区"
echo ""

# 获取用户选择
read -p "请选择时区编号 (1-12): " choice

# 根据用户选择设置时区
case "$choice" in
    1) timezone="Asia/Shanghai";;
    2) timezone="Asia/Tokyo";;
    3) timezone="Asia/Singapore";;
    4) timezone="Asia/Hong_Kong";;
    5) timezone="Asia/Seoul";;
    6) timezone="Europe/London";;
    7) timezone="Europe/Paris";;
    8) timezone="Europe/Berlin";;
    9) timezone="America/New_York";;
    10) timezone="America/Los_Angeles";;
    11) timezone="Australia/Sydney";;
    12) 
        read -p "请输入完整的时区名称 (例如 Asia/Shanghai): " timezone
        
        # 验证时区是否存在
        if [ ! -f /usr/share/zoneinfo/"$timezone" ]; then
            echo -e "${RED}错误: 时区 '$timezone' 不存在${NC}"
            exit 1
        fi
        ;;
    *) 
        echo -e "${RED}错误: 无效的选择${NC}"
        exit 1
        ;;
esac

# 确认修改
echo -e "${WHITE}您选择的时区是: ${YELLOW}$timezone${NC}"
read -p "确定要将时区修改为 '$timezone' 吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}正在修改时区...${NC}";;
  n|N ) echo -e "${YELLOW}已取消时区修改${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消时区修改${NC}"; exit 1;;
esac

# 修改时区
timedatectl set-timezone "$timezone"

# 验证修改结果
new_timezone=$(timedatectl | grep "Time zone" | awk '{print $3}')
if [ "$new_timezone" == "$timezone" ]; then
    echo -e "${GREEN}时区已成功修改为: $timezone${NC}"
    echo -e "${WHITE}更新后的系统时间: ${YELLOW}$(date)${NC}"
    
    # 询问是否启用NTP
    read -p "是否启用NTP自动同步时间? (y/n): " ntp_choice
    case "$ntp_choice" in 
      y|Y ) 
          timedatectl set-ntp true
          if [ $? -eq 0 ]; then
              echo -e "${GREEN}NTP已启用，系统时间将自动同步${NC}"
          else
              echo -e "${YELLOW}启用NTP失败，请手动检查${NC}"
          fi
          ;;
      n|N ) echo -e "${YELLOW}已取消启用NTP${NC}";;
      * ) echo -e "${YELLOW}已取消启用NTP${NC}";;
    esac
else
    echo -e "${RED}时区修改失败，请手动检查${NC}"
    exit 1
fi

echo ""
read -n 1 -s -r -p "按任意键返回主菜单..."
