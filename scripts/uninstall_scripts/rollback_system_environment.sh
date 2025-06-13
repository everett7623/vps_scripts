#!/bin/bash
#/vps_scripts/scripts/uninstall_scripts/rollback_system_environment.sh - VPS Scripts 系统环境回滚工具

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

echo -e "${WHITE}VPS Scripts 系统环境回滚工具${NC}"
echo "------------------------"

# 确认操作
echo -e "${YELLOW}警告: 此操作将回滚系统环境${NC}"
echo -e "${YELLOW}移除VPS Scripts安装过程中对系统环境所做的更改${NC}"
echo -e "${RED}此操作不可逆转，可能导致系统不稳定${NC}"
read -p "确定要继续吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}开始回滚系统环境...${NC}";;
  n|N ) echo -e "${YELLOW}已取消操作${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消操作${NC}"; exit 1;;
esac

# 获取当前脚本目录
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(realpath "$SCRIPT_DIR/..")

# 创建备份目录
BACKUP_DIR="$PARENT_DIR/backup/environment_rollback_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 环境变量列表
echo -e "${WHITE}可回滚的环境变量:${NC}"
echo "1. BBR网络加速"
echo "2. Fail2ban安全防护"
echo "3. Swap空间"
echo "4. 系统时区"
echo "5. 系统主机名"
echo "6. 系统内核"
echo "7. 全部环境"
echo ""

# 获取用户选择
read -p "请选择要回滚的环境变量编号 (1-7): " choice

# 根据用户选择回滚环境
case "$choice" in
    1) # BBR网络加速
        echo -e "${WHITE}回滚BBR网络加速...${NC}"
        
        # 备份当前配置
        cp /etc/sysctl.conf "$BACKUP_DIR/sysctl.conf.bak"
        
        # 移除BBR配置
        sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
        
        # 应用新配置
        sysctl -p
        
        echo -e "${GREEN}BBR网络加速已回滚${NC}"
        ;;
        
    2) # Fail2ban安全防护
        echo -e "${WHITE}回滚Fail2ban安全防护...${NC}"
        
        # 停止服务
        systemctl stop fail2ban &> /dev/null
        systemctl disable fail2ban &> /dev/null
        
        # 检测系统类型
        if [ -f /etc/redhat-release ]; then
            yum remove -y fail2ban
        else
            apt-get purge -y fail2ban
        fi
        
        # 删除残留文件
        rm -rf /etc/fail2ban
        
        echo -e "${GREEN}Fail2ban安全防护已回滚${NC}"
        ;;
        
    3) # Swap空间
        echo -e "${WHITE}回滚Swap空间...${NC}"
        
        # 备份当前配置
        cp /etc/fstab "$BACKUP_DIR/fstab.bak"
        
        # 关闭swap
        swapoff -a
        
        # 移除swap配置
        sed -i '/swap/d' /etc/fstab
        
        # 删除swap文件
        rm -f /swapfile
        
        echo -e "${GREEN}Swap空间已回滚${NC}"
        ;;
        
    4) # 系统时区
        echo -e "${WHITE}回滚系统时区...${NC}"
        
        # 备份当前配置
        cp /etc/timezone "$BACKUP_DIR/timezone.bak" 2> /dev/null
        cp /etc/localtime "$BACKUP_DIR/localtime.bak" 2> /dev/null
        
        # 设置默认时区为UTC
        timedatectl set-timezone UTC
        
        echo -e "${GREEN}系统时区已回滚为UTC${NC}"
        ;;
        
    5) # 系统主机名
        echo -e "${WHITE}回滚系统主机名...${NC}"
        
        # 获取原始主机名
        read -p "请输入原始主机名: " original_hostname
        
        # 备份当前配置
        cp /etc/hostname "$BACKUP_DIR/hostname.bak"
        cp /etc/hosts "$BACKUP_DIR/hosts.bak"
        
        # 修改主机名
        hostnamectl set-hostname "$original_hostname"
        
        # 更新hosts文件
        sed -i "s/$(hostname)/$original_hostname/g" /etc/hosts
        
        echo -e "${GREEN}系统主机名已回滚为: $original_hostname${NC}"
        ;;
        
    6) # 系统内核
        echo -e "${WHITE}回滚系统内核...${NC}"
        
        echo -e "${YELLOW}警告: 回滚系统内核可能导致系统不稳定${NC}"
        read -p "确定要继续吗? (y/n): " confirm_kernel
        case "$confirm_kernel" in 
          y|Y ) echo -e "${GREEN}开始回滚系统内核...${NC}";;
          n|N ) echo -e "${YELLOW}已取消内核回滚${NC}"; exit 0;;
          * ) echo -e "${RED}无效选择，已取消内核回滚${NC}"; exit 1;;
        esac
        
        # 检测系统类型
        if [ -f /etc/redhat-release ]; then
            # 列出可用内核
            echo -e "${WHITE}可用内核列表:${NC}"
            rpm -qa kernel | sort -V
            
            read -p "请输入要回滚到的内核版本 (例如: kernel-5.15.0-71-generic): " kernel_version
            
            # 安装指定内核
            yum install -y "$kernel_version"
            
            # 设置默认启动内核
            grubby --set-default /boot/vmlinuz-$(echo "$kernel_version" | cut -d "-" -f 2-)
            
            echo -e "${GREEN}系统内核已设置为: $kernel_version${NC}"
            echo -e "${YELLOW}注意: 请重启系统以应用新内核${NC}"
        else
            # 列出可用内核
            echo -e "${WHITE}可用内核列表:${NC}"
            dpkg -l | grep linux-image | grep -v linux-modules | grep -v linux-headers
            
            read -p "请输入要回滚到的内核版本 (例如: linux-image-5.15.0-71-generic): " kernel_version
            
            # 安装指定内核
            apt-get install -y "$kernel_version"
            
            # 更新GRUB
            update-grub
            
            echo -e "${GREEN}系统内核已设置为: $kernel_version${NC}"
            echo -e "${YELLOW}注意: 请重启系统以应用新内核${NC}"
        fi
        ;;
        
    7) # 全部环境
        echo -e "${WHITE}回滚所有系统环境...${NC}"
        
        # 执行所有回滚操作
        bash "$0" <<< "1"
        bash "$0" <<< "2"
        bash "$0" <<< "3"
        bash "$0" <<< "4"
        bash "$0" <<< "5"
        
        echo -e "${GREEN}所有系统环境已回滚${NC}"
        ;;
        
    *) 
        echo -e "${RED}错误: 无效的选择${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}系统环境回滚完成${NC}"
echo -e "${WHITE}备份目录: ${YELLOW}$BACKUP_DIR${NC}"
echo ""
read -n 1 -s -r -p "按任意键返回主菜单..."
