#!/bin/bash
# ==============================================================================
# Script: update_log.sh
# Purpose: Display repository version metadata and a readable changelog summary.
# ==============================================================================

set -u

SCRIPT_PATH="$0"
SCRIPT_DIR=$(cd "$(dirname "$SCRIPT_PATH")" && pwd)
CHANGELOG_FILE="${SCRIPT_DIR}/CHANGELOG.md"
VERSION_FILE="${SCRIPT_DIR}/version.json"

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

PLAIN_OUTPUT=false
LINES_LIMIT=60

clear_screen() {
    command -v clear >/dev/null 2>&1 && clear
}

draw_rule() {
    local width="${1:-74}"
    local color="${2:-$CYAN}"
    printf '%b' "${color}"
    printf '%*s' "${width}" '' | tr ' ' '='
    printf '%b\n' "${RESET}"
}

extract_json_value() {
    local key="${1}"
    local line=""

    while IFS= read -r line; do
        case "${line}" in
            *"\"${key}\""*":"*)
                line="${line#*:}"
                line="${line# }"
                line="${line#\"}"
                line="${line%%\"*}"
                printf '%s\n' "${line}"
                return 0
                ;;
        esac
    done < "${VERSION_FILE}"

    return 1
}

print_header() {
    local version="$1"
    local release_date="$2"
    local message="$3"

    if [ "${PLAIN_OUTPUT}" = true ]; then
        printf 'VPS Scripts update log\n'
        printf 'Version: %s\n' "${version}"
        printf 'Release Date: %s\n' "${release_date}"
        printf 'Message: %s\n' "${message}"
        printf '\n'
        return 0
    fi

    clear_screen
    draw_rule 74 "$CYAN"
    echo -e "${BOLD}${WHITE}  VPS Scripts update log${RESET}"
    echo -e "${CYAN}  version:${RESET} ${version}"
    echo -e "${CYAN}  release:${RESET} ${release_date}"
    echo -e "${CYAN}  note:${RESET} ${message}"
    draw_rule 74 "$CYAN"
    echo ""
}

print_changelog_excerpt() {
    local lines_printed=0
    local line=""
    local started=false

    if [ ! -f "${CHANGELOG_FILE}" ]; then
        echo -e "${RED}CHANGELOG.md not found.${RESET}"
        return 1
    fi

    if [ "${PLAIN_OUTPUT}" = false ]; then
        echo -e "${BOLD}${PURPLE}Changelog summary${RESET}"
        draw_rule 74 "$PURPLE"
    fi

    while IFS= read -r line; do
        case "${line}" in
            "## "*)
                started=true
                ;;
        esac

        if [ "${started}" = false ]; then
            continue
        fi

        printf '%s\n' "${line}"
        lines_printed=$((lines_printed + 1))
        if [ "${lines_printed}" -ge "${LINES_LIMIT}" ]; then
            break
        fi
    done < "${CHANGELOG_FILE}"
}

show_help() {
    printf '%s\n' \
        "Usage: bash update_log.sh [options]" \
        "" \
        "Options:" \
        "  --plain          Print without ANSI styling" \
        "  --lines <n>      Limit changelog lines shown (default: 60)" \
        "  --help           Show this help message"
}

main() {
    local version="unknown"
    local release_date="unknown"
    local message="No update message available."

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --plain)
                PLAIN_OUTPUT=true
                ;;
            --lines)
                shift
                LINES_LIMIT="${1:-60}"
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                printf 'Unknown option: %s\n' "$1" >&2
                show_help
                exit 1
                ;;
        esac
        shift
    done

    [ -f "${VERSION_FILE}" ] && version=$(extract_json_value "version" || printf 'unknown')
    [ -f "${VERSION_FILE}" ] && release_date=$(extract_json_value "release_date" || printf 'unknown')
    [ -f "${VERSION_FILE}" ] && message=$(extract_json_value "message" || printf 'No update message available.')

    print_header "${version}" "${release_date}" "${message}"
    print_changelog_excerpt
}

main "$@"
