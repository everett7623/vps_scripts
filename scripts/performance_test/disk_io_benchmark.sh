#!/bin/bash

#==============================================================================
# 脚本名称: disk_io_benchmark.sh
# 描述: VPS磁盘IO性能测试脚本 - 测试顺序读写、随机读写、IOPS等
# 作者: Jensfrank
# 路径: vps_scripts/scripts/performance_test/disk_io_benchmark.sh
# 使用方法: bash disk_io_benchmark.sh [选项]
# 选项: --quick (快速测试) --full (完整测试) --size (测试文件大小GB)
# 更新日期: 2024-06-17
#==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# 配置变量
LOG_DIR="/var/log/vps_scripts"
LOG_FILE="$LOG_DIR/disk_io_benchmark_$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="/var/log/vps_scripts/reports"
REPORT_FILE="$REPORT_DIR/disk_io_benchmark_$(date +%Y%m%d_%H%M%S).txt"
TEMP_DIR="/tmp/disk_io_benchmark_$$"
TEST_DIR="${TEST_PATH:-/tmp}/disk_test_$$"

# 测试模式
QUICK_MODE=false
FULL_MODE=false

# 测试参数
TEST_SIZE=${TEST_SIZE:-1}  # 默认1GB测试文件
DD_BS="1M"
DD_COUNT=$((TEST_SIZE * 1024))
FIO_RUNTIME=30  # FIO测试时长(秒)
IOPING_COUNT=100  # ioping测试次数

# 创建目录
create_directories() {
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    [ ! -d "$REPORT_DIR" ] && mkdir -p "$REPORT_DIR"
    [ ! -d "$TEMP_DIR" ] && mkdir -p "$TEMP_DIR"
    [ ! -d "$TEST_DIR" ] && mkdir -p "$TEST_DIR"
}

# 清理
cleanup() {
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
    [ -d "$TEST_DIR" ] && rm -rf "$TEST_DIR"
    # 清理测试文件
    rm -f /tmp/test_file_* 2>/dev/null
}

trap cleanup EXIT

# 日志记录
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 打印消息
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
    log "$msg"
}

# 检查依赖
check_dependencies() {
    local deps=("fio" "ioping" "hdparm" "dd" "df" "iostat")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_msg "$YELLOW" "缺少依赖工具，正在安装..."
        
        if command -v apt-get &> /dev/null; then
            apt-get update -qq
            apt-get install -y fio ioping hdparm sysstat &>> "$LOG_FILE"
        elif command -v yum &> /dev/null; then
            yum install -y epel-release &>> "$LOG_FILE"
            yum install -y fio ioping hdparm sysstat &>> "$LOG_FILE"
        elif command -v apk &> /dev/null; then
            apk add --no-cache fio ioping hdparm sysstat &>> "$LOG_FILE"
        fi
    fi
}

# 获取磁盘信息
get_disk_info() {
    print_msg "$BLUE" "========== 磁盘基本信息 =========="
    
    # 获取测试目录所在磁盘
    local test_mount=$(df "$TEST_DIR" | tail -1 | awk '{print $NF}')
    local test_device=$(df "$TEST_DIR" | tail -1 | awk '{print $1}')
    
    # 磁盘使用情况
    local disk_info=$(df -h "$TEST_DIR" | tail -1)
    local disk_size=$(echo "$disk_info" | awk '{print $2}')
    local disk_used=$(echo "$disk_info" | awk '{print $3}')
    local disk_avail=$(echo "$disk_info" | awk '{print $4}')
    local disk_usage=$(echo "$disk_info" | awk '{print $5}')
    
    echo -e "${CYAN}测试路径:${NC} $TEST_DIR"
    echo -e "${CYAN}挂载点:${NC} $test_mount"
    echo -e "${CYAN}设备:${NC} $test_device"
    echo -e "${CYAN}总容量:${NC} $disk_size"
    echo -e "${CYAN}已使用:${NC} $disk_used ($disk_usage)"
    echo -e "${CYAN}可用:${NC} $disk_avail"
    
    # 检测磁盘类型（SSD/HDD）
    local disk_type="未知"
    local rotational=$(cat /sys/block/$(basename $test_device | sed 's/[0-9]*$//')/queue/rotational 2>/dev/null)
    
    if [ "$rotational" = "0" ]; then
        disk_type="SSD"
    elif [ "$rotational" = "1" ]; then
        disk_type="HDD"
    fi
    
    # 虚拟磁盘检测
    if [[ "$test_device" =~ ^/dev/(vd|xvd) ]]; then
        disk_type="虚拟磁盘"
    fi
    
    echo -e "${CYAN}磁盘类型:${NC} $disk_type"
    
    # 文件系统信息
    local fs_type=$(df -T "$TEST_DIR" | tail -1 | awk '{print $2}')
    echo -e "${CYAN}文件系统:${NC} $fs_type"
    
    # 检查可用空间是否足够
    local avail_gb=$(df "$TEST_DIR" | tail -1 | awk '{print $4}')
    avail_gb=$((avail_gb / 1024 / 1024))
    
    if [ $avail_gb -lt $((TEST_SIZE * 2)) ]; then
        print_msg "$YELLOW" "警告: 可用空间不足，建议至少有 $((TEST_SIZE * 2))GB 空闲空间"
    fi
    
    # 保存信息
    {
        echo "========== 磁盘信息 =========="
        echo "测试路径: $TEST_DIR"
        echo "设备: $test_device"
        echo "磁盘类型: $disk_type"
        echo "文件系统: $fs_type"
        echo "总容量: $disk_size"
        echo "可用空间: $disk_avail"
        echo ""
    } >> "$REPORT_FILE"
}

# DD测试
dd_test() {
    print_msg "$BLUE" "\n========== DD读写测试 =========="
    
    # 顺序写入测试
    print_msg "$CYAN" "顺序写入测试 (${TEST_SIZE}GB)..."
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
    
    local write_result=$(dd if=/dev/zero of="$TEST_DIR/test_write" bs=$DD_BS count=$DD_COUNT conv=fdatasync 2>&1 | tail -1)
    local write_speed=$(echo "$write_result" | grep -oE '[0-9.]+ [GM]B/s' | tail -1)
    
    if [ -n "$write_speed" ]; then
        echo -e "${GREEN}顺序写入: $write_speed${NC}"
    else
        echo -e "${RED}顺序写入测试失败${NC}"
        write_speed="N/A"
    fi
    
    # 顺序读取测试
    print_msg "$CYAN" "顺序读取测试 (${TEST_SIZE}GB)..."
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
    
    local read_result=$(dd if="$TEST_DIR/test_write" of=/dev/null bs=$DD_BS 2>&1 | tail -1)
    local read_speed=$(echo "$read_result" | grep -oE '[0-9.]+ [GM]B/s' | tail -1)
    
    if [ -n "$read_speed" ]; then
        echo -e "${GREEN}顺序读取: $read_speed${NC}"
    else
        echo -e "${RED}顺序读取测试失败${NC}"
        read_speed="N/A"
    fi
    
    # 清理测试文件
    rm -f "$TEST_DIR/test_write"
    
    # 保存结果
    {
        echo "========== DD测试 =========="
        echo "顺序写入: $write_speed"
        echo "顺序读取: $read_speed"
        echo ""
    } >> "$REPORT_FILE"
}

# FIO测试
fio_test() {
    if ! command -v fio &> /dev/null; then
        print_msg "$YELLOW" "FIO未安装，跳过详细IO测试"
        return
    fi
    
    print_msg "$BLUE" "\n========== FIO性能测试 =========="
    
    # 创建FIO测试配置
    cat > "$TEMP_DIR/fio_test.ini" << EOF
[global]
ioengine=libaio
direct=1
runtime=$FIO_RUNTIME
time_based
group_reporting
numjobs=1
directory=$TEST_DIR

[seq-read]
rw=read
bs=1M
size=${TEST_SIZE}G
name=seq-read
stonewall

[seq-write]
rw=write
bs=1M
size=${TEST_SIZE}G
name=seq-write
stonewall

[rand-read-4k]
rw=randread
bs=4k
size=${TEST_SIZE}G
name=rand-read-4k
stonewall

[rand-write-4k]
rw=randwrite
bs=4k
size=${TEST_SIZE}G
name=rand-write-4k
stonewall

[rand-rw-4k]
rw=randrw
bs=4k
size=${TEST_SIZE}G
name=rand-rw-4k
stonewall
EOF

    # 运行FIO测试
    print_msg "$CYAN" "运行FIO测试套件..."
    fio "$TEMP_DIR/fio_test.ini" --output="$TEMP_DIR/fio_result.txt" &>> "$LOG_FILE"
    
    # 解析结果
    if [ -f "$TEMP_DIR/fio_result.txt" ]; then
        # 顺序读取
        local seq_read=$(grep -A10 "seq-read:" "$TEMP_DIR/fio_result.txt" | grep "READ:" | grep -oE 'BW=[0-9.]+[KMG]iB/s' | cut -d= -f2)
        local seq_read_iops=$(grep -A10 "seq-read:" "$TEMP_DIR/fio_result.txt" | grep "READ:" | grep -oE 'IOPS=[0-9.]+[KMG]?' | cut -d= -f2)
        
        # 顺序写入
        local seq_write=$(grep -A10 "seq-write:" "$TEMP_DIR/fio_result.txt" | grep "WRITE:" | grep -oE 'BW=[0-9.]+[KMG]iB/s' | cut -d= -f2)
        local seq_write_iops=$(grep -A10 "seq-write:" "$TEMP_DIR/fio_result.txt" | grep "WRITE:" | grep -oE 'IOPS=[0-9.]+[KMG]?' | cut -d= -f2)
        
        # 4K随机读取
        local rand_read=$(grep -A10 "rand-read-4k:" "$TEMP_DIR/fio_result.txt" | grep "READ:" | grep -oE 'BW=[0-9.]+[KMG]iB/s' | cut -d= -f2)
        local rand_read_iops=$(grep -A10 "rand-read-4k:" "$TEMP_DIR/fio_result.txt" | grep "READ:" | grep -oE 'IOPS=[0-9.]+[KMG]?' | cut -d= -f2)
        
        # 4K随机写入
        local rand_write=$(grep -A10 "rand-write-4k:" "$TEMP_DIR/fio_result.txt" | grep "WRITE:" | grep -oE 'BW=[0-9.]+[KMG]iB/s' | cut -d= -f2)
        local rand_write_iops=$(grep -A10 "rand-write-4k:" "$TEMP_DIR/fio_result.txt" | grep "WRITE:" | grep -oE 'IOPS=[0-9.]+[KMG]?' | cut -d= -f2)
        
        # 显示结果
        echo -e "${GREEN}顺序读取:${NC} $seq_read (IOPS: $seq_read_iops)"
        echo -e "${GREEN}顺序写入:${NC} $seq_write (IOPS: $seq_write_iops)"
        echo -e "${GREEN}4K随机读:${NC} $rand_read (IOPS: $rand_read_iops)"
        echo -e "${GREEN}4K随机写:${NC} $rand_write (IOPS: $rand_write_iops)"
        
        # 保存结果
        {
            echo "========== FIO测试 =========="
            echo "顺序读取: $seq_read (IOPS: $seq_read_iops)"
            echo "顺序写入: $seq_write (IOPS: $seq_write_iops)"
            echo "4K随机读: $rand_read (IOPS: $rand_read_iops)"
            echo "4K随机写: $rand_write (IOPS: $rand_write_iops)"
            echo ""
        } >> "$REPORT_FILE"
    else
        print_msg "$RED" "FIO测试失败"
    fi
}

# IOPing延迟测试
ioping_test() {
    if ! command -v ioping &> /dev/null; then
        print_msg "$YELLOW" "IOPing未安装，跳过延迟测试"
        return
    fi
    
    print_msg "$BLUE" "\n========== IO延迟测试 =========="
    
    # 延迟测试
    print_msg "$CYAN" "测试IO延迟..."
    
    cd "$TEST_DIR"
    local ioping_result=$(ioping -c $IOPING_COUNT . 2>&1 | tail -n 3)
    
    # 提取延迟信息
    local min_latency=$(echo "$ioping_result" | grep "min/avg/max/mdev" | awk '{print $3}' | sed 's/\///')
    local avg_latency=$(echo "$ioping_result" | grep "min/avg/max/mdev" | awk '{print $4}' | sed 's/\///')
    local max_latency=$(echo "$ioping_result" | grep "min/avg/max/mdev" | awk '{print $5}' | sed 's/\///')
    
    if [ -n "$avg_latency" ]; then
        echo -e "${GREEN}IO延迟:${NC}"
        echo -e "  最小: $min_latency"
        echo -e "  平均: $avg_latency"
        echo -e "  最大: $max_latency"
        
        # 评估延迟
        local avg_us=$(echo "$avg_latency" | grep -oE '[0-9.]+' | head -1)
        local unit=$(echo "$avg_latency" | grep -oE '[a-z]+$')
        
        # 转换为微秒
        case $unit in
            ms) avg_us=$(echo "$avg_us * 1000" | bc) ;;
            s) avg_us=$(echo "$avg_us * 1000000" | bc) ;;
        esac
        
        # 评估
        if (( $(echo "$avg_us < 100" | bc -l) )); then
            echo -e "  ${GREEN}延迟评级: 优秀 (NVMe级别)${NC}"
        elif (( $(echo "$avg_us < 1000" | bc -l) )); then
            echo -e "  ${GREEN}延迟评级: 良好 (SSD级别)${NC}"
        elif (( $(echo "$avg_us < 10000" | bc -l) )); then
            echo -e "  ${YELLOW}延迟评级: 一般 (HDD级别)${NC}"
        else
            echo -e "  ${RED}延迟评级: 较差${NC}"
        fi
    else
        print_msg "$RED" "IO延迟测试失败"
    fi
    
    cd - > /dev/null
    
    # 保存结果
    {
        echo "========== IO延迟 =========="
        echo "最小延迟: $min_latency"
        echo "平均延迟: $avg_latency"
        echo "最大延迟: $max_latency"
        echo ""
    } >> "$REPORT_FILE"
}

# 文件系统性能测试
fs_benchmark() {
    print_msg "$BLUE" "\n========== 文件系统性能测试 =========="
    
    # 小文件创建测试
    print_msg "$CYAN" "小文件创建测试 (1000个1KB文件)..."
    
    local start_time=$(date +%s.%N)
    
    for i in {1..1000}; do
        echo "test" > "$TEST_DIR/small_file_$i"
    done
    sync
    
    local end_time=$(date +%s.%N)
    local create_time=$(echo "$end_time - $start_time" | bc)
    local create_rate=$(echo "scale=2; 1000 / $create_time" | bc)
    
    echo -e "${GREEN}文件创建速率: ${create_rate} 文件/秒${NC}"
    
    # 小文件删除测试
    print_msg "$CYAN" "小文件删除测试..."
    
    start_time=$(date +%s.%N)
    
    rm -f "$TEST_DIR"/small_file_*
    sync
    
    end_time=$(date +%s.%N)
    local delete_time=$(echo "$end_time - $start_time" | bc)
    local delete_rate=$(echo "scale=2; 1000 / $delete_time" | bc)
    
    echo -e "${GREEN}文件删除速率: ${delete_rate} 文件/秒${NC}"
    
    # 保存结果
    {
        echo "========== 文件系统性能 =========="
        echo "文件创建: ${create_rate} 文件/秒"
        echo "文件删除: ${delete_rate} 文件/秒"
        echo ""
    } >> "$REPORT_FILE"
}

# 压力测试
stress_test() {
    print_msg "$BLUE" "\n========== 磁盘压力测试 =========="
    print_msg "$YELLOW" "进行30秒混合读写压力测试..."
    
    if command -v fio &> /dev/null; then
        # 使用FIO进行压力测试
        fio --name=stress \
            --ioengine=libaio \
            --direct=1 \
            --rw=randrw \
            --bs=4k \
            --size=${TEST_SIZE}G \
            --numjobs=4 \
            --runtime=30 \
            --time_based \
            --group_reporting \
            --directory="$TEST_DIR" \
            --output="$TEMP_DIR/stress_result.txt" &>> "$LOG_FILE"
        
        # 提取结果
        if [ -f "$TEMP_DIR/stress_result.txt" ]; then
            local stress_read=$(grep "READ:" "$TEMP_DIR/stress_result.txt" | grep -oE 'BW=[0-9.]+[KMG]iB/s' | cut -d= -f2)
            local stress_write=$(grep "WRITE:" "$TEMP_DIR/stress_result.txt" | grep -oE 'BW=[0-9.]+[KMG]iB/s' | cut -d= -f2)
            local stress_read_iops=$(grep "READ:" "$TEMP_DIR/stress_result.txt" | grep -oE 'IOPS=[0-9.]+[KMG]?' | cut -d= -f2)
            local stress_write_iops=$(grep "WRITE:" "$TEMP_DIR/stress_result.txt" | grep -oE 'IOPS=[0-9.]+[KMG]?' | cut -d= -f2)
            
            echo -e "${GREEN}压力测试结果:${NC}"
            echo -e "  读取: $stress_read (IOPS: $stress_read_iops)"
            echo -e "  写入: $stress_write (IOPS: $stress_write_iops)"
            
            # 保存结果
            {
                echo "========== 压力测试 =========="
                echo "混合读取: $stress_read (IOPS: $stress_read_iops)"
                echo "混合写入: $stress_write (IOPS: $stress_write_iops)"
                echo ""
            } >> "$REPORT_FILE"
        fi
    else
        print_msg "$YELLOW" "FIO未安装，跳过压力测试"
    fi
}

# 性能评分
calculate_score() {
    print_msg "$BLUE" "\n========== 磁盘性能评分 =========="
    
    # 提取IOPS数据用于评分
    local rand_read_iops=$(grep "4K随机读:" "$REPORT_FILE" | grep -oE 'IOPS: [0-9.]+[KMG]?' | awk '{print $2}')
    local rand_write_iops=$(grep "4K随机写:" "$REPORT_FILE" | grep -oE 'IOPS: [0-9.]+[KMG]?' | awk '{print $2}')
    
    # 转换IOPS为数字
    local read_iops_num=0
    local write_iops_num=0
    
    if [ -n "$rand_read_iops" ]; then
        if [[ "$rand_read_iops" =~ K$ ]]; then
            read_iops_num=$(echo "${rand_read_iops%K} * 1000" | bc)
        else
            read_iops_num=${rand_read_iops%[KMG]}
        fi
    fi
    
    if [ -n "$rand_write_iops" ]; then
        if [[ "$rand_write_iops" =~ K$ ]]; then
            write_iops_num=$(echo "${rand_write_iops%K} * 1000" | bc)
        else
            write_iops_num=${rand_write_iops%[KMG]}
        fi
    fi
    
    # 评分标准
    local performance_level=""
    local score_color=""
    
    if (( $(echo "$read_iops_num > 50000" | bc -l) )); then
        performance_level="NVMe高性能"
        score_color=$GREEN
    elif (( $(echo "$read_iops_num > 10000" | bc -l) )); then
        performance_level="SSD标准性能"
        score_color=$GREEN
    elif (( $(echo "$read_iops_num > 1000" | bc -l) )); then
        performance_level="入门级SSD"
        score_color=$YELLOW
    else
        performance_level="HDD级别"
        score_color=$RED
    fi
    
    echo -e "${CYAN}性能等级: ${score_color}${performance_level}${NC}"
    
    # 应用场景建议
    echo -e "\n${CYAN}推荐应用场景:${NC}"
    
    case $performance_level in
        "NVMe高性能")
            echo -e "${GREEN}  ✓ 大型数据库${NC}"
            echo -e "${GREEN}  ✓ 高并发Web应用${NC}"
            echo -e "${GREEN}  ✓ 实时数据处理${NC}"
            echo -e "${GREEN}  ✓ 虚拟化平台${NC}"
            ;;
        "SSD标准性能")
            echo -e "${GREEN}  ✓ 中型数据库${NC}"
            echo -e "${GREEN}  ✓ Web应用服务器${NC}"
            echo -e "${GREEN}  ✓ 缓存服务器${NC}"
            echo -e "${GREEN}  ✓ 开发环境${NC}"
            ;;
        "入门级SSD")
            echo -e "${YELLOW}  ✓ 小型网站${NC}"
            echo -e "${YELLOW}  ✓ 博客系统${NC}"
            echo -e "${YELLOW}  ✓ 轻量级应用${NC}"
            echo -e "${YELLOW}  ⚡ 小型数据库${NC}"
            ;;
        "HDD级别")
            echo -e "${RED}  ✓ 文件存储${NC}"
            echo -e "${RED}  ✓ 备份服务${NC}"
            echo -e "${RED}  ✓ 冷数据存储${NC}"
            echo -e "${RED}  ✗ 不适合数据库应用${NC}"
            ;;
    esac
}

# 生成报告
generate_report() {
    print_msg "$BLUE" "\n生成测试报告..."
    
    local summary_file="$REPORT_DIR/disk_io_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "        磁盘IO性能测试报告"
        echo "=========================================="
        echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "测试主机: $(hostname)"
        echo "测试大小: ${TEST_SIZE}GB"
        echo ""
        
        cat "$REPORT_FILE"
        
        echo ""
        echo "=========================================="
        echo "测试说明:"
        echo "1. 顺序读写测试使用${TEST_SIZE}GB文件"
        echo "2. 4K随机读写最能反映真实性能"
        echo "3. IOPS越高表示随机IO性能越好"
        echo "4. 延迟越低表示响应速度越快"
        echo ""
        echo "详细日志: $LOG_FILE"
        echo "=========================================="
    } | tee "$summary_file"
    
    print_msg "$GREEN" "\n测试报告已保存到: $summary_file"
}

# 快速测试
quick_test() {
    get_disk_info
    dd_test
    ioping_test
}

# 完整测试
full_test() {
    get_disk_info
    dd_test
    fio_test
    ioping_test
    fs_benchmark
    stress_test
}

# 交互式菜单
interactive_menu() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                        VPS 磁盘IO性能测试工具 v1.0                        ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 显示当前磁盘信息
    local disk_info=$(df -h / | tail -1)
    local disk_avail=$(echo "$disk_info" | awk '{print $4}')
    echo -e "${CYAN}根目录可用空间: $disk_avail${NC}"
    echo ""
    
    echo -e "${CYAN}请选择测试模式:${NC}"
    echo -e "${GREEN}1)${NC} 快速测试 (DD + 延迟)"
    echo -e "${GREEN}2)${NC} 标准测试 (推荐)"
    echo -e "${GREEN}3)${NC} 完整测试 (包含压力测试)"
    echo -e "${GREEN}4)${NC} 自定义测试"
    echo -e "${GREEN}5)${NC} 更改测试参数"
    echo -e "${GREEN}0)${NC} 退出"
    echo ""
    
    read -p "请输入选项 [0-5]: " choice
    
    case $choice in
        1)
            QUICK_MODE=true
            quick_test
            calculate_score
            generate_report
            ;;
        2)
            get_disk_info
            dd_test
            fio_test
            ioping_test
            calculate_score
            generate_report
            ;;
        3)
            FULL_MODE=true
            full_test
            calculate_score
            generate_report
            ;;
        4)
            custom_test_menu
            ;;
        5)
            change_parameters
            ;;
        0)
            print_msg "$YELLOW" "退出程序"
            exit 0
            ;;
        *)
            print_msg "$RED" "无效选项"
            sleep 2
            interactive_menu
            ;;
    esac
}

# 自定义测试菜单
custom_test_menu() {
    clear
    echo -e "${CYAN}选择要进行的测试:${NC}"
    echo -e "${GREEN}1)${NC} DD顺序读写测试"
    echo -e "${GREEN}2)${NC} FIO综合性能测试"
    echo -e "${GREEN}3)${NC} IO延迟测试"
    echo -e "${GREEN}4)${NC} 文件系统性能测试"
    echo -e "${GREEN}5)${NC} 磁盘压力测试"
    echo -e "${GREEN}0)${NC} 返回主菜单"
    echo ""
    
    read -p "请输入选项 [0-5]: " test_choice
    
    case $test_choice in
        1) dd_test ;;
        2) fio_test ;;
        3) ioping_test ;;
        4) fs_benchmark ;;
        5) stress_test ;;
        0) interactive_menu ;;
        *)
            print_msg "$RED" "无效选项"
            sleep 2
            custom_test_menu
            ;;
    esac
}

# 更改测试参数
change_parameters() {
    clear
    echo -e "${CYAN}当前测试参数:${NC}"
    echo -e "  测试文件大小: ${TEST_SIZE}GB"
    echo -e "  测试路径: ${TEST_DIR%/*}"
    echo ""
    
    read -p "输入新的测试文件大小(GB) [回车保持当前]: " new_size
    if [ -n "$new_size" ] && [[ "$new_size" =~ ^[0-9]+$ ]]; then
        TEST_SIZE=$new_size
        DD_COUNT=$((TEST_SIZE * 1024))
    fi
    
    read -p "输入新的测试路径 [回车保持当前]: " new_path
    if [ -n "$new_path" ] && [ -d "$new_path" ]; then
        TEST_DIR="$new_path/disk_test_$$"
        mkdir -p "$TEST_DIR"
    fi
    
    print_msg "$GREEN" "参数已更新"
    sleep 2
    interactive_menu
}

# 显示帮助
show_help() {
    cat << EOF
使用方法: $0 [选项]

选项:
  --quick     快速测试模式
  --full      完整测试模式
  --size N    设置测试文件大小(GB)，默认1GB
  --help, -h  显示此帮助信息

示例:
  $0              # 交互式菜单
  $0 --quick      # 快速测试
  $0 --full       # 完整测试
  $0 --size 5     # 使用5GB测试文件

测试项目:
  - DD顺序读写测试
  - FIO综合性能测试
  - IO延迟测试
  - 文件系统性能测试
  - 磁盘压力测试

注意:
  - 测试需要足够的磁盘空间
  - 建议在系统负载较低时测试
  - 测试会产生大量IO操作
EOF
}

# 解析参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                QUICK_MODE=true
                shift
                ;;
            --full)
                FULL_MODE=true
                shift
                ;;
            --size)
                TEST_SIZE=$2
                DD_COUNT=$((TEST_SIZE * 1024))
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_msg "$RED" "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 主函数
main() {
    # 初始化
    create_directories
    check_dependencies
    
    # 解析参数
    parse_arguments "$@"
    
    # 开始测试
    log "开始磁盘IO性能测试"
    
    {
        echo "========== 磁盘IO性能测试 =========="
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
    } > "$REPORT_FILE"
    
    if [ "$QUICK_MODE" = true ]; then
        quick_test
        calculate_score
        generate_report
    elif [ "$FULL_MODE" = true ]; then
        full_test
        calculate_score
        generate_report
    else
        interactive_menu
    fi
    
    print_msg "$GREEN" "\n磁盘IO性能测试完成！"
}

# 运行主函数
main "$@"
