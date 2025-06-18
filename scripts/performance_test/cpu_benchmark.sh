#!/bin/bash

#==============================================================================
# 脚本名称: cpu_benchmark.sh
# 描述: VPS CPU性能基准测试脚本 - 测试单核/多核性能、加密性能、压缩性能等
# 作者: Jensfrank
# 路径: vps_scripts/scripts/performance_test/cpu_benchmark.sh
# 使用方法: bash cpu_benchmark.sh [选项]
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
LOG_FILE="$LOG_DIR/cpu_benchmark_$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="/var/log/vps_scripts/reports"
REPORT_FILE="$REPORT_DIR/cpu_benchmark_$(date +%Y%m%d_%H%M%S).txt"
TEMP_DIR="/tmp/cpu_benchmark_$$"

# 测试模式
QUICK_MODE=false
FULL_MODE=false
STRESS_MODE=false

# 测试参数
SYSBENCH_THREADS=$(nproc)
SYSBENCH_TIME=30
STRESS_DURATION=300  # 5分钟压力测试
PRIME_LIMIT=20000    # 素数计算上限

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

# 检查并安装依赖
check_dependencies() {
    local deps=("sysbench" "bc" "stress-ng" "openssl" "gzip" "xz" "7z")
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
            apt-get install -y sysbench bc stress-ng openssl gzip xz-utils p7zip-full &>> "$LOG_FILE"
        elif command -v yum &> /dev/null; then
            yum install -y epel-release &>> "$LOG_FILE"
            yum install -y sysbench bc stress-ng openssl gzip xz p7zip &>> "$LOG_FILE"
        elif command -v apk &> /dev/null; then
            apk add --no-cache sysbench bc stress-ng openssl gzip xz 7zip &>> "$LOG_FILE"
        fi
    fi
}

# 获取CPU信息
get_cpu_info() {
    print_msg "$BLUE" "========== CPU基本信息 =========="
    
    # CPU型号
    local cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
    # CPU核心数
    local cpu_cores=$(nproc)
    # CPU物理核心数
    local physical_cores=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l)
    [ $physical_cores -eq 0 ] && physical_cores=1
    local cores_per_socket=$(grep "cpu cores" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    [ -z "$cores_per_socket" ] && cores_per_socket=$cpu_cores
    
    # CPU频率
    local cpu_freq=$(grep -m1 "cpu MHz" /proc/cpuinfo | cut -d: -f2 | xargs)
    # CPU缓存
    local cpu_cache=$(grep -m1 "cache size" /proc/cpuinfo | cut -d: -f2 | xargs)
    
    # CPU架构
    local cpu_arch=$(uname -m)
    
    # 虚拟化检测
    local virt_type="物理机"
    if systemd-detect-virt &> /dev/null; then
        virt_type=$(systemd-detect-virt)
    fi
    
    echo -e "${CYAN}CPU型号:${NC} $cpu_model"
    echo -e "${CYAN}CPU架构:${NC} $cpu_arch"
    echo -e "${CYAN}逻辑核心:${NC} $cpu_cores"
    echo -e "${CYAN}物理核心:${NC} $((physical_cores * cores_per_socket))"
    echo -e "${CYAN}CPU频率:${NC} ${cpu_freq} MHz"
    echo -e "${CYAN}缓存大小:${NC} ${cpu_cache:-未知}"
    echo -e "${CYAN}虚拟化:${NC} $virt_type"
    
    # CPU特性
    local cpu_flags=$(grep -m1 "flags" /proc/cpuinfo | cut -d: -f2)
    local features=""
    
    # 检查重要特性
    echo "$cpu_flags" | grep -q " aes " && features+="AES-NI "
    echo "$cpu_flags" | grep -q " avx " && features+="AVX "
    echo "$cpu_flags" | grep -q " avx2 " && features+="AVX2 "
    echo "$cpu_flags" | grep -q " sse4_2 " && features+="SSE4.2 "
    echo "$cpu_flags" | grep -q " vmx \| svm " && features+="VT "
    
    echo -e "${CYAN}CPU特性:${NC} ${features:-标准}"
    
    # 保存到报告
    {
        echo "========== CPU基本信息 =========="
        echo "CPU型号: $cpu_model"
        echo "CPU架构: $cpu_arch"
        echo "逻辑核心: $cpu_cores"
        echo "CPU频率: ${cpu_freq} MHz"
        echo "CPU特性: $features"
        echo "虚拟化: $virt_type"
        echo ""
    } >> "$REPORT_FILE"
}

# Sysbench CPU测试
sysbench_cpu_test() {
    print_msg "$BLUE" "\n========== Sysbench CPU测试 =========="
    
    # 单核测试
    print_msg "$CYAN" "单核性能测试..."
    local single_result=$(sysbench cpu --cpu-max-prime=$PRIME_LIMIT --threads=1 --time=$SYSBENCH_TIME run 2>/dev/null | grep "events per second" | awk '{print $4}')
    
    if [ -n "$single_result" ]; then
        echo -e "${GREEN}单核性能: $single_result events/sec${NC}"
    else
        echo -e "${RED}单核测试失败${NC}"
        single_result=0
    fi
    
    # 多核测试
    print_msg "$CYAN" "多核性能测试 ($SYSBENCH_THREADS 线程)..."
    local multi_result=$(sysbench cpu --cpu-max-prime=$PRIME_LIMIT --threads=$SYSBENCH_THREADS --time=$SYSBENCH_TIME run 2>/dev/null | grep "events per second" | awk '{print $4}')
    
    if [ -n "$multi_result" ]; then
        echo -e "${GREEN}多核性能: $multi_result events/sec${NC}"
    else
        echo -e "${RED}多核测试失败${NC}"
        multi_result=0
    fi
    
    # 计算多核效率
    if [ "$single_result" != "0" ] && [ "$multi_result" != "0" ]; then
        local efficiency=$(echo "scale=2; ($multi_result / $single_result / $SYSBENCH_THREADS) * 100" | bc)
        echo -e "${CYAN}多核效率: ${efficiency}%${NC}"
        
        # 评估多核效率
        if (( $(echo "$efficiency > 90" | bc -l) )); then
            echo -e "${GREEN}多核扩展性: 优秀${NC}"
        elif (( $(echo "$efficiency > 70" | bc -l) )); then
            echo -e "${YELLOW}多核扩展性: 良好${NC}"
        else
            echo -e "${RED}多核扩展性: 较差${NC}"
        fi
    fi
    
    # 保存结果
    {
        echo "========== Sysbench测试 =========="
        echo "单核性能: $single_result events/sec"
        echo "多核性能: $multi_result events/sec"
        echo "测试线程: $SYSBENCH_THREADS"
        echo "多核效率: ${efficiency}%"
        echo ""
    } >> "$REPORT_FILE"
}

# 加密性能测试
crypto_benchmark() {
    print_msg "$BLUE" "\n========== 加密性能测试 =========="
    
    # 测试不同算法
    local algorithms=("aes-128-cbc" "aes-256-cbc" "sha256" "sha512" "md5")
    
    for algo in "${algorithms[@]}"; do
        print_msg "$CYAN" "测试 $algo..."
        
        # OpenSSL速度测试
        local speed_result=$(openssl speed -elapsed -seconds 3 "$algo" 2>&1 | grep "^$algo" | tail -1)
        
        if [ -n "$speed_result" ]; then
            # 提取速度数据
            local speed=$(echo "$speed_result" | awk '{print $(NF-1)" "$NF}')
            echo -e "${GREEN}  $algo: $speed${NC}"
            echo "$algo: $speed" >> "$REPORT_FILE"
        else
            echo -e "${RED}  $algo: 测试失败${NC}"
        fi
    done
    
    # AES-NI加速测试
    if grep -q " aes " /proc/cpuinfo; then
        echo -e "\n${GREEN}检测到AES-NI硬件加速支持${NC}"
        
        # 对比有无AES-NI的性能
        local aes_speed=$(openssl speed -elapsed -seconds 1 -evp aes-256-cbc 2>&1 | grep "^aes-256-cbc" | awk '{print $NF}')
        echo -e "${CYAN}AES-256-CBC (硬件加速): ${aes_speed}${NC}"
    else
        echo -e "\n${YELLOW}未检测到AES-NI硬件加速${NC}"
    fi
}

# 压缩性能测试
compression_benchmark() {
    print_msg "$BLUE" "\n========== 压缩性能测试 =========="
    
    # 创建测试文件（100MB随机数据）
    print_msg "$CYAN" "创建测试文件..."
    dd if=/dev/urandom of="$TEMP_DIR/test_file" bs=1M count=100 2>/dev/null
    
    # 测试不同压缩算法
    local compressors=("gzip" "bzip2" "xz" "7z")
    
    for comp in "${compressors[@]}"; do
        if ! command -v "$comp" &> /dev/null; then
            continue
        fi
        
        print_msg "$CYAN" "测试 $comp 压缩..."
        
        # 压缩测试
        local start_time=$(date +%s.%N)
        
        case $comp in
            gzip)
                gzip -c "$TEMP_DIR/test_file" > "$TEMP_DIR/test.gz" 2>/dev/null
                ;;
            bzip2)
                bzip2 -c "$TEMP_DIR/test_file" > "$TEMP_DIR/test.bz2" 2>/dev/null
                ;;
            xz)
                xz -c "$TEMP_DIR/test_file" > "$TEMP_DIR/test.xz" 2>/dev/null
                ;;
            7z)
                7z a -bd "$TEMP_DIR/test.7z" "$TEMP_DIR/test_file" > /dev/null 2>&1
                ;;
        esac
        
        local end_time=$(date +%s.%N)
        local compress_time=$(echo "$end_time - $start_time" | bc)
        
        # 计算压缩速度
        local compress_speed=$(echo "scale=2; 100 / $compress_time" | bc)
        
        echo -e "${GREEN}  $comp 压缩速度: ${compress_speed} MB/s${NC}"
        
        # 清理压缩文件
        rm -f "$TEMP_DIR/test."* 2>/dev/null
        
        # 保存结果
        echo "$comp 压缩: ${compress_speed} MB/s" >> "$REPORT_FILE"
    done
    
    # 清理测试文件
    rm -f "$TEMP_DIR/test_file"
}

# 整数运算测试
integer_benchmark() {
    print_msg "$BLUE" "\n========== 整数运算测试 =========="
    
    # 斐波那契数列计算
    print_msg "$CYAN" "斐波那契数列计算 (n=45)..."
    
    cat > "$TEMP_DIR/fib_test.c" << 'EOF'
#include <stdio.h>
#include <time.h>

long long fibonacci(int n) {
    if (n <= 1) return n;
    return fibonacci(n-1) + fibonacci(n-2);
}

int main() {
    clock_t start = clock();
    long long result = fibonacci(45);
    clock_t end = clock();
    double time_spent = ((double)(end - start)) / CLOCKS_PER_SEC;
    printf("结果: %lld\n", result);
    printf("耗时: %.3f 秒\n", time_spent);
    return 0;
}
EOF
    
    # 编译并运行
    if gcc -O2 "$TEMP_DIR/fib_test.c" -o "$TEMP_DIR/fib_test" 2>/dev/null; then
        local fib_output=$("$TEMP_DIR/fib_test")
        echo -e "${GREEN}$fib_output${NC}"
        echo "斐波那契测试: $fib_output" >> "$REPORT_FILE"
    else
        echo -e "${RED}编译失败${NC}"
    fi
    
    # 素数计算测试
    print_msg "$CYAN" "素数计算测试 (前10000个)..."
    
    local start_time=$(date +%s.%N)
    local prime_count=0
    
    for ((n=2; prime_count<10000; n++)); do
        is_prime=true
        for ((i=2; i*i<=n; i++)); do
            if ((n % i == 0)); then
                is_prime=false
                break
            fi
        done
        if $is_prime; then
            ((prime_count++))
        fi
    done
    
    local end_time=$(date +%s.%N)
    local prime_time=$(echo "$end_time - $start_time" | bc)
    
    echo -e "${GREEN}计算10000个素数耗时: ${prime_time} 秒${NC}"
    echo "素数计算: ${prime_time} 秒" >> "$REPORT_FILE"
}

# 浮点运算测试
float_benchmark() {
    print_msg "$BLUE" "\n========== 浮点运算测试 =========="
    
    # 使用bc进行浮点运算测试
    print_msg "$CYAN" "π值计算测试 (5000位)..."
    
    local start_time=$(date +%s.%N)
    
    # 计算π值（使用Machin公式）
    echo "scale=5000; 4*a(1)" | bc -l > /dev/null 2>&1
    
    local end_time=$(date +%s.%N)
    local pi_time=$(echo "$end_time - $start_time" | bc)
    
    echo -e "${GREEN}计算π(5000位)耗时: ${pi_time} 秒${NC}"
    echo "π计算(5000位): ${pi_time} 秒" >> "$REPORT_FILE"
    
    # LINPACK测试（如果可用）
    if command -v stress-ng &> /dev/null; then
        print_msg "$CYAN" "LINPACK浮点测试..."
        
        local linpack_result=$(stress-ng --matrix 1 --matrix-ops 1000 --metrics 2>&1 | grep "matrix" | awk '{print $(NF-1)" "$NF}')
        
        if [ -n "$linpack_result" ]; then
            echo -e "${GREEN}矩阵运算性能: $linpack_result${NC}"
            echo "矩阵运算: $linpack_result" >> "$REPORT_FILE"
        fi
    fi
}

# CPU压力测试
stress_test() {
    if [ "$STRESS_MODE" = false ]; then
        return
    fi
    
    print_msg "$BLUE" "\n========== CPU压力测试 =========="
    print_msg "$YELLOW" "将进行${STRESS_DURATION}秒压力测试..."
    
    # 记录初始温度（如果可用）
    local temp_before=""
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        temp_before=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp_before=$(echo "scale=1; $temp_before / 1000" | bc)
        echo -e "${CYAN}测试前温度: ${temp_before}°C${NC}"
    fi
    
    # 开始压力测试
    if command -v stress-ng &> /dev/null; then
        stress-ng --cpu $SYSBENCH_THREADS --cpu-method all --metrics --timeout ${STRESS_DURATION}s 2>&1 | \
            grep -E "cpu|dispatches|temperature" | while read line; do
            echo -e "${CYAN}$line${NC}"
        done
    else
        # 使用sysbench替代
        sysbench cpu --threads=$SYSBENCH_THREADS --time=$STRESS_DURATION run &> /dev/null &
        local stress_pid=$!
        
        # 监控CPU使用率
        for ((i=0; i<$STRESS_DURATION; i+=5)); do
            local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
            echo -ne "\r${CYAN}CPU使用率: ${cpu_usage}% (${i}/${STRESS_DURATION}秒)${NC}"
            sleep 5
        done
        
        kill $stress_pid 2>/dev/null
        echo ""
    fi
    
    # 记录测试后温度
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local temp_after=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp_after=$(echo "scale=1; $temp_after / 1000" | bc)
        echo -e "${CYAN}测试后温度: ${temp_after}°C${NC}"
        
        local temp_rise=$(echo "$temp_after - $temp_before" | bc)
        echo -e "${CYAN}温度上升: ${temp_rise}°C${NC}"
        
        # 保存温度信息
        {
            echo "========== 压力测试 =========="
            echo "测试时长: ${STRESS_DURATION}秒"
            echo "测试前温度: ${temp_before}°C"
            echo "测试后温度: ${temp_after}°C"
            echo "温度上升: ${temp_rise}°C"
            echo ""
        } >> "$REPORT_FILE"
    fi
    
    print_msg "$GREEN" "压力测试完成"
}

# 生成性能评分
calculate_score() {
    print_msg "$BLUE" "\n========== CPU性能评分 =========="
    
    # 基于sysbench结果评分
    local single_score=$(grep "单核性能:" "$REPORT_FILE" | awk '{print $2}')
    local multi_score=$(grep "多核性能:" "$REPORT_FILE" | awk '{print $2}')
    
    # 参考分数（基于常见VPS性能）
    # 单核: 低端<500, 中端500-1000, 高端>1000
    # 多核: 根据核心数调整
    
    local performance_level=""
    local score_color=""
    
    if [ -n "$single_score" ]; then
        if (( $(echo "$single_score > 1000" | bc -l) )); then
            performance_level="高性能"
            score_color=$GREEN
        elif (( $(echo "$single_score > 500" | bc -l) )); then
            performance_level="中等性能"
            score_color=$YELLOW
        else
            performance_level="入门级"
            score_color=$RED
        fi
        
        echo -e "${CYAN}性能等级: ${score_color}${performance_level}${NC}"
        
        # 应用场景建议
        echo -e "\n${CYAN}推荐应用场景:${NC}"
        
        case $performance_level in
            "高性能")
                echo -e "${GREEN}  ✓ 高负载Web应用${NC}"
                echo -e "${GREEN}  ✓ 数据库服务器${NC}"
                echo -e "${GREEN}  ✓ 编译构建服务${NC}"
                echo -e "${GREEN}  ✓ 科学计算${NC}"
                ;;
            "中等性能")
                echo -e "${YELLOW}  ✓ 中小型网站${NC}"
                echo -e "${YELLOW}  ✓ 应用服务器${NC}"
                echo -e "${YELLOW}  ✓ 开发测试环境${NC}"
                echo -e "${YELLOW}  ⚡ 轻量级数据库${NC}"
                ;;
            "入门级")
                echo -e "${RED}  ✓ 静态网站${NC}"
                echo -e "${RED}  ✓ 代理服务${NC}"
                echo -e "${RED}  ✓ 个人博客${NC}"
                echo -e "${RED}  ✗ 不适合计算密集型应用${NC}"
                ;;
        esac
    fi
}

# 生成测试报告
generate_report() {
    print_msg "$BLUE" "\n生成测试报告..."
    
    local summary_file="$REPORT_DIR/cpu_benchmark_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "         CPU性能测试报告"
        echo "=========================================="
        echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "测试主机: $(hostname)"
        echo ""
        
        cat "$REPORT_FILE"
        
        echo ""
        echo "=========================================="
        echo "测试说明:"
        echo "1. Sysbench测试基于素数计算"
        echo "2. 加密测试使用OpenSSL"
        echo "3. 分数仅供参考，实际性能因应用而异"
        echo ""
        echo "详细日志: $LOG_FILE"
        echo "=========================================="
    } | tee "$summary_file"
    
    print_msg "$GREEN" "\n测试报告已保存到: $summary_file"
}

# 快速测试
quick_test() {
    get_cpu_info
    sysbench_cpu_test
    calculate_score
}

# 完整测试
full_test() {
    get_cpu_info
    sysbench_cpu_test
    crypto_benchmark
    compression_benchmark
    integer_benchmark
    float_benchmark
    calculate_score
}

# 交互式菜单
interactive_menu() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                         VPS CPU性能测试工具 v1.0                           ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 显示CPU简要信息
    local cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
    local cpu_cores=$(nproc)
    echo -e "${CYAN}CPU: $cpu_model (${cpu_cores}核)${NC}"
    echo ""
    
    echo -e "${CYAN}请选择测试模式:${NC}"
    echo -e "${GREEN}1)${NC} 快速测试 (仅基准测试)"
    echo -e "${GREEN}2)${NC} 标准测试 (推荐)"
    echo -e "${GREEN}3)${NC} 完整测试 (包含所有项目)"
    echo -e "${GREEN}4)${NC} 压力测试 (5分钟高负载)"
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
            get_cpu_info
            sysbench_cpu_test
            crypto_benchmark
            compression_benchmark
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
            get_cpu_info
            stress_test
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
    echo -e "${GREEN}1)${NC} Sysbench基准测试"
    echo -e "${GREEN}2)${NC} 加密性能测试"
    echo -e "${GREEN}3)${NC} 压缩性能测试"
    echo -e "${GREEN}4)${NC} 整数运算测试"
    echo -e "${GREEN}5)${NC} 浮点运算测试"
    echo -e "${GREEN}0)${NC} 返回主菜单"
    echo ""
    
    read -p "请输入选项 [0-5]: " test_choice
    
    case $test_choice in
        1) sysbench_cpu_test ;;
        2) crypto_benchmark ;;
        3) compression_benchmark ;;
        4) integer_benchmark ;;
        5) float_benchmark ;;
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
  $0 --quick      # 快速基准测试
  $0 --full       # 完整性能测试
  $0 --stress     # 包含压力测试

测试项目:
  - Sysbench CPU基准测试
  - 加密算法性能测试
  - 压缩算法性能测试
  - 整数运算性能测试
  - 浮点运算性能测试
  - CPU压力测试（可选）

注意:
  - 某些测试需要编译器支持
  - 压力测试会使CPU满载运行
  - 测试结果仅供参考
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
    log "开始CPU性能测试"
    
    {
        echo "========== CPU性能测试 =========="
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
    } > "$REPORT_FILE"
    
    if [ "$QUICK_MODE" = true ]; then
        quick_test
        generate_report
    elif [ "$FULL_MODE" = true ]; then
        full_test
        [ "$STRESS_MODE" = true ] && stress_test
        generate_report
    else
        interactive_menu
    fi
    
    print_msg "$GREEN" "\nCPU性能测试完成！"
}

# 运行主函数
main "$@"
