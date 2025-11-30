#!/bin/bash
#===============================================================================
# Common Library - Shared Functions for Mail Server Scripts
#
# Purpose:
#   Provides reusable functions for logging, JSON generation, Docker access,
#   and utility operations used across all mail server management scripts.
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
    echo -e "${COLORS[$level]}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*${COLORS[NC]}"
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

#===============================================================================
# Docker Helper Functions
#===============================================================================

postfix_exec() {
    docker exec -i mail-postfix "$@"
}

dovecot_exec() {
    docker exec -i mail-dovecot "$@"
}

mysql_exec() {
    docker exec -i mail-mysql mysql -u "${MYSQL_USER:-mailuser}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE:-mailserver}" -e "$@"
}

mysql_query() {
    docker exec -i mail-mysql mysql -u "${MYSQL_USER:-mailuser}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE:-mailserver}" -sN -e "$@"
}

#===============================================================================
# JSON Helper Functions
#===============================================================================

json_escape() {
    local string="$1"
    # Escape backslashes and quotes
    echo "$string" | sed 's/\\/\\\\/g; s/"/\\"/g'
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
# Utility Functions
#===============================================================================

is_containerized() {
    [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null
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
        if ! check_command "$cmd"; then
            ((missing++))
        fi
    done

    if ((missing > 0)); then
        log_error "Missing $missing required command(s)"
        return 1
    fi
}

timestamp_iso() {
    date -Iseconds
}

timestamp_filename() {
    date +%Y%m%d_%H%M%S
}

#===============================================================================
# File Operations
#===============================================================================

ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    fi
}

#===============================================================================
# Network Operations
#===============================================================================

check_port() {
    local host="$1"
    local port="$2"
    timeout 2 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null
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

bytes_to_mb() {
    local bytes="$1"
    echo "scale=2; $bytes / 1048576" | bc
}

#===============================================================================
# End of common library
#===============================================================================
