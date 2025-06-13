#!/bin/bash
#/scripts/system_tools/change_hostname.sh - VPS Scripts 系统工具库

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

echo -e "${WHITE}主机名修改工具${NC}"
echo "------------------------"

# 获取当前主机名
current_hostname=$(hostname)
echo -e "${WHITE}当前主机名: ${YELLOW}$current_hostname${NC}"

# 检查主机名是否有效
valid_hostname() {
    local h="$1"
    if [[ "$h" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]]; then
        return 0
    else
        return 1
    fi
}

# 获取新主机名
read -p "请输入新的主机名: " new_hostname

# 验证主机名
if ! valid_hostname "$new_hostname"; then
    echo -e "${RED}错误: 主机名无效。主机名只能包含字母、数字和连字符，且不能以连字符开头或结尾。${NC}"
    exit 1
fi

# 确认修改
read -p "确定要将主机名从 '$current_hostname' 修改为 '$new_hostname' 吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}正在修改主机名...${NC}";;
  n|N ) echo -e "${YELLOW}已取消主机名修改${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消主机名修改${NC}"; exit 1;;
esac

# 修改主机名
hostnamectl set-hostname "$new_hostname"

# 更新 /etc/hosts 文件
if grep -q "$current_hostname" /etc/hosts; then
    sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts
    echo -e "${GREEN}/etc/hosts 文件已更新${NC}"
else
    # 如果没有找到当前主机名，添加一个新条目
    ip=$(hostname -I | awk '{print $1}')
    echo "$ip $new_hostname" >> /etc/hosts
    echo -e "${GREEN}已在 /etc/hosts 文件中添加新主机名条目${NC}"
fi

# 显示修改结果
new_hostname_verification=$(hostname)
if [ "$new_hostname_verification" == "$new_hostname" ]; then
    echo -e "${GREEN}主机名已成功修改为: $new_hostname${NC}"
    echo -e "${YELLOW}注意: 某些程序可能仍在使用旧的主机名，建议重启系统以确保所有程序都使用新的主机名。${NC}"
    
    read -p "是否立即重启系统? (y/n): " reboot_choice
    case "$reboot_choice" in 
      y|Y ) echo -e "${GREEN}系统将在5秒后重启...${NC}"; sleep 5; reboot;;
      n|N ) echo -e "${YELLOW}请在适当的时候手动重启系统${NC}";;
      * ) echo -e "${YELLOW}已取消重启，系统不会立即重启${NC}";;
    esac
else
    echo -e "${RED}主机名修改失败，请手动检查${NC}"
    exit 1
fi

echo ""
read -n 1 -s -r -p "按任意键返回主菜单..."
