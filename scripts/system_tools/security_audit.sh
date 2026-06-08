#!/bin/bash
# ==============================================================================
# Script: scripts/system_tools/security_audit.sh
# Purpose: Read-only security baseline audit for VPS hosts.
# ==============================================================================

set -u
set -o pipefail

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

LIB_FILE="${PROJECT_ROOT}/lib/common_functions.sh"
WARNINGS=0
CRITICALS=0
SHOW_PORTS=true

if [ -f "${LIB_FILE}" ]; then
    # shellcheck source=/dev/null
    source "${LIB_FILE}"
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'; WHITE='\033[1;37m'
    print_msg() { echo -e "${1}${2}${NC}"; }
    print_info() { print_msg "${CYAN}" "[INFO] $1"; }
    print_success() { print_msg "${GREEN}" "[OK] $1"; }
    print_warn() { print_msg "${YELLOW}" "[WARN] $1"; }
    print_error() { print_msg "${RED}" "[ERROR] $1"; }
    print_separator() { printf '%b%s%b\n' "${BLUE}" "$(printf '%*s' "${2:-80}" '' | tr ' ' "${1:--}")" "${NC}"; }
    print_header() { echo ""; print_separator "=" 80; printf "%b%*s %s %b\n" "${BOLD}${WHITE}" 26 "" "$1" "${NC}"; print_separator "=" 80; echo ""; }
    print_title() { echo ""; printf "%b>> %s%b\n" "${BOLD}${YELLOW}" "$1" "${NC}"; print_separator "-" 80; }
    command_exists() { command -v "$1" >/dev/null 2>&1; }
fi

show_help() {
    cat <<'EOF'
Usage: bash security_audit.sh [options]

Options:
  --no-ports   Skip listening port inventory
  --help, -h   Show this help
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --no-ports)
                SHOW_PORTS=false
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

warn() {
    WARNINGS=$((WARNINGS + 1))
    print_warn "$1"
}

critical() {
    CRITICALS=$((CRITICALS + 1))
    print_error "$1"
}

ok() {
    print_success "$1"
}

sshd_effective_value() {
    local key="$1"
    local value=""

    if command_exists sshd; then
        value=$(sshd -T 2>/dev/null | awk -v k="$(printf '%s' "${key}" | tr '[:upper:]' '[:lower:]')" '$1 == k {print $2; exit}')
    fi

    if [ -z "${value}" ] && [ -f /etc/ssh/sshd_config ]; then
        value=$(awk -v k="${key}" 'tolower($1) == tolower(k) {print $2}' /etc/ssh/sshd_config 2>/dev/null | tail -n1)
    fi

    printf '%s\n' "${value:-unknown}"
}

audit_ssh() {
    local permit_root=""
    local password_auth=""
    local pubkey_auth=""
    local port=""

    print_title "SSH"

    if [ ! -f /etc/ssh/sshd_config ] && ! command_exists sshd; then
        warn "OpenSSH server configuration was not found."
        return 0
    fi

    permit_root=$(sshd_effective_value "PermitRootLogin")
    password_auth=$(sshd_effective_value "PasswordAuthentication")
    pubkey_auth=$(sshd_effective_value "PubkeyAuthentication")
    port=$(sshd_effective_value "Port")

    printf "Port: %s\nPermitRootLogin: %s\nPasswordAuthentication: %s\nPubkeyAuthentication: %s\n" \
        "${port}" "${permit_root}" "${password_auth}" "${pubkey_auth}"

    case "${permit_root}" in
        yes) critical "SSH root login is explicitly allowed." ;;
        prohibit-password|forced-commands-only|no) ok "SSH root login policy is not fully open." ;;
        *) warn "SSH root login policy could not be determined." ;;
    esac

    case "${password_auth}" in
        yes) warn "SSH password authentication is enabled." ;;
        no) ok "SSH password authentication is disabled." ;;
        *) warn "SSH password authentication policy could not be determined." ;;
    esac
}

audit_firewall() {
    print_title "Firewall"

    if command_exists ufw; then
        ufw status 2>/dev/null | head -n 5
        if ufw status 2>/dev/null | grep -qi "Status: active"; then
            ok "ufw is active."
            return 0
        fi
        warn "ufw is installed but not active."
    fi

    if command_exists firewall-cmd; then
        if firewall-cmd --state >/dev/null 2>&1; then
            ok "firewalld is running."
            return 0
        fi
        warn "firewalld is installed but not running."
    fi

    if command_exists nft && nft list ruleset >/dev/null 2>&1; then
        ok "nftables has a readable ruleset."
        return 0
    fi

    if command_exists iptables && iptables -S >/dev/null 2>&1; then
        if iptables -S 2>/dev/null | grep -Eq '^-A '; then
            ok "iptables has explicit rules."
            return 0
        fi
    fi

    warn "No active firewall baseline was detected."
}

audit_fail2ban() {
    print_title "Intrusion Protection"

    if ! command_exists fail2ban-client; then
        warn "fail2ban-client is not installed."
        return 0
    fi

    if fail2ban-client ping >/dev/null 2>&1; then
        ok "fail2ban is responding."
        fail2ban-client status 2>/dev/null || true
    else
        warn "fail2ban is installed but not responding."
    fi
}

audit_ports() {
    print_title "Listening Ports"

    if [ "${SHOW_PORTS}" = false ]; then
        print_info "Port inventory skipped."
        return 0
    fi

    if command_exists ss; then
        ss -tulpen 2>/dev/null | awk 'NR == 1 || /LISTEN|udp/ {print}' | head -n 30
    elif command_exists netstat; then
        netstat -tulpen 2>/dev/null | awk 'NR <= 2 || /LISTEN|udp/ {print}' | head -n 30
    else
        warn "Neither ss nor netstat is available."
    fi
}

audit_accounts() {
    local empty_password_users=""
    local sudoers=""

    print_title "Accounts"

    if [ "${EUID}" -eq 0 ]; then
        empty_password_users=$(awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null | paste -sd', ' -)
        if [ -n "${empty_password_users}" ]; then
            critical "Users with empty passwords: ${empty_password_users}"
        else
            ok "No empty-password users were found."
        fi
    else
        warn "Run as root to audit empty-password accounts."
    fi

    sudoers=$(getent group sudo 2>/dev/null | cut -d: -f4)
    [ -z "${sudoers}" ] && sudoers=$(getent group wheel 2>/dev/null | cut -d: -f4)
    printf "Privileged group members: %s\n" "${sudoers:-none detected}"
}

audit_permissions() {
    print_title "File Permissions"

    if [ "$(uname -s 2>/dev/null)" != "Linux" ]; then
        warn "Non-Linux runtime detected; deep filesystem permission checks were skipped."
        return 0
    fi

    if [ -f /etc/passwd ] && [ "$(stat -c '%a' /etc/passwd 2>/dev/null || echo 644)" -le 644 ]; then
        ok "/etc/passwd permissions look normal."
    else
        warn "/etc/passwd permissions should be reviewed."
    fi

    if [ -f /etc/shadow ]; then
        if [ "${EUID}" -eq 0 ]; then
            case "$(stat -c '%a' /etc/shadow 2>/dev/null || echo unknown)" in
                600|640) ok "/etc/shadow permissions look normal." ;;
                *) warn "/etc/shadow permissions should be reviewed." ;;
            esac
        else
            print_info "Run as root to inspect /etc/shadow permissions."
        fi
    fi

    if find /tmp /var/tmp -xdev -maxdepth 3 -type f -perm -0002 -not -perm -1000 -print -quit 2>/dev/null | grep -q .; then
        warn "World-writable files without sticky protection were found under temp directories."
    else
        ok "No obvious unsafe world-writable temp files were found."
    fi
}

print_summary() {
    echo ""
    print_separator
    printf "Security audit summary: %s critical, %s warning(s)\n" "${CRITICALS}" "${WARNINGS}"

    if [ "${CRITICALS}" -gt 0 ]; then
        print_error "Critical security findings were detected."
    elif [ "${WARNINGS}" -gt 0 ]; then
        print_warn "Security warnings were detected."
    else
        print_success "No obvious security baseline issues were detected."
    fi
}

main() {
    parse_args "$@"
    print_header "VPS Security Audit"
    audit_ssh
    audit_firewall
    audit_fail2ban
    audit_ports
    audit_accounts
    audit_permissions
    print_summary
}

main "$@"
