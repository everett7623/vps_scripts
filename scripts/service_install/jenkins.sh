#!/bin/bash
#==============================================================================
# 脚本名称: jenkins.sh
# 脚本描述: Jenkins CI/CD平台安装配置脚本 - 支持多种部署方式和插件管理
# 脚本路径: vps_scripts/scripts/service_install/jenkins.sh
# 作者: Jensfrank
# 使用方法: bash jenkins.sh [选项]
# 选项说明:
#   --install-type <类型>  安装类型 (package/war/docker)
#   --version <版本>       Jenkins版本 (lts/weekly/具体版本号)
#   --port <端口>          HTTP端口 (默认: 8080)
#   --prefix <前缀>        URL前缀 (如: /jenkins)
#   --java-version <版本>  Java版本 (11/17)
#   --install-plugins      安装推荐插件集
#   --plugin-list <插件>   自定义插件列表 (逗号分隔)
#   --skip-setup-wizard    跳过初始设置向导
#   --admin-user <用户>    管理员用户名
#   --admin-password       管理员密码
#   --enable-security      启用安全配置
#   --install-tools        安装构建工具 (Maven/Gradle/NodeJS)
#   --docker-group         将Jenkins用户加入docker组
#   --nginx-proxy          配置Nginx反向代理
#   --backup-schedule      配置自动备份
#   --china-mirror         使用中国镜像源
#   --force                强制重新安装
#   --help                 显示帮助信息
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
INSTALL_TYPE="package"
JENKINS_VERSION="lts"
HTTP_PORT="8080"
URL_PREFIX=""
JAVA_VERSION="11"
INSTALL_PLUGINS=false
PLUGIN_LIST=""
SKIP_SETUP_WIZARD=false
ADMIN_USER="admin"
ADMIN_PASSWORD=""
ENABLE_SECURITY=false
INSTALL_TOOLS=false
DOCKER_GROUP=false
NGINX_PROXY=false
BACKUP_SCHEDULE=false
USE_CHINA_MIRROR=false
FORCE_INSTALL=false
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/jenkins_install_$(date +%Y%m%d_%H%M%S).log"

# 默认配置
JENKINS_HOME="/var/lib/jenkins"
JENKINS_USER="jenkins"
JENKINS_WAR="/usr/share/jenkins/jenkins.war"
JENKINS_CONFIG="/etc/default/jenkins"
JENKINS_INIT_DIR="/var/lib/jenkins/init.groovy.d"
BACKUP_DIR="/var/backups/jenkins"

# 推荐插件列表
RECOMMENDED_PLUGINS=(
    "git"
    "github"
    "gitlab-plugin"
    "workflow-aggregator"
    "pipeline-stage-view"
    "blueocean"
    "docker-workflow"
    "docker-plugin"
    "kubernetes"
    "kubernetes-cli"
    "configuration-as-code"
    "job-dsl"
    "matrix-auth"
    "role-strategy"
    "ldap"
    "active-directory"
    "email-ext"
    "mailer"
    "slack"
    "timestamper"
    "ws-cleanup"
    "ansicolor"
    "build-timeout"
    "gradle"
    "maven-plugin"
    "nodejs"
    "sonar"
    "jacoco"
    "cobertura"
    "htmlpublisher"
    "publish-over-ssh"
    "ssh-agent"
    "credentials-binding"
    "pipeline-utility-steps"
    "http_request"
    "build-monitor-plugin"
    "dashboard-view"
    "cloudbees-folder"
    "antisamy-markup-formatter"
    "build-name-setter"
    "rebuild"
    "throttle-concurrents"
    "workspace-cleanup"
    "monitoring"
    "metrics"
    "prometheus"
)

# 记录日志
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}   Jenkins CI/CD平台安装脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash jenkins.sh [选项]"
    echo
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --install-type <类型>  安装类型:"
    echo "                         package - 系统包安装 (默认)"
    echo "                         war     - WAR包安装"
    echo "                         docker  - Docker容器安装"
    echo "  --version <版本>       Jenkins版本:"
    echo "                         lts     - 长期支持版 (默认)"
    echo "                         weekly  - 每周更新版"
    echo "                         2.426.1 - 指定版本号"
    echo "  --port <端口>          HTTP端口 (默认: 8080)"
    echo "  --prefix <前缀>        URL前缀 (如: /jenkins)"
    echo "  --java-version <版本>  Java版本 (11/17)"
    echo "  --install-plugins      安装推荐插件集"
    echo "  --plugin-list <插件>   自定义插件列表"
    echo "  --skip-setup-wizard    跳过初始设置向导"
    echo "  --admin-user <用户>    管理员用户名"
    echo "  --admin-password       管理员密码"
    echo "  --enable-security      启用安全配置"
    echo "  --install-tools        安装构建工具"
    echo "  --docker-group         将Jenkins用户加入docker组"
    echo "  --nginx-proxy          配置Nginx反向代理"
    echo "  --backup-schedule      配置自动备份"
    echo "  --china-mirror         使用中国镜像源"
    echo "  --force                强制重新安装"
    echo "  --help                 显示此帮助信息"
    echo
    echo -e "${GREEN}示例:${NC}"
    echo "  bash jenkins.sh                                           # 默认安装"
    echo "  bash jenkins.sh --install-plugins --docker-group"
    echo "  bash jenkins.sh --install-type docker --port 8090"
    echo "  bash jenkins.sh --china-mirror --install-tools --nginx-proxy"
    echo "  bash jenkins.sh --admin-password MyPass123 --enable-security"
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
        VER_MAJOR=$(echo $VER | cut -d. -f1)
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VER=$(lsb_release -sr)
        VER_MAJOR=$(echo $VER | cut -d. -f1)
    else
        log "${RED}错误: 无法检测系统类型${NC}"
        exit 1
    fi
    
    log "${GREEN}检测到系统: ${OS} ${VER}${NC}"
}

# 生成随机密码
generate_password() {
    openssl rand -base64 16 | tr -d "=+/" | cut -c1-16
}

# 检查Jenkins是否已安装
check_jenkins_installed() {
    if systemctl list-units --type=service | grep -q jenkins || [[ -f "$JENKINS_WAR" ]]; then
        if [[ "$FORCE_INSTALL" = false ]]; then
            log "${YELLOW}检测到Jenkins已安装${NC}"
            if command -v jenkins &> /dev/null; then
                jenkins --version 2>/dev/null || true
            fi
            read -p "是否继续安装? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "${YELLOW}安装已取消${NC}"
                exit 0
            fi
        fi
        
        # 停止现有服务
        systemctl stop jenkins 2>/dev/null || true
    fi
}

# 安装Java
install_java() {
    log "${CYAN}安装Java ${JAVA_VERSION}...${NC}"
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y openjdk-${JAVA_VERSION}-jdk
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if [[ "$JAVA_VERSION" == "11" ]]; then
                yum install -y java-11-openjdk java-11-openjdk-devel
            elif [[ "$JAVA_VERSION" == "17" ]]; then
                yum install -y java-17-openjdk java-17-openjdk-devel
            fi
            ;;
    esac
    
    # 设置JAVA_HOME
    export JAVA_HOME=$(readlink -f $(which java) | sed "s:/bin/java::")
    echo "export JAVA_HOME=$JAVA_HOME" > /etc/profile.d/java.sh
    
    log "${GREEN}Java ${JAVA_VERSION} 安装完成${NC}"
}

# 创建Jenkins用户
create_jenkins_user() {
    if ! id "$JENKINS_USER" &>/dev/null; then
        log "${CYAN}创建Jenkins用户...${NC}"
        useradd --system --shell /bin/bash --home-dir "$JENKINS_HOME" --create-home $JENKINS_USER
    fi
    
    # 创建必要的目录
    mkdir -p "$JENKINS_HOME"
    mkdir -p "$JENKINS_HOME/.jenkins"
    mkdir -p "$JENKINS_INIT_DIR"
    chown -R $JENKINS_USER:$JENKINS_USER "$JENKINS_HOME"
}

# 系统包方式安装
install_package() {
    log "${CYAN}使用系统包安装Jenkins...${NC}"
    
    case $OS in
        ubuntu|debian)
            # 添加Jenkins仓库
            if [[ "$USE_CHINA_MIRROR" = true ]]; then
                wget -q -O - https://mirrors.tuna.tsinghua.edu.cn/jenkins/debian-stable/jenkins.io.key | apt-key add -
                echo "deb https://mirrors.tuna.tsinghua.edu.cn/jenkins/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
            else
                wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | apt-key add -
                echo "deb https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
            fi
            
            apt-get update
            if [[ "$JENKINS_VERSION" == "lts" ]]; then
                apt-get install -y jenkins
            else
                apt-get install -y jenkins=$JENKINS_VERSION
            fi
            ;;
        centos|rhel|fedora|rocky|almalinux)
            # 添加Jenkins仓库
            if [[ "$USE_CHINA_MIRROR" = true ]]; then
                wget -O /etc/yum.repos.d/jenkins.repo https://mirrors.tuna.tsinghua.edu.cn/jenkins/redhat-stable/jenkins.repo
                rpm --import https://mirrors.tuna.tsinghua.edu.cn/jenkins/redhat-stable/jenkins.io.key
            else
                wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
                rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
            fi
            
            yum install -y jenkins
            ;;
    esac
}

# WAR包方式安装
install_war() {
    log "${CYAN}使用WAR包安装Jenkins...${NC}"
    
    # 创建目录
    mkdir -p /usr/share/jenkins
    
    # 下载Jenkins WAR
    if [[ "$JENKINS_VERSION" == "lts" ]]; then
        DOWNLOAD_URL="http://mirrors.jenkins.io/war-stable/latest/jenkins.war"
        if [[ "$USE_CHINA_MIRROR" = true ]]; then
            DOWNLOAD_URL="https://mirrors.tuna.tsinghua.edu.cn/jenkins/war-stable/latest/jenkins.war"
        fi
    elif [[ "$JENKINS_VERSION" == "weekly" ]]; then
        DOWNLOAD_URL="http://mirrors.jenkins.io/war/latest/jenkins.war"
        if [[ "$USE_CHINA_MIRROR" = true ]]; then
            DOWNLOAD_URL="https://mirrors.tuna.tsinghua.edu.cn/jenkins/war/latest/jenkins.war"
        fi
    else
        DOWNLOAD_URL="http://mirrors.jenkins.io/war-stable/${JENKINS_VERSION}/jenkins.war"
        if [[ "$USE_CHINA_MIRROR" = true ]]; then
            DOWNLOAD_URL="https://mirrors.tuna.tsinghua.edu.cn/jenkins/war-stable/${JENKINS_VERSION}/jenkins.war"
        fi
    fi
    
    log "${YELLOW}下载Jenkins WAR包...${NC}"
    wget -O "$JENKINS_WAR" "$DOWNLOAD_URL"
    
    if [[ ! -f "$JENKINS_WAR" ]]; then
        log "${RED}错误: Jenkins WAR包下载失败${NC}"
        exit 1
    fi
    
    # 创建systemd服务文件
    create_systemd_service
}

# Docker方式安装
install_docker() {
    log "${CYAN}使用Docker安装Jenkins...${NC}"
    
    # 检查Docker是否安装
    if ! command -v docker &> /dev/null; then
        log "${RED}错误: Docker未安装，请先安装Docker${NC}"
        exit 1
    fi
    
    # 创建数据目录
    mkdir -p "$JENKINS_HOME"
    chown 1000:1000 "$JENKINS_HOME"
    
    # 拉取镜像
    if [[ "$JENKINS_VERSION" == "lts" ]]; then
        docker pull jenkins/jenkins:lts
        JENKINS_IMAGE="jenkins/jenkins:lts"
    elif [[ "$JENKINS_VERSION" == "weekly" ]]; then
        docker pull jenkins/jenkins:latest
        JENKINS_IMAGE="jenkins/jenkins:latest"
    else
        docker pull jenkins/jenkins:${JENKINS_VERSION}
        JENKINS_IMAGE="jenkins/jenkins:${JENKINS_VERSION}"
    fi
    
    # 创建并启动容器
    docker run -d \
        --name jenkins \
        --restart always \
        -p ${HTTP_PORT}:8080 \
        -p 50000:50000 \
        -v ${JENKINS_HOME}:/var/jenkins_home \
        -v /var/run/docker.sock:/var/run/docker.sock \
        ${JENKINS_IMAGE}
    
    log "${GREEN}Jenkins Docker容器已启动${NC}"
}

# 创建systemd服务文件
create_systemd_service() {
    log "${CYAN}创建systemd服务文件...${NC}"
    
    cat > /etc/systemd/system/jenkins.service << EOF
[Unit]
Description=Jenkins Continuous Integration Server
After=network.target

[Service]
Type=notify
NotifyAccess=main
ExecStart=/usr/bin/java -Djava.awt.headless=true -jar ${JENKINS_WAR} --httpPort=${HTTP_PORT} ${URL_PREFIX:+--prefix=$URL_PREFIX}
Restart=on-failure
User=$JENKINS_USER
Group=$JENKINS_USER
Environment="JENKINS_HOME=$JENKINS_HOME"
WorkingDirectory=$JENKINS_HOME

# Java options
Environment="JAVA_OPTS=-Xmx2048m -XX:+UseG1GC -Djenkins.install.runSetupWizard=${SKIP_SETUP_WIZARD}"

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
}

# 配置Jenkins
configure_jenkins() {
    log "${CYAN}配置Jenkins...${NC}"
    
    # 配置更新中心
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        mkdir -p "$JENKINS_HOME/updates"
        cat > "$JENKINS_HOME/hudson.model.UpdateCenter.xml" << EOF
<?xml version='1.1' encoding='UTF-8'?>
<sites>
  <site>
    <id>default</id>
    <url>https://mirrors.tuna.tsinghua.edu.cn/jenkins/updates/update-center.json</url>
  </site>
</sites>
EOF
        chown $JENKINS_USER:$JENKINS_USER "$JENKINS_HOME/hudson.model.UpdateCenter.xml"
    fi
    
    # 创建初始化脚本目录
    mkdir -p "$JENKINS_INIT_DIR"
    
    # 跳过设置向导
    if [[ "$SKIP_SETUP_WIZARD" = true ]]; then
        echo "$JENKINS_VERSION" > "$JENKINS_HOME/jenkins.install.UpgradeWizard.state"
        echo "$JENKINS_VERSION" > "$JENKINS_HOME/jenkins.install.InstallUtil.lastExecVersion"
        chown $JENKINS_USER:$JENKINS_USER "$JENKINS_HOME"/jenkins.install.*
    fi
}

# 创建管理员用户
create_admin_user() {
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        ADMIN_PASSWORD=$(generate_password)
        log "${YELLOW}生成的管理员密码: $ADMIN_PASSWORD${NC}"
    fi
    
    log "${CYAN}创建管理员用户...${NC}"
    
    # 创建Groovy脚本设置管理员
    cat > "$JENKINS_INIT_DIR/01-create-admin-user.groovy" << EOF
import jenkins.model.*
import hudson.security.*
import hudson.model.*

def instance = Jenkins.getInstance()

// 创建管理员用户
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("${ADMIN_USER}", "${ADMIN_PASSWORD}")
instance.setSecurityRealm(hudsonRealm)

// 设置授权策略
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.save()

println "管理员用户 ${ADMIN_USER} 创建成功"
EOF
    
    chown $JENKINS_USER:$JENKINS_USER "$JENKINS_INIT_DIR/01-create-admin-user.groovy"
}

# 配置安全设置
configure_security() {
    if [[ "$ENABLE_SECURITY" != true ]]; then
        return
    fi
    
    log "${CYAN}配置安全设置...${NC}"
    
    # 创建安全配置脚本
    cat > "$JENKINS_INIT_DIR/02-security-config.groovy" << 'EOF'
import jenkins.model.*
import hudson.security.csrf.DefaultCrumbIssuer
import jenkins.security.s2m.AdminWhitelistRule

def instance = Jenkins.getInstance()

// 启用CSRF保护
instance.setCrumbIssuer(new DefaultCrumbIssuer(true))

// 禁用CLI over Remoting
instance.getDescriptor("jenkins.CLI").get().setEnabled(false)

// 配置代理兼容性
System.setProperty("hudson.model.DirectoryBrowserSupport.CSP", "")

instance.save()

println "安全配置完成"
EOF
    
    chown $JENKINS_USER:$JENKINS_USER "$JENKINS_INIT_DIR/02-security-config.groovy"
}

# 安装插件
install_plugins() {
    if [[ "$INSTALL_PLUGINS" != true ]] && [[ -z "$PLUGIN_LIST" ]]; then
        return
    fi
    
    log "${CYAN}准备插件安装脚本...${NC}"
    
    # 合并插件列表
    local plugins=()
    if [[ "$INSTALL_PLUGINS" = true ]]; then
        plugins+=("${RECOMMENDED_PLUGINS[@]}")
    fi
    if [[ -n "$PLUGIN_LIST" ]]; then
        IFS=',' read -ra CUSTOM_PLUGINS <<< "$PLUGIN_LIST"
        plugins+=("${CUSTOM_PLUGINS[@]}")
    fi
    
    # 创建插件安装脚本
    cat > "$JENKINS_INIT_DIR/03-install-plugins.groovy" << EOF
import jenkins.model.*
import java.util.logging.Logger

def logger = Logger.getLogger("")
def installed = false
def initialized = false

def pluginParameter = "${plugins[*]}"
def plugins = pluginParameter.split()

def instance = Jenkins.getInstance()
def pm = instance.getPluginManager()
def uc = instance.getUpdateCenter()

plugins.each {
    logger.info("Checking " + it)
    if (!pm.getPlugin(it)) {
        logger.info("Looking for " + it)
        if (!initialized) {
            uc.updateAllSites()
            initialized = true
        }
        def plugin = uc.getPlugin(it)
        if (plugin) {
            logger.info("Installing " + it)
            def installFuture = plugin.deploy()
            while (!installFuture.isDone()) {
                logger.info("Waiting for plugin install: " + it)
                sleep(3000)
            }
            installed = true
        }
    }
}

if (installed) {
    logger.info("Plugins installed, restarting...")
    instance.save()
    instance.restart()
}
EOF
    
    chown $JENKINS_USER:$JENKINS_USER "$JENKINS_INIT_DIR/03-install-plugins.groovy"
}

# 安装构建工具
install_build_tools() {
    if [[ "$INSTALL_TOOLS" != true ]]; then
        return
    fi
    
    log "${CYAN}安装构建工具...${NC}"
    
    # 安装Maven
    log "${YELLOW}安装Maven...${NC}"
    MAVEN_VERSION="3.9.5"
    wget https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz
    tar -xzf apache-maven-${MAVEN_VERSION}-bin.tar.gz -C /opt/
    ln -sf /opt/apache-maven-${MAVEN_VERSION} /opt/maven
    rm -f apache-maven-${MAVEN_VERSION}-bin.tar.gz
    
    # 安装Gradle
    log "${YELLOW}安装Gradle...${NC}"
    GRADLE_VERSION="8.5"
    wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip
    unzip -q gradle-${GRADLE_VERSION}-bin.zip -d /opt/
    ln -sf /opt/gradle-${GRADLE_VERSION} /opt/gradle
    rm -f gradle-${GRADLE_VERSION}-bin.zip
    
    # 安装Node.js
    log "${YELLOW}安装Node.js...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
    
    # 配置环境变量
    cat > /etc/profile.d/build-tools.sh << EOF
export MAVEN_HOME=/opt/maven
export GRADLE_HOME=/opt/gradle
export PATH=\$MAVEN_HOME/bin:\$GRADLE_HOME/bin:\$PATH
EOF
    
    # 配置Maven镜像（中国）
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        mkdir -p /opt/maven/conf
        cat > /opt/maven/conf/settings.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<settings>
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
    fi
    
    log "${GREEN}构建工具安装完成${NC}"
}

# 配置Docker权限
configure_docker_group() {
    if [[ "$DOCKER_GROUP" != true ]]; then
        return
    fi
    
    log "${CYAN}配置Docker权限...${NC}"
    
    # 将Jenkins用户加入docker组
    if getent group docker > /dev/null 2>&1; then
        usermod -aG docker $JENKINS_USER
        log "${GREEN}Jenkins用户已加入docker组${NC}"
    else
        log "${YELLOW}Docker组不存在，请先安装Docker${NC}"
    fi
}

# 配置Nginx反向代理
configure_nginx_proxy() {
    if [[ "$NGINX_PROXY" != true ]]; then
        return
    fi
    
    log "${CYAN}配置Nginx反向代理...${NC}"
    
    # 检查Nginx是否安装
    if ! command -v nginx &> /dev/null; then
        log "${YELLOW}Nginx未安装，正在安装...${NC}"
        case $OS in
            ubuntu|debian)
                apt-get update
                apt-get install -y nginx
                ;;
            centos|rhel|fedora|rocky|almalinux)
                yum install -y nginx
                ;;
        esac
    fi
    
    # 创建Jenkins配置
    cat > /etc/nginx/sites-available/jenkins << EOF
upstream jenkins {
    server 127.0.0.1:${HTTP_PORT} fail_timeout=0;
}

server {
    listen 80;
    server_name _;
    
    location ${URL_PREFIX:=/}/ {
        proxy_set_header        Host \$host:\$server_port;
        proxy_set_header        X-Real-IP \$remote_addr;
        proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto \$scheme;
        proxy_redirect          http:// https://;
        proxy_pass              http://jenkins${URL_PREFIX}/;
        
        # Required for new HTTP-based CLI
        proxy_http_version 1.1;
        proxy_request_buffering off;
        proxy_buffering off;
        
        # Increase timeouts
        proxy_connect_timeout       600;
        proxy_send_timeout          600;
        proxy_read_timeout          600;
        send_timeout                600;
    }
}
EOF
    
    # 启用配置
    ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    
    log "${GREEN}Nginx反向代理配置完成${NC}"
}

# 配置自动备份
configure_backup() {
    if [[ "$BACKUP_SCHEDULE" != true ]]; then
        return
    fi
    
    log "${CYAN}配置自动备份...${NC}"
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
    
    # 创建备份脚本
    cat > /usr/local/bin/jenkins_backup.sh << 'EOF'
#!/bin/bash
# Jenkins自动备份脚本

JENKINS_HOME="/var/lib/jenkins"
BACKUP_DIR="/var/backups/jenkins"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="jenkins_backup_$TIMESTAMP"

# 创建备份
echo "开始备份Jenkins..."
tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" \
    --exclude="$JENKINS_HOME/workspace" \
    --exclude="$JENKINS_HOME/logs" \
    --exclude="$JENKINS_HOME/.cache" \
    -C "$JENKINS_HOME" .

# 清理30天前的备份
find "$BACKUP_DIR" -name "jenkins_backup_*.tar.gz" -mtime +30 -delete

echo "备份完成: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
EOF
    
    chmod +x /usr/local/bin/jenkins_backup.sh
    
    # 添加cron任务
    echo "0 2 * * * /usr/local/bin/jenkins_backup.sh >> $BACKUP_DIR/backup.log 2>&1" | crontab -
    
    log "${GREEN}自动备份配置完成 (每天凌晨2点执行)${NC}"
}

# 创建示例任务
create_sample_job() {
    log "${CYAN}创建示例任务配置...${NC}"
    
    # 创建示例Pipeline任务
    mkdir -p "$JENKINS_HOME/jobs/sample-pipeline/builds"
    
    cat > "$JENKINS_HOME/jobs/sample-pipeline/config.xml" << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>示例Pipeline任务</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>
pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code...'
                // git 'https://github.com/your-repo/your-project.git'
            }
        }
        
        stage('Build') {
            steps {
                echo 'Building application...'
                sh 'echo "Build completed"'
            }
        }
        
        stage('Test') {
            steps {
                echo 'Running tests...'
                sh 'echo "Tests passed"'
            }
        }
        
        stage('Deploy') {
            steps {
                echo 'Deploying application...'
                sh 'echo "Deployment successful"'
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline completed'
        }
        success {
            echo 'Pipeline succeeded'
        }
        failure {
            echo 'Pipeline failed'
        }
    }
}
    </script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF
    
    chown -R $JENKINS_USER:$JENKINS_USER "$JENKINS_HOME/jobs"
}

# 启动Jenkins服务
start_jenkins_service() {
    log "${CYAN}启动Jenkins服务...${NC}"
    
    if [[ "$INSTALL_TYPE" == "docker" ]]; then
        # Docker已经在安装时启动
        if docker ps | grep -q jenkins; then
            log "${GREEN}Jenkins Docker容器运行正常${NC}"
        else
            log "${RED}Jenkins Docker容器启动失败${NC}"
            docker logs jenkins
        fi
    else
        systemctl enable jenkins
        systemctl start jenkins
        
        # 等待Jenkins启动
        log "${YELLOW}等待Jenkins启动...${NC}"
        sleep 30
        
        # 检查服务状态
        if systemctl is-active --quiet jenkins; then
            log "${GREEN}Jenkins服务启动成功${NC}"
        else
            log "${RED}Jenkins服务启动失败${NC}"
            systemctl status jenkins
            exit 1
        fi
    fi
}

# 获取初始密码
get_initial_password() {
    if [[ "$SKIP_SETUP_WIZARD" = true ]]; then
        return
    fi
    
    log "${CYAN}获取初始管理员密码...${NC}"
    
    local password_file="$JENKINS_HOME/secrets/initialAdminPassword"
    local attempts=0
    
    while [[ ! -f "$password_file" ]] && [[ $attempts -lt 30 ]]; do
        sleep 2
        ((attempts++))
    done
    
    if [[ -f "$password_file" ]]; then
        INITIAL_PASSWORD=$(cat "$password_file")
        log "${GREEN}初始管理员密码: ${INITIAL_PASSWORD}${NC}"
    fi
}

# 保存配置信息
save_config_info() {
    log "${CYAN}保存配置信息...${NC}"
    
    # 获取服务器IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    # 创建配置信息文件
    cat > /root/jenkins_config_info.txt << EOF
Jenkins CI/CD平台配置信息
========================

访问地址: http://${SERVER_IP}:${HTTP_PORT}${URL_PREFIX}
管理员用户: ${ADMIN_USER}
管理员密码: ${ADMIN_PASSWORD}
${INITIAL_PASSWORD:+初始密码: $INITIAL_PASSWORD}

安装类型: ${INSTALL_TYPE}
Jenkins版本: ${JENKINS_VERSION}
Java版本: ${JAVA_VERSION}
Jenkins主目录: ${JENKINS_HOME}

服务管理:
- 启动: systemctl start jenkins
- 停止: systemctl stop jenkins
- 重启: systemctl restart jenkins
- 状态: systemctl status jenkins
- 日志: journalctl -u jenkins -f

${NGINX_PROXY:+Nginx反向代理: 已配置 (端口80)}
${BACKUP_SCHEDULE:+自动备份: 已配置 (每天凌晨2点)}
${DOCKER_GROUP:+Docker权限: Jenkins用户已加入docker组}

构建工具:
${INSTALL_TOOLS:+- Maven: /opt/maven}
${INSTALL_TOOLS:+- Gradle: /opt/gradle}
${INSTALL_TOOLS:+- Node.js: $(node --version 2>/dev/null || echo "未安装")}

备份目录: ${BACKUP_DIR}
日志位置: ${JENKINS_HOME}/logs
工作空间: ${JENKINS_HOME}/workspace
插件目录: ${JENKINS_HOME}/plugins
EOF
    
    chmod 600 /root/jenkins_config_info.txt
}

# 验证安装
verify_installation() {
    log "${CYAN}验证Jenkins安装...${NC}"
    
    # 检查Jenkins是否响应
    local jenkins_url="http://localhost:${HTTP_PORT}${URL_PREFIX}"
    local attempts=0
    local max_attempts=30
    
    while [[ $attempts -lt $max_attempts ]]; do
        if curl -s -o /dev/null -w "%{http_code}" "$jenkins_url/login" | grep -q "200\|403"; then
            log "${GREEN}Jenkins Web界面响应正常${NC}"
            break
        fi
        sleep 2
        ((attempts++))
    done
    
    if [[ $attempts -eq $max_attempts ]]; then
        log "${RED}Jenkins Web界面无响应${NC}"
    fi
    
    # 显示版本信息
    if [[ "$INSTALL_TYPE" != "docker" ]]; then
        log "${CYAN}Jenkins版本信息:${NC}"
        java -jar "$JENKINS_WAR" --version 2>/dev/null || true
    fi
}

# 显示安装后说明
show_post_install_info() {
    echo
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${GREEN}Jenkins安装配置完成!${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
    echo -e "${CYAN}访问信息:${NC}"
    echo "- 访问地址: http://$(hostname -I | awk '{print $1}'):${HTTP_PORT}${URL_PREFIX}"
    if [[ "$NGINX_PROXY" = true ]]; then
        echo "- Nginx代理: http://$(hostname -I | awk '{print $1}')${URL_PREFIX}"
    fi
    echo "- 管理员用户: ${ADMIN_USER}"
    if [[ -n "$ADMIN_PASSWORD" ]]; then
        echo "- 管理员密码: ${ADMIN_PASSWORD}"
    fi
    if [[ -n "$INITIAL_PASSWORD" ]]; then
        echo "- 初始密码: ${INITIAL_PASSWORD}"
    fi
    echo "- 配置信息: /root/jenkins_config_info.txt"
    echo
    echo -e "${CYAN}服务管理:${NC}"
    if [[ "$INSTALL_TYPE" == "docker" ]]; then
        echo "- 查看日志: docker logs -f jenkins"
        echo "- 进入容器: docker exec -it jenkins bash"
        echo "- 重启容器: docker restart jenkins"
    else
        echo "- 启动服务: systemctl start jenkins"
        echo "- 停止服务: systemctl stop jenkins"
        echo "- 查看日志: journalctl -u jenkins -f"
    fi
    echo
    echo -e "${CYAN}初始配置:${NC}"
    if [[ "$SKIP_SETUP_WIZARD" = false ]]; then
        echo "1. 访问Jenkins Web界面"
        echo "2. 输入初始管理员密码"
        echo "3. 安装推荐的插件"
        echo "4. 创建第一个管理员用户"
    else
        echo "- 设置向导已跳过"
        echo "- 使用配置的管理员账号登录"
    fi
    
    if [[ "$INSTALL_PLUGINS" = true ]]; then
        echo
        echo -e "${CYAN}已安装插件:${NC}"
        echo "- Git, GitHub, GitLab"
        echo "- Pipeline, Blue Ocean"
        echo "- Docker, Kubernetes"
        echo "- 更多插件请查看插件管理页面"
    fi
    
    if [[ "$INSTALL_TOOLS" = true ]]; then
        echo
        echo -e "${CYAN}构建工具:${NC}"
        echo "- Maven: /opt/maven/bin/mvn"
        echo "- Gradle: /opt/gradle/bin/gradle"
        echo "- Node.js: $(which node)"
    fi
    
    echo
    echo -e "${CYAN}常用操作:${NC}"
    echo "1. 创建任务: 新建任务 > 选择类型 > 配置"
    echo "2. 配置凭据: 凭据 > 系统 > 全局凭据"
    echo "3. 管理插件: 系统管理 > 插件管理"
    echo "4. 系统配置: 系统管理 > 系统配置"
    echo "5. 查看日志: 系统管理 > 系统日志"
    
    echo
    echo -e "${CYAN}Pipeline示例:${NC}"
    echo "已创建示例Pipeline任务: sample-pipeline"
    echo
    cat << 'EOF'
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'echo "Building..."'
            }
        }
        stage('Test') {
            steps {
                sh 'echo "Testing..."'
            }
        }
        stage('Deploy') {
            steps {
                sh 'echo "Deploying..."'
            }
        }
    }
}
EOF
    
    echo
    echo -e "${YELLOW}安全建议:${NC}"
    echo "1. 定期更新Jenkins和插件"
    echo "2. 使用强密码和适当的权限控制"
    echo "3. 启用HTTPS加密传输"
    echo "4. 定期备份Jenkins配置"
    echo "5. 监控系统资源使用"
    
    if [[ "$BACKUP_SCHEDULE" = true ]]; then
        echo
        echo -e "${YELLOW}备份信息:${NC}"
        echo "- 自动备份: 每天凌晨2点"
        echo "- 备份目录: ${BACKUP_DIR}"
        echo "- 手动备份: /usr/local/bin/jenkins_backup.sh"
    fi
    
    echo
    echo -e "${YELLOW}日志文件: ${LOG_FILE}${NC}"
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-type)
                INSTALL_TYPE="$2"
                shift 2
                ;;
            --version)
                JENKINS_VERSION="$2"
                shift 2
                ;;
            --port)
                HTTP_PORT="$2"
                shift 2
                ;;
            --prefix)
                URL_PREFIX="$2"
                shift 2
                ;;
            --java-version)
                JAVA_VERSION="$2"
                shift 2
                ;;
            --install-plugins)
                INSTALL_PLUGINS=true
                shift
                ;;
            --plugin-list)
                PLUGIN_LIST="$2"
                shift 2
                ;;
            --skip-setup-wizard)
                SKIP_SETUP_WIZARD=true
                shift
                ;;
            --admin-user)
                ADMIN_USER="$2"
                shift 2
                ;;
            --admin-password)
                ADMIN_PASSWORD="$2"
                shift 2
                ;;
            --enable-security)
                ENABLE_SECURITY=true
                shift
                ;;
            --install-tools)
                INSTALL_TOOLS=true
                shift
                ;;
            --docker-group)
                DOCKER_GROUP=true
                shift
                ;;
            --nginx-proxy)
                NGINX_PROXY=true
                shift
                ;;
            --backup-schedule)
                BACKUP_SCHEDULE=true
                shift
                ;;
            --china-mirror)
                USE_CHINA_MIRROR=true
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
    check_jenkins_installed
    
    # 安装Java
    install_java
    
    # 创建Jenkins用户
    create_jenkins_user
    
    # 根据类型安装Jenkins
    case $INSTALL_TYPE in
        package)
            install_package
            ;;
        war)
            install_war
            ;;
        docker)
            install_docker
            ;;
        *)
            log "${RED}错误: 无效的安装类型 ${INSTALL_TYPE}${NC}"
            exit 1
            ;;
    esac
    
    # 配置Jenkins
    if [[ "$INSTALL_TYPE" != "docker" ]]; then
        configure_jenkins
        
        # 创建管理员用户
        if [[ "$SKIP_SETUP_WIZARD" = true ]] || [[ -n "$ADMIN_PASSWORD" ]]; then
            create_admin_user
        fi
        
        # 配置安全
        configure_security
        
        # 准备插件安装
        install_plugins
    fi
    
    # 安装构建工具
    install_build_tools
    
    # 配置Docker权限
    configure_docker_group
    
    # 启动服务
    start_jenkins_service
    
    # 获取初始密码
    get_initial_password
    
    # 配置Nginx
    configure_nginx_proxy
    
    # 配置备份
    configure_backup
    
    # 创建示例任务
    if [[ "$INSTALL_TYPE" != "docker" ]]; then
        create_sample_job
    fi
    
    # 保存配置信息
    save_config_info
    
    # 验证安装
    verify_installation
    
    # 显示安装后信息
    show_post_install_info
}

# 执行主函数
main "$@"