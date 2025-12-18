#!/bin/bash

# ==============================================================================
#                          Nezha Agent Cleanup Tool
#
#      Project: https://github.com/everett7623/nezha-agent-cleaner
#      Author: everett7623
#      Version: 1.2 (Intelligent Path Tracking)
#
#      Description: A safe utility to completely remove Nezha Agent with
#                   intelligent path tracking, even for non-standard installations.
#      
#      Safety Features:
#      - Fixed critical bug: removed dangerous "*agent*" wildcard
#      - Intelligent process tracking to find installation paths
#      - System directory protection (prevents deletion of /usr, /bin, etc.)
#      - Double confirmation before deletion
# ==============================================================================

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印运行时的欢迎横幅
echo -e "${BLUE}=================================================================${NC}"
echo -e "${GREEN}        哪吒探针Agent彻底清理脚本 v1.2 (智能追踪版)          ${NC}"
echo -e "${GREEN}        Nezha Agent Removal Tool v1.2 (Smart Tracking)         ${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo -e "${CYAN}新特性: 智能路径追踪 + 系统目录保护${NC}"
echo -e "${CYAN}New: Intelligent path tracking + system protection${NC}"
echo -e "${BLUE}=================================================================${NC}"

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}[错误] 此脚本必须以root权限运行！${NC}" 
   echo -e "${RED}[Error] This script must be run as root!${NC}" 
   exit 1
fi

echo -e "${YELLOW}[信息] 开始清理哪吒探针Agent...${NC}"
echo -e "${YELLOW}[INFO] Starting Nezha Agent cleanup...${NC}"

# 定义系统保护目录列表（不应被删除的目录）
PROTECTED_DIRS=(
    "/bin"
    "/sbin"
    "/usr"
    "/lib"
    "/lib64"
    "/boot"
    "/dev"
    "/proc"
    "/sys"
    "/run"
    "/var"
    "/etc"
)

# 函数：检查路径是否为系统保护目录
is_protected_dir() {
    local path="$1"
    local real_path=$(realpath "$path" 2>/dev/null || echo "$path")
    
    for protected in "${PROTECTED_DIRS[@]}"; do
        if [[ "$real_path" == "$protected" ]] || [[ "$real_path" == "$protected"/* ]]; then
            return 0  # 是保护目录
        fi
    done
    return 1  # 不是保护目录
}

# 步骤1: 检查和显示系统中的nezha进程
echo -e "\n${BLUE}[步骤1] 检查哪吒探针进程...${NC}"
echo -e "${BLUE}[Step1] Checking Nezha Agent processes...${NC}"
ps_result=$(ps aux | grep -E "[n]ezha-agent")
if [ -n "$ps_result" ]; then
    echo -e "${YELLOW}发现哪吒探针进程:${NC}"
    echo -e "${YELLOW}Found Nezha Agent processes:${NC}"
    echo "$ps_result"
else
    echo -e "${GREEN}未发现哪吒探针进程${NC}"
    echo -e "${GREEN}No Nezha Agent processes found${NC}"
fi

# 步骤1.5: 智能路径追踪 - 通过进程找到所有相关路径
echo -e "\n${CYAN}[步骤1.5] 🔍 智能路径追踪...${NC}"
echo -e "${CYAN}[Step1.5] 🔍 Intelligent path tracking...${NC}"

# 创建数组存储发现的路径
declare -a TRACKED_PATHS

# 通过进程追踪可执行文件路径
if pgrep -f "nezha-agent" >/dev/null; then
    echo -e "${YELLOW}正在追踪运行中的进程路径...${NC}"
    echo -e "${YELLOW}Tracking running process paths...${NC}"
    
    while IFS= read -r proc_path; do
        if [ -n "$proc_path" ] && [ -f "$proc_path" ]; then
            real_path=$(realpath "$proc_path" 2>/dev/null)
            if [ -n "$real_path" ]; then
                TRACKED_PATHS+=("$real_path")
                parent_dir=$(dirname "$real_path")
                
                # 如果可执行文件在子目录中，也追踪父目录
                if [[ "$parent_dir" != "/usr/bin" ]] && [[ "$parent_dir" != "/bin" ]] && [[ "$parent_dir" != "/usr/sbin" ]] && [[ "$parent_dir" != "/sbin" ]]; then
                    TRACKED_PATHS+=("$parent_dir")
                fi
                
                echo -e "${CYAN}  → 追踪到: $real_path${NC}"
            fi
        fi
    done < <(pgrep -f "nezha-agent" | xargs -I {} readlink -f /proc/{}/exe 2>/dev/null | sort -u)
fi

# 通过systemd服务追踪路径
if systemctl list-units --type=service --all | grep -qiE "nezha-agent|nezha\.service"; then
    echo -e "${YELLOW}正在分析systemd服务配置...${NC}"
    echo -e "${YELLOW}Analyzing systemd service configs...${NC}"
    
    while IFS= read -r service_file; do
        if [ -f "$service_file" ]; then
            # 从服务文件中提取ExecStart路径
            exec_start=$(grep -E "^ExecStart=" "$service_file" | sed 's/ExecStart=//' | awk '{print $1}')
            if [ -n "$exec_start" ] && [ -f "$exec_start" ]; then
                real_path=$(realpath "$exec_start" 2>/dev/null)
                if [ -n "$real_path" ]; then
                    TRACKED_PATHS+=("$real_path")
                    parent_dir=$(dirname "$real_path")
                    if ! is_protected_dir "$parent_dir"; then
                        TRACKED_PATHS+=("$parent_dir")
                    fi
                    echo -e "${CYAN}  → 从服务追踪到: $real_path${NC}"
                fi
            fi
            
            # 提取WorkingDirectory
            working_dir=$(grep -E "^WorkingDirectory=" "$service_file" | sed 's/WorkingDirectory=//')
            if [ -n "$working_dir" ] && [ -d "$working_dir" ]; then
                real_path=$(realpath "$working_dir" 2>/dev/null)
                if [ -n "$real_path" ] && ! is_protected_dir "$real_path"; then
                    TRACKED_PATHS+=("$real_path")
                    echo -e "${CYAN}  → 工作目录: $real_path${NC}"
                fi
            fi
        fi
    done < <(find /etc/systemd/system/ -type f \( -name "*nezha-agent*" -o -name "*nezha.service*" \) 2>/dev/null)
fi

# 去重并显示所有追踪到的路径
if [ ${#TRACKED_PATHS[@]} -gt 0 ]; then
    # 使用关联数组去重
    declare -A unique_paths
    for path in "${TRACKED_PATHS[@]}"; do
        unique_paths["$path"]=1
    done
    
    echo -e "\n${GREEN}✓ 智能追踪发现以下安装路径:${NC}"
    echo -e "${GREEN}✓ Intelligent tracking found these installation paths:${NC}"
    for path in "${!unique_paths[@]}"; do
        if [ -e "$path" ]; then
            echo -e "${YELLOW}  📍 $path${NC}"
        fi
    done
else
    echo -e "${GREEN}未通过进程追踪到特殊安装路径${NC}"
    echo -e "${GREEN}No special installation paths tracked from processes${NC}"
fi

# 步骤2: 检查定时任务（精确匹配nezha-agent）
echo -e "\n${BLUE}[步骤2] 检查相关定时任务...${NC}"
echo -e "${BLUE}[Step2] Checking related cron jobs...${NC}"
cron_result=$(crontab -l 2>/dev/null | grep -iE "nezha-agent|/nezha/" || echo "No crontab found")
if [ "$cron_result" != "No crontab found" ]; then
    echo -e "${YELLOW}发现相关定时任务:${NC}"
    echo -e "${YELLOW}Found related cron jobs:${NC}"
    echo "$cron_result"
    
    echo -e "${YELLOW}正在移除相关定时任务...${NC}"
    echo -e "${YELLOW}Removing related cron jobs...${NC}"
    crontab -l | grep -v -iE "nezha-agent|/nezha/" | crontab -
    echo -e "${GREEN}定时任务清理完成${NC}"
    echo -e "${GREEN}Cron jobs cleaned${NC}"
else
    echo -e "${GREEN}未发现相关定时任务${NC}"
    echo -e "${GREEN}No related cron jobs found${NC}"
fi

# 步骤3: 停止并禁用所有nezha-agent服务（精确匹配）
echo -e "\n${BLUE}[步骤3] 停止并禁用所有哪吒探针服务...${NC}"
echo -e "${BLUE}[Step3] Stopping and disabling all Nezha Agent services...${NC}"
nezha_services=$(systemctl list-units --type=service --all | grep -iE "nezha-agent|nezha\.service" | awk '{print $1}')
if [ -n "$nezha_services" ]; then
    echo -e "${YELLOW}发现以下哪吒探针服务:${NC}"
    echo -e "${YELLOW}Found the following Nezha Agent services:${NC}"
    echo "$nezha_services"
    
    for service in $nezha_services; do
        echo -e "${YELLOW}停止并禁用 $service...${NC}"
        echo -e "${YELLOW}Stopping and disabling $service...${NC}"
        systemctl stop "$service" 2>/dev/null
        systemctl disable "$service" 2>/dev/null
    done
    echo -e "${GREEN}所有服务已停止并禁用${NC}"
    echo -e "${GREEN}All services stopped and disabled${NC}"
else
    echo -e "${GREEN}未发现哪吒探针服务${NC}"
    echo -e "${GREEN}No Nezha Agent services found${NC}"
fi

# 步骤4: 杀死所有相关进程
echo -e "\n${BLUE}[步骤4] 强制终止所有哪吒探针进程...${NC}"
echo -e "${BLUE}[Step4] Forcefully terminating all Nezha Agent processes...${NC}"
if pgrep -f "nezha-agent" >/dev/null; then
    echo -e "${YELLOW}正在终止进程...${NC}"
    echo -e "${YELLOW}Terminating processes...${NC}"
    pkill -9 -f "nezha-agent"
    sleep 1
    echo -e "${GREEN}进程已终止${NC}"
    echo -e "${GREEN}Processes terminated${NC}"
else
    echo -e "${GREEN}没有需要终止的进程${NC}"
    echo -e "${GREEN}No processes to terminate${NC}"
fi

# 步骤5: 删除所有服务文件（精确匹配）
echo -e "\n${BLUE}[步骤5] 删除所有服务文件...${NC}"
echo -e "${BLUE}[Step5] Removing all service files...${NC}"
service_files=$(find /etc/systemd/system/ -type f \( -name "*nezha-agent*" -o -name "*nezha.service*" \) 2>/dev/null)
if [ -n "$service_files" ]; then
    echo -e "${YELLOW}发现以下服务文件:${NC}"
    echo -e "${YELLOW}Found the following service files:${NC}"
    echo "$service_files"
    
    echo -e "${YELLOW}删除服务文件...${NC}"
    echo -e "${YELLOW}Removing service files...${NC}"
    find /etc/systemd/system/ -type f \( -name "*nezha-agent*" -o -name "*nezha.service*" \) -exec rm -f {} \; 2>/dev/null
    echo -e "${GREEN}服务文件已删除${NC}"
    echo -e "${GREEN}Service files removed${NC}"
else
    echo -e "${GREEN}未发现服务文件${NC}"
    echo -e "${GREEN}No service files found${NC}"
fi

# 步骤6: 删除标准位置的二进制文件和目录
echo -e "\n${BLUE}[步骤6] 删除标准位置的二进制文件和目录...${NC}"
echo -e "${BLUE}[Step6] Removing binaries and directories in standard locations...${NC}"

# 标准安装目录
directories=(
    "/opt/nezha"
    "/opt/nezha-agent"
    "/usr/local/nezha"
)

# 标准二进制文件位置
binaries=(
    "/usr/local/bin/nezha-agent"
    "/usr/bin/nezha-agent"
    "/usr/sbin/nezha-agent"
    "/bin/nezha-agent"
)

for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${YELLOW}删除目录: $dir${NC}"
        echo -e "${YELLOW}Removing directory: $dir${NC}"
        rm -rf "$dir"
    fi
done

for bin in "${binaries[@]}"; do
    if [ -f "$bin" ]; then
        echo -e "${YELLOW}删除二进制文件: $bin${NC}"
        echo -e "${YELLOW}Removing binary file: $bin${NC}"
        rm -f "$bin"
    fi
done

# 步骤6.5: 删除智能追踪到的非标准路径
if [ ${#unique_paths[@]} -gt 0 ]; then
    echo -e "\n${CYAN}[步骤6.5] 🎯 清理智能追踪到的路径...${NC}"
    echo -e "${CYAN}[Step6.5] 🎯 Cleaning tracked paths...${NC}"
    
    for path in "${!unique_paths[@]}"; do
        if [ -e "$path" ]; then
            # 检查是否为系统保护目录
            if is_protected_dir "$path"; then
                echo -e "${RED}⚠️  跳过系统保护目录: $path${NC}"
                echo -e "${RED}⚠️  Skipping protected system directory: $path${NC}"
                continue
            fi
            
            # 再次确认路径包含nezha
            if [[ "$path" == *"nezha"* ]]; then
                echo -e "${YELLOW}删除追踪到的路径: $path${NC}"
                echo -e "${YELLOW}Removing tracked path: $path${NC}"
                rm -rf "$path" 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓ 已删除${NC}"
                else
                    echo -e "${RED}✗ 删除失败${NC}"
                fi
            else
                echo -e "${YELLOW}⚠️  路径不包含nezha，跳过: $path${NC}"
            fi
        fi
    done
fi

# 步骤7: 查找和删除所有相关文件（全局搜索）
echo -e "\n${BLUE}[步骤7] 查找并删除所有相关文件（全局搜索）...${NC}"
echo -e "${BLUE}[Step7] Finding and removing all related files (global search)...${NC}"
echo -e "${YELLOW}正在搜索系统中的哪吒探针相关文件...${NC}"
echo -e "${YELLOW}Searching for Nezha Agent related files in the system...${NC}"

# 创建临时文件保存查找结果
temp_file=$(mktemp)

# ⚠️ 安全修复：只搜索包含 "nezha" 的文件
# ⚠️ Safety Fix: Only search for files containing "nezha"
find /root /home /tmp /var/tmp /etc /usr/local /opt /data /www 2>/dev/null | grep -i "nezha" > "$temp_file"

if [ -s "$temp_file" ]; then
    echo -e "${YELLOW}发现以下相关文件:${NC}"
    echo -e "${YELLOW}Found the following related files:${NC}"
    cat "$temp_file"
    
    echo -e "\n${YELLOW}是否删除这些文件? [y/N] ${NC}"
    echo -e "${YELLOW}Would you like to delete these files? [y/N] ${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        while IFS= read -r file; do
            # 三重安全检查
            if [[ "$file" == *"nezha"* ]] && [ -e "$file" ] && ! is_protected_dir "$file"; then
                echo -e "${YELLOW}删除: $file${NC}"
                echo -e "${YELLOW}Removing: $file${NC}"
                rm -rf "$file" 2>/dev/null
            elif is_protected_dir "$file"; then
                echo -e "${RED}⚠️  跳过系统保护路径: $file${NC}"
            fi
        done < "$temp_file"
        echo -e "${GREEN}文件已删除${NC}"
        echo -e "${GREEN}Files removed${NC}"
    else
        echo -e "${YELLOW}跳过删除文件${NC}"
        echo -e "${YELLOW}Skipping file removal${NC}"
    fi
else
    echo -e "${GREEN}未发现相关文件${NC}"
    echo -e "${GREEN}No related files found${NC}"
fi

# 删除临时文件
rm -f "$temp_file"

# 步骤8: 重新加载systemd
echo -e "\n${BLUE}[步骤8] 重新加载systemd配置...${NC}"
echo -e "${BLUE}[Step8] Reloading systemd configuration...${NC}"
systemctl daemon-reload
echo -e "${GREEN}systemd配置已重新加载${NC}"
echo -e "${GREEN}systemd configuration reloaded${NC}"

# 步骤9: 检查Docker容器（精确匹配）
echo -e "\n${BLUE}[步骤9] 检查相关Docker容器...${NC}"
echo -e "${BLUE}[Step9] Checking related Docker containers...${NC}"
if command -v docker &> /dev/null; then
    nezha_containers=$(docker ps -a --format "{{.ID}}\t{{.Names}}\t{{.Image}}" | grep -iE "nezha-agent|nezha:" || echo "No containers found")
    if [ "$nezha_containers" != "No containers found" ]; then
        echo -e "${YELLOW}发现以下相关Docker容器:${NC}"
        echo -e "${YELLOW}Found the following related Docker containers:${NC}"
        echo "$nezha_containers"
        
        echo -e "${YELLOW}是否停止并删除这些容器? [y/N] ${NC}"
        echo -e "${YELLOW}Would you like to stop and remove these containers? [y/N] ${NC}"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            container_ids=$(docker ps -a --format "{{.ID}}\t{{.Names}}\t{{.Image}}" | grep -iE "nezha-agent|nezha:" | awk '{print $1}')
            for id in $container_ids; do
                echo -e "${YELLOW}停止并删除容器: $id${NC}"
                echo -e "${YELLOW}Stopping and removing container: $id${NC}"
                docker stop "$id" 2>/dev/null
                docker rm "$id" 2>/dev/null
            done
            echo -e "${GREEN}容器已清理${NC}"
            echo -e "${GREEN}Containers cleaned${NC}"
        else
            echo -e "${YELLOW}跳过容器清理${NC}"
            echo -e "${YELLOW}Skipping container cleanup${NC}"
        fi
    else
        echo -e "${GREEN}未发现相关Docker容器${NC}"
        echo -e "${GREEN}No related Docker containers found${NC}"
    fi
else
    echo -e "${YELLOW}Docker未安装，跳过检查${NC}"
    echo -e "${YELLOW}Docker not installed, skipping check${NC}"
fi

# 步骤10: 最终检查
echo -e "\n${BLUE}[步骤10] 最终检查...${NC}"
echo -e "${BLUE}[Step10] Final check...${NC}"

# 检查是否还有任何nezha进程
if pgrep -f "nezha-agent" >/dev/null; then
    echo -e "${RED}⚠️  警告: 仍然检测到哪吒探针进程!${NC}"
    echo -e "${RED}⚠️  Warning: Nezha Agent processes still detected!${NC}"
    ps aux | grep -E "[n]ezha-agent"
else
    echo -e "${GREEN}✓ 未检测到任何哪吒探针进程${NC}"
    echo -e "${GREEN}✓ No Nezha Agent processes detected${NC}"
fi

# 检查是否还有任何服务
nezha_services_remaining=$(systemctl list-units --type=service --all | grep -iE "nezha-agent|nezha\.service" | awk '{print $1}')
if [ -n "$nezha_services_remaining" ]; then
    echo -e "${RED}⚠️  警告: 仍然检测到哪吒探针服务!${NC}"
    echo -e "${RED}⚠️  Warning: Nezha Agent services still detected!${NC}"
    echo "$nezha_services_remaining"
else
    echo -e "${GREEN}✓ 未检测到任何哪吒探针服务${NC}"
    echo -e "${GREEN}✓ No Nezha Agent services detected${NC}"
fi

# 检查是否还有残留文件
remaining_files=$(find /root /home /opt /usr/local /data /www 2>/dev/null | grep -i "nezha" | head -10)
if [ -n "$remaining_files" ]; then
    echo -e "${YELLOW}⚠️  发现一些可能的残留文件:${NC}"
    echo -e "${YELLOW}⚠️  Found some possible remaining files:${NC}"
    echo "$remaining_files"
    echo -e "${YELLOW}如需手动清理，请检查这些文件${NC}"
    echo -e "${YELLOW}Please check these files for manual cleanup if needed${NC}"
else
    echo -e "${GREEN}✓ 未发现任何残留文件${NC}"
    echo -e "${GREEN}✓ No remaining files detected${NC}"
fi

echo -e "\n${BLUE}=================================================================${NC}"
echo -e "${GREEN}           哪吒探针Agent清理完成!                               ${NC}"
echo -e "${GREEN}           Nezha Agent cleanup complete!                         ${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo -e "${CYAN}v1.2 新特性已启用: 智能路径追踪 + 系统保护${NC}"
echo -e "${CYAN}v1.2 features enabled: Smart tracking + system protection${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo -e "${YELLOW}如果您在清理后仍然遇到问题，可能需要考虑系统重启。${NC}"
echo -e "${YELLOW}If issues persist after cleanup, consider restarting your system.${NC}"
echo -e "\n${GREEN}感谢使用此脚本!${NC}"
echo -e "${GREEN}Thank you for using this script!${NC}"

exit 0
