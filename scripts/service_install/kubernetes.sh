#!/bin/bash
#==============================================================================
# 脚本名称: kubernetes.sh
# 脚本描述: Kubernetes 容器编排平台安装脚本 - 支持单节点和集群部署
# 脚本路径: vps_scripts/scripts/service_install/kubernetes.sh
# 作者: Jensfrank
# 使用方法: bash kubernetes.sh [选项]
# 选项说明:
#   --version <版本>      Kubernetes版本 (如: 1.28.4, 1.27.8)
#   --mode <模式>         部署模式 (single/master/worker)
#   --master-ip <IP>      主节点IP地址 (worker模式必需)
#   --pod-network <网络>  Pod网络插件 (calico/flannel/weave)
#   --container-runtime   容器运行时 (docker/containerd/cri-o)
#   --api-server-port     API服务器端口 (默认: 6443)
#   --service-cidr        Service网络CIDR (默认: 10.96.0.0/12)
#   --pod-cidr           Pod网络CIDR (默认: 10.244.0.0/16)
#   --china-mirror       使用中国镜像源
#   --install-dashboard  安装Kubernetes Dashboard
#   --install-ingress    安装Ingress Controller
#   --install-metrics    安装Metrics Server
#   --install-helm       安装Helm包管理器
#   --force              强制重新安装
#   --help               显示帮助信息
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
K8S_VERSION=""
DEPLOY_MODE="single"
MASTER_IP=""
POD_NETWORK="calico"
CONTAINER_RUNTIME="containerd"
API_SERVER_PORT="6443"
SERVICE_CIDR="10.96.0.0/12"
POD_CIDR="10.244.0.0/16"
USE_CHINA_MIRROR=false
INSTALL_DASHBOARD=false
INSTALL_INGRESS=false
INSTALL_METRICS=false
INSTALL_HELM=false
FORCE_INSTALL=false
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/kubernetes_install_$(date +%Y%m%d_%H%M%S).log"

# 默认配置
DEFAULT_K8S_VERSION="1.28.4"
KUBECONFIG="/etc/kubernetes/admin.conf"
JOIN_TOKEN=""
JOIN_COMMAND_FILE="/root/kubeadm_join_command.sh"

# 记录日志
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}  Kubernetes 安装配置脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash kubernetes.sh [选项]"
    echo
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --version <版本>      Kubernetes版本 (如: 1.28.4, 1.27.8)"
    echo "  --mode <模式>         部署模式:"
    echo "                        single - 单节点集群 (默认)"
    echo "                        master - 主节点"
    echo "                        worker - 工作节点"
    echo "  --master-ip <IP>      主节点IP地址 (worker模式必需)"
    echo "  --pod-network <网络>  Pod网络插件:"
    echo "                        calico  - Calico网络 (推荐)"
    echo "                        flannel - Flannel网络"
    echo "                        weave   - Weave网络"
    echo "  --container-runtime   容器运行时:"
    echo "                        docker     - Docker CE"
    echo "                        containerd - Containerd (默认)"
    echo "                        cri-o      - CRI-O"
    echo "  --api-server-port     API服务器端口"
    echo "  --service-cidr        Service网络CIDR"
    echo "  --pod-cidr           Pod网络CIDR"
    echo "  --china-mirror       使用中国镜像源"
    echo "  --install-dashboard  安装Kubernetes Dashboard"
    echo "  --install-ingress    安装Nginx Ingress Controller"
    echo "  --install-metrics    安装Metrics Server"
    echo "  --install-helm       安装Helm 3"
    echo "  --force              强制重新安装"
    echo "  --help               显示此帮助信息"
    echo
    echo -e "${GREEN}示例:${NC}"
    echo "  bash kubernetes.sh                                      # 单节点集群"
    echo "  bash kubernetes.sh --mode master --pod-network calico"
    echo "  bash kubernetes.sh --mode worker --master-ip 192.168.1.100"
    echo "  bash kubernetes.sh --china-mirror --install-dashboard --install-helm"
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
    else
        log "${RED}错误: 无法检测系统类型${NC}"
        exit 1
    fi
    
    # 检查系统兼容性
    case $OS in
        ubuntu)
            if [[ "$VER" != "20.04" ]] && [[ "$VER" != "22.04" ]]; then
                log "${YELLOW}警告: 推荐使用 Ubuntu 20.04 或 22.04${NC}"
            fi
            ;;
        debian)
            if [[ "$VER_MAJOR" -lt 10 ]]; then
                log "${RED}错误: 需要 Debian 10 或更高版本${NC}"
                exit 1
            fi
            ;;
        centos|rhel|rocky|almalinux)
            if [[ "$VER_MAJOR" -lt 7 ]]; then
                log "${RED}错误: 需要 CentOS/RHEL 7 或更高版本${NC}"
                exit 1
            fi
            ;;
        *)
            log "${RED}错误: 不支持的系统类型 ${OS}${NC}"
            exit 1
            ;;
    esac
    
    # 检测系统架构
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" ]] && [[ "$ARCH" != "aarch64" ]]; then
        log "${RED}错误: 仅支持 x86_64 和 aarch64 架构${NC}"
        exit 1
    fi
    
    log "${GREEN}检测到系统: ${OS} ${VER} (${ARCH})${NC}"
}

# 检查系统要求
check_system_requirements() {
    log "${CYAN}检查系统要求...${NC}"
    
    # 检查CPU
    CPU_CORES=$(nproc)
    if [[ $CPU_CORES -lt 2 ]]; then
        log "${RED}错误: 至少需要2个CPU核心${NC}"
        exit 1
    fi
    
    # 检查内存
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $TOTAL_MEM -lt 2048 ]]; then
        log "${RED}错误: 至少需要2GB内存${NC}"
        exit 1
    fi
    
    # 检查磁盘空间
    DISK_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $DISK_SPACE -lt 20 ]]; then
        log "${YELLOW}警告: 建议至少20GB可用磁盘空间${NC}"
    fi
    
    log "${GREEN}系统要求检查通过${NC}"
}

# 配置系统参数
configure_system() {
    log "${CYAN}配置系统参数...${NC}"
    
    # 关闭防火墙
    case $OS in
        ubuntu|debian)
            systemctl stop ufw 2>/dev/null || true
            systemctl disable ufw 2>/dev/null || true
            ;;
        centos|rhel|rocky|almalinux)
            systemctl stop firewalld 2>/dev/null || true
            systemctl disable firewalld 2>/dev/null || true
            ;;
    esac
    
    # 关闭SELinux
    if command -v getenforce &> /dev/null; then
        setenforce 0 2>/dev/null || true
        sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true
    fi
    
    # 关闭swap
    swapoff -a
    sed -i '/swap/d' /etc/fstab
    
    # 配置内核参数
    cat > /etc/sysctl.d/99-kubernetes.conf << EOF
# Kubernetes系统参数优化
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_max_tw_buckets = 36000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_orphans = 327680
net.ipv4.tcp_orphan_retries = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_timestamps = 0
net.core.somaxconn = 16384
vm.overcommit_memory = 1
vm.panic_on_oom = 0
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288
fs.file-max = 52706963
fs.nr_open = 52706963
EOF
    
    # 加载内核模块
    modprobe overlay
    modprobe br_netfilter
    
    # 持久化内核模块
    cat > /etc/modules-load.d/kubernetes.conf << EOF
overlay
br_netfilter
EOF
    
    # 应用系统参数
    sysctl -p /etc/sysctl.d/99-kubernetes.conf
    
    log "${GREEN}系统参数配置完成${NC}"
}

# 配置主机名和hosts
configure_hosts() {
    log "${CYAN}配置主机名和hosts文件...${NC}"
    
    # 获取主机IP
    HOST_IP=$(hostname -I | awk '{print $1}')
    
    # 设置主机名
    if [[ "$DEPLOY_MODE" == "master" ]] || [[ "$DEPLOY_MODE" == "single" ]]; then
        hostnamectl set-hostname k8s-master
    else
        hostnamectl set-hostname k8s-worker-$(date +%s | tail -c 5)
    fi
    
    # 更新hosts文件
    sed -i '/k8s-/d' /etc/hosts
    echo "${HOST_IP} $(hostname)" >> /etc/hosts
    
    if [[ -n "$MASTER_IP" ]] && [[ "$DEPLOY_MODE" == "worker" ]]; then
        echo "${MASTER_IP} k8s-master" >> /etc/hosts
    fi
}

# 安装容器运行时
install_container_runtime() {
    log "${CYAN}安装容器运行时: ${CONTAINER_RUNTIME}...${NC}"
    
    case $CONTAINER_RUNTIME in
        docker)
            install_docker
            ;;
        containerd)
            install_containerd
            ;;
        cri-o)
            install_crio
            ;;
        *)
            log "${RED}错误: 不支持的容器运行时 ${CONTAINER_RUNTIME}${NC}"
            exit 1
            ;;
    esac
}

# 安装Docker
install_docker() {
    log "${CYAN}安装Docker CE...${NC}"
    
    # 安装依赖
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
            
            # 添加Docker仓库
            if [[ "$USE_CHINA_MIRROR" = true ]]; then
                curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | apt-key add -
                add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
            else
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
                add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
            fi
            
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y yum-utils
            
            if [[ "$USE_CHINA_MIRROR" = true ]]; then
                yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
            else
                yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            fi
            
            yum install -y docker-ce docker-ce-cli containerd.io
            ;;
    esac
    
    # 配置Docker
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "registry-mirrors": [$(if [[ "$USE_CHINA_MIRROR" = true ]]; then echo '"https://registry.docker-cn.com"'; fi)]
}
EOF
    
    # 创建docker服务目录
    mkdir -p /etc/systemd/system/docker.service.d
    
    # 重启Docker
    systemctl daemon-reload
    systemctl enable docker
    systemctl restart docker
}

# 安装Containerd
install_containerd() {
    log "${CYAN}安装Containerd...${NC}"
    
    # 安装containerd
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y containerd
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y containerd.io
            ;;
    esac
    
    # 生成默认配置
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    
    # 配置systemd cgroup驱动
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
    
    # 配置镜像加速
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        sed -i 's#registry.k8s.io#registry.aliyuncs.com/google_containers#g' /etc/containerd/config.toml
    fi
    
    # 重启containerd
    systemctl daemon-reload
    systemctl enable containerd
    systemctl restart containerd
}

# 安装CRI-O
install_crio() {
    log "${CYAN}安装CRI-O...${NC}"
    
    # 确定CRI-O版本（与K8s版本匹配）
    CRIO_VERSION=$(echo $K8S_VERSION | cut -d. -f1,2)
    
    case $OS in
        ubuntu|debian)
            # 添加CRI-O仓库
            echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_$(lsb_release -rs)/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
            echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/xUbuntu_$(lsb_release -rs)/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.list
            
            curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_$(lsb_release -rs)/Release.key | apt-key add -
            curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/xUbuntu_$(lsb_release -rs)/Release.key | apt-key add -
            
            apt-get update
            apt-get install -y cri-o cri-o-runc
            ;;
        centos|rhel|rocky|almalinux)
            # 添加CRI-O仓库
            curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/CentOS_${VER_MAJOR}/devel:kubic:libcontainers:stable.repo
            curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION/CentOS_${VER_MAJOR}/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.repo
            
            yum install -y cri-o
            ;;
    esac
    
    # 启动CRI-O
    systemctl daemon-reload
    systemctl enable crio
    systemctl start crio
}

# 安装Kubernetes组件
install_kubernetes() {
    log "${CYAN}安装Kubernetes组件...${NC}"
    
    # 确定版本
    if [[ -z "$K8S_VERSION" ]]; then
        K8S_VERSION="$DEFAULT_K8S_VERSION"
    fi
    
    case $OS in
        ubuntu|debian)
            # 添加Kubernetes仓库
            if [[ "$USE_CHINA_MIRROR" = true ]]; then
                curl -s https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
                cat > /etc/apt/sources.list.d/kubernetes.list << EOF
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
            else
                curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
                cat > /etc/apt/sources.list.d/kubernetes.list << EOF
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
            fi
            
            apt-get update
            apt-get install -y kubelet=${K8S_VERSION}-00 kubeadm=${K8S_VERSION}-00 kubectl=${K8S_VERSION}-00
            apt-mark hold kubelet kubeadm kubectl
            ;;
        centos|rhel|rocky|almalinux)
            # 添加Kubernetes仓库
            if [[ "$USE_CHINA_MIRROR" = true ]]; then
                cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
EOF
            else
                cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
            fi
            
            yum install -y kubelet-${K8S_VERSION} kubeadm-${K8S_VERSION} kubectl-${K8S_VERSION}
            ;;
    esac
    
    # 配置kubelet
    if [[ "$CONTAINER_RUNTIME" == "docker" ]]; then
        cat > /etc/sysconfig/kubelet << EOF
KUBELET_EXTRA_ARGS=--cgroup-driver=systemd
EOF
    fi
    
    # 启用kubelet
    systemctl enable kubelet
    
    log "${GREEN}Kubernetes组件安装完成${NC}"
}

# 初始化主节点
init_master() {
    log "${CYAN}初始化Kubernetes主节点...${NC}"
    
    # 生成kubeadm配置文件
    cat > /tmp/kubeadm-config.yaml << EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $(hostname -I | awk '{print $1}')
  bindPort: $API_SERVER_PORT
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v${K8S_VERSION}
networking:
  serviceSubnet: $SERVICE_CIDR
  podSubnet: $POD_CIDR
controllerManager:
  extraArgs:
    bind-address: 0.0.0.0
scheduler:
  extraArgs:
    bind-address: 0.0.0.0
EOF

    # 如果使用中国镜像
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        cat >> /tmp/kubeadm-config.yaml << EOF
imageRepository: registry.aliyuncs.com/google_containers
EOF
    fi
    
    # 初始化集群
    kubeadm init --config=/tmp/kubeadm-config.yaml | tee /tmp/kubeadm_init.log
    
    # 检查初始化结果
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        log "${RED}错误: Kubernetes集群初始化失败${NC}"
        exit 1
    fi
    
    # 配置kubectl
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    
    # 对于单节点集群，允许在主节点调度Pod
    if [[ "$DEPLOY_MODE" == "single" ]]; then
        kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true
        kubectl taint nodes --all node-role.kubernetes.io/master- 2>/dev/null || true
    fi
    
    # 保存join命令
    grep -A 2 "kubeadm join" /tmp/kubeadm_init.log > "$JOIN_COMMAND_FILE"
    chmod 600 "$JOIN_COMMAND_FILE"
    
    log "${GREEN}Kubernetes主节点初始化完成${NC}"
}

# 加入工作节点
join_worker() {
    log "${CYAN}将节点加入Kubernetes集群...${NC}"
    
    if [[ -z "$MASTER_IP" ]]; then
        log "${RED}错误: 未指定主节点IP地址${NC}"
        exit 1
    fi
    
    # 获取join命令
    log "${YELLOW}请在主节点执行以下命令获取join命令:${NC}"
    log "${YELLOW}kubeadm token create --print-join-command${NC}"
    echo
    read -p "请输入完整的join命令: " JOIN_CMD
    
    # 执行join命令
    eval "$JOIN_CMD"
    
    if [[ $? -eq 0 ]]; then
        log "${GREEN}节点成功加入集群${NC}"
    else
        log "${RED}错误: 节点加入集群失败${NC}"
        exit 1
    fi
}

# 安装Pod网络插件
install_pod_network() {
    log "${CYAN}安装Pod网络插件: ${POD_NETWORK}...${NC}"
    
    case $POD_NETWORK in
        calico)
            if [[ "$USE_CHINA_MIRROR" = true ]]; then
                # 使用国内镜像
                curl -O https://docs.projectcalico.org/manifests/calico.yaml
                sed -i 's#docker.io/calico/#registry.cn-beijing.aliyuncs.com/calico/#g' calico.yaml
                kubectl apply -f calico.yaml
                rm -f calico.yaml
            else
                kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
            fi
            ;;
        flannel)
            kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
            ;;
        weave)
            kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
            ;;
        *)
            log "${RED}错误: 不支持的网络插件 ${POD_NETWORK}${NC}"
            exit 1
            ;;
    esac
    
    log "${GREEN}Pod网络插件安装完成${NC}"
}

# 安装Dashboard
install_dashboard() {
    if [[ "$INSTALL_DASHBOARD" != true ]]; then
        return
    fi
    
    log "${CYAN}安装Kubernetes Dashboard...${NC}"
    
    # 部署Dashboard
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
    
    # 创建管理员用户
    cat > /tmp/dashboard-admin.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
    
    kubectl apply -f /tmp/dashboard-admin.yaml
    
    # 修改Service类型为NodePort
    kubectl patch svc kubernetes-dashboard -n kubernetes-dashboard -p '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8443,"nodePort":30443}]}}'
    
    # 获取token
    DASHBOARD_TOKEN=$(kubectl -n kubernetes-dashboard create token admin-user)
    
    # 保存访问信息
    cat > /root/kubernetes_dashboard_info.txt << EOF
Kubernetes Dashboard 访问信息
=============================

访问地址: https://$(hostname -I | awk '{print $1}'):30443
用户名: admin-user
Token: ${DASHBOARD_TOKEN}

注意: 使用Chrome浏览器访问时可能需要输入 thisisunsafe 来绕过证书警告
EOF
    
    chmod 600 /root/kubernetes_dashboard_info.txt
    
    log "${GREEN}Dashboard安装完成，访问信息已保存到: /root/kubernetes_dashboard_info.txt${NC}"
}

# 安装Ingress Controller
install_ingress() {
    if [[ "$INSTALL_INGRESS" != true ]]; then
        return
    fi
    
    log "${CYAN}安装Nginx Ingress Controller...${NC}"
    
    # 部署Nginx Ingress
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/baremetal/deploy.yaml
    
    # 修改Service类型为NodePort
    kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":80,"targetPort":80,"nodePort":30080},{"name":"https","port":443,"targetPort":443,"nodePort":30443}]}}'
    
    log "${GREEN}Ingress Controller安装完成${NC}"
    log "${YELLOW}HTTP端口: 30080, HTTPS端口: 30443${NC}"
}

# 安装Metrics Server
install_metrics() {
    if [[ "$INSTALL_METRICS" != true ]]; then
        return
    fi
    
    log "${CYAN}安装Metrics Server...${NC}"
    
    # 下载并修改配置
    wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml -O /tmp/metrics-server.yaml
    
    # 添加启动参数以支持自签名证书
    sed -i '/args:/a\        - --kubelet-insecure-tls' /tmp/metrics-server.yaml
    
    # 如果使用中国镜像
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        sed -i 's#registry.k8s.io/metrics-server/#registry.cn-hangzhou.aliyuncs.com/google_containers/#g' /tmp/metrics-server.yaml
    fi
    
    kubectl apply -f /tmp/metrics-server.yaml
    
    log "${GREEN}Metrics Server安装完成${NC}"
}

# 安装Helm
install_helm() {
    if [[ "$INSTALL_HELM" != true ]]; then
        return
    fi
    
    log "${CYAN}安装Helm 3...${NC}"
    
    # 下载安装脚本
    curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 /tmp/get_helm.sh
    
    # 安装Helm
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        export HELM_INSTALL_DIR=/usr/local/bin
        /tmp/get_helm.sh
    else
        /tmp/get_helm.sh
    fi
    
    # 添加常用仓库
    helm repo add stable https://charts.helm.sh/stable
    helm repo add bitnami https://charts.bitnami.com/bitnami
    
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        helm repo add azure http://mirror.azure.cn/kubernetes/charts/
    fi
    
    helm repo update
    
    log "${GREEN}Helm 3安装完成${NC}"
}

# 配置kubectl自动补全
configure_kubectl_completion() {
    log "${CYAN}配置kubectl自动补全...${NC}"
    
    # 安装bash-completion
    case $OS in
        ubuntu|debian)
            apt-get install -y bash-completion
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y bash-completion
            ;;
    esac
    
    # 配置kubectl自动补全
    kubectl completion bash > /etc/bash_completion.d/kubectl
    
    # 配置别名
    cat >> ~/.bashrc << 'EOF'

# Kubernetes别名
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployment'
alias kgn='kubectl get nodes'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'
alias klog='kubectl logs'
alias kexec='kubectl exec -it'
complete -F __start_kubectl k
EOF
    
    log "${GREEN}kubectl自动补全配置完成${NC}"
}

# 创建测试应用
create_test_app() {
    log "${CYAN}创建测试应用...${NC}"
    
    # 创建测试命名空间
    kubectl create namespace test-app 2>/dev/null || true
    
    # 部署nginx测试应用
    cat > /tmp/test-app.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  namespace: test-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-test
  namespace: test-app
spec:
  type: NodePort
  selector:
    app: nginx-test
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30088
EOF
    
    kubectl apply -f /tmp/test-app.yaml
    
    log "${GREEN}测试应用创建完成${NC}"
    log "${YELLOW}访问地址: http://$(hostname -I | awk '{print $1}'):30088${NC}"
}

# 验证安装
verify_installation() {
    log "${CYAN}验证Kubernetes安装...${NC}"
    
    # 检查节点状态
    log "${CYAN}节点状态:${NC}"
    kubectl get nodes -o wide
    
    # 检查系统Pod
    log "${CYAN}系统Pod状态:${NC}"
    kubectl get pods -n kube-system
    
    # 检查版本信息
    log "${CYAN}版本信息:${NC}"
    kubectl version --short
    
    # 检查集群信息
    log "${CYAN}集群信息:${NC}"
    kubectl cluster-info
    
    # 如果安装了Dashboard
    if [[ "$INSTALL_DASHBOARD" = true ]]; then
        log "${CYAN}Dashboard状态:${NC}"
        kubectl get pods -n kubernetes-dashboard
    fi
    
    # 如果安装了Metrics
    if [[ "$INSTALL_METRICS" = true ]]; then
        sleep 30  # 等待metrics server启动
        log "${CYAN}节点资源使用:${NC}"
        kubectl top nodes 2>/dev/null || log "${YELLOW}Metrics Server正在启动...${NC}"
    fi
}

# 显示安装后说明
show_post_install_info() {
    echo
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${GREEN}Kubernetes安装配置完成!${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
    echo -e "${CYAN}安装信息:${NC}"
    echo "- Kubernetes版本: ${K8S_VERSION}"
    echo "- 部署模式: ${DEPLOY_MODE}"
    echo "- 容器运行时: ${CONTAINER_RUNTIME}"
    echo "- Pod网络插件: ${POD_NETWORK}"
    echo "- Service CIDR: ${SERVICE_CIDR}"
    echo "- Pod CIDR: ${POD_CIDR}"
    echo "- API Server: https://$(hostname -I | awk '{print $1}'):${API_SERVER_PORT}"
    
    echo
    echo -e "${CYAN}kubectl配置:${NC}"
    echo "- 配置文件: $HOME/.kube/config"
    echo "- 已配置命令别名和自动补全"
    
    if [[ "$DEPLOY_MODE" == "master" ]] || [[ "$DEPLOY_MODE" == "single" ]]; then
        echo
        echo -e "${CYAN}添加工作节点:${NC}"
        echo "1. 在工作节点运行本脚本: bash kubernetes.sh --mode worker --master-ip $(hostname -I | awk '{print $1}')"
        echo "2. 或在主节点执行: kubeadm token create --print-join-command"
        echo "3. Join命令已保存到: $JOIN_COMMAND_FILE"
    fi
    
    if [[ "$INSTALL_DASHBOARD" = true ]]; then
        echo
        echo -e "${CYAN}Dashboard访问:${NC}"
        echo "- 地址: https://$(hostname -I | awk '{print $1}'):30443"
        echo "- 详细信息: /root/kubernetes_dashboard_info.txt"
    fi
    
    if [[ "$INSTALL_INGRESS" = true ]]; then
        echo
        echo -e "${CYAN}Ingress Controller:${NC}"
        echo "- HTTP: $(hostname -I | awk '{print $1}'):30080"
        echo "- HTTPS: $(hostname -I | awk '{print $1}'):30443"
    fi
    
    if [[ "$INSTALL_HELM" = true ]]; then
        echo
        echo -e "${CYAN}Helm使用:${NC}"
        echo "- 搜索Chart: helm search repo <name>"
        echo "- 安装Chart: helm install <n> <chart>"
        echo "- 查看发布: helm list"
    fi
    
    echo
    echo -e "${CYAN}常用命令:${NC}"
    echo "- 查看所有Pod: kubectl get pods --all-namespaces"
    echo "- 查看日志: kubectl logs <pod-name>"
    echo "- 进入容器: kubectl exec -it <pod-name> -- /bin/sh"
    echo "- 端口转发: kubectl port-forward <pod-name> 8080:80"
    echo "- 创建部署: kubectl create deployment <n> --image=<image>"
    echo "- 暴露服务: kubectl expose deployment <n> --port=80 --type=NodePort"
    echo "- 扩容: kubectl scale deployment <n> --replicas=3"
    
    echo
    echo -e "${CYAN}故障排查:${NC}"
    echo "- 查看事件: kubectl get events --sort-by=.metadata.creationTimestamp"
    echo "- 查看Pod详情: kubectl describe pod <pod-name>"
    echo "- 查看日志: journalctl -u kubelet -f"
    echo "- 检查网络: kubectl run test --image=busybox --rm -it -- /bin/sh"
    
    echo
    echo -e "${YELLOW}测试应用:${NC}"
    echo "- 访问地址: http://$(hostname -I | awk '{print $1}'):30088"
    echo "- 命名空间: test-app"
    
    echo
    echo -e "${YELLOW}重要提示:${NC}"
    echo "1. 请妥善保管 /etc/kubernetes/admin.conf 文件"
    echo "2. 定期备份etcd数据"
    echo "3. 生产环境建议使用多主节点高可用部署"
    echo "4. 定期更新Kubernetes版本和安全补丁"
    
    echo
    echo -e "${YELLOW}日志文件: ${LOG_FILE}${NC}"
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                K8S_VERSION="$2"
                shift 2
                ;;
            --mode)
                DEPLOY_MODE="$2"
                shift 2
                ;;
            --master-ip)
                MASTER_IP="$2"
                shift 2
                ;;
            --pod-network)
                POD_NETWORK="$2"
                shift 2
                ;;
            --container-runtime)
                CONTAINER_RUNTIME="$2"
                shift 2
                ;;
            --api-server-port)
                API_SERVER_PORT="$2"
                shift 2
                ;;
            --service-cidr)
                SERVICE_CIDR="$2"
                shift 2
                ;;
            --pod-cidr)
                POD_CIDR="$2"
                shift 2
                ;;
            --china-mirror)
                USE_CHINA_MIRROR=true
                shift
                ;;
            --install-dashboard)
                INSTALL_DASHBOARD=true
                shift
                ;;
            --install-ingress)
                INSTALL_INGRESS=true
                shift
                ;;
            --install-metrics)
                INSTALL_METRICS=true
                shift
                ;;
            --install-helm)
                INSTALL_HELM=true
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
    
    # 验证参数
    if [[ "$DEPLOY_MODE" == "worker" ]] && [[ -z "$MASTER_IP" ]]; then
        log "${RED}错误: worker模式需要指定 --master-ip${NC}"
        exit 1
    fi
    
    # 显示标题
    show_title
    
    # 检查root权限
    check_root
    
    # 检测系统
    detect_system
    
    # 检查系统要求
    check_system_requirements
    
    # 配置系统参数
    configure_system
    
    # 配置主机名和hosts
    configure_hosts
    
    # 安装容器运行时
    install_container_runtime
    
    # 安装Kubernetes
    install_kubernetes
    
    # 根据模式进行配置
    case $DEPLOY_MODE in
        single|master)
            init_master
            install_pod_network
            install_dashboard
            install_ingress
            install_metrics
            install_helm
            configure_kubectl_completion
            create_test_app
            ;;
        worker)
            join_worker
            ;;
    esac
    
    # 验证安装
    if [[ "$DEPLOY_MODE" != "worker" ]]; then
        sleep 30  # 等待系统稳定
        verify_installation
    fi
    
    # 显示安装后信息
    show_post_install_info
}

# 执行主函数
main "$@"