#!/bin/bash
#==============================================================================
# 脚本名称: java.sh
# 脚本描述: Java 环境安装脚本 - 支持 OpenJDK、Oracle JDK 和 GraalVM
# 脚本路径: vps_scripts/scripts/service_install/java.sh
# 作者: Jensfrank
# 使用方法: bash java.sh [选项]
# 选项说明:
#   --type <类型>     JDK类型 (openjdk/oracle/graalvm)
#   --version <版本>  Java版本 (8/11/17/21等)
#   --install-maven   同时安装Maven
#   --install-gradle  同时安装Gradle
#   --force          强制重新安装
#   --help           显示帮助信息
# 更新日期: 2025-06-22
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

# 全局变量
JDK_TYPE="openjdk"
JAVA_VERSION="17"
INSTALL_MAVEN=false
INSTALL_GRADLE=false
FORCE_INSTALL=false
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/java_install_$(date +%Y%m%d_%H%M%S).log"

# 默认版本配置
MAVEN_VERSION="3.9.6"
GRADLE_VERSION="8.5"

# 记录日志
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}    Java 环境安装脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash java.sh [选项]"
    echo
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --type <类型>      JDK类型:"
    echo "                     openjdk  - OpenJDK (默认)"
    echo "                     oracle   - Oracle JDK"
    echo "                     graalvm  - GraalVM"
    echo "  --version <版本>   Java版本:"
    echo "                     8, 11, 17, 21 等"
    echo "  --install-maven    同时安装 Maven"
    echo "  --install-gradle   同时安装 Gradle"
    echo "  --force           强制重新安装"
    echo "  --help            显示此帮助信息"
    echo
    echo -e "${GREEN}示例:${NC}"
    echo "  bash java.sh                                    # 安装 OpenJDK 17"
    echo "  bash java.sh --type openjdk --version 11"
    echo "  bash java.sh --type oracle --version 17 --install-maven"
    echo "  bash java.sh --type graalvm --version 21 --install-gradle"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "${RED}错误: 此脚本需要root权限运行${NC}"
        exit 1
    fi
}

# 检测系统类型
detect_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VER=$(lsb_release -sr)
    else
        log "${RED}错误: 无法检测系统类型${NC}"
        exit 1
    fi
    
    # 检测系统架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH_TYPE="x64"
            ;;
        aarch64)
            ARCH_TYPE="aarch64"
            ;;
        *)
            log "${RED}错误: 不支持的系统架构 ${ARCH}${NC}"
            exit 1
            ;;
    esac
    
    log "${GREEN}检测到系统: ${OS} ${VER} (${ARCH})${NC}"
}

# 安装基础依赖
install_dependencies() {
    log "${YELLOW}正在安装基础依赖...${NC}"
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y wget curl tar gzip unzip
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y wget curl tar gzip unzip
            ;;
        *)
            log "${RED}错误: 不支持的系统类型 ${OS}${NC}"
            exit 1
            ;;
    esac
    
    log "${GREEN}基础依赖安装完成${NC}"
}

# 检查Java是否已安装
check_java_installed() {
    if command -v java &> /dev/null; then
        local current_version=$(java -version 2>&1 | head -n 1)
        if [[ "$FORCE_INSTALL" = false ]]; then
            log "${YELLOW}检测到已安装的Java:${NC}"
            log "${YELLOW}${current_version}${NC}"
            read -p "是否继续安装? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "${YELLOW}安装已取消${NC}"
                exit 0
            fi
        fi
    fi
}

# 清理旧版本
clean_old_java() {
    log "${YELLOW}清理旧版本Java...${NC}"
    
    case $OS in
        ubuntu|debian)
            apt-get remove -y openjdk-* oracle-java* || true
            apt-get autoremove -y || true
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum remove -y java-*-openjdk* oracle-java* || true
            ;;
    esac
}

# 安装OpenJDK
install_openjdk() {
    log "${CYAN}安装 OpenJDK ${JAVA_VERSION}...${NC}"
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y openjdk-${JAVA_VERSION}-jdk openjdk-${JAVA_VERSION}-jre
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if [[ "$JAVA_VERSION" == "8" ]]; then
                yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel
            else
                yum install -y java-${JAVA_VERSION}-openjdk java-${JAVA_VERSION}-openjdk-devel
            fi
            ;;
    esac
}

# 安装Oracle JDK
install_oracle_jdk() {
    log "${CYAN}安装 Oracle JDK ${JAVA_VERSION}...${NC}"
    
    # Oracle JDK 下载地址（需要根据实际情况更新）
    case $JAVA_VERSION in
        8)
            JDK_URL="https://download.oracle.com/otn/java/jdk/8u391-b13/b291ca3e0c8548b5a51d5a5f50063037/jdk-8u391-linux-${ARCH_TYPE}.tar.gz"
            JDK_FOLDER="jdk1.8.0_391"
            ;;
        11)
            JDK_URL="https://download.oracle.com/otn/java/jdk/11.0.21+9/e40fb879b87d4a3e95da6ed7c4301e32/jdk-11.0.21_linux-${ARCH_TYPE}_bin.tar.gz"
            JDK_FOLDER="jdk-11.0.21"
            ;;
        17)
            JDK_URL="https://download.oracle.com/java/17/latest/jdk-17_linux-${ARCH_TYPE}_bin.tar.gz"
            JDK_FOLDER="jdk-17"
            ;;
        21)
            JDK_URL="https://download.oracle.com/java/21/latest/jdk-21_linux-${ARCH_TYPE}_bin.tar.gz"
            JDK_FOLDER="jdk-21"
            ;;
        *)
            log "${RED}错误: 不支持的Oracle JDK版本 ${JAVA_VERSION}${NC}"
            exit 1
            ;;
    esac
    
    # 下载并安装
    cd /tmp
    log "${YELLOW}正在下载 Oracle JDK...${NC}"
    wget --no-check-certificate -c --header "Cookie: oraclelicense=accept-securebackup-cookie" -O oracle-jdk.tar.gz "$JDK_URL"
    
    if [[ ! -f oracle-jdk.tar.gz ]]; then
        log "${RED}错误: Oracle JDK 下载失败${NC}"
        log "${YELLOW}提示: Oracle JDK 需要接受许可协议，建议使用 OpenJDK${NC}"
        exit 1
    fi
    
    # 解压到 /opt
    tar -xzf oracle-jdk.tar.gz -C /opt/
    
    # 查找实际的JDK目录名
    JDK_DIR=$(find /opt -maxdepth 1 -type d -name "jdk*" | head -1)
    
    # 设置环境变量
    echo "export JAVA_HOME=${JDK_DIR}" > /etc/profile.d/java.sh
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile.d/java.sh
    
    # 创建软链接
    ln -sf ${JDK_DIR}/bin/java /usr/bin/java
    ln -sf ${JDK_DIR}/bin/javac /usr/bin/javac
    ln -sf ${JDK_DIR}/bin/jar /usr/bin/jar
    
    # 清理
    rm -f /tmp/oracle-jdk.tar.gz
}

# 安装GraalVM
install_graalvm() {
    log "${CYAN}安装 GraalVM ${JAVA_VERSION}...${NC}"
    
    # GraalVM 版本映射
    case $JAVA_VERSION in
        17)
            GRAALVM_VERSION="23.0.3"
            ;;
        21)
            GRAALVM_VERSION="23.1.2"
            ;;
        *)
            log "${RED}错误: GraalVM 不支持 Java ${JAVA_VERSION}${NC}"
            log "${YELLOW}GraalVM 仅支持 Java 17 和 21${NC}"
            exit 1
            ;;
    esac
    
    # 下载URL
    GRAALVM_URL="https://github.com/graalvm/graalvm-ce-builds/releases/download/jdk-${JAVA_VERSION}.0.2/graalvm-community-jdk-${JAVA_VERSION}.0.2_linux-${ARCH_TYPE}_bin.tar.gz"
    
    # 下载并安装
    cd /tmp
    log "${YELLOW}正在下载 GraalVM...${NC}"
    wget -O graalvm.tar.gz "$GRAALVM_URL"
    
    if [[ ! -f graalvm.tar.gz ]]; then
        log "${RED}错误: GraalVM 下载失败${NC}"
        exit 1
    fi
    
    # 解压到 /opt
    tar -xzf graalvm.tar.gz -C /opt/
    
    # 查找实际的GraalVM目录名
    GRAALVM_DIR=$(find /opt -maxdepth 1 -type d -name "graalvm*" | head -1)
    
    # 设置环境变量
    echo "export JAVA_HOME=${GRAALVM_DIR}" > /etc/profile.d/graalvm.sh
    echo "export GRAALVM_HOME=${GRAALVM_DIR}" >> /etc/profile.d/graalvm.sh
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile.d/graalvm.sh
    
    # 创建软链接
    ln -sf ${GRAALVM_DIR}/bin/java /usr/bin/java
    ln -sf ${GRAALVM_DIR}/bin/javac /usr/bin/javac
    ln -sf ${GRAALVM_DIR}/bin/jar /usr/bin/jar
    ln -sf ${GRAALVM_DIR}/bin/gu /usr/bin/gu
    
    # 安装native-image
    log "${CYAN}安装 GraalVM native-image...${NC}"
    ${GRAALVM_DIR}/bin/gu install native-image
    
    # 清理
    rm -f /tmp/graalvm.tar.gz
}

# 安装Maven
install_maven() {
    log "${CYAN}安装 Apache Maven ${MAVEN_VERSION}...${NC}"
    
    # 下载Maven
    cd /tmp
    wget "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"
    
    if [[ ! -f "apache-maven-${MAVEN_VERSION}-bin.tar.gz" ]]; then
        log "${RED}错误: Maven 下载失败${NC}"
        return 1
    fi
    
    # 解压到 /opt
    tar -xzf "apache-maven-${MAVEN_VERSION}-bin.tar.gz" -C /opt/
    
    # 创建软链接
    ln -sf /opt/apache-maven-${MAVEN_VERSION} /opt/maven
    
    # 设置环境变量
    echo "export MAVEN_HOME=/opt/maven" > /etc/profile.d/maven.sh
    echo "export PATH=\$MAVEN_HOME/bin:\$PATH" >> /etc/profile.d/maven.sh
    
    # 创建软链接到 /usr/bin
    ln -sf /opt/maven/bin/mvn /usr/bin/mvn
    
    # 配置Maven镜像（使用阿里云镜像加速）
    mkdir -p /opt/maven/conf
    cat > /opt/maven/conf/settings.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
          http://maven.apache.org/xsd/settings-1.0.0.xsd">
    <mirrors>
        <mirror>
            <id>aliyunmaven</id>
            <mirrorOf>*</mirrorOf>
            <name>阿里云公共仓库</name>
            <url>https://maven.aliyun.com/repository/public</url>
        </mirror>
    </mirrors>
</settings>
EOF
    
    # 清理
    rm -f /tmp/apache-maven-${MAVEN_VERSION}-bin.tar.gz
    
    log "${GREEN}Maven ${MAVEN_VERSION} 安装完成${NC}"
}

# 安装Gradle
install_gradle() {
    log "${CYAN}安装 Gradle ${GRADLE_VERSION}...${NC}"
    
    # 下载Gradle
    cd /tmp
    wget "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip"
    
    if [[ ! -f "gradle-${GRADLE_VERSION}-bin.zip" ]]; then
        log "${RED}错误: Gradle 下载失败${NC}"
        return 1
    fi
    
    # 解压到 /opt
    unzip -q "gradle-${GRADLE_VERSION}-bin.zip" -d /opt/
    
    # 创建软链接
    ln -sf /opt/gradle-${GRADLE_VERSION} /opt/gradle
    
    # 设置环境变量
    echo "export GRADLE_HOME=/opt/gradle" > /etc/profile.d/gradle.sh
    echo "export PATH=\$GRADLE_HOME/bin:\$PATH" >> /etc/profile.d/gradle.sh
    
    # 创建软链接到 /usr/bin
    ln -sf /opt/gradle/bin/gradle /usr/bin/gradle
    
    # 清理
    rm -f /tmp/gradle-${GRADLE_VERSION}-bin.zip
    
    log "${GREEN}Gradle ${GRADLE_VERSION} 安装完成${NC}"
}

# 配置JAVA_HOME
configure_java_home() {
    log "${CYAN}配置 JAVA_HOME 环境变量...${NC}"
    
    # 查找Java安装路径
    if [[ "$JDK_TYPE" == "openjdk" ]]; then
        JAVA_PATH=$(readlink -f $(which java))
        JAVA_HOME=$(dirname $(dirname $JAVA_PATH))
        
        # 设置环境变量
        echo "export JAVA_HOME=${JAVA_HOME}" > /etc/profile.d/java.sh
        echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile.d/java.sh
    fi
    
    # 重新加载环境变量
    source /etc/profile.d/java.sh 2>/dev/null || true
}

# 验证安装
verify_installation() {
    log "${CYAN}验证安装...${NC}"
    
    # 重新加载所有环境变量
    for profile in /etc/profile.d/*.sh; do
        source "$profile" 2>/dev/null || true
    done
    
    # 验证Java
    if command -v java &> /dev/null; then
        java_version=$(java -version 2>&1 | head -n 1)
        log "${GREEN}Java 安装成功:${NC}"
        log "${GREEN}${java_version}${NC}"
        log "${GREEN}JAVA_HOME: ${JAVA_HOME:-未设置}${NC}"
    else
        log "${RED}错误: Java 安装验证失败${NC}"
        exit 1
    fi
    
    # 验证Maven
    if [[ "$INSTALL_MAVEN" = true ]] && command -v mvn &> /dev/null; then
        mvn_version=$(mvn -version 2>&1 | head -n 1)
        log "${GREEN}Maven 安装成功:${NC}"
        log "${GREEN}${mvn_version}${NC}"
    fi
    
    # 验证Gradle
    if [[ "$INSTALL_GRADLE" = true ]] && command -v gradle &> /dev/null; then
        gradle_version=$(gradle -version 2>&1 | grep "Gradle" | head -n 1)
        log "${GREEN}Gradle 安装成功:${NC}"
        log "${GREEN}${gradle_version}${NC}"
    fi
}

# 显示安装后说明
show_post_install_info() {
    echo
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${GREEN}Java 环境安装完成!${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
    echo -e "${CYAN}环境信息:${NC}"
    echo "- JDK类型: ${JDK_TYPE}"
    echo "- Java版本: ${JAVA_VERSION}"
    
    if [[ "$INSTALL_MAVEN" = true ]]; then
        echo "- Maven版本: ${MAVEN_VERSION}"
    fi
    
    if [[ "$INSTALL_GRADLE" = true ]]; then
        echo "- Gradle版本: ${GRADLE_VERSION}"
    fi
    
    echo
    echo -e "${CYAN}使用说明:${NC}"
    echo "1. 编译Java程序: javac HelloWorld.java"
    echo "2. 运行Java程序: java HelloWorld"
    echo "3. 查看Java版本: java -version"
    
    if [[ "$INSTALL_MAVEN" = true ]]; then
        echo
        echo -e "${CYAN}Maven使用:${NC}"
        echo "- 创建项目: mvn archetype:generate"
        echo "- 编译项目: mvn compile"
        echo "- 打包项目: mvn package"
        echo "- 运行测试: mvn test"
    fi
    
    if [[ "$INSTALL_GRADLE" = true ]]; then
        echo
        echo -e "${CYAN}Gradle使用:${NC}"
        echo "- 初始化项目: gradle init"
        echo "- 构建项目: gradle build"
        echo "- 运行测试: gradle test"
        echo "- 查看任务: gradle tasks"
    fi
    
    if [[ "$JDK_TYPE" == "graalvm" ]]; then
        echo
        echo -e "${CYAN}GraalVM特性:${NC}"
        echo "- 编译本地镜像: native-image HelloWorld"
        echo "- 安装语言支持: gu install python/ruby/nodejs"
        echo "- 查看已安装组件: gu list"
    fi
    
    echo
    echo -e "${YELLOW}注意: 某些更改可能需要重新登录或执行 source /etc/profile 才能生效${NC}"
    echo -e "${YELLOW}日志文件: ${LOG_FILE}${NC}"
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                JDK_TYPE="$2"
                shift 2
                ;;
            --version)
                JAVA_VERSION="$2"
                shift 2
                ;;
            --install-maven)
                INSTALL_MAVEN=true
                shift
                ;;
            --install-gradle)
                INSTALL_GRADLE=true
                shift
                ;;
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}错误: 未知选项 $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 显示标题
    show_title
    
    # 检查root权限
    check_root
    
    # 检测系统
    detect_system
    
    # 检查是否已安装
    check_java_installed
    
    # 安装依赖
    install_dependencies
    
    # 如果强制安装，先清理旧版本
    if [[ "$FORCE_INSTALL" = true ]]; then
        clean_old_java
    fi
    
    # 根据类型安装
    case $JDK_TYPE in
        openjdk)
            install_openjdk
            ;;
        oracle)
            install_oracle_jdk
            ;;
        graalvm)
            install_graalvm
            ;;
        *)
            log "${RED}错误: 无效的JDK类型 ${JDK_TYPE}${NC}"
            show_help
            exit 1
            ;;
    esac
    
    # 配置JAVA_HOME
    configure_java_home
    
    # 安装构建工具
    if [[ "$INSTALL_MAVEN" = true ]]; then
        install_maven
    fi
    
    if [[ "$INSTALL_GRADLE" = true ]]; then
        install_gradle
    fi
    
    # 验证安装
    verify_installation
    
    # 显示安装后信息
    show_post_install_info
}

# 执行主函数
main "$@"