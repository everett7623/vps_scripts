#!/bin/bash
# ======================================================================
# 📌 脚本名称: vps_new.sh (最新重构版本)
# 📍 脚本路径: /vps_scripts/vps_new.sh
# 🚀 主要用途: VPS服务器测试与开发功能集成
# 🔧 适用系统: CentOS/Ubuntu/Debian
# 📅 更新时间: 2026年01月20日
# ======================================================================

# --- 1. 核心框架引导 (Boilerplate) ---
# 自动定位项目根目录，无论脚本被如何调用（软链、相对路径、绝对路径）
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT="$SCRIPT_DIR"

# 向上递归查找 lib 目录，直到根目录
while [ "$PROJECT_ROOT" != "/" ] && [ ! -f "$PROJECT_ROOT/lib/common_functions.sh" ]; do
    PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

# 如果找不到项目根目录，报错退出
if [ "$PROJECT_ROOT" = "/" ]; then
    echo "Error: Cannot find project root (lib/common_functions.sh missing)."
    exit 1
fi

# --- 2. 加载公共库与配置 ---
source "$PROJECT_ROOT/lib/common_functions.sh"

# 加载全局配置 (如果文件存在)
if [ -f "$PROJECT_ROOT/config/vps_scripts.conf" ]; then
    source "$PROJECT_ROOT/config/vps_scripts.conf"
fi

# --- 3. 脚本特有配置 (支持配置文件覆盖) ---
# 语法：VAR=${CONFIG_VAR:-DEFAULT_VALUE}
TARGET_IP=${1:-}   # 支持命令行传参
TIMEOUT=${DEFAULT_TIMEOUT:-30} 
LOG_FILE=${GLOBAL_LOG_FILE:-"/var/log/vps_scripts/module_name.log"}

# --- 4. 主逻辑 ---
main() {
    # 标准化初始化：检查Root -> 安装依赖 -> 打印标题
    check_root
    # check_dependencies "curl" "wget" "python3" # 如果需要依赖，在这里声明
    
    print_title "正在启动 [功能名称]..."
    log_info "脚本启动，目标: ${TARGET_IP:-自动检测}"

    # --- 您的业务代码开始 ---
    
    # 示例：使用公共函数库的颜色输出
    print_msg "$CYAN" "正在进行测试..."
    sleep 1
    
    # 示例：使用公共函数库的错误处理
    if [ -z "$TIMEOUT" ]; then
        log_error "超时设置无效"
        exit 1
    fi
    
    print_success "测试完成！结果已保存。"
    
    # --- 您的业务代码结束 ---
}

# --- 5. 执行入口 ---
# 捕获 Ctrl+C 信号，调用公共库的 graceful_exit
trap 'graceful_exit 1 "用户取消操作"' INT TERM
main "$@"
