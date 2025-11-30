#!/bin/bash
#===============================================================================
# [SCRIPT_NAME] - [Brief Description]
#
# Purpose:
#   [Detailed description of what this script does]
#
# Usage:
#   [script-name].sh [OPTIONS] [ARGUMENTS]
#
# Examples:
#   [script-name].sh --help
#   [script-name].sh --verbose
#
# Skills Demonstrated:
#   - [Skill 1: e.g., Associative arrays]
#   - [Skill 2: e.g., Error handling]
#   - [Skill 3: e.g., JSON generation]
#
# Author: [Your Name]
# License: MIT
#===============================================================================

set -euo pipefail

#===============================================================================
# Configuration
#===============================================================================

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly SCRIPT_VERSION="1.0.0"

# Configuration via environment variables with defaults
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"
readonly LOG_FILE="${LOG_FILE:-/var/log/${SCRIPT_NAME%.*}.log}"
readonly REPORT_DIR="${REPORT_DIR:-/var/reports}"

# Thresholds and limits
readonly MAX_RETRIES="${MAX_RETRIES:-3}"
readonly TIMEOUT="${TIMEOUT:-30}"

#===============================================================================
# Colors & Logging
#===============================================================================

# Color codes for terminal output
declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [PURPLE]='\033[0;35m'
    [CYAN]='\033[0;36m'
    [NC]='\033[0m'  # No Color
)

# Logging function with levels and colors
log() {
    local level=$1
    shift
    local color="${COLORS[NC]}"

    case $level in
        INFO)   color="${COLORS[BLUE]}" ;;
        OK)     color="${COLORS[GREEN]}" ;;
        WARN)   color="${COLORS[YELLOW]}" ;;
        ERROR)  color="${COLORS[RED]}" ;;
        DEBUG)  color="${COLORS[PURPLE]}" ;;
    esac

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${color}[$timestamp] [$level] $*${COLORS[NC]}"

    # Also write to log file if it's writable
    if [[ -w "$(dirname "$LOG_FILE")" ]] 2>/dev/null; then
        echo "[$timestamp] [$level] $*" >> "$LOG_FILE"
    fi
}

# Convenience logging functions
info()  { log "INFO" "$*"; }
ok()    { log "OK" "$*"; }
warn()  { log "WARN" "$*"; }
error() { log "ERROR" "$*" >&2; }
debug() { [[ "${DEBUG:-0}" == "1" ]] && log "DEBUG" "$*"; }

#===============================================================================
# Utility Functions
#===============================================================================

# Show usage information
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] [ARGUMENTS]

[Description of what the script does]

Options:
    -h, --help          Show this help message and exit
    -v, --verbose       Enable verbose output
    -V, --version       Show version information
    -d, --dry-run       Show what would be done without making changes
    -c, --config FILE   Use specified configuration file

Arguments:
    [ARGUMENT]          [Description of argument]

Environment Variables:
    LOG_LEVEL           Logging level (default: INFO)
    LOG_FILE            Log file path (default: /var/log/${SCRIPT_NAME%.*}.log)
    REPORT_DIR          Report output directory (default: /var/reports)
    DEBUG               Enable debug output (set to 1)

Examples:
    # Basic usage
    $SCRIPT_NAME

    # With verbose output
    $SCRIPT_NAME --verbose

    # Dry run mode
    $SCRIPT_NAME --dry-run

Exit Codes:
    0   Success
    1   General error
    2   Invalid arguments
    3   Missing dependencies

EOF
}

# Show version information
version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION"
}

# Check if required commands are available
check_dependencies() {
    local deps=("curl" "jq")  # Add required commands here
    local missing=()

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required commands: ${missing[*]}"
        error "Please install them and try again"
        return 3
    fi

    debug "All dependencies found"
}

# Cleanup function - runs on exit
cleanup() {
    local exit_code=$?

    # Remove temporary files
    if [[ -n "${TMPDIR:-}" ]] && [[ -d "$TMPDIR" ]]; then
        rm -rf "$TMPDIR"
        debug "Cleaned up temp directory: $TMPDIR"
    fi

    # Add any other cleanup tasks here

    debug "Cleanup complete (exit code: $exit_code)"
}

# Set up signal handlers
trap cleanup EXIT
trap 'error "Interrupted"; exit 130' INT
trap 'error "Terminated"; exit 143' TERM

#===============================================================================
# Core Functions
#===============================================================================

# Initialize script - create directories, validate environment
initialize() {
    info "Initializing $SCRIPT_NAME..."

    # Create report directory if needed
    if [[ ! -d "$REPORT_DIR" ]]; then
        mkdir -p "$REPORT_DIR"
        debug "Created report directory: $REPORT_DIR"
    fi

    # Create temporary directory
    TMPDIR=$(mktemp -d)
    debug "Created temp directory: $TMPDIR"

    # Check dependencies
    check_dependencies

    ok "Initialization complete"
}

# Main processing function - replace with actual logic
process() {
    info "Starting main processing..."

    # Example: Process with progress
    local items=("item1" "item2" "item3")
    local total=${#items[@]}
    local current=0

    for item in "${items[@]}"; do
        ((current++))
        info "Processing $item ($current/$total)..."

        # Add your processing logic here
        sleep 0.5  # Placeholder

        ok "Processed: $item"
    done

    ok "Processing complete"
}

# Generate report - example JSON output
generate_report() {
    local report_file="${REPORT_DIR}/report_$(date +%Y%m%d_%H%M%S).json"

    info "Generating report: $report_file"

    cat > "$report_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "script": "$SCRIPT_NAME",
    "version": "$SCRIPT_VERSION",
    "hostname": "$(hostname)",
    "status": "success",
    "data": {
        "example_key": "example_value"
    }
}
EOF

    ok "Report saved: $report_file"
}

#===============================================================================
# Main
#===============================================================================

main() {
    local verbose=0
    local dry_run=0
    local config_file=""

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -V|--version)
                version
                exit 0
                ;;
            -v|--verbose)
                verbose=1
                export DEBUG=1
                shift
                ;;
            -d|--dry-run)
                dry_run=1
                shift
                ;;
            -c|--config)
                config_file="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            -*)
                error "Unknown option: $1"
                usage
                exit 2
                ;;
            *)
                # Positional argument
                break
                ;;
        esac
    done

    # Load config file if specified
    if [[ -n "$config_file" ]]; then
        if [[ -f "$config_file" ]]; then
            # shellcheck source=/dev/null
            source "$config_file"
            info "Loaded config: $config_file"
        else
            error "Config file not found: $config_file"
            exit 1
        fi
    fi

    info "========================================="
    info "$SCRIPT_NAME v$SCRIPT_VERSION"
    info "========================================="

    # Check if running as root (if required)
    # if [[ $EUID -ne 0 ]]; then
    #     error "This script must be run as root"
    #     exit 1
    # fi

    # Dry run notice
    if [[ $dry_run -eq 1 ]]; then
        warn "DRY RUN MODE - No changes will be made"
    fi

    # Initialize
    initialize

    # Main processing
    process

    # Generate report
    generate_report

    info "========================================="
    ok "$SCRIPT_NAME completed successfully!"
    info "========================================="
}

# Run main function if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
