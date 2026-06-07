#!/bin/bash
# ==============================================================================
# Script: vps.sh
# Project: https://github.com/everett7623/vps_scripts
# Purpose: Modular remote launcher for VPS Scripts.
# ==============================================================================

set -u

GITHUB_RAW_URL="https://raw.githubusercontent.com/everett7623/vps_scripts/main"
PROJECT_URL="https://github.com/everett7623/vps_scripts"
LAUNCHER_STYLE_VERSION="2026.06"

RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
DIM='\033[2m'

DOWNLOAD_TOOL=""

check_environment() {
    if command -v curl >/dev/null 2>&1; then
        DOWNLOAD_TOOL="curl"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOAD_TOOL="wget"
    else
        echo -e "${RED}[ERROR] curl or wget is required.${RESET}"
        exit 1
    fi
}

clear_screen() {
    command -v clear >/dev/null 2>&1 && clear
}

draw_rule() {
    local width="${1:-74}"
    local color="${2:-$BLUE}"
    printf '%b' "${color}"
    printf '%*s' "${width}" '' | tr ' ' '='
    printf '%b\n' "${RESET}"
}

print_header() {
    clear_screen
    draw_rule 74 "$CYAN"
    echo -e "${BOLD}${WHITE}  VPS Scripts${RESET}${DIM}  modular launcher | style ${LAUNCHER_STYLE_VERSION}${RESET}"
    echo -e "${CYAN}  repo:${RESET} ${PROJECT_URL}"
    echo -e "${CYAN}  mode:${RESET} safer first-party downloads | reviewed menus | guided third-party runs"
    draw_rule 74 "$CYAN"
    echo ""
}

print_panel_title() {
    echo -e "${BOLD}${PURPLE}$1${RESET}"
    draw_rule 74 "$PURPLE"
}

print_status_line() {
    echo -e "${DIM}download:${RESET} ${DOWNLOAD_TOOL}  ${DIM}| launcher:${RESET} modular  ${DIM}| theme:${RESET} neon-shell"
    echo ""
}

pause_for_menu() {
    echo ""
    echo -e "${CYAN}[Press any key to return]${RESET}"
    read -n 1 -s -r
}

invalid_choice() {
    echo -e "${RED}Invalid choice.${RESET}"
    sleep 1
}

print_menu_item() {
    local key="${1}"
    local label="${2}"
    local detail="${3:-}"
    printf "%b%2s%b. %-24s" "${YELLOW}" "${key}" "${RESET}" "${label}"
    [ -n "${detail}" ] && printf "%b%s%b" "${DIM}" "${detail}" "${RESET}"
    printf "\n"
}

is_safe_repo_path() {
    local script_rel_path="${1}"
    [[ -n "${script_rel_path}" ]] && [[ "${script_rel_path}" != /* ]] && [[ "${script_rel_path}" != *".."* ]]
}

download_file_with_tool() {
    local url="${1}"
    local output="${2}"

    case "${DOWNLOAD_TOOL}" in
        curl)
            curl -fsSL --connect-timeout 10 --max-time 120 "${url}" -o "${output}"
            ;;
        wget)
            wget -q --timeout=120 -O "${output}" "${url}"
            ;;
        *)
            return 1
            ;;
    esac
}

run_repo_script() {
    local script_rel_path="${1}"
    local full_url="${GITHUB_RAW_URL}/${script_rel_path}"
    local temp_file=""

    print_header
    print_panel_title "First-party module"
    echo -e "${WHITE}> ${script_rel_path}${RESET}"
    echo ""

    if ! is_safe_repo_path "${script_rel_path}"; then
        echo -e "${RED}[ERROR] Invalid repository path.${RESET}"
        pause_for_menu
        return 1
    fi

    temp_file=$(mktemp "/tmp/vps_repo_script.XXXXXX") || {
        echo -e "${RED}[ERROR] Failed to create a temporary file.${RESET}"
        pause_for_menu
        return 1
    }

    if ! download_file_with_tool "${full_url}" "${temp_file}" || [ ! -s "${temp_file}" ]; then
        rm -f "${temp_file}"
        echo -e "${RED}[ERROR] Failed to download module.${RESET}"
        echo -e "${DIM}URL:${RESET} ${full_url}"
        pause_for_menu
        return 1
    fi

    if ! bash "${temp_file}"; then
        echo ""
        echo -e "${RED}[ERROR] Module execution failed.${RESET}"
        echo -e "${DIM}URL:${RESET} ${full_url}"
    fi

    rm -f "${temp_file}"
    pause_for_menu
}

run_remote_script_url() {
    local url="${1}"
    local label="${2}"
    local temp_file=""

    print_header
    print_panel_title "Third-party script"
    echo -e "${WHITE}> ${label}${RESET}"
    echo -e "${DIM}URL:${RESET} ${url}"
    echo ""
    read -r -p "Download and run this third-party script? [y/N]: " confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cancelled.${RESET}"
        pause_for_menu
        return 0
    fi

    temp_file=$(mktemp "/tmp/vps_remote_script.XXXXXX") || {
        echo -e "${RED}[ERROR] Failed to create a temporary file.${RESET}"
        pause_for_menu
        return 1
    }

    if ! download_file_with_tool "${url}" "${temp_file}" || [ ! -s "${temp_file}" ]; then
        rm -f "${temp_file}"
        echo -e "${RED}[ERROR] Failed to download third-party script.${RESET}"
        pause_for_menu
        return 1
    fi

    chmod +x "${temp_file}" 2>/dev/null || true
    if ! bash "${temp_file}"; then
        echo ""
        echo -e "${RED}[ERROR] Third-party script execution failed.${RESET}"
    fi

    rm -f "${temp_file}"
    pause_for_menu
}

run_remote_command() {
    local command_to_run="${1}"
    local description="${2:-third-party command}"

    print_header
    print_panel_title "Third-party command"
    echo -e "${WHITE}> ${description}${RESET}"
    echo -e "${DIM}${command_to_run}${RESET}"
    echo ""
    read -r -p "Run this command? [y/N]: " confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cancelled.${RESET}"
        pause_for_menu
        return 0
    fi

    eval "${command_to_run}"
    pause_for_menu
}

system_tools_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "System Tools"
        print_menu_item 1 "System info" "hardware, kernel, network"
        print_menu_item 2 "Install dependencies" "baseline runtime packages"
        print_menu_item 3 "Update system" "safe package update flow"
        print_menu_item 4 "Clean system" "cache and residue cleanup"
        print_menu_item 5 "Optimize system" "sysctl and runtime tuning"
        print_menu_item 6 "Change hostname" "rename server identity"
        print_menu_item 7 "Set timezone" "clock and locale alignment"
        print_menu_item 0 "Back"
        echo ""
        read -r -p "Select [0-7]: " choice

        case "${choice}" in
            1) run_repo_script "scripts/system_tools/system_info.sh" ;;
            2) run_repo_script "scripts/system_tools/install_deps.sh" ;;
            3) run_repo_script "scripts/system_tools/update_system.sh" ;;
            4) run_repo_script "scripts/system_tools/clean_system.sh" ;;
            5) run_repo_script "scripts/system_tools/optimize_system.sh" ;;
            6) run_repo_script "scripts/system_tools/change_hostname.sh" ;;
            7) run_repo_script "scripts/system_tools/set_timezone.sh" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

network_test_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "Network Tests"
        print_menu_item 1 "Backhaul route" "return path visibility"
        print_menu_item 2 "Bandwidth test" "speedtest and links"
        print_menu_item 3 "IP quality" "asn, region, blacklist hints"
        print_menu_item 4 "Network quality" "combined route + latency"
        print_menu_item 5 "Streaming unlock" "media region checks"
        print_menu_item 0 "Back"
        echo ""
        echo -e "${DIM}More ad-hoc checks remain available from the Community menu.${RESET}"
        echo ""
        read -r -p "Select [0-5]: " choice

        case "${choice}" in
            1) run_repo_script "scripts/network_test/backhaul_route_test.sh" ;;
            2) run_repo_script "scripts/network_test/bandwidth_test.sh" ;;
            3) run_repo_script "scripts/network_test/ip_quality_test.sh" ;;
            4) run_repo_script "scripts/network_test/network_quality_test.sh" ;;
            5) run_repo_script "scripts/network_test/streaming_unlock_test.sh" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

performance_test_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "Performance Tests"
        print_menu_item 1 "CPU benchmark" "single and multi-core"
        print_menu_item 2 "Disk I/O" "fio and storage checks"
        print_menu_item 3 "Memory benchmark" "throughput and latency"
        print_menu_item 4 "Network throughput" "iperf style checks"
        print_menu_item 0 "Back"
        echo ""
        read -r -p "Select [0-4]: " choice

        case "${choice}" in
            1) run_repo_script "scripts/performance_test/cpu_benchmark.sh" ;;
            2) run_repo_script "scripts/performance_test/disk_io_benchmark.sh" ;;
            3) run_repo_script "scripts/performance_test/memory_benchmark.sh" ;;
            4) run_repo_script "scripts/performance_test/network_throughput_test.sh" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

service_install_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "Service Install"
        print_menu_item 1  "Docker" "container runtime"
        print_menu_item 2  "LDNMP" "lightweight web stack"
        print_menu_item 3  "Nginx" "web server"
        print_menu_item 4  "MySQL" "database server"
        print_menu_item 5  "PostgreSQL" "database server"
        print_menu_item 6  "Node.js" "javascript runtime"
        print_menu_item 7  "Python" "python runtime"
        print_menu_item 8  "Redis" "cache and queue"
        print_menu_item 9  "Go" "golang runtime"
        print_menu_item 10 "Java" "jdk and tooling"
        print_menu_item 11 "Ruby" "ruby runtime"
        print_menu_item 12 "Rust" "cargo toolchain"
        print_menu_item 13 "WordPress" "cms deploy"
        print_menu_item 14 "aaPanel" "control panel"
        print_menu_item 15 "BTPanel" "control panel"
        print_menu_item 16 "1Panel" "control panel"
        print_menu_item 17 "AMH" "control panel"
        print_menu_item 18 "CyberPanel" "control panel"
        print_menu_item 19 "Jenkins" "automation server"
        print_menu_item 20 "Kubernetes" "cluster stack"
        print_menu_item 0  "Back"
        echo ""
        read -r -p "Select [0-20]: " choice

        case "${choice}" in
            1) run_repo_script "scripts/service_install/docker.sh" ;;
            2) run_repo_script "scripts/service_install/ldnmp.sh" ;;
            3) run_repo_script "scripts/service_install/nginx.sh" ;;
            4) run_repo_script "scripts/service_install/mysql.sh" ;;
            5) run_repo_script "scripts/service_install/postgresql.sh" ;;
            6) run_repo_script "scripts/service_install/nodejs.sh" ;;
            7) run_repo_script "scripts/service_install/python.sh" ;;
            8) run_repo_script "scripts/service_install/redis.sh" ;;
            9) run_repo_script "scripts/service_install/go.sh" ;;
            10) run_repo_script "scripts/service_install/java.sh" ;;
            11) run_repo_script "scripts/service_install/ruby.sh" ;;
            12) run_repo_script "scripts/service_install/rust.sh" ;;
            13) run_repo_script "scripts/service_install/wordpress.sh" ;;
            14) run_repo_script "scripts/service_install/aapanel.sh" ;;
            15) run_repo_script "scripts/service_install/btpanel.sh" ;;
            16) run_repo_script "scripts/service_install/1panel.sh" ;;
            17) run_repo_script "scripts/service_install/amh.sh" ;;
            18) run_repo_script "scripts/service_install/cyberpanel.sh" ;;
            19) run_repo_script "scripts/service_install/jenkins.sh" ;;
            20) run_repo_script "scripts/service_install/kubernetes.sh" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

community_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "Community Scripts"
        print_menu_item 1  "YABS benchmark" "yet another bench script"
        print_menu_item 2  "XY-IP quality" "ip inspection"
        print_menu_item 3  "XY network quality" "route and quality"
        print_menu_item 4  "NodeLoc benchmark" "multi-test script"
        print_menu_item 5  "spiritLHLS ecs" "combined benchmark"
        print_menu_item 6  "Media unlock test" "streaming services"
        print_menu_item 7  "Response time test" "curl timing"
        print_menu_item 8  "SSH tool" "remote access helper"
        print_menu_item 9  "JCNF toolbox" "community toolbox"
        print_menu_item 10 "KejiLion toolbox" "community toolbox"
        print_menu_item 11 "BlueSkyXN toolbox" "community toolbox"
        print_menu_item 12 "Multi-line speedtest" "speed nodes"
        print_menu_item 13 "AutoTrace" "trace route utility"
        print_menu_item 14 "Oversell check" "memory pressure test"
        print_menu_item 0  "Back"
        echo ""
        read -r -p "Select [0-14]: " choice

        case "${choice}" in
            1) run_remote_script_url "https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/yabs.sh" "YABS benchmark" ;;
            2) run_remote_script_url "https://IP.Check.Place" "XY-IP quality" ;;
            3) run_remote_script_url "https://Net.Check.Place" "XY network quality" ;;
            4) run_remote_command "curl -sSL https://abc.sd | bash" "NodeLoc benchmark" ;;
            5) run_remote_script_url "https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh" "spiritLHLS ecs" ;;
            6) run_remote_script_url "https://media.ispvps.com" "Media unlock test" ;;
            7) run_remote_script_url "https://nodebench.mereith.com/scripts/curltime.sh" "Response time test" ;;
            8) run_remote_command "curl -fsSL https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh -o ssh_tool.sh && chmod +x ssh_tool.sh && ./ssh_tool.sh" "SSH tool" ;;
            9) run_remote_command "wget -O jcnfbox.sh https://raw.githubusercontent.com/Netflixxp/jcnf-box/main/jcnfbox.sh && chmod +x jcnfbox.sh && clear && ./jcnfbox.sh" "JCNF toolbox" ;;
            10) run_remote_script_url "https://kejilion.sh" "KejiLion toolbox" ;;
            11) run_remote_command "wget -O box.sh https://raw.githubusercontent.com/BlueSkyXN/SKY-BOX/main/box.sh && chmod +x box.sh && clear && ./box.sh" "BlueSkyXN toolbox" ;;
            12) run_remote_script_url "https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh" "Multi-line speedtest" ;;
            13) run_remote_command "wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh" "AutoTrace" ;;
            14) run_remote_command "wget --no-check-certificate -O memoryCheck.sh https://raw.githubusercontent.com/uselibrary/memoryCheck/main/memoryCheck.sh && chmod +x memoryCheck.sh && bash memoryCheck.sh" "Oversell check" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

proxy_tools_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "Proxy Tools"
        print_menu_item 1 "yonggekkk sing-box" "community script"
        print_menu_item 2 "fscarmen sing-box" "community script"
        print_menu_item 3 "yonggekkk x-ui" "community script"
        print_menu_item 4 "Official 3x-ui" "community script"
        print_menu_item 5 "xeefei 3x-ui" "community script"
        print_menu_item 0 "Back"
        echo ""
        read -r -p "Select [0-5]: " choice

        case "${choice}" in
            1) run_remote_script_url "https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh" "yonggekkk sing-box" ;;
            2) run_remote_script_url "https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh" "fscarmen sing-box" ;;
            3) run_remote_script_url "https://gitlab.com/rwkgyg/x-ui-yg/raw/main/install.sh" "yonggekkk x-ui" ;;
            4) run_remote_script_url "https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh" "Official 3x-ui" ;;
            5) run_remote_script_url "https://raw.githubusercontent.com/xeefei/3x-ui/master/install.sh" "xeefei 3x-ui" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

other_tools_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "Other Tools"
        print_menu_item 1 "BBR" "network acceleration"
        print_menu_item 2 "Fail2ban" "basic protection"
        print_menu_item 3 "Nezha agent" "monitoring helper"
        print_menu_item 4 "Swap" "virtual memory"
        print_menu_item 5 "Nezha cleaner" "third-party cleanup"
        print_menu_item 0 "Back"
        echo ""
        read -r -p "Select [0-5]: " choice

        case "${choice}" in
            1) run_repo_script "scripts/other_tools/bbr.sh" ;;
            2) run_repo_script "scripts/other_tools/fail2ban.sh" ;;
            3) run_repo_script "scripts/other_tools/nezha.sh" ;;
            4) run_repo_script "scripts/other_tools/swap.sh" ;;
            5) run_remote_script_url "https://raw.githubusercontent.com/everett7623/Nezha-cleaner/main/nezha-agent-cleaner.sh" "Nezha cleaner" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

update_info_menu() {
    print_header
    print_panel_title "Update Info"
    echo -e "${WHITE}This launcher pulls first-party modules at runtime.${RESET}"
    echo -e "${DIM}To refresh the experience, run the launcher again:${RESET}"
    echo ""
    echo -e "${CYAN}bash <(curl -fsSL ${GITHUB_RAW_URL}/vps.sh)${RESET}"
    pause_for_menu
}

uninstall_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "Cleanup / Uninstall"
        print_menu_item 1 "Clean service residue" "remove leftovers"
        print_menu_item 2 "Roll back environment" "undo runtime changes"
        print_menu_item 3 "Clear config files" "clean repository settings"
        print_menu_item 4 "Full uninstall" "aggressive cleanup path"
        print_menu_item 0 "Back"
        echo ""
        read -r -p "Select [0-4]: " choice

        case "${choice}" in
            1) run_repo_script "scripts/uninstall_scripts/clean_service_residues.sh" ;;
            2) run_repo_script "scripts/uninstall_scripts/rollback_system_environment.sh" ;;
            3) run_repo_script "scripts/uninstall_scripts/clear_configuration_files.sh" ;;
            4) run_repo_script "scripts/uninstall_scripts/full_uninstall.sh" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

main_menu() {
    check_environment

    while true; do
        print_header
        print_status_line
        print_panel_title "Main Menu"
        print_menu_item 1 "System Tools" "inspect, tune, update"
        print_menu_item 2 "Network Tests" "quality, route, streaming"
        print_menu_item 3 "Performance Tests" "cpu, disk, memory"
        print_menu_item 4 "Service Install" "language and stack setup"
        print_menu_item 5 "Community Scripts" "popular external tools"
        print_menu_item 6 "Proxy Tools" "sing-box and x-ui family"
        print_menu_item 7 "Other Tools" "bbr, fail2ban, swap"
        print_menu_item 8 "Update Info" "launcher refresh usage"
        print_menu_item 9 "Cleanup / Uninstall" "residue removal"
        print_menu_item 0 "Exit"
        echo ""
        echo -e "${DIM}First-party modules download safely into temp files before execution.${RESET}"
        echo ""
        read -r -p "Select [0-9]: " choice

        case "${choice}" in
            1) system_tools_menu ;;
            2) network_test_menu ;;
            3) performance_test_menu ;;
            4) service_install_menu ;;
            5) community_menu ;;
            6) proxy_tools_menu ;;
            7) other_tools_menu ;;
            8) update_info_menu ;;
            9) uninstall_menu ;;
            0)
                echo ""
                echo -e "${GREEN}Session closed. See you next deploy.${RESET}"
                exit 0
                ;;
            *) invalid_choice ;;
        esac
    done
}

trap 'echo -e "\n${GREEN}Interrupted by user.${RESET}"; exit 0' INT TERM

main_menu
