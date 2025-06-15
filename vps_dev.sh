#!/bin/bash
#
# vps_dev.sh - VPS Administration and Management Test Script
#
# This script is a development version for testing new features and structures
# for the main vps.sh script. It provides a menu-driven interface to run
# various system administration, benchmarking, and installation scripts.
#
# Project: https://github.com/everett7623/vps_scripts/
# Path: /vps_dev.sh

# --- Global Variables ---
# Determine the absolute path of the script's directory
# This ensures that all paths are relative to the script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Define paths to core directories based on the script's location
LIB_DIR="${SCRIPT_DIR}/lib"
CONFIG_DIR="${SCRIPT_DIR}/config"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

# --- Source Core Libraries ---

# Source common functions library
if [ -f "${LIB_DIR}/common_functions.sh" ]; then
    source "${LIB_DIR}/common_functions.sh"
else
    echo "Error: Core functions library not found at '${LIB_DIR}/common_functions.sh'."
    echo "Please ensure the script is run from the root of the 'vps_scripts' project directory."
    exit 1
fi

# Source configuration file
if [ -f "${CONFIG_DIR}/vps_scripts.conf" ]; then
    source "${CONFIG_DIR}/vps_scripts.conf"
else
    # It's a warning because the script might be able to run with default values
    echo "Warning: Configuration file not found at '${CONFIG_DIR}/vps_scripts.conf'."
    echo "The script will proceed with default settings."
fi


# --- Menu Functions ---

# --- Sub-Menus ---

# System Tools Menu
show_system_tools_menu() {
    clear
    echo "----------------------------------------"
    echo "          System Tools Menu"
    echo "----------------------------------------"
    echo "1. View System Information"
    echo "2. Install Common Dependencies"
    echo "3. Update System"
    echo "4. Clean System"
    echo "5. Optimize System"
    echo "6. Change Hostname"
    echo "7. Set Timezone"
    echo "0. Back to Main Menu"
    echo "----------------------------------------"
    read -p "Enter your choice [0-7]: " choice
    case $choice in
        1) bash "${SCRIPTS_DIR}/system_tools/system_info.sh" ;;
        2) bash "${SCRIPTS_DIR}/system_tools/install_deps.sh" ;;
        3) bash "${SCRIPTS_DIR}/system_tools/update_system.sh" ;;
        4) bash "${SCRIPTS_DIR}/system_tools/clean_system.sh" ;;
        5) bash "${SCRIPTS_DIR}/system_tools/optimize_system.sh" ;;
        6) bash "${SCRIPTS_DIR}/system_tools/change_hostname.sh" ;;
        7) bash "${SCRIPTS_DIR}/system_tools/set_timezone.sh" ;;
        0) return ;;
        *) echo "Invalid option, please try again." ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    show_system_tools_menu
}

# Network Test Menu
show_network_test_menu() {
    clear
    echo "----------------------------------------"
    echo "          Network Test Menu"
    echo "----------------------------------------"
    echo "1. Backhaul Route Test"
    echo "2. Bandwidth Test"
    echo "3. CDN Latency Test"
    echo "4. IP Quality Test"
    echo "5. Network Connectivity Test"
    echo "6. Network Quality Test"
    echo "7. Network Security Scan"
    echo "8. Network Speedtest"
    echo "9. Traceroute"
    echo "10. Port Scanner"
    echo "11. Response Time Test"
    echo "12. Streaming Unlock Test"
    echo "0. Back to Main Menu"
    echo "----------------------------------------"
    read -p "Enter your choice [0-12]: " choice
    case $choice in
        1) bash "${SCRIPTS_DIR}/network_test/backhaul_route_test.sh" ;;
        2) bash "${SCRIPTS_DIR}/network_test/bandwidth_test.sh" ;;
        3) bash "${SCRIPTS_DIR}/network_test/cdn_latency_test.sh" ;;
        4) bash "${SCRIPTS_DIR}/network_test/ip_quality_test.sh" ;;
        5) bash "${SCRIPTS_DIR}/network_test/network_connectivity_test.sh" ;;
        6) bash "${SCRIPTS_DIR}/network_test/network_quality_test.sh" ;;
        7) bash "${SCRIPTS_DIR}/network_test/network_security_scan.sh" ;;
        8) bash "${SCRIPTS_DIR}/network_test/network_speedtest.sh" ;;
        9) bash "${SCRIPTS_DIR}/network_test/network_traceroute.sh" ;;
        10) bash "${SCRIPTS_DIR}/network_test/port_scanner.sh" ;;
        11) bash "${SCRIPTS_DIR}/network_test/response_time_test.sh" ;;
        12) bash "${SCRIPTS_DIR}/network_test/streaming_unlock_test.sh" ;;
        0) return ;;
        *) echo "Invalid option, please try again." ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    show_network_test_menu
}

# Performance Test Menu
show_performance_test_menu() {
    clear
    echo "----------------------------------------"
    echo "        Performance Test Menu"
    echo "----------------------------------------"
    echo "1. CPU Benchmark"
    echo "2. Disk I/O Benchmark"
    echo "3. Memory Benchmark"
    echo "4. Network Throughput Test"
    echo "0. Back to Main Menu"
    echo "----------------------------------------"
    read -p "Enter your choice [0-4]: " choice
    case $choice in
        1) bash "${SCRIPTS_DIR}/performance_test/cpu_benchmark.sh" ;;
        2) bash "${SCRIPTS_DIR}/performance_test/disk_io_benchmark.sh" ;;
        3) bash "${SCRIPTS_DIR}/performance_test/memory_benchmark.sh" ;;
        4) bash "${SCRIPTS_DIR}/performance_test/network_throughput_test.sh" ;;
        0) return ;;
        *) echo "Invalid option, please try again." ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    show_performance_test_menu
}

# Service Installation Menu
show_service_install_menu() {
    clear
    echo "----------------------------------------"
    echo "       Service Installation Menu"
    echo "----------------------------------------"
    echo "1. Install Docker"
    echo "2. Install LNMP Stack"
    echo "3. Install Node.js"
    echo "4. Install Python"
    echo "5. Install Redis"
    echo "6. Install BT Panel"
    echo "7. Install 1Panel"
    echo "8. Install WordPress"
    echo "0. Back to Main Menu"
    echo "----------------------------------------"
    read -p "Enter your choice [0-8]: " choice
    case $choice in
        1) bash "${SCRIPTS_DIR}/service_install/install_docker.sh" ;;
        2) bash "${SCRIPTS_DIR}/service_install/install_lnmp.sh" ;;
        3) bash "${SCRIPTS_DIR}/service_install/install_nodejs.sh" ;;
        4) bash "${SCRIPTS_DIR}/service_install/install_python.sh" ;;
        5) bash "${SCRIPTS_DIR}/service_install/install_redis.sh" ;;
        6) bash "${SCRIPTS_DIR}/service_install/install_bt_panel.sh" ;;
        7) bash "${SCRIPTS_DIR}/service_install/install_1panel.sh" ;;
        8) bash "${SCRIPTS_DIR}/service_install/install_wordpress.sh" ;;
        0) return ;;
        *) echo "Invalid option, please try again." ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    show_service_install_menu
}

# Good Scripts Menu
show_good_scripts_menu() {
    bash "${SCRIPTS_DIR}/good_scripts/good_scripts.sh"
    read -n 1 -s -r -p "Press any key to continue..."
}

# Proxy Tools Menu
show_proxy_tools_menu() {
    bash "${SCRIPTS_DIR}/proxy_tools/proxy_tools.sh"
    read -n 1 -s -r -p "Press any key to continue..."
}

# Other Tools Menu
show_other_tools_menu() {
    clear
    echo "----------------------------------------"
    echo "           Other Tools Menu"
    echo "----------------------------------------"
    echo "1. BBR Acceleration"
    echo "2. Install Fail2ban"
    echo "3. Install Nezha Monitoring"
    echo "4. Set SWAP"
    echo "5. Clean Nezha Agent"
    echo "0. Back to Main Menu"
    echo "----------------------------------------"
    read -p "Enter your choice [0-5]: " choice
    case $choice in
        1) bash "${SCRIPTS_DIR}/other_tools/bbr.sh" ;;
        2) bash "${SCRIPTS_DIR}/other_tools/fail2ban.sh" ;;
        3) bash "${SCRIPTS_DIR}/other_tools/nezha.sh" ;;
        4) bash "${SCRIPTS_DIR}/other_tools/swap.sh" ;;
        5) bash <(curl -s https://raw.githubusercontent.com/everett7623/Nezha-cleaner/main/nezha-agent-cleaner.sh) ;;
        0) return ;;
        *) echo "Invalid option, please try again." ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    show_other_tools_menu
}

# Update Scripts Menu
show_update_scripts_menu() {
    clear
    echo "----------------------------------------"
    echo "          Update Scripts Menu"
    echo "----------------------------------------"
    echo "1. Trigger Auto-Update"
    echo "2. Update Core Scripts"
    echo "3. Update Dependencies"
    echo "4. Update Functional Tools"
    echo "0. Back to Main Menu"
    echo "----------------------------------------"
    read -p "Enter your choice [0-4]: " choice
    case $choice in
        1) bash "${SCRIPTS_DIR}/update_scripts/trigger_auto_update.sh" ;;
        2) bash "${SCRIPTS_DIR}/update_scripts/update_core_scripts.sh" ;;
        3) bash "${SCRIPTS_DIR}/update_scripts/update_dependencies.sh" ;;
        4) bash "${SCRIPTS_DIR}/update_scripts/update_functional_tools.sh" ;;
        0) return ;;
        *) echo "Invalid option, please try again." ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    show_update_scripts_menu
}

# Uninstall Scripts Menu
show_uninstall_scripts_menu() {
    clear
    echo "----------------------------------------"
    echo "         Uninstall Scripts Menu"
    echo "----------------------------------------"
    echo "1. Clean Service Residues"
    echo "2. Rollback System Environment"
    echo "3. Clear Configuration Files"
    echo "4. Full Uninstall"
    echo "0. Back to Main Menu"
    echo "----------------------------------------"
    read -p "Enter your choice [0-4]: " choice
    case $choice in
        1) bash "${SCRIPTS_DIR}/uninstall_scripts/clean_service_residues.sh" ;;
        2) bash "${SCRIPTS_DIR}/uninstall_scripts/rollback_system_environment.sh" ;;
        3) bash "${SCRIPTS_DIR}/uninstall_scripts/clear_configuration_files.sh" ;;
        4) bash "${SCRIPTS_DIR}/uninstall_scripts/full_uninstall.sh" ;;
        0) return ;;
        *) echo "Invalid option, please try again." ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    show_uninstall_scripts_menu
}


# --- Main Menu ---
show_main_menu() {
    clear
    echo "========================================"
    echo "   VPS Scripts Main Menu (Dev Version)"
    echo "========================================"
    echo "  Project: https://github.com/everett7623/vps_scripts/"
    echo "----------------------------------------"
    echo "1. System Tools"
    echo "2. Network Tests"
    echo "3. Performance Tests"
    echo "4. Service Installation"
    echo "5. Awesome Scripts Collection"
    echo "6. Proxy Tools Collection"
    echo "7. Other Tools"
    echo "8. Update Scripts"
    echo "9. Uninstall Scripts"
    echo "0. Exit"
    echo "----------------------------------------"
    read -p "Enter your choice [0-9]: " main_choice
    case $main_choice in
        1) show_system_tools_menu ;;
        2) show_network_test_menu ;;
        3) show_performance_test_menu ;;
        4) show_service_install_menu ;;
        5) show_good_scripts_menu ;;
        6) show_proxy_tools_menu ;;
        7) show_other_tools_menu ;;
        8) show_update_scripts_menu ;;
        9) show_uninstall_scripts_menu ;;
        0) echo "Exiting script. Goodbye!"; exit 0 ;;
        *) echo "Invalid option, please try again." ; read -n 1 -s -r -p "Press any key to continue..." ;;
    esac
    show_main_menu
}

# --- Script Entry Point ---
# This is where the script execution begins.
show_main_menu
