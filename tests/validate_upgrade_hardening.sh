#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
LAUNCHER="${LAUNCHER_OVERRIDE:-${REPO_ROOT}/vps.sh}"
NEZHA_SCRIPT="${REPO_ROOT}/scripts/other_tools/nezha.sh"
LDNMP_SCRIPT="${REPO_ROOT}/scripts/service_install/ldnmp.sh"
BANDWIDTH_SCRIPT="${REPO_ROOT}/scripts/network_test/bandwidth_test.sh"

for script in "${LAUNCHER}" "${NEZHA_SCRIPT}" "${LDNMP_SCRIPT}" "${BANDWIDTH_SCRIPT}"; do
    bash -n "${script}"
done

grep -Fq 'local -a script_args=("$@")' "${LAUNCHER}"
grep -Fq '(cd "${temp_root}" && bash "${temp_file}" "${script_args[@]}")' "${LAUNCHER}"
if grep -Eq 'run_remote_command "[^"\n]*(\|[[:space:]]*(bash|sh)|bash[[:space:]]+<\()' "${LAUNCHER}"; then
    echo "Launcher contains a remote shell pipeline or process substitution." >&2
    exit 1
fi

grep -Fq 'readonly RELEASE_BASE_URL="https://github.com/nezhahq/agent/releases/latest/download"' "${NEZHA_SCRIPT}"
grep -Fq '"${RELEASE_BASE_URL}/checksums.txt"' "${NEZHA_SCRIPT}"
grep -Fq 'sha256sum "${archive}"' "${NEZHA_SCRIPT}"
grep -Fq 'systemd-analyze verify "${SERVICE_FILE}"' "${NEZHA_SCRIPT}"
grep -Fq "unzip -Z1 \"\${archive}\" | grep -qx 'nezha-agent'" "${NEZHA_SCRIPT}"
grep -Fq 'chmod 600 -- "${CONFIG_FILE}"' "${NEZHA_SCRIPT}"
if grep -Eq 'naiba/nezha|ExecStart=.*-p ' "${NEZHA_SCRIPT}"; then
    echo "Nezha installer still uses the retired release or passes the secret on the command line." >&2
    exit 1
fi
grep -Fq 'run_remote_bash_installer()' "${LDNMP_SCRIPT}"
grep -Fq 'signed-by=/usr/share/keyrings/nginx-signing.gpg' "${LDNMP_SCRIPT}"
grep -Fq 'signed-by=/usr/share/keyrings/sury-php.gpg' "${LDNMP_SCRIPT}"
if grep -Eq 'curl[^\n]*\|[[:space:]]*(bash|sh)|apt-key' "${LDNMP_SCRIPT}"; then
    echo "LDNMP installer retains an unsafe remote shell pipeline or apt-key." >&2
    exit 1
fi

FRP_SCRIPT="${REPO_ROOT}/scripts/other_tools/frp.sh"
bash -n "${FRP_SCRIPT}"
grep -Fq 'readonly RELEASE_REPO_URL="https://github.com/fatedier/frp"' "${FRP_SCRIPT}"
grep -Fq 'frp_sha256_checksums.txt' "${FRP_SCRIPT}"
grep -Fq 'sha256sum "${WORK_DIR}/${asset}"' "${FRP_SCRIPT}"
grep -Fq 'auth.method = "token"' "${FRP_SCRIPT}"
grep -Fq 'run_repo_script "scripts/other_tools/frp.sh"' "${LAUNCHER}"

GO_SCRIPT="${REPO_ROOT}/scripts/service_install/go.sh"
NODE_SCRIPT="${REPO_ROOT}/scripts/service_install/nodejs.sh"
grep -Fq 'https://dl.google.com/go/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz.sha256' "${GO_SCRIPT}"
grep -Fq 'https://nodejs.org/dist/${FULL_VERSION}/SHASUMS256.txt' "${NODE_SCRIPT}"
grep -Fq 'work_dir=$(mktemp -d "/tmp/nodejs-install.XXXXXX")' "${NODE_SCRIPT}"
if grep -Fq 'funnyzak/frpc' "${LAUNCHER}"; then
    echo "Launcher still points FRP at the retired third-party installer." >&2
    exit 1
fi
grep -Fq 'DOCKER_REQUIRED_CHECK="command -v docker' "${LAUNCHER}"
while IFS= read -r docker_line; do
    if [[ ${docker_line} != *'${DOCKER_REQUIRED_CHECK}'* ]]; then
        echo "Docker-based launcher entry lacks the Docker presence check: ${docker_line}" >&2
        exit 1
    fi
done < <(grep -E 'run_remote_command ".*docker (run|volume|compose)' "${LAUNCHER}")
if grep -Fq 'louislam/uptime-kuma:1' "${LAUNCHER}"; then
    echo "Uptime Kuma entry still pins the previous major version." >&2
    exit 1
fi
for stale_proxy_url in 'gitlab.com/rwkgyg/x-ui-yg' 'xeefei/3x-ui/'; do
    if grep -Fq "${stale_proxy_url}" "${LAUNCHER}"; then
        echo "Proxy menu still uses a superseded upstream URL: ${stale_proxy_url}" >&2
        exit 1
    fi
done
grep -Fq 'Xray-install/raw/main/install-release.sh" "Official Xray-core install" install' "${LAUNCHER}"

grep -Fq 'https://ipapi.co/json/' "${BANDWIDTH_SCRIPT}"
grep -Fq 'run_repo_setup_script()' "${BANDWIDTH_SCRIPT}"
grep -Fq 'ID必须为数字' "${BANDWIDTH_SCRIPT}"
if grep -Fq -- '--no-check-certificate' "${BANDWIDTH_SCRIPT}"; then
    echo "Bandwidth test disables TLS certificate verification." >&2
    exit 1
fi

# No first-party script may disable TLS verification for downloads.
# Match curl -k even when combined with other short flags (e.g. curl -ksSL).
tls_bypass=$(grep -rnE --include='*.sh' \
    -e '--no-check-certificate' \
    -e 'curl[^\n]*[[:space:]](-[A-Za-z0-9]*k[A-Za-z0-9]*|--insecure)([[:space:]=]|$)' \
    "${REPO_ROOT}/scripts" "${REPO_ROOT}/lib" "${LAUNCHER}" || true)
if [ -n "${tls_bypass}" ]; then
    echo "First-party scripts disable TLS certificate verification:" >&2
    echo "${tls_bypass}" >&2
    exit 1
fi

# Executable payloads (installers and source archives) must not be fetched ove
# plain HTTP. Include .war (Jenkins) and common package suffixes.
plain_http=$(grep -rnE 'http://[^"[:space:]]+\.(sh|tar\.gz|tgz|zip|war|rpm|deb)' \
    --include='*.sh' "${REPO_ROOT}/scripts" "${REPO_ROOT}/lib" "${LAUNCHER}" || true)
if [ -n "${plain_http}" ]; then
    echo "Executable payloads downloaded over plain HTTP:" >&2
    echo "${plain_http}" >&2
    exit 1
fi

REDIS_SCRIPT="${REPO_ROOT}/scripts/service_install/redis.sh"
grep -Fq 'redis/redis-hashes/master/README' "${REDIS_SCRIPT}"
grep -Fq 'Redis 源码归档 SHA-256 校验失败' "${REDIS_SCRIPT}"
grep -Fq 'https://dl.amh.sh/' "${REPO_ROOT}/scripts/service_install/amh.sh"
grep -Fq 'https://io.bt.sy/' "${REPO_ROOT}/scripts/service_install/btpanel.sh"
if grep -Eq 'http://(dl\.amh\.sh|io\.bt\.sy)/' \
    "${REPO_ROOT}/scripts/service_install/amh.sh" \
    "${REPO_ROOT}/scripts/service_install/btpanel.sh"; then
    echo "AMH/BT panel installers still use plain HTTP download URLs." >&2
    exit 1
fi

# aaPanel must not bypass TLS; Jenkins WAR and PostgreSQL apt use HTTPS.
grep -Fq 'curl -fsSL "$INSTALL_SCRIPT"' "${REPO_ROOT}/scripts/service_install/aapanel.sh"
if grep -Eq 'curl[[:space:]]+-[A-Za-z0-9]*k' "${REPO_ROOT}/scripts/service_install/aapanel.sh"; then
    echo "aaPanel installer still disables TLS verification." >&2
    exit 1
fi
for panel_script in 1panel.sh aapanel.sh amh.sh btpanel.sh cyberpanel.sh; do
    if ! grep -Eq 'bash -n ' "${REPO_ROOT}/scripts/service_install/${panel_script}"; then
        echo "Panel installer missing bash -n before remote script execution: ${panel_script}" >&2
        exit 1
    fi
done
grep -Fq 'henrygd/beszel/main/supplemental/scripts/install-agent.sh' "${LAUNCHER}"
grep -Fq 'get.beszel.dev/hub' "${LAUNCHER}"
grep -Fq 'print_menu_item 27 "CyberPanel" "小众控制面板"' "${LAUNCHER}"
grep -Fq 'bash -n "$rvm_script"' "${REPO_ROOT}/scripts/service_install/ruby.sh"
grep -Fq 'bash -n "$helm_installer"' "${REPO_ROOT}/scripts/service_install/kubernetes.sh"
grep -Fq 'bash -n "$wasm_pack_script"' "${REPO_ROOT}/scripts/service_install/rust.sh"
grep -Fq '7f454c46' "${REPO_ROOT}/scripts/service_install/ldnmp.sh"
grep -Fq 'https://get.jenkins.io/war-stable/' "${REPO_ROOT}/scripts/service_install/jenkins.sh"
grep -Fq 'checksum_url="${official_war_url}.sha256"' "${REPO_ROOT}/scripts/service_install/jenkins.sh"
grep -Fq 'Jenkins WAR SHA-256 校验失败' "${REPO_ROOT}/scripts/service_install/jenkins.sh"
grep -Fq 'jenkins.io-2023.key' "${REPO_ROOT}/scripts/service_install/jenkins.sh"
grep -Fq 'jenkins-keyring.gpg' "${REPO_ROOT}/scripts/service_install/jenkins.sh"
if grep -Eq 'http://mirrors\.jenkins\.io/' "${REPO_ROOT}/scripts/service_install/jenkins.sh"; then
    echo "Jenkins installer still downloads WAR over plain HTTP." >&2
    exit 1
fi
if grep -Eq 'wget -O "\$JENKINS_WAR"' "${REPO_ROOT}/scripts/service_install/jenkins.sh"; then
    echo "Jenkins installer still writes the WAR path before checksum verification." >&2
    exit 1
fi
if grep -Eq 'apt-key[[:space:]]+add' "${REPO_ROOT}/scripts/service_install/jenkins.sh"; then
    echo "Jenkins installer still uses deprecated apt-key add." >&2
    exit 1
fi
grep -Fq 'https://apt.postgresql.org/pub/repos/apt' "${REPO_ROOT}/scripts/service_install/postgresql.sh"
grep -Fq 'signed-by=' "${REPO_ROOT}/scripts/service_install/postgresql.sh"
grep -Fq 'postgresql-archive-keyring.gpg' "${REPO_ROOT}/scripts/service_install/postgresql.sh"
if grep -Eq 'apt-key[[:space:]]+add' "${REPO_ROOT}/scripts/service_install/postgresql.sh"; then
    echo "PostgreSQL installer still uses deprecated apt-key add." >&2
    exit 1
fi
grep -Fq 'nginx-signing.gpg' "${REPO_ROOT}/scripts/service_install/nginx.sh"
grep -Fq 'Nginx 源码 PGP 签名校验失败' "${REPO_ROOT}/scripts/service_install/nginx.sh"
grep -Fq 'wp-cli.phar.sha256' "${REPO_ROOT}/scripts/service_install/wordpress.sh"
grep -Fq 'WP-CLI SHA-256 校验失败' "${REPO_ROOT}/scripts/service_install/wordpress.sh"
if grep -Fq 'curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar' "${REPO_ROOT}/scripts/service_install/wordpress.sh"; then
    echo "WordPress installer still downloads WP-CLI without a checksum sidecar." >&2
    exit 1
fi
grep -Fq 'signed-by=%s' "${REPO_ROOT}/scripts/service_install/nginx.sh"
if grep -Eq 'apt-key[[:space:]]+add' "${REPO_ROOT}/scripts/service_install/nginx.sh"; then
    echo "Nginx installer still uses deprecated apt-key add." >&2
    exit 1
fi
grep -Fq 'mariadb-keyring.gpg' "${REPO_ROOT}/scripts/service_install/mysql.sh"
grep -Fq 'signed-by=%s' "${REPO_ROOT}/scripts/service_install/mysql.sh"
if grep -Eq 'apt-key[[:space:]]+add' "${REPO_ROOT}/scripts/service_install/mysql.sh"; then
    echo "MySQL/MariaDB installer still uses deprecated apt-key add." >&2
    exit 1
fi
grep -Fq 'https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:' \
    "${REPO_ROOT}/scripts/service_install/kubernetes.sh"
grep -Fq 'https://mirror.azure.cn/kubernetes/charts/' "${REPO_ROOT}/scripts/service_install/kubernetes.sh"
grep -Fq 'pkgs.k8s.io/core:/stable:/v' "${REPO_ROOT}/scripts/service_install/kubernetes.sh"
grep -Fq 'kubernetes-apt-keyring.gpg' "${REPO_ROOT}/scripts/service_install/kubernetes.sh"
if grep -Eq 'apt-key[[:space:]]+add' "${REPO_ROOT}/scripts/service_install/kubernetes.sh"; then
    echo "Kubernetes installer still uses deprecated apt-key add." >&2
    exit 1
fi
if grep -Fq 'kubernetes-xenial' "${REPO_ROOT}/scripts/service_install/kubernetes.sh"; then
    echo "Kubernetes installer still uses retired kubernetes-xenial apt repo." >&2
    exit 1
fi

# Ruby source installs verify against the official releases.yml digests.
grep -Fq 'ruby/www.ruby-lang.org/master/_data/releases.yml' \
    "${REPO_ROOT}/scripts/service_install/ruby.sh"
grep -Fq 'Ruby 源码归档 SHA-256 校验失败' "${REPO_ROOT}/scripts/service_install/ruby.sh"

# Python source installs verify against the official python.org downloads API.
PYTHON_SCRIPT="${REPO_ROOT}/scripts/service_install/python.sh"
grep -Fq 'api/v2/downloads/release/?name=Python%20' "${PYTHON_SCRIPT}"
grep -Fq 'verify_python_source_digest' "${PYTHON_SCRIPT}"
grep -Fq 'bash -n "${installer}"' "${PYTHON_SCRIPT}"
grep -Fq 'bash -n "${installer}"' "${REPO_ROOT}/scripts/service_install/nodejs.sh"
grep -Fq 'bash -n "$installer_file"' "${REPO_ROOT}/scripts/service_install/go.sh"

# Oracle JDK 17 / GraalVM community download URLs stay on live endpoints.
# Oracle 8/11 OTN soft-404s are refused in favor of openjdk.
JAVA_SCRIPT="${REPO_ROOT}/scripts/service_install/java.sh"
grep -Fq 'java/17/archive/jdk-17.0.12_linux-' "${JAVA_SCRIPT}"
grep -Fq 'graalvm_jdk_tag="17.0.9"' "${JAVA_SCRIPT}"
grep -Fq 'graalvm_jdk_tag="21.0.2"' "${JAVA_SCRIPT}"
grep -Fq 'Oracle JDK ${JAVA_VERSION} 已无法匿名下载' "${JAVA_SCRIPT}"
if grep -Fq 'java/17/latest/jdk-17_linux-' "${JAVA_SCRIPT}"; then
    echo "Java installer still uses retired Oracle JDK 17 latest URL." >&2
    exit 1
fi
if grep -Eq 'download\.oracle\.com/otn/java/jdk/' "${JAVA_SCRIPT}"; then
    echo "Java installer still uses Oracle OTN JDK 8/11 URLs." >&2
    exit 1
fi

# Rust installs official rustup-init with SHA-256; seedloc blog URL retired.
RUST_SCRIPT="${REPO_ROOT}/scripts/service_install/rust.sh"
grep -Fq 'static.rust-lang.org/rustup/dist' "${RUST_SCRIPT}"
grep -Fq 'rustup-init SHA-256 校验失败' "${RUST_SCRIPT}"
if grep -Fq 'https://sh.rustup.rs' "${RUST_SCRIPT}"; then
    echo "Rust installer still uses the sh.rustup.rs wrapper." >&2
    exit 1
fi
if grep -Fq 'https://seedloc.com' "${LAUNCHER}"; then
    echo "Launcher still links the offline seedloc.com blog." >&2
    exit 1
fi
grep -Fq 'github.com/everett7623/vps_scripts/blob/main/README.md' "${LAUNCHER}"

# Catalog short URLs pinned to raw GitHub to avoid UA-dependent HTML landers.
grep -Fq 'raw.githubusercontent.com/teddysun/across/master/bench.sh' "${LAUNCHER}"
grep -Fq 'raw.githubusercontent.com/kejilion/sh/main/kejilion.sh' "${LAUNCHER}"
if grep -Eq 'run_remote_script_url "https://bench\.sh"' "${LAUNCHER}"; then
    echo "Launcher still uses the UA-sensitive https://bench.sh short URL." >&2
    exit 1
fi
if grep -Eq 'run_remote_script_url "https://kejilion\.sh"' "${LAUNCHER}"; then
    echo "Launcher still uses the UA-sensitive https://kejilion.sh short URL." >&2
    exit 1
fi

# Caddy / cloudflared download to temp and require ELF magic before install.
grep -Fq 'Downloaded Caddy is not an ELF binary' "${LAUNCHER}"
grep -Fq 'Downloaded cloudflared is not an ELF binary' "${LAUNCHER}"
grep -Fq '7f454c46' "${LAUNCHER}"

# CRI-O OpenSUSE kubic streams stop at 1.28.
K8S_SCRIPT="${REPO_ROOT}/scripts/service_install/kubernetes.sh"
grep -Fq 'crio_minor' "${K8S_SCRIPT}"
grep -Fq 'kubic 路径 404' "${K8S_SCRIPT}"
grep -Fq 'download_k8s_manifest' "${K8S_SCRIPT}"
grep -Fq '清单不是 Kubernetes YAML' "${K8S_SCRIPT}"
grep -Fq 'metrics-server/releases/download/v0.7.2/components.yaml' "${K8S_SCRIPT}"
if grep -Fq 'curl -O https://docs.projectcalico.org/manifests/calico.yaml' "${K8S_SCRIPT}"; then
    echo "Kubernetes installer still downloads Calico into the working directory." >&2
    exit 1
fi
if grep -Eq 'kubectl apply -f https://' "${K8S_SCRIPT}"; then
    echo "Kubernetes installer still applies a remote manifest URL." >&2
    exit 1
fi
if grep -Fq 'metrics-server/releases/latest/download/components.yaml' "${K8S_SCRIPT}"; then
    echo "Kubernetes installer still uses unpinned Metrics Server latest." >&2
    exit 1
fi
JENKINS_SCRIPT="${REPO_ROOT}/scripts/service_install/jenkins.sh"
grep -Fq 'mktemp -d "/tmp/jenkins-maven.XXXXXX"' "${JENKINS_SCRIPT}"
grep -Fq 'verify_archive_checksum sha512 "${maven_url}.sha512"' "${JENKINS_SCRIPT}"
grep -Fq 'verify_archive_checksum sha256 "${gradle_url}.sha256"' "${JENKINS_SCRIPT}"
if grep -Eq 'wget[[:space:]]+https://archive\.apache\.org/dist/maven/' "${JENKINS_SCRIPT}"; then
    echo "Jenkins installer still downloads Maven into the working directory." >&2
    exit 1
fi

echo "Upgrade hardening checks are valid."
