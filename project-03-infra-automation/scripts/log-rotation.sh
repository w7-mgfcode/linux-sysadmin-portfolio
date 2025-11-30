#!/bin/bash
#===============================================================================
# Log Rotation Manager - Advanced Log Rotation and Compression
#
# Purpose:
#   Manages log file rotation with size/age-based policies, deferred compression,
#   service-aware signaling, and comprehensive retention management.
#
# Usage:
#   ./log-rotation.sh rotate [config-file]    # Rotate logs using config
#   ./log-rotation.sh check [log-file]        # Check if rotation needed
#   ./log-rotation.sh compress [directory]    # Compress old rotated logs
#   ./log-rotation.sh prune [directory]       # Remove old logs per retention
#   ./log-rotation.sh stats [directory]       # Show rotation statistics
#   ./log-rotation.sh generate-config         # Generate example config
#
# Configuration:
#   Uses /etc/logrotate-custom.conf or specify custom config file
#
# Skills Demonstrated:
#   - Size and age-based rotation logic
#   - Deferred compression strategies
#   - Service-aware signal handling (SIGHUP, SIGUSR1)
#   - Multiple compression algorithms
#   - Retention policy enforcement
#   - PID-based process signaling
#   - Statistics tracking and reporting
#   - Configuration file parsing
#
# Author: Linux Sysadmin Portfolio
# License: MIT
#===============================================================================

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

#===============================================================================
# Configuration
#===============================================================================
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_CONFIG="/etc/logrotate-custom.conf"
readonly STATE_DIR="/var/lib/logrotate-custom"
readonly DEFAULT_MAX_SIZE="100M"
readonly DEFAULT_MAX_AGE="30"
readonly DEFAULT_RETENTION="90"

# Compression settings
COMPRESSION="${LOG_COMPRESSION:-gzip}"
COMPRESSION_EXT=".gz"
COMPRESSION_CMD="gzip -9"
COMPRESSION_DELAY="${COMPRESSION_DELAY:-1}"  # Days to wait before compression

#===============================================================================
# Utility Functions
#===============================================================================

parse_size() {
    local size_str="$1"
    local size_num
    local unit

    # Extract number and unit
    size_num=$(echo "$size_str" | grep -oP '^\d+')
    unit=$(echo "$size_str" | grep -oP '[KMGT]?$' | tr '[:lower:]' '[:upper:]')

    # Convert to bytes
    case "$unit" in
        K) echo "$((size_num * 1024))" ;;
        M) echo "$((size_num * 1048576))" ;;
        G) echo "$((size_num * 1073741824))" ;;
        T) echo "$((size_num * 1099511627776))" ;;
        *) echo "$size_num" ;;
    esac
}

get_file_age_days() {
    local file="$1"
    local now
    local mtime
    local age_seconds

    now=$(date +%s)
    mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
    age_seconds=$((now - mtime))
    echo $((age_seconds / 86400))
}

get_file_size() {
    local file="$1"
    stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null
}

ensure_state_dir() {
    ensure_directory "$STATE_DIR"
}

#===============================================================================
# Configuration Parsing
#===============================================================================

parse_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi

    log_info "Parsing configuration: $config_file"

    # Initialize arrays
    declare -g -A LOG_CONFIGS
    declare -g -a LOG_FILES

    local current_log=""
    local line_num=0

    while IFS= read -r line; do
        ((line_num++))

        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Log file definition
        if [[ "$line" =~ ^[[:space:]]*([^[:space:]]+)[[:space:]]*\{[[:space:]]*$ ]]; then
            current_log="${BASH_REMATCH[1]}"
            LOG_FILES+=("$current_log")
            LOG_CONFIGS["${current_log}:maxsize"]="$DEFAULT_MAX_SIZE"
            LOG_CONFIGS["${current_log}:maxage"]="$DEFAULT_MAX_AGE"
            LOG_CONFIGS["${current_log}:retention"]="$DEFAULT_RETENTION"
            LOG_CONFIGS["${current_log}:compress"]="delayed"
            LOG_CONFIGS["${current_log}:signal"]=""
            LOG_CONFIGS["${current_log}:pidfile"]=""
            LOG_CONFIGS["${current_log}:postrotate"]=""
            continue
        fi

        # End of block
        if [[ "$line" =~ ^[[:space:]]*\}[[:space:]]*$ ]]; then
            current_log=""
            continue
        fi

        # Configuration directives
        if [[ -n "$current_log" ]]; then
            if [[ "$line" =~ ^[[:space:]]*maxsize[[:space:]]+([^[:space:]]+) ]]; then
                LOG_CONFIGS["${current_log}:maxsize"]="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*maxage[[:space:]]+([0-9]+) ]]; then
                LOG_CONFIGS["${current_log}:maxage"]="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*retention[[:space:]]+([0-9]+) ]]; then
                LOG_CONFIGS["${current_log}:retention"]="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*compress[[:space:]]+([^[:space:]]+) ]]; then
                LOG_CONFIGS["${current_log}:compress"]="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*signal[[:space:]]+([^[:space:]]+) ]]; then
                LOG_CONFIGS["${current_log}:signal"]="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*pidfile[[:space:]]+([^[:space:]]+) ]]; then
                LOG_CONFIGS["${current_log}:pidfile"]="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*postrotate[[:space:]]+(.+)$ ]]; then
                LOG_CONFIGS["${current_log}:postrotate"]="${BASH_REMATCH[1]}"
            fi
        fi
    done < "$config_file"

    log_success "Parsed ${#LOG_FILES[@]} log file configurations"
}

#===============================================================================
# Rotation Logic
#===============================================================================

needs_rotation() {
    local log_file="$1"
    local max_size="$2"
    local max_age="$3"

    if [[ ! -f "$log_file" ]]; then
        log_debug "Log file does not exist: $log_file"
        return 1
    fi

    # Check size
    local file_size
    file_size=$(get_file_size "$log_file")
    local max_size_bytes
    max_size_bytes=$(parse_size "$max_size")

    if ((file_size >= max_size_bytes)); then
        log_debug "Size threshold reached: $file_size >= $max_size_bytes"
        return 0
    fi

    # Check age
    local age_days
    age_days=$(get_file_age_days "$log_file")

    if ((age_days >= max_age)); then
        log_debug "Age threshold reached: ${age_days}d >= ${max_age}d"
        return 0
    fi

    return 1
}

rotate_log() {
    local log_file="$1"
    local signal="${2:-}"
    local pidfile="${3:-}"
    local postrotate="${4:-}"

    if [[ ! -f "$log_file" ]]; then
        log_warning "Log file not found: $log_file"
        return 1
    fi

    log_info "Rotating log: $log_file"

    # Generate timestamp-based name
    local timestamp
    timestamp=$(timestamp_filename)
    local rotated_name="${log_file}.${timestamp}"

    # Rotate the log (copy and truncate to preserve file descriptor)
    if ! cp -p "$log_file" "$rotated_name"; then
        log_error "Failed to copy log file"
        return 1
    fi

    if ! truncate -s 0 "$log_file"; then
        log_error "Failed to truncate log file"
        return 1
    fi

    log_success "Rotated: $log_file → $rotated_name"

    # Signal process if configured
    if [[ -n "$signal" && -n "$pidfile" ]]; then
        signal_process "$signal" "$pidfile"
    fi

    # Run postrotate hook
    if [[ -n "$postrotate" ]]; then
        log_info "Running postrotate hook: $postrotate"
        if eval "$postrotate" 2>&1 | tee -a /var/log/infra/log-rotation.log; then
            log_success "Postrotate hook completed"
        else
            log_warning "Postrotate hook failed (non-fatal)"
        fi
    fi

    # Record rotation in state file
    record_rotation "$log_file" "$rotated_name"

    echo "$rotated_name"
}

signal_process() {
    local signal="$1"
    local pidfile="$2"

    if [[ ! -f "$pidfile" ]]; then
        log_warning "PID file not found: $pidfile"
        return 1
    fi

    local pid
    pid=$(cat "$pidfile")

    if ! kill -0 "$pid" 2>/dev/null; then
        log_warning "Process not running (PID: $pid)"
        return 1
    fi

    log_info "Sending $signal to PID $pid"
    if kill -"$signal" "$pid" 2>/dev/null; then
        log_success "Signal sent successfully"
        return 0
    else
        log_error "Failed to send signal"
        return 1
    fi
}

record_rotation() {
    local log_file="$1"
    local rotated_name="$2"

    ensure_state_dir

    local state_file="${STATE_DIR}/$(basename "$log_file").state"
    local timestamp
    timestamp=$(timestamp_iso)

    local entry
    entry=$(cat << EOF
{
    "timestamp": "$timestamp",
    "original": "$log_file",
    "rotated": "$rotated_name",
    "size": $(get_file_size "$rotated_name")
}
EOF
)

    echo "$entry" >> "$state_file"
}

#===============================================================================
# Compression
#===============================================================================

setup_compression() {
    local compression_type="$1"

    case "$compression_type" in
        gzip)
            COMPRESSION_CMD="gzip -9"
            COMPRESSION_EXT=".gz"
            ;;
        bzip2)
            COMPRESSION_CMD="bzip2 -9"
            COMPRESSION_EXT=".bz2"
            ;;
        xz)
            COMPRESSION_CMD="xz -9"
            COMPRESSION_EXT=".xz"
            ;;
        zstd)
            COMPRESSION_CMD="zstd -19 --rm"
            COMPRESSION_EXT=".zst"
            ;;
        none)
            COMPRESSION_CMD=""
            COMPRESSION_EXT=""
            ;;
        *)
            log_warning "Unknown compression type: $compression_type, using gzip"
            COMPRESSION_CMD="gzip -9"
            COMPRESSION_EXT=".gz"
            ;;
    esac
}

compress_rotated_logs() {
    local directory="$1"
    local delay_days="${2:-$COMPRESSION_DELAY}"

    log_info "Compressing rotated logs older than ${delay_days} days in: $directory"

    if [[ -z "$COMPRESSION_CMD" ]]; then
        log_info "Compression disabled"
        return 0
    fi

    local count=0
    local now
    now=$(date +%s)
    local cutoff=$((now - delay_days * 86400))

    # Find rotated logs (by naming pattern)
    while IFS= read -r -d '' log_file; do
        # Skip if already compressed
        if [[ "$log_file" =~ \.(gz|bz2|xz|zst)$ ]]; then
            continue
        fi

        # Check if it's old enough
        local mtime
        mtime=$(stat -c %Y "$log_file" 2>/dev/null || stat -f %m "$log_file" 2>/dev/null)

        if ((mtime < cutoff)); then
            log_info "Compressing: $log_file"

            if eval "$COMPRESSION_CMD \"$log_file\"" 2>&1 | tee -a /var/log/infra/log-rotation.log; then
                ((count++))
                log_success "Compressed: $log_file"
            else
                log_error "Compression failed: $log_file"
            fi
        fi
    done < <(find "$directory" -type f -name "*.log.*[0-9]" -print0 2>/dev/null || true)

    log_success "Compressed $count log files"
}

#===============================================================================
# Retention Management
#===============================================================================

prune_old_logs() {
    local directory="$1"
    local retention_days="${2:-$DEFAULT_RETENTION}"

    log_info "Pruning logs older than ${retention_days} days in: $directory"

    local count=0
    local now
    now=$(date +%s)
    local cutoff=$((now - retention_days * 86400))

    # Find old rotated and compressed logs
    while IFS= read -r -d '' log_file; do
        local mtime
        mtime=$(stat -c %Y "$log_file" 2>/dev/null || stat -f %m "$log_file" 2>/dev/null)

        if ((mtime < cutoff)); then
            log_info "Removing: $log_file"

            if rm -f "$log_file"; then
                ((count++))
                log_success "Removed: $log_file"
            else
                log_error "Failed to remove: $log_file"
            fi
        fi
    done < <(find "$directory" -type f \( -name "*.log.*" -o -name "*.log.*.gz" -o -name "*.log.*.bz2" -o -name "*.log.*.xz" -o -name "*.log.*.zst" \) -print0 2>/dev/null || true)

    log_success "Removed $count old log files"
}

#===============================================================================
# Statistics
#===============================================================================

generate_statistics() {
    local directory="$1"

    log_info "Generating statistics for: $directory"

    # Count files by type
    local total_logs=0
    local compressed_logs=0
    local total_size=0
    local compressed_size=0

    while IFS= read -r -d '' log_file; do
        ((total_logs++))
        local size
        size=$(get_file_size "$log_file")
        ((total_size += size))

        if [[ "$log_file" =~ \.(gz|bz2|xz|zst)$ ]]; then
            ((compressed_logs++))
            ((compressed_size += size))
        fi
    done < <(find "$directory" -type f -name "*.log.*" -print0 2>/dev/null || true)

    # Calculate statistics
    local uncompressed_logs=$((total_logs - compressed_logs))
    local uncompressed_size=$((total_size - compressed_size))
    local compression_ratio="0"

    if ((compressed_logs > 0)); then
        compression_ratio=$(echo "scale=2; ($compressed_size * 100) / $total_size" | bc)
    fi

    # Generate report
    local report_json
    report_json=$(cat << EOF
{
    "timestamp": "$(timestamp_iso)",
    "directory": "$directory",
    "statistics": {
        "total_logs": $total_logs,
        "compressed_logs": $compressed_logs,
        "uncompressed_logs": $uncompressed_logs,
        "total_size_bytes": $total_size,
        "compressed_size_bytes": $compressed_size,
        "uncompressed_size_bytes": $uncompressed_size,
        "compression_ratio_percent": $compression_ratio,
        "total_size_human": "$(bytes_to_mb $total_size) MB",
        "compressed_size_human": "$(bytes_to_mb $compressed_size) MB",
        "uncompressed_size_human": "$(bytes_to_mb $uncompressed_size) MB"
    }
}
EOF
)

    echo "$report_json"

    # Also print human-readable summary
    echo ""
    log_info "=== Log Rotation Statistics ==="
    echo "Directory: $directory"
    echo "Total log files: $total_logs"
    echo "  - Compressed: $compressed_logs"
    echo "  - Uncompressed: $uncompressed_logs"
    echo "Total size: $(bytes_to_mb $total_size) MB"
    echo "  - Compressed: $(bytes_to_mb $compressed_size) MB (${compression_ratio}%)"
    echo "  - Uncompressed: $(bytes_to_mb $uncompressed_size) MB"
}

#===============================================================================
# Commands
#===============================================================================

cmd_rotate() {
    local config_file="${1:-$DEFAULT_CONFIG}"

    log_info "Starting log rotation with config: $config_file"

    # Parse configuration
    if ! parse_config "$config_file"; then
        log_error "Failed to parse configuration"
        return 1
    fi

    # Rotate each configured log
    local rotated_count=0
    for log_file in "${LOG_FILES[@]}"; do
        local max_size="${LOG_CONFIGS[${log_file}:maxsize]}"
        local max_age="${LOG_CONFIGS[${log_file}:maxage]}"
        local signal="${LOG_CONFIGS[${log_file}:signal]}"
        local pidfile="${LOG_CONFIGS[${log_file}:pidfile]}"
        local postrotate="${LOG_CONFIGS[${log_file}:postrotate]}"

        log_info "Checking: $log_file (maxsize=$max_size, maxage=$max_age)"

        if needs_rotation "$log_file" "$max_size" "$max_age"; then
            if rotate_log "$log_file" "$signal" "$pidfile" "$postrotate"; then
                ((rotated_count++))
            fi
        else
            log_debug "No rotation needed for: $log_file"
        fi
    done

    log_success "Rotation complete: $rotated_count logs rotated"
}

cmd_check() {
    local log_file="$1"
    local max_size="${2:-$DEFAULT_MAX_SIZE}"
    local max_age="${3:-$DEFAULT_MAX_AGE}"

    if [[ ! -f "$log_file" ]]; then
        log_error "Log file not found: $log_file"
        return 1
    fi

    log_info "Checking: $log_file"

    local file_size
    file_size=$(get_file_size "$log_file")
    local file_age
    file_age=$(get_file_age_days "$log_file")

    local max_size_bytes
    max_size_bytes=$(parse_size "$max_size")

    echo "File: $log_file"
    echo "Size: $(bytes_to_mb $file_size) MB (threshold: $max_size)"
    echo "Age: ${file_age} days (threshold: ${max_age} days)"

    if needs_rotation "$log_file" "$max_size" "$max_age"; then
        log_warning "Rotation NEEDED"
        return 0
    else
        log_success "Rotation not needed"
        return 1
    fi
}

cmd_compress() {
    local directory="$1"
    local delay="${2:-$COMPRESSION_DELAY}"

    if [[ ! -d "$directory" ]]; then
        log_error "Directory not found: $directory"
        return 1
    fi

    setup_compression "$COMPRESSION"
    compress_rotated_logs "$directory" "$delay"
}

cmd_prune() {
    local directory="$1"
    local retention="${2:-$DEFAULT_RETENTION}"

    if [[ ! -d "$directory" ]]; then
        log_error "Directory not found: $directory"
        return 1
    fi

    prune_old_logs "$directory" "$retention"
}

cmd_stats() {
    local directory="${1:-.}"

    if [[ ! -d "$directory" ]]; then
        log_error "Directory not found: $directory"
        return 1
    fi

    generate_statistics "$directory"
}

cmd_generate_config() {
    cat << 'EOF'
# Log Rotation Configuration Example
# Format:
#   /path/to/logfile {
#       maxsize 100M
#       maxage 7
#       retention 90
#       compress gzip
#       signal HUP
#       pidfile /var/run/service.pid
#       postrotate systemctl reload nginx
#   }

/var/log/nginx/access.log {
    maxsize 100M
    maxage 7
    retention 90
    compress gzip
    signal HUP
    pidfile /var/run/nginx.pid
    postrotate systemctl reload nginx
}

/var/log/nginx/error.log {
    maxsize 50M
    maxage 7
    retention 90
    compress gzip
    signal HUP
    pidfile /var/run/nginx.pid
}

/var/log/application/app.log {
    maxsize 200M
    maxage 1
    retention 30
    compress zstd
    signal USR1
    pidfile /var/run/app.pid
}

/var/log/mysql/slow-query.log {
    maxsize 500M
    maxage 7
    retention 60
    compress xz
    postrotate mysqladmin flush-logs
}
EOF
}

#===============================================================================
# Usage
#===============================================================================

usage() {
    cat << EOF
Usage: $SCRIPT_NAME <command> [options]

Advanced log rotation and compression management.

Commands:
    rotate [config]        Rotate logs using configuration file
                           Default: $DEFAULT_CONFIG

    check <file> [size] [age]
                           Check if a log file needs rotation
                           size: Max size (e.g., 100M, 1G)
                           age: Max age in days

    compress <dir> [delay] Compress rotated logs in directory
                           delay: Days to wait before compression (default: $COMPRESSION_DELAY)

    prune <dir> [retention]
                           Remove logs older than retention period
                           retention: Days to keep (default: $DEFAULT_RETENTION)

    stats <dir>            Generate rotation statistics for directory

    generate-config        Print example configuration file

Environment Variables:
    LOG_COMPRESSION        Compression type: gzip, bzip2, xz, zstd, none
    COMPRESSION_DELAY      Days to wait before compressing (default: 1)

Examples:
    # Rotate all logs per config
    $SCRIPT_NAME rotate /etc/logrotate-custom.conf

    # Check if specific log needs rotation
    $SCRIPT_NAME check /var/log/app.log 100M 7

    # Compress rotated logs older than 2 days
    $SCRIPT_NAME compress /var/log 2

    # Remove logs older than 60 days
    $SCRIPT_NAME prune /var/log 60

    # Show statistics
    $SCRIPT_NAME stats /var/log

Configuration File Format:
    See: $SCRIPT_NAME generate-config

EOF
}

#===============================================================================
# Main Entry Point
#===============================================================================

main() {
    local command="${1:-help}"

    case "$command" in
        rotate)
            shift
            cmd_rotate "$@"
            ;;
        check)
            shift
            if [[ $# -lt 1 ]]; then
                log_error "Missing log file argument"
                usage
                exit 1
            fi
            cmd_check "$@"
            ;;
        compress)
            shift
            if [[ $# -lt 1 ]]; then
                log_error "Missing directory argument"
                usage
                exit 1
            fi
            cmd_compress "$@"
            ;;
        prune)
            shift
            if [[ $# -lt 1 ]]; then
                log_error "Missing directory argument"
                usage
                exit 1
            fi
            cmd_prune "$@"
            ;;
        stats)
            shift
            cmd_stats "$@"
            ;;
        generate-config)
            cmd_generate_config
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Allow sourcing for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
