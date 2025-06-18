#!/bin/bash

#==============================================================================
# 脚本名称: memory_benchmark.sh
# 描述: VPS内存性能测试脚本 - 测试内存带宽、延迟、稳定性等
# 作者: Jensfrank
# 路径: vps_scripts/scripts/performance_test/memory_benchmark.sh
# 使用方法: bash memory_benchmark.sh [选项]
# 选项: --quick (快速测试) --full (完整测试) --stress (压力测试)
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
LOG_FILE="$LOG_DIR/memory_benchmark_$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="/var/log/vps_scripts/reports"
REPORT_FILE="$REPORT_DIR/memory_benchmark_$(date +%Y%m%d_%H%M%S).txt"
TEMP_DIR="/tmp/memory_benchmark_$$"

# 测试模式
QUICK_MODE=false
FULL_MODE=false
STRESS_MODE=false

# 测试参数
STRESS_DURATION=300  # 压力测试时长(秒)
MEMTEST_LOOPS=1      # 内存测试循环次数
STREAM_THREADS=$(nproc)  # STREAM测试线程数

# 创建目录
create_directories() {
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    [ ! -d "$REPORT_DIR" ] && mkdir -p "$REPORT_DIR"
    [ ! -d "$TEMP_DIR" ] && mkdir -p "$TEMP_DIR"
}

# 清理
cleanup() {
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
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
    local deps=("sysbench" "stress-ng" "bc" "gcc" "make")
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
            apt-get install -y sysbench stress-ng bc gcc make &>> "$LOG_FILE"
        elif command -v yum &> /dev/null; then
            yum install -y epel-release &>> "$LOG_FILE"
            yum install -y sysbench stress-ng bc gcc make &>> "$LOG_FILE"
        elif command -v apk &> /dev/null; then
            apk add --no-cache sysbench stress-ng bc gcc make &>> "$LOG_FILE"
        fi
    fi
}

# 获取内存信息
get_memory_info() {
    print_msg "$BLUE" "========== 内存基本信息 =========="
    
    # 内存大小
    local mem_total=$(free -b | awk '/^Mem:/ {print $2}')
    local mem_free=$(free -b | awk '/^Mem:/ {print $4}')
    local mem_available=$(free -b | awk '/^Mem:/ {print $7}')
    local mem_used=$((mem_total - mem_available))
    
    # 转换为人类可读格式
    local total_gb=$(echo "scale=2; $mem_total / 1024 / 1024 / 1024" | bc)
    local used_gb=$(echo "scale=2; $mem_used / 1024 / 1024 / 1024" | bc)
    local available_gb=$(echo "scale=2; $mem_available / 1024 / 1024 / 1024" | bc)
    
    echo -e "${CYAN}总内存:${NC} ${total_gb} GB"
    echo -e "${CYAN}已使用:${NC} ${used_gb} GB"
    echo -e "${CYAN}可用:${NC} ${available_gb} GB"
    
    # Swap信息
    local swap_total=$(free -b | awk '/^Swap:/ {print $2}')
    local swap_used=$(free -b | awk '/^Swap:/ {print $3}')
    
    if [ "$swap_total" -gt 0 ]; then
        local swap_gb=$(echo "scale=2; $swap_total / 1024 / 1024 / 1024" | bc)
        local swap_used_gb=$(echo "scale=2; $swap_used / 1024 / 1024 / 1024" | bc)
        echo -e "${CYAN}Swap:${NC} ${swap_gb} GB (已用: ${swap_used_gb} GB)"
    else
        echo -e "${CYAN}Swap:${NC} 未配置"
    fi
    
    # 内存类型和速度（如果可用）
    if [ -f /proc/meminfo ]; then
        # 获取详细内存信息
        local hugepages=$(grep "HugePages_Total" /proc/meminfo | awk '{print $2}')
        local transparent_hugepage=$(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null | grep -oE '\[[a-z]+\]' | tr -d '[]')
        
        [ "$hugepages" -gt 0 ] && echo -e "${CYAN}大页面:${NC} $hugepages"
        [ -n "$transparent_hugepage" ] && echo -e "${CYAN}透明大页:${NC} $transparent_hugepage"
    fi
    
    # 使用dmidecode获取内存硬件信息（需要root权限）
    if command -v dmidecode &> /dev/null && [ $EUID -eq 0 ]; then
        local mem_speed=$(dmidecode -t memory 2>/dev/null | grep "Speed:" | grep -v "Unknown" | head -1 | awk '{print $2" "$3}')
        local mem_type=$(dmidecode -t memory 2>/dev/null | grep "Type:" | grep -v "Unknown" | head -1 | awk '{print $2}')
        
        [ -n "$mem_speed" ] && echo -e "${CYAN}内存速度:${NC} $mem_speed"
        [ -n "$mem_type" ] && echo -e "${CYAN}内存类型:${NC} $mem_type"
    fi
    
    # 保存信息
    {
        echo "========== 内存信息 =========="
        echo "总内存: ${total_gb} GB"
        echo "已使用: ${used_gb} GB"
        echo "可用: ${available_gb} GB"
        echo "Swap: ${swap_gb:-0} GB"
        [ -n "$mem_type" ] && echo "类型: $mem_type"
        [ -n "$mem_speed" ] && echo "速度: $mem_speed"
        echo ""
    } >> "$REPORT_FILE"
}

# Sysbench内存测试
sysbench_memory_test() {
    print_msg "$BLUE" "\n========== Sysbench内存测试 =========="
    
    # 内存读取测试
    print_msg "$CYAN" "内存顺序读取测试..."
    local read_result=$(sysbench memory --memory-oper=read --memory-access-mode=seq --memory-total-size=10G run 2>/dev/null | grep "transferred" | grep -oE '[0-9.]+ MiB/sec' | awk '{print $1}')
    
    if [ -n "$read_result" ]; then
        echo -e "${GREEN}顺序读取: ${read_result} MB/s${NC}"
    else
        echo -e "${RED}顺序读取测试失败${NC}"
        read_result=0
    fi
    
    # 内存写入测试
    print_msg "$CYAN" "内存顺序写入测试..."
    local write_result=$(sysbench memory --memory-oper=write --memory-access-mode=seq --memory-total-size=10G run 2>/dev/null | grep "transferred" | grep -oE '[0-9.]+ MiB/sec' | awk '{print $1}')
    
    if [ -n "$write_result" ]; then
        echo -e "${GREEN}顺序写入: ${write_result} MB/s${NC}"
    else
        echo -e "${RED}顺序写入测试失败${NC}"
        write_result=0
    fi
    
    # 随机访问测试
    print_msg "$CYAN" "内存随机访问测试..."
    local random_result=$(sysbench memory --memory-oper=read --memory-access-mode=rnd --memory-total-size=10G run 2>/dev/null | grep "transferred" | grep -oE '[0-9.]+ MiB/sec' | awk '{print $1}')
    
    if [ -n "$random_result" ]; then
        echo -e "${GREEN}随机访问: ${random_result} MB/s${NC}"
    else
        echo -e "${RED}随机访问测试失败${NC}"
        random_result=0
    fi
    
    # 保存结果
    {
        echo "========== Sysbench测试 =========="
        echo "顺序读取: ${read_result} MB/s"
        echo "顺序写入: ${write_result} MB/s"
        echo "随机访问: ${random_result} MB/s"
        echo ""
    } >> "$REPORT_FILE"
}

# STREAM内存带宽测试
stream_test() {
    print_msg "$BLUE" "\n========== STREAM内存带宽测试 =========="
    
    # 编译STREAM
    print_msg "$CYAN" "编译STREAM测试程序..."
    
    cat > "$TEMP_DIR/stream.c" << 'EOF'
#include <stdio.h>
#include <math.h>
#include <float.h>
#include <limits.h>
#include <sys/time.h>

#ifndef STREAM_ARRAY_SIZE
#   define STREAM_ARRAY_SIZE 10000000
#endif

#ifndef NTIMES
#   define NTIMES 10
#endif

#define HLINE "-------------------------------------------------------------\n"

static double a[STREAM_ARRAY_SIZE+OFFSET],
              b[STREAM_ARRAY_SIZE+OFFSET],
              c[STREAM_ARRAY_SIZE+OFFSET];

static double avgtime[4] = {0}, maxtime[4] = {0},
              mintime[4] = {FLT_MAX,FLT_MAX,FLT_MAX,FLT_MAX};

static char *label[4] = {"Copy:      ", "Scale:     ",
                         "Add:       ", "Triad:     "};

static double bytes[4] = {
    2 * sizeof(double) * STREAM_ARRAY_SIZE,
    2 * sizeof(double) * STREAM_ARRAY_SIZE,
    3 * sizeof(double) * STREAM_ARRAY_SIZE,
    3 * sizeof(double) * STREAM_ARRAY_SIZE
};

extern double mysecond();

int main() {
    int j, k;
    double times[4][NTIMES];
    double scalar = 3.0;
    
    for (j=0; j<STREAM_ARRAY_SIZE; j++) {
        a[j] = 1.0;
        b[j] = 2.0;
        c[j] = 0.0;
    }
    
    printf(HLINE);
    printf("STREAM内存带宽测试\n");
    printf(HLINE);
    
    for (k=0; k<NTIMES; k++) {
        times[0][k] = mysecond();
        for (j=0; j<STREAM_ARRAY_SIZE; j++)
            c[j] = a[j];
        times[0][k] = mysecond() - times[0][k];
        
        times[1][k] = mysecond();
        for (j=0; j<STREAM_ARRAY_SIZE; j++)
            b[j] = scalar*c[j];
        times[1][k] = mysecond() - times[1][k];
        
        times[2][k] = mysecond();
        for (j=0; j<STREAM_ARRAY_SIZE; j++)
            c[j] = a[j]+b[j];
        times[2][k] = mysecond() - times[2][k];
        
        times[3][k] = mysecond();
        for (j=0; j<STREAM_ARRAY_SIZE; j++)
            a[j] = b[j]+scalar*c[j];
        times[3][k] = mysecond() - times[3][k];
    }
    
    for (k=1; k<NTIMES; k++) {
        for (j=0; j<4; j++) {
            avgtime[j] = avgtime[j] + times[j][k];
            mintime[j] = (mintime[j] < times[j][k]) ? mintime[j] : times[j][k];
            maxtime[j] = (maxtime[j] > times[j][k]) ? maxtime[j] : times[j][k];
        }
    }
    
    printf("Function    Best Rate MB/s  Avg Rate MB/s  \n");
    for (j=0; j<4; j++) {
        avgtime[j] = avgtime[j]/(double)(NTIMES-1);
        printf("%s%12.1f  %12.1f\n", label[j],
               1.0E-06 * bytes[j]/mintime[j],
               1.0E-06 * bytes[j]/avgtime[j]);
    }
    printf(HLINE);
    
    return 0;
}

double mysecond() {
    struct timeval tp;
    gettimeofday(&tp, NULL);
    return ( (double) tp.tv_sec + (double) tp.tv_usec * 1.e-6 );
}
EOF

    # 编译
    if gcc -O3 -fopenmp "$TEMP_DIR/stream.c" -o "$TEMP_DIR/stream" -lm 2>/dev/null; then
        # 运行测试
        print_msg "$CYAN" "运行STREAM测试..."
        local stream_output=$("$TEMP_DIR/stream" 2>&1)
        
        echo "$stream_output" | grep -E "Copy:|Scale:|Add:|Triad:" | while read line; do
            echo -e "${GREEN}$line${NC}"
        done
        
        # 提取结果保存
        {
            echo "========== STREAM测试 =========="
            echo "$stream_output" | grep -E "Copy:|Scale:|Add:|Triad:"
            echo ""
        } >> "$REPORT_FILE"
    else
        print_msg "$RED" "STREAM编译失败"
    fi
}

# 内存延迟测试
latency_test() {
    print_msg "$BLUE" "\n========== 内存延迟测试 =========="
    
    # 使用stress-ng测试内存延迟
    if command -v stress-ng &> /dev/null; then
        print_msg "$CYAN" "测试内存访问延迟..."
        
        # 缓存行测试
        local cache_result=$(stress-ng --cache 1 --cache-ops 1000000 --metrics 2>&1 | grep "cache" | tail -1)
        if [ -n "$cache_result" ]; then
            echo -e "${GREEN}缓存延迟测试: $cache_result${NC}"
        fi
        
        # TLB测试
        local tlb_result=$(stress-ng --tlb-shootdown 1 --tlb-shootdown-ops 10000 --metrics 2>&1 | grep "tlb" | tail -1)
        if [ -n "$tlb_result" ]; then
            echo -e "${GREEN}TLB测试: $tlb_result${NC}"
        fi
    fi
    
    # 自定义延迟测试
    print_msg "$CYAN" "随机内存访问延迟测试..."
    
    cat > "$TEMP_DIR/latency_test.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

#define ARRAY_SIZE (64 * 1024 * 1024)  // 64MB
#define ITERATIONS 1000000

int main() {
    char *array = malloc(ARRAY_SIZE);
    if (!array) {
        printf("内存分配失败\n");
        return 1;
    }
    
    // 初始化数组
    memset(array, 0, ARRAY_SIZE);
    
    // 预热
    for (int i = 0; i < ARRAY_SIZE; i += 64) {
        array[i] = 1;
    }
    
    // 测试随机访问延迟
    clock_t start = clock();
    long sum = 0;
    
    for (int i = 0; i < ITERATIONS; i++) {
        int index = rand() % ARRAY_SIZE;
        sum += array[index];
    }
    
    clock_t end = clock();
    double time_spent = ((double)(end - start)) / CLOCKS_PER_SEC;
    double latency_ns = (time_spent * 1e9) / ITERATIONS;
    
    printf("平均访问延迟: %.2f ns\n", latency_ns);
    printf("测试完成 (sum=%ld)\n", sum);
    
    free(array);
    return 0;
}
EOF

    if gcc -O2 "$TEMP_DIR/latency_test.c" -o "$TEMP_DIR/latency_test" 2>/dev/null; then
        local latency_output=$("$TEMP_DIR/latency_test" 2>&1)
        echo -e "${GREEN}$latency_output${NC}"
        
        # 保存结果
        {
            echo "========== 延迟测试 =========="
            echo "$latency_output"
            echo ""
        } >> "$REPORT_FILE"
    fi
}

# 内存压力测试
memory_stress_test() {
    if [ "$STRESS_MODE" = false ]; then
        return
    fi
    
    print_msg "$BLUE" "\n========== 内存压力测试 =========="
    print_msg "$YELLOW" "将进行${STRESS_DURATION}秒内存压力测试..."
    
    # 获取可用内存
    local available_mem=$(free -m | awk '/^Mem:/ {print $7}')
    local test_mem=$((available_mem * 80 / 100))  # 使用80%可用内存
    
    echo -e "${CYAN}测试内存大小: ${test_mem}MB${NC}"
    
    if command -v stress-ng &> /dev/null; then
        # 使用stress-ng进行压力测试
        stress-ng --vm 1 --vm-bytes ${test_mem}M --vm-method all --metrics --timeout ${STRESS_DURATION}s 2>&1 | \
            grep -E "vm|memory|completed" | while read line; do
            echo -e "${CYAN}$line${NC}"
        done
        
        # 内存错误检测
        print_msg "$CYAN" "\n进行内存错误检测..."
        stress-ng --vm 1 --vm-bytes ${test_mem}M --vm-hang 0 --verify --timeout 60s 2>&1 | \
            grep -E "verify|error|fail" | while read line; do
            if echo "$line" | grep -qE "error|fail"; then
                echo -e "${RED}$line${NC}"
            else
                echo -e "${GREEN}$line${NC}"
            fi
        done
    else
        # 使用简单的内存分配测试
        print_msg "$CYAN" "使用基础方法进行压力测试..."
        
        cat > "$TEMP_DIR/mem_stress.c" << EOF
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main() {
    size_t size = ${test_mem}L * 1024 * 1024;
    char *mem = malloc(size);
    
    if (!mem) {
        printf("内存分配失败\n");
        return 1;
    }
    
    printf("分配 %zu MB 内存成功\n", size / 1024 / 1024);
    
    // 写入测试
    printf("写入测试中...\n");
    for (size_t i = 0; i < size; i += 4096) {
        mem[i] = i & 0xFF;
    }
    
    // 读取验证
    printf("验证数据中...\n");
    int errors = 0;
    for (size_t i = 0; i < size; i += 4096) {
        if (mem[i] != (i & 0xFF)) {
            errors++;
        }
    }
    
    if (errors > 0) {
        printf("发现 %d 个错误\n", errors);
    } else {
        printf("内存测试通过\n");
    }
    
    sleep($STRESS_DURATION);
    free(mem);
    return errors;
}
EOF

        if gcc "$TEMP_DIR/mem_stress.c" -o "$TEMP_DIR/mem_stress" 2>/dev/null; then
            "$TEMP_DIR/mem_stress"
        fi
    fi
    
    print_msg "$GREEN" "内存压力测试完成"
}

# 内存复制性能测试
memcpy_test() {
    print_msg "$BLUE" "\n========== 内存复制性能测试 =========="
    
    cat > "$TEMP_DIR/memcpy_test.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define SIZE_MB 100
#define ITERATIONS 100

int main() {
    size_t size = SIZE_MB * 1024 * 1024;
    char *src = malloc(size);
    char *dst = malloc(size);
    
    if (!src || !dst) {
        printf("内存分配失败\n");
        return 1;
    }
    
    // 初始化源数据
    memset(src, 0x5A, size);
    
    // 测试memcpy性能
    clock_t start = clock();
    
    for (int i = 0; i < ITERATIONS; i++) {
        memcpy(dst, src, size);
    }
    
    clock_t end = clock();
    double time_spent = ((double)(end - start)) / CLOCKS_PER_SEC;
    double bandwidth = (double)(SIZE_MB * ITERATIONS) / time_spent;
    
    printf("内存复制性能: %.2f MB/s\n", bandwidth);
    printf("总时间: %.2f 秒\n", time_spent);
    
    // 测试memmove性能
    start = clock();
    
    for (int i = 0; i < ITERATIONS; i++) {
        memmove(dst + 1024, src + 1024, size - 1024);
    }
    
    end = clock();
    time_spent = ((double)(end - start)) / CLOCKS_PER_SEC;
    bandwidth = (double)(SIZE_MB * ITERATIONS) / time_spent;
    
    printf("内存移动性能: %.2f MB/s\n", bandwidth);
    
    free(src);
    free(dst);
    return 0;
}
EOF

    if gcc -O3 "$TEMP_DIR/memcpy_test.c" -o "$TEMP_DIR/memcpy_test" 2>/dev/null; then
        local memcpy_output=$("$TEMP_DIR/memcpy_test" 2>&1)
        echo -e "${GREEN}$memcpy_output${NC}"
        
        # 保存结果
        {
            echo "========== 内存复制测试 =========="
            echo "$memcpy_output"
            echo ""
        } >> "$REPORT_FILE"
    else
        print_msg "$RED" "内存复制测试编译失败"
    fi
}

# 计算性能评分
calculate_score() {
    print_msg "$BLUE" "\n========== 内存性能评分 =========="
    
    # 从报告中提取数据
    local seq_read=$(grep "顺序读取:" "$REPORT_FILE" | head -1 | awk '{print $2}')
    local seq_write=$(grep "顺序写入:" "$REPORT_FILE" | head -1 | awk '{print $2}')
    
    # 简单评分（基于顺序读写速度）
    local avg_speed=0
    if [ -n "$seq_read" ] && [ -n "$seq_write" ]; then
        avg_speed=$(echo "scale=0; ($seq_read + $seq_write) / 2" | bc)
    fi
    
    # 性能等级评估
    local performance_level=""
    local score_color=""
    
    if [ "$avg_speed" -gt 10000 ]; then
        performance_level="DDR4高频/DDR5"
        score_color=$GREEN
    elif [ "$avg_speed" -gt 5000 ]; then
        performance_level="DDR4标准"
        score_color=$GREEN
    elif [ "$avg_speed" -gt 2000 ]; then
        performance_level="DDR3/低频DDR4"
        score_color=$YELLOW
    else
        performance_level="低速内存"
        score_color=$RED
    fi
    
    echo -e "${CYAN}内存性能等级: ${score_color}${performance_level}${NC}"
    echo -e "${CYAN}平均带宽: ${avg_speed} MB/s${NC}"
    
    # 应用场景建议
    echo -e "\n${CYAN}推荐应用场景:${NC}"
    
    case $performance_level in
        "DDR4高频/DDR5")
            echo -e "${GREEN}  ✓ 内存数据库${NC}"
            echo -e "${GREEN}  ✓ 大数据分析${NC}"
            echo -e "${GREEN}  ✓ 科学计算${NC}"
            echo -e "${GREEN}  ✓ 虚拟化平台${NC}"
            ;;
        "DDR4标准")
            echo -e "${GREEN}  ✓ Web应用服务器${NC}"
            echo -e "${GREEN}  ✓ 中型数据库${NC}"
            echo -e "${GREEN}  ✓ 容器化应用${NC}"
            echo -e "${GREEN}  ✓ 缓存服务器${NC}"
            ;;
        "DDR3/低频DDR4")
            echo -e "${YELLOW}  ✓ 轻量级Web服务${NC}"
            echo -e "${YELLOW}  ✓ 小型应用${NC}"
            echo -e "${YELLOW}  ⚡ 基础数据库${NC}"
            echo -e "${YELLOW}  ⚡ 开发测试环境${NC}"
            ;;
        "低速内存")
            echo -e "${RED}  ✓ 静态网站${NC}"
            echo -e "${RED}  ✓ 代理服务${NC}"
            echo -e "${RED}  ✗ 不适合内存密集型应用${NC}"
            echo -e "${RED}  ✗ 避免大量并发访问${NC}"
            ;;
    esac
}

# 生成报告
generate_report() {
    print_msg "$BLUE" "\n生成测试报告..."
    
    local summary_file="$REPORT_DIR/memory_benchmark_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "        内存性能测试报告"
        echo "=========================================="
        echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "测试主机: $(hostname)"
        echo ""
        
        cat "$REPORT_FILE"
        
        echo ""
        echo "=========================================="
        echo "测试说明:"
        echo "1. 带宽测试反映内存吞吐能力"
        echo "2. 延迟测试反映内存响应速度"
        echo "3. 压力测试检验内存稳定性"
        echo "4. 分数仅供参考，实际性能因应用而异"
        echo ""
        echo "详细日志: $LOG_FILE"
        echo "=========================================="
    } | tee "$summary_file"
    
    print_msg "$GREEN" "\n测试报告已保存到: $summary_file"
}

# 快速测试
quick_test() {
    get_memory_info
    sysbench_memory_test
    calculate_score
}

# 完整测试
full_test() {
    get_memory_info
    sysbench_memory_test
    stream_test
    latency_test
    memcpy_test
    calculate_score
}

# 交互式菜单
interactive_menu() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                       VPS 内存性能测试工具 v1.0                           ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 显示内存信息
    local mem_info=$(free -h | awk '/^Mem:/ {print "总量: "$2" 已用: "$3" 可用: "$7}')
    echo -e "${CYAN}$mem_info${NC}"
    echo ""
    
    echo -e "${CYAN}请选择测试模式:${NC}"
    echo -e "${GREEN}1)${NC} 快速测试 (Sysbench)"
    echo -e "${GREEN}2)${NC} 标准测试 (推荐)"
    echo -e "${GREEN}3)${NC} 完整测试 (所有项目)"
    echo -e "${GREEN}4)${NC} 压力测试"
    echo -e "${GREEN}5)${NC} 单项测试"
    echo -e "${GREEN}0)${NC} 退出"
    echo ""
    
    read -p "请输入选项 [0-5]: " choice
    
    case $choice in
        1)
            QUICK_MODE=true
            quick_test
            generate_report
            ;;
        2)
            get_memory_info
            sysbench_memory_test
            stream_test
            latency_test
            calculate_score
            generate_report
            ;;
        3)
            FULL_MODE=true
            full_test
            generate_report
            ;;
        4)
            STRESS_MODE=true
            get_memory_info
            memory_stress_test
            generate_report
            ;;
        5)
            single_test_menu
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

# 单项测试菜单
single_test_menu() {
    clear
    echo -e "${CYAN}选择要进行的测试:${NC}"
    echo -e "${GREEN}1)${NC} Sysbench内存测试"
    echo -e "${GREEN}2)${NC} STREAM带宽测试"
    echo -e "${GREEN}3)${NC} 内存延迟测试"
    echo -e "${GREEN}4)${NC} 内存复制测试"
    echo -e "${GREEN}5)${NC} 内存压力测试"
    echo -e "${GREEN}0)${NC} 返回主菜单"
    echo ""
    
    read -p "请输入选项 [0-5]: " test_choice
    
    case $test_choice in
        1) sysbench_memory_test ;;
        2) stream_test ;;
        3) latency_test ;;
        4) memcpy_test ;;
        5) 
            STRESS_MODE=true
            memory_stress_test 
            ;;
        0) interactive_menu ;;
        *)
            print_msg "$RED" "无效选项"
            sleep 2
            single_test_menu
            ;;
    esac
}

# 显示帮助
show_help() {
    cat << EOF
使用方法: $0 [选项]

选项:
  --quick     快速测试模式
  --full      完整测试模式
  --stress    包含压力测试
  --help, -h  显示此帮助信息

示例:
  $0              # 交互式菜单
  $0 --quick      # 快速测试
  $0 --full       # 完整测试
  $0 --stress     # 压力测试

测试项目:
  - Sysbench内存带宽测试
  - STREAM内存带宽测试
  - 内存访问延迟测试
  - 内存复制性能测试
  - 内存压力稳定性测试

注意:
  - 部分测试需要编译器
  - 压力测试会占用大量内存
  - 测试结果受系统负载影响
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
            --stress)
                STRESS_MODE=true
                shift
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
    log "开始内存性能测试"
    
    {
        echo "========== 内存性能测试 =========="
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
    } > "$REPORT_FILE"
    
    if [ "$QUICK_MODE" = true ]; then
        quick_test
        generate_report
    elif [ "$FULL_MODE" = true ]; then
        full_test
        [ "$STRESS_MODE" = true ] && memory_stress_test
        generate_report
    else
        interactive_menu
    fi
    
    print_msg "$GREEN" "\n内存性能测试完成！"
}

# 运行主函数
main "$@"
