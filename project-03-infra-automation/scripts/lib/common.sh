#!/bin/bash
#===============================================================================
# Common Library - Shared Functions for Infrastructure Automation
#
# Purpose:
#   Provides reusable functions for logging, OS detection, JSON generation,
#   validation, and utility operations used across all infrastructure automation
#   scripts.
#
# Usage:
#   source /path/to/lib/common.sh
#
# Author: Linux Sysadmin Portfolio
# License: MIT
#===============================================================================

#===============================================================================
# Color Definitions
#===============================================================================
declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [MAGENTA]='\033[0;35m'
    [CYAN]='\033[0;36m'
    [NC]='\033[0m'
)

#===============================================================================
# Logging Functions
#===============================================================================

log() {
    local level=$1
    shift
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${COLORS[$level]}[$timestamp] [$level] $*${COLORS[NC]}"
}

log_info() {
    log "BLUE" "$*"
}

log_success() {
    log "GREEN" "$*"
}

log_warning() {
    log "YELLOW" "$*"
}

log_error() {
    log "RED" "$*" >&2
}

log_debug() {
    if [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]]; then
        log "CYAN" "$*"
    fi
}

#===============================================================================
# OS Detection Functions
#===============================================================================

detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        echo "${ID:-unknown}"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    elif [[ -f /etc/alpine-release ]]; then
        echo "alpine"
    else
        echo "unknown"
    fi
}

detect_os_version() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        echo "${VERSION_ID:-unknown}"
    else
        echo "unknown"
    fi
}

detect_package_manager() {
    local os
    os=$(detect_os)

    case "$os" in
        debian|ubuntu)
            echo "apt"
            ;;
        alpine)
            echo "apk"
            ;;
        rhel|centos|fedora)
            echo "yum"
            ;;
        arch)
            echo "pacman"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

detect_init_system() {
    if pidof systemd &>/dev/null; then
        echo "systemd"
    elif [[ -f /sbin/openrc ]]; then
        echo "openrc"
    elif [[ -f /etc/init.d/rc ]]; then
        echo "sysvinit"
    else
        echo "unknown"
    fi
}

is_debian_based() {
    local os
    os=$(detect_os)
    [[ "$os" == "debian" || "$os" == "ubuntu" ]]
}

is_alpine() {
    [[ "$(detect_os)" == "alpine" ]]
}

#===============================================================================
# Validation Functions
#===============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        return 1
    fi
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required command not found: $1"
        return 1
    fi
}

check_dependencies() {
    local -a deps=("$@")
    local missing=0

    for cmd in "${deps[@]}"; do
        if ! check_command "$cmd" 2>/dev/null; then
            ((missing++))
        fi
    done

    if ((missing > 0)); then
        log_error "Missing $missing required command(s)"
        return 1
    fi

    return 0
}

check_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
}

check_directory_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_error "Directory not found: $dir"
        return 1
    fi
}

is_containerized() {
    [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null
}

#===============================================================================
# JSON Helper Functions
#===============================================================================

json_escape() {
    local string="$1"
    # Escape backslashes, quotes, newlines, tabs
    echo "$string" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g; s/\t/\\t/g'
}

json_timestamp() {
    date -Iseconds
}

json_header() {
    local script_name="$1"
    cat << EOF
{
    "timestamp": "$(json_timestamp)",
    "hostname": "$(hostname)",
    "script": "$script_name",
    "version": "1.0.0",
EOF
}

json_footer() {
    echo "}"
}

#===============================================================================
# Timestamp Functions
#===============================================================================

timestamp_iso() {
    date -Iseconds
}

timestamp_filename() {
    date +%Y%m%d_%H%M%S
}

timestamp_date() {
    date +%Y-%m-%d
}

timestamp_human() {
    date '+%Y-%m-%d %H:%M:%S'
}

#===============================================================================
# File Operations
#===============================================================================

ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_debug "Created directory: $dir"
    fi
}

backup_file() {
    local file="$1"
    local backup_dir="${2:-$(dirname "$file")}"
    local timestamp
    timestamp=$(timestamp_filename)

    if [[ -f "$file" ]]; then
        local backup_path="${backup_dir}/$(basename "$file").backup.${timestamp}"
        cp -p "$file" "$backup_path"
        log_debug "Backed up: $file → $backup_path"
        echo "$backup_path"
    fi
}

#===============================================================================
# Network Operations
#===============================================================================

check_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-2}"
    timeout "$timeout" bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null
}

get_ip_address() {
    hostname -I | awk '{print $1}'
}

get_primary_interface() {
    ip route | grep default | awk '{print $5}' | head -1
}

#===============================================================================
# Math Operations
#===============================================================================

percentage() {
    local part="$1"
    local total="$2"
    if ((total == 0)); then
        echo "0"
    else
        echo "scale=2; ($part * 100) / $total" | bc
    fi
}

bytes_to_kb() {
    local bytes="$1"
    echo "scale=2; $bytes / 1024" | bc
}

bytes_to_mb() {
    local bytes="$1"
    echo "scale=2; $bytes / 1048576" | bc
}

bytes_to_gb() {
    local bytes="$1"
    echo "scale=2; $bytes / 1073741824" | bc
}

seconds_to_duration() {
    local seconds="$1"
    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if ((days > 0)); then
        echo "${days}d ${hours}h ${minutes}m ${secs}s"
    elif ((hours > 0)); then
        echo "${hours}h ${minutes}m ${secs}s"
    elif ((minutes > 0)); then
        echo "${minutes}m ${secs}s"
    else
        echo "${secs}s"
    fi
}

#===============================================================================
# String Operations
#===============================================================================

trim() {
    local var="$*"
    # Remove leading whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove trailing whitespace
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

to_lowercase() {
    echo "$*" | tr '[:upper:]' '[:lower:]'
}

to_uppercase() {
    echo "$*" | tr '[:lower:]' '[:upper:]'
}

#===============================================================================
# Docker Helper Functions (if in container)
#===============================================================================

debian_exec() {
    if is_containerized; then
        docker exec -i infra-debian-target "$@"
    else
        "$@"
    fi
}

alpine_exec() {
    if is_containerized; then
        docker exec -i infra-alpine-target "$@"
    else
        "$@"
    fi
}

ubuntu_exec() {
    if is_containerized; then
        docker exec -i infra-ubuntu-target "$@"
    else
        "$@"
    fi
}

#===============================================================================
# Confirmation Prompts
#===============================================================================

confirm() {
    local prompt="${1:-Are you sure?}"
    local default="${2:-n}"
    local response

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi

    read -r -p "$prompt" response
    response=$(to_lowercase "$response")

    if [[ -z "$response" ]]; then
        response="$default"
    fi

    [[ "$response" == "y" || "$response" == "yes" ]]
}

#===============================================================================
# End of common library
#===============================================================================
