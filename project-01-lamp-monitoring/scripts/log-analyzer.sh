#!/bin/bash
#===============================================================================
# Log Analyzer - Real-time Nginx & PHP-FPM Log Analysis Tool
#
# Purpose:
#   Analyzes Nginx access logs, calculates statistics, generates JSON reports,
#   and sends alerts when error rates exceed configured thresholds.
#
# Usage:
#   log-analyzer.sh [OPTIONS]
#
# Skills Demonstrated:
#   - Associative arrays (declare -A)
#   - Process substitution and redirection
#   - Regex pattern matching (grep -oP)
#   - AWK field extraction
#   - bc floating point calculations
#   - JSON generation with heredocs
#   - Conditional alerting logic
#   - Webhook integration
#
# Author: Linux Sysadmin Portfolio
# License: MIT
#===============================================================================

set -euo pipefail

#===============================================================================
# Configuration
#===============================================================================

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_VERSION="1.0.0"

# Paths
readonly LOG_DIR="${LOG_DIR:-/var/log/nginx}"
readonly ACCESS_LOG="${ACCESS_LOG:-${LOG_DIR}/access.log}"
readonly ERROR_LOG="${ERROR_LOG:-${LOG_DIR}/error.log}"
readonly REPORT_DIR="${REPORT_DIR:-/var/reports}"

# Thresholds
readonly ERROR_THRESHOLD="${ERROR_THRESHOLD:-5.0}"
readonly WARNING_THRESHOLD="${WARNING_THRESHOLD:-2.0}"

# Timestamp for reports
readonly DATE_FORMAT=$(date +%Y-%m-%d_%H-%M-%S)

#===============================================================================
# Colors & Logging
#===============================================================================

declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [NC]='\033[0m'
)

log() {
    local level=$1
    shift
    echo -e "${COLORS[$level]}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*${COLORS[NC]}"
}

#===============================================================================
# Data Structures
#===============================================================================

# Associative arrays for aggregation
declare -A STATUS_CATEGORIES=(
    [2xx]=0 [3xx]=0 [4xx]=0 [5xx]=0
)
declare -A ip_counts
declare -A endpoint_counts
declare -A hourly_traffic

#===============================================================================
# Core Analysis Functions
#===============================================================================

analyze_access_logs() {
    log "BLUE" "Analyzing access logs: $ACCESS_LOG"

    if [[ ! -f "$ACCESS_LOG" ]]; then
        log "RED" "Access log not found: $ACCESS_LOG"
        return 1
    fi

    local total_requests=0
    local -A method_counts

    while IFS= read -r line; do
        ((total_requests++))

        # Extract IP address (first field)
        local ip=$(echo "$line" | awk '{print $1}')
        ((ip_counts[$ip]++))

        # Extract endpoint (path from request)
        local endpoint=$(echo "$line" | awk '{print $7}' | cut -d'?' -f1)
        ((endpoint_counts[$endpoint]++))

        # Extract HTTP method
        local method=$(echo "$line" | awk '{print $6}' | tr -d '"')
        ((method_counts[$method]++))

        # Extract HTTP status code
        local status=$(echo "$line" | awk '{print $9}')
        case $status in
            2[0-9][0-9]) ((STATUS_CATEGORIES[2xx]++)) ;;
            3[0-9][0-9]) ((STATUS_CATEGORIES[3xx]++)) ;;
            4[0-9][0-9]) ((STATUS_CATEGORIES[4xx]++)) ;;
            5[0-9][0-9]) ((STATUS_CATEGORIES[5xx]++)) ;;
        esac

        # Extract hour for traffic analysis
        local hour=$(echo "$line" | grep -oP '\d{2}(?=:\d{2}:\d{2})' | head -1)
        if [[ -n "$hour" ]]; then
            ((hourly_traffic[$hour]++))
        fi

    done < "$ACCESS_LOG"

    log "GREEN" "Analyzed $total_requests requests"

    # Generate statistics report
    generate_report "$total_requests"
}

analyze_error_logs() {
    log "BLUE" "Analyzing error logs: $ERROR_LOG"

    if [[ ! -f "$ERROR_LOG" ]]; then
        log "YELLOW" "Error log not found: $ERROR_LOG (may be empty)"
        return 0
    fi

    local error_count
    error_count=$(wc -l < "$ERROR_LOG" 2>/dev/null || echo 0)

    log "GREEN" "Found $error_count error log entries"

    # Count error types
    local -A error_types
    while IFS= read -r line; do
        if [[ "$line" =~ \[error\] ]]; then
            ((error_types[error]++))
        elif [[ "$line" =~ \[warn\] ]]; then
            ((error_types[warn]++))
        elif [[ "$line" =~ \[crit\] ]]; then
            ((error_types[crit]++))
        fi
    done < "$ERROR_LOG"

    # Log error type breakdown
    for type in "${!error_types[@]}"; do
        log "BLUE" "  $type: ${error_types[$type]}"
    done
}

generate_report() {
    local total=$1
    local report_file="${REPORT_DIR}/analysis_${DATE_FORMAT}.json"

    mkdir -p "$REPORT_DIR"

    log "BLUE" "Generating JSON report..."

    # Calculate error rate
    local error_rate=0
    if [[ $total -gt 0 ]]; then
        error_rate=$(echo "scale=2; ${STATUS_CATEGORIES[5xx]} * 100 / $total" | bc)
    fi

    # Get top 5 IPs
    local top_ips
    top_ips=$(for ip in "${!ip_counts[@]}"; do
        echo "${ip_counts[$ip]} $ip"
    done | sort -rn | head -5 | awk '{print "\"" $2 "\": " $1}' | paste -sd,)

    # Get top 5 endpoints
    local top_endpoints
    top_endpoints=$(for endpoint in "${!endpoint_counts[@]}"; do
        echo "${endpoint_counts[$endpoint]} $endpoint"
    done | sort -rn | head -5 | awk '{print "\"" $2 "\": " $1}' | paste -sd,)

    # Generate JSON report using heredoc
    cat > "$report_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "analysis_period": {
        "start": "$(head -1 "$ACCESS_LOG" 2>/dev/null | awk '{print $4}' | tr -d '[')",
        "end": "$(tail -1 "$ACCESS_LOG" 2>/dev/null | awk '{print $4}' | tr -d '[')"
    },
    "summary": {
        "total_requests": $total,
        "unique_ips": ${#ip_counts[@]},
        "unique_endpoints": ${#endpoint_counts[@]}
    },
    "status_codes": {
        "success_2xx": ${STATUS_CATEGORIES[2xx]},
        "redirect_3xx": ${STATUS_CATEGORIES[3xx]},
        "client_error_4xx": ${STATUS_CATEGORIES[4xx]},
        "server_error_5xx": ${STATUS_CATEGORIES[5xx]}
    },
    "metrics": {
        "error_rate_percent": $error_rate,
        "success_rate_percent": $(echo "scale=2; ${STATUS_CATEGORIES[2xx]} * 100 / $total" | bc)
    },
    "top_ips": {
        $top_ips
    },
    "top_endpoints": {
        $top_endpoints
    },
    "hourly_traffic": {
$(for hour in $(echo "${!hourly_traffic[@]}" | tr ' ' '\n' | sort -n); do
    echo "        \"$hour:00\": ${hourly_traffic[$hour]},"
done | sed '$ s/,$//')
    }
}
EOF

    log "GREEN" "Report generated: $report_file"

    # Display summary
    echo ""
    log "BLUE" "=== Analysis Summary ==="
    log "GREEN" "Total Requests: $total"
    log "GREEN" "Success (2xx): ${STATUS_CATEGORIES[2xx]}"
    log "YELLOW" "Client Errors (4xx): ${STATUS_CATEGORIES[4xx]}"
    log "RED" "Server Errors (5xx): ${STATUS_CATEGORIES[5xx]}"
    log "BLUE" "Error Rate: ${error_rate}%"
    echo ""

    # Check thresholds and alert if necessary
    check_thresholds "$error_rate"
}

check_thresholds() {
    local error_rate=$1

    if (( $(echo "$error_rate >= $ERROR_THRESHOLD" | bc -l) )); then
        log "RED" "CRITICAL: Error rate ${error_rate}% exceeds critical threshold ${ERROR_THRESHOLD}%"
        send_alert "CRITICAL" "Error rate ${error_rate}% exceeds threshold"
        return 2
    elif (( $(echo "$error_rate >= $WARNING_THRESHOLD" | bc -l) )); then
        log "YELLOW" "WARNING: Error rate ${error_rate}% exceeds warning threshold ${WARNING_THRESHOLD}%"
        send_alert "WARNING" "Error rate ${error_rate}% approaching threshold"
        return 1
    else
        log "GREEN" "Error rate within acceptable limits"
        return 0
    fi
}

send_alert() {
    local severity=$1
    local message=$2

    log "BLUE" "Sending alert: [$severity] $message"

    # Webhook integration (if configured)
    if [[ -n "${WEBHOOK_URL:-}" ]]; then
        local payload
        payload=$(cat << EOF
{
    "severity": "$severity",
    "message": "$message",
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "service": "log-analyzer"
}
EOF
)

        if curl -s -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "$payload" >/dev/null 2>&1; then
            log "GREEN" "Alert sent successfully"
        else
            log "RED" "Failed to send webhook alert"
        fi
    else
        log "YELLOW" "No webhook URL configured (set WEBHOOK_URL environment variable)"
    fi
}

#===============================================================================
# Main Execution
#===============================================================================

main() {
    log "GREEN" "========================================="
    log "GREEN" "Log Analyzer v$SCRIPT_VERSION"
    log "GREEN" "========================================="

    # Validate access log exists
    if [[ ! -f "$ACCESS_LOG" ]]; then
        log "RED" "Access log not found: $ACCESS_LOG"
        log "YELLOW" "Generate some traffic: curl http://localhost"
        exit 1
    fi

    # Run analysis
    analyze_access_logs
    analyze_error_logs

    log "GREEN" "========================================="
    log "GREEN" "Analysis complete!"
    log "GREEN" "========================================="
}

# Run main if executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
