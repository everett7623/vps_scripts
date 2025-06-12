#!/bin/bash
#/scripts/performance_test/disk_io_benchmark.sh - VPS Scripts 性能测试工具库

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
        sudo apt install -y fio ioping
    elif command -v yum &>/dev/null; then
        sudo yum install -y fio ioping
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm fio ioping
    else
        echo -e "${RED}无法安装必要的工具，请手动安装。${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}工具安装完成。${NC}"
}

# 获取磁盘列表
get_disk_list() {
    echo -e "${BLUE}正在获取磁盘列表...${NC}"
    
    # 获取所有磁盘
    disks=$(lsblk -d -n -o NAME | grep -v "loop")
    
    # 如果没有找到磁盘，退出
    if [ -z "$disks" ]; then
        echo -e "${RED}✗ 未找到任何磁盘${NC}"
        exit 1
    fi
    
    # 显示磁盘列表
    echo -e "${YELLOW}可用磁盘列表:${NC}"
    i=1
    disk_array=()
    while read -r disk; do
        size=$(lsblk -n -o SIZE /dev/$disk)
        type=$(lsblk -n -o TYPE /dev/$disk)
        echo -e "${GREEN}$i) /dev/$disk - $size ($type)${NC}"
        disk_array+=("/dev/$disk")
        i=$((i+1))
    done <<< "$disks"
    
    # 让用户选择磁盘
    read -p "请选择要测试的磁盘编号 (1-$((i-1))): " disk_choice
    
    # 验证选择
    if [ "$disk_choice" -lt 1 ] || [ "$disk_choice" -ge $i ]; then
        echo -e "${RED}✗ 无效的选择${NC}"
        exit 1
    fi
    
    selected_disk=${disk_array[$((disk_choice-1))]}
    echo -e "${YELLOW}已选择磁盘: ${GREEN}$selected_disk${NC}"
    
    # 获取挂载点
    mount_point=$(df -h | grep $selected_disk | awk '{print $6}')
    if [ -n "$mount_point" ]; then
        echo -e "${YELLOW}挂载点: ${GREEN}$mount_point${NC}"
    else
        echo -e "${YELLOW}未挂载${NC}"
    fi
    
    echo "$selected_disk"
}

# 测试顺序读写性能
test_sequential_io() {
    local disk=$1
    
    echo -e "${BLUE}正在测试磁盘 $disk 的顺序读写性能...${NC}"
    
    # 创建结果文件
    result_file="/tmp/disk_sequential_io_benchmark_$(date +%Y%m%d%H%M%S).txt"
    echo "磁盘顺序读写性能测试结果 - $(date)" > $result_file
    echo "测试磁盘: $disk" >> $result_file
    echo "==============================================" >> $result_file
    
    # 测试顺序读取性能
    echo -e "${YELLOW}正在测试顺序读取性能...${NC}"
    read_result=$(fio --name=seq-read --ioengine=libaio --rw=read --bs=1M --size=1G --numjobs=1 --runtime=30 --time_based --group_reporting | grep "READ:" | awk '{print $5 " " $6}')
    
    echo -e "${GREEN}✓ 顺序读取性能: $read_result${NC}"
    echo "顺序读取性能: $read_result" >> $result_file
    
    # 测试顺序写入性能
    echo -e "${YELLOW}正在测试顺序写入性能...${NC}"
    write_result=$(fio --name=seq-write --ioengine=libaio --rw=write --bs=1M --size=1G --numjobs=1 --runtime=30 --time_based --group_reporting | grep "WRITE:" | awk '{print $5 " " $6}')
    
    echo -e "${GREEN}✓ 顺序写入性能: $write_result${NC}"
    echo "顺序写入性能: $write_result" >> $result_file
    
    # 测试混合读写性能
    echo -e "${YELLOW}正在测试混合读写性能...${NC}"
    mix_result=$(fio --name=seq-mix --ioengine=libaio --rw=rw --rwmixread=70 --bs=1M --size=1G --numjobs=1 --runtime=30 --time_based --group_reporting)
    
    read_mix=$(echo "$mix_result" | grep "READ:" | awk '{print $5 " " $6}')
    write_mix=$(echo "$mix_result" | grep "WRITE:" | awk '{print $5 " " $6}')
    
    echo -e "${GREEN}✓ 混合读取性能: $read_mix${NC}"
    echo -e "${GREEN}✓ 混合写入性能: $write_mix${NC}"
    echo "混合读取性能: $read_mix" >> $result_file
    echo "混合写入性能: $write_mix" >> $result_file
    
    echo -e "${GREEN}磁盘顺序读写性能测试完成。${NC}"
    echo ""
    echo -e "${YELLOW}测试结果已保存到: $result_file${NC}"
    echo ""
}

# 测试随机读写性能
test_random_io() {
    local disk=$1
    
    echo -e "${BLUE}正在测试磁盘 $disk 的随机读写性能...${NC}"
    
    # 创建结果文件
    result_file="/tmp/disk_random_io_benchmark_$(date +%Y%m%d%H%M%S).txt"
    echo "磁盘随机读写性能测试结果 - $(date)" > $result_file
    echo "测试磁盘: $disk" >> $result_file
    echo "==============================================" >> $result_file
    
    # 测试4K随机读取性能
    echo -e "${YELLOW}正在测试4K随机读取性能...${NC}"
    rand4k_read_result=$(fio --name=rand4k-read --ioengine=libaio --rw=randread --bs=4k --size=512M --numjobs=1 --runtime=30 --time_based --group_reporting | grep "READ:" | awk '{print $5 " " $6}')
    
    echo -e "${GREEN}✓ 4K随机读取性能: $rand4k_read_result${NC}"
    echo "4K随机读取性能: $rand4k_read_result" >> $result_file
    
    # 测试4K随机写入性能
    echo -e "${YELLOW}正在测试4K随机写入性能...${NC}"
    rand4k_write_result=$(fio --name=rand4k-write --ioengine=libaio --rw=randwrite --bs=4k --size=512M --numjobs=1 --runtime=30 --time_based --group_reporting | grep "WRITE:" | awk '{print $5 " " $6}')
    
    echo -e "${GREEN}✓ 4K随机写入性能: $rand4k_write_result${NC}"
    echo "4K随机写入性能: $rand4k_write_result" >> $result_file
    
    # 测试4K随机混合读写性能
    echo -e "${YELLOW}正在测试4K随机混合读写性能...${NC}"
    rand4k_mix_result=$(fio --name=rand4k-mix --ioengine=libaio --rw=randrw --rwmixread=70 --bs=4k --size=512M --numjobs=1 --runtime=30 --time_based --group_reporting)
    
    rand4k_read_mix=$(echo "$rand4k_mix_result" | grep "READ:" | awk '{print $5 " " $6}')
    rand4k_write_mix=$(echo "$rand4k_mix_result" | grep "WRITE:" | awk '{print $5 " " $6}')
    
    echo -e "${GREEN}✓ 4K随机混合读取性能: $rand4k_read_mix${NC}"
    echo -e "${GREEN}✓ 4K随机混合写入性能: $rand4k_write_mix${NC}"
    echo "4K随机混合读取性能: $rand4k_read_mix" >> $result_file
    echo "4K随机混合写入性能: $rand4k_write_mix" >> $result_file
    
    echo -e "${GREEN}磁盘随机读写性能测试完成。${NC}"
    echo ""
    echo -e "${YELLOW}测试结果已保存到: $result_file${NC}"
    echo ""
}

# 测试IOPS和延迟
test_iops_latency() {
    local disk=$1
    
    echo -e "${BLUE}正在测试磁盘 $disk 的IOPS和延迟...${NC}"
    
    # 创建结果文件
    result_file="/tmp/disk_iops_latency_benchmark_$(date +%Y%m%d%H%M%S).txt"
    echo "磁盘IOPS和延迟测试结果 - $(date)" > $result_file
    echo "测试磁盘: $disk" >> $result_file
    echo "==============================================" >> $result_file
    
    # 测试4K随机读取IOPS
    echo -e "${YELLOW}正在测试4K随机读取IOPS...${NC}"
    iops_read_result=$(fio --name=iops-read --ioengine=libaio --rw=randread --bs=4k --size=512M --numjobs=1 --runtime=30 --time_based --group_reporting | grep "READ:" | awk '{print $8}')
    
    echo -e "${GREEN}✓ 4K随机读取IOPS: $iops_read_result${NC}"
    echo "4K随机读取IOPS: $iops_read_result" >> $result_file
    
    # 测试4K随机写入IOPS
    echo -e "${YELLOW}正在测试4K随机写入IOPS...${NC}"
    iops_write_result=$(fio --name=iops-write --ioengine=libaio --rw=randwrite --bs=4k --size=512M --numjobs=1 --runtime=30 --time_based --group_reporting | grep "WRITE:" | awk '{print $8}')
    
    echo -e "${GREEN}✓ 4K随机写入IOPS: $iops_write_result${NC}"
    echo "4K随机写入IOPS: $iops_write_result" >> $result_file
    
    # 测试IO延迟
    echo -e "${YELLOW}正在测试IO延迟...${NC}"
    latency_result=$(ioping -c 100 . | grep "Summary" | awk '{print $4 " " $5}')
    
    echo -e "${GREEN}✓ IO延迟: $latency_result${NC}"
    echo "IO延迟: $latency_result" >> $result_file
    
    echo -e "${GREEN}磁盘IOPS和延迟测试完成。${NC}"
    echo ""
    echo -e "${YELLOW}测试结果已保存到: $result_file${NC}"
    echo ""
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           磁盘I/O性能测试工具                ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    # 检查是否已安装必要工具
    if ! command -v fio &>/dev/null || ! command -v ioping &>/dev/null; then
        install_tools
    fi
    
    # 获取要测试的磁盘
    disk=$(get_disk_list)
    
    # 显示测试选项菜单
    echo "请选择要执行的磁盘测试项目:"
    echo "1. 全部测试"
    echo "2. 仅测试顺序读写性能"
    echo "3. 仅测试随机读写性能"
    echo "4. 仅测试IOPS和延迟"
    echo ""
    
    read -p "请输入选项 (1-4): " option
    
    case $option in
        1)
            test_sequential_io $disk
            test_random_io $disk
            test_iops_latency $disk
            ;;
        2) test_sequential_io $disk ;;
        3) test_random_io $disk ;;
        4) test_iops_latency $disk ;;
        *)
            echo -e "${RED}无效选项，操作已取消。${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}磁盘I/O性能测试完成!${NC}"
    read -n 1 -s -r -p "按任意键返回..."
}

# 执行主函数
main
