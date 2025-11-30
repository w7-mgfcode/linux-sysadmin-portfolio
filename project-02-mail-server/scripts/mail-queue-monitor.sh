#!/bin/bash
#===============================================================================
# Mail Queue Monitor - Real-time Postfix Queue Analysis & Alerting
#
# Purpose:
#   Monitors Postfix mail queue with daemon mode support, analyzes deferred
#   messages, categorizes bounce reasons, and sends threshold-based alerts.
#
# Usage:
#   ./mail-queue-monitor.sh           # One-shot mode
#   ./mail-queue-monitor.sh daemon    # Daemon mode (background)
#   ./mail-queue-monitor.sh status    # Check daemon status
#
# Skills Demonstrated:
#   - Daemon mode with signal handling (SIGTERM, SIGINT, SIGHUP)
#   - PID file management
#   - Mail queue parsing (mailq, postcat, postqueue commands)
#   - Associative arrays for data categorization
#   - Process substitution and background job management
#   - Threshold-based alerting system
#   - JSON report generation
#   - Advanced error handling
#
# Author: Linux Sysadmin Portfolio
# License: MIT
#===============================================================================

set -euo pipefail

#===============================================================================
# Configuration
#===============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"

# Source common library
# shellcheck source=./lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Queue thresholds
readonly QUEUE_WARNING_THRESHOLD="${QUEUE_WARNING:-50}"
readonly QUEUE_CRITICAL_THRESHOLD="${QUEUE_CRITICAL:-200}"
readonly DEFERRED_WARNING_THRESHOLD="${DEFERRED_WARNING:-25}"

# Daemon settings
readonly CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
readonly PID_FILE="${PID_FILE:-/var/run/mail-queue-monitor.pid}"
readonly LOG_FILE="${LOG_FILE:-/var/log/mail-queue-monitor.log}"

# Alert settings
readonly MAIL_ADMIN="${MAIL_ADMIN:-admin@localhost}"
readonly ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"
readonly ALERT_COOLDOWN="${ALERT_COOLDOWN:-300}"

# Paths
readonly POSTFIX_QUEUE="${POSTFIX_QUEUE:-/var/spool/postfix}"
readonly REPORT_DIR="${REPORT_DIR:-/var/reports}"

# Global state
declare -i running=1
declare -i last_alert_time=0
declare -A queue_stats=(
    [total]=0
    [active]=0
    [deferred]=0
    [hold]=0
    [size_bytes]=0
    [oldest_hours]=0
)

#===============================================================================
# Signal Handlers
#===============================================================================

handle_sigterm() {
    log_info "Received SIGTERM, shutting down gracefully..."
    running=0
}

handle_sigint() {
    log_info "Received SIGINT, shutting down immediately..."
    running=0
}

handle_sighup() {
    log_info "Received SIGHUP, reloading configuration..."
    # Reload configuration if needed
}

setup_signals() {
    trap 'handle_sigterm' SIGTERM
    trap 'handle_sigint' SIGINT
    trap 'handle_sighup' SIGHUP
}

#===============================================================================
# PID File Management
#===============================================================================

create_pid_file() {
    if [[ -f "$PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            log_error "Daemon already running with PID $old_pid"
            return 1
        else
            log_warning "Stale PID file found, removing..."
            rm -f "$PID_FILE"
        fi
    fi

    echo $$ > "$PID_FILE"
    log_success "PID file created: $PID_FILE"
}

remove_pid_file() {
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
        log_info "PID file removed"
    fi
}

check_running() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "Daemon is not running (no PID file)"
        return 1
    fi

    local pid
    pid=$(cat "$PID_FILE")

    if kill -0 "$pid" 2>/dev/null; then
        echo "Daemon is running (PID: $pid)"
        return 0
    else
        echo "Daemon is not running (stale PID file)"
        return 1
    fi
}

#===============================================================================
# Queue Statistics Functions
#===============================================================================

get_queue_stats() {
    log_info "Gathering queue statistics..."

    # Reset counters
    queue_stats[total]=0
    queue_stats[active]=0
    queue_stats[deferred]=0
    queue_stats[hold]=0

    # Get mailq output
    local mailq_output
    mailq_output=$(postfix_exec mailq 2>/dev/null || echo "Mail queue is empty")

    if [[ "$mailq_output" == *"Mail queue is empty"* ]]; then
        log_success "Mail queue is empty"
        return 0
    fi

    # Count total messages
    queue_stats[total]=$(echo "$mailq_output" | grep -c "^[A-F0-9]" || echo 0)

    # Count by queue type (if accessible)
    if [[ -d "$POSTFIX_QUEUE" ]]; then
        queue_stats[active]=$(find "$POSTFIX_QUEUE/active" -type f 2>/dev/null | wc -l)
        queue_stats[deferred]=$(find "$POSTFIX_QUEUE/deferred" -type f 2>/dev/null | wc -l)
        queue_stats[hold]=$(find "$POSTFIX_QUEUE/hold" -type f 2>/dev/null | wc -l)
    fi

    # Calculate queue age
    calculate_queue_age

    # Calculate total size
    if [[ -d "$POSTFIX_QUEUE" ]]; then
        queue_stats[size_bytes]=$(du -sb "$POSTFIX_QUEUE" 2>/dev/null | awk '{print $1}')
    fi

    log_info "Queue stats: total=${queue_stats[total]}, active=${queue_stats[active]}, deferred=${queue_stats[deferred]}, hold=${queue_stats[hold]}"
}

calculate_queue_age() {
    if [[ ! -d "$POSTFIX_QUEUE/deferred" ]]; then
        queue_stats[oldest_hours]=0
        return
    fi

    local oldest_file
    oldest_file=$(find "$POSTFIX_QUEUE/deferred" -type f -printf '%T@\n' 2>/dev/null | sort -n | head -1)

    if [[ -n "$oldest_file" ]]; then
        local now
        now=$(date +%s)
        local age_seconds=$((now - ${oldest_file%.*}))
        queue_stats[oldest_hours]=$((age_seconds / 3600))
    else
        queue_stats[oldest_hours]=0
    fi
}

#===============================================================================
# Deferred Queue Analysis
#===============================================================================

analyze_deferred() {
    log_info "Analyzing deferred queue..."

    if ((queue_stats[deferred] == 0)); then
        log_info "No deferred messages"
        return
    fi

    declare -A bounce_reasons=(
        [spam_block_4_7_x]=0
        [connection_timeout_4_4_2]=0
        [mailbox_full_4_2_2]=0
        [user_unknown_5_1_1]=0
        [other]=0
    )

    # Parse deferred queue for bounce reasons
    local mailq_output
    mailq_output=$(postfix_exec mailq 2>/dev/null)

    while IFS= read -r queue_id; do
        # Remove special characters
        queue_id=$(echo "$queue_id" | awk '{print $1}' | tr -d '*!')

        # Get queue file details
        local queue_details
        queue_details=$(postfix_exec postcat -q "$queue_id" 2>/dev/null || echo "")

        if [[ -z "$queue_details" ]]; then
            continue
        fi

        # Extract DSN code
        local dsn_code
        dsn_code=$(echo "$queue_details" | grep -oP 'dsn=\K[0-9]\.[0-9]\.[0-9]' | head -1)

        # Categorize bounce reason
        case "$dsn_code" in
            4.7.*) ((bounce_reasons[spam_block_4_7_x]++)) ;;
            4.4.2) ((bounce_reasons[connection_timeout_4_4_2]++)) ;;
            4.2.2) ((bounce_reasons[mailbox_full_4_2_2]++)) ;;
            5.1.1) ((bounce_reasons[user_unknown_5_1_1]++)) ;;
            *)     ((bounce_reasons[other]++)) ;;
        esac
    done < <(echo "$mailq_output" | grep "^[A-F0-9]" | head -20)

    # Log analysis results
    for reason in "${!bounce_reasons[@]}"; do
        if ((bounce_reasons[$reason] > 0)); then
            log_info "  $reason: ${bounce_reasons[$reason]}"
        fi
    done
}

#===============================================================================
# Alerting Functions
#===============================================================================

check_thresholds() {
    local total=${queue_stats[total]}
    local deferred=${queue_stats[deferred]}

    if ((total >= QUEUE_CRITICAL_THRESHOLD)); then
        send_alert "CRITICAL" "Queue size $total exceeds critical threshold $QUEUE_CRITICAL_THRESHOLD"
        return 2
    elif ((total >= QUEUE_WARNING_THRESHOLD)); then
        send_alert "WARNING" "Queue size $total exceeds warning threshold $QUEUE_WARNING_THRESHOLD"
        return 1
    elif ((deferred >= DEFERRED_WARNING_THRESHOLD)); then
        send_alert "WARNING" "Deferred queue $deferred exceeds warning threshold $DEFERRED_WARNING_THRESHOLD"
        return 1
    fi

    return 0
}

send_alert() {
    local severity="$1"
    local message="$2"

    # Check cooldown
    local now
    now=$(date +%s)
    if ((now - last_alert_time < ALERT_COOLDOWN)); then
        log_warning "Alert cooldown active, skipping alert"
        return
    fi

    log_warning "ALERT [$severity]: $message"
    last_alert_time=$now

    # Send webhook if configured
    if [[ -n "$ALERT_WEBHOOK" ]]; then
        local payload
        payload=$(cat << EOF
{
    "severity": "$severity",
    "message": "$message",
    "timestamp": "$(timestamp_iso)",
    "hostname": "$(hostname)",
    "queue_stats": {
        "total": ${queue_stats[total]},
        "active": ${queue_stats[active]},
        "deferred": ${queue_stats[deferred]},
        "hold": ${queue_stats[hold]}
    }
}
EOF
)
        curl -s -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "$payload" || log_error "Failed to send webhook alert"
    fi

    # Send email if mail command available
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "[$severity] Mail Queue Alert - $(hostname)" "$MAIL_ADMIN" 2>/dev/null || true
    fi
}

#===============================================================================
# Report Generation
#===============================================================================

generate_report() {
    ensure_directory "$REPORT_DIR"

    local report_file="${REPORT_DIR}/mail-queue-$(timestamp_filename).json"
    local latest_link="${REPORT_DIR}/mail-queue-latest.json"

    cat > "$report_file" << EOF
{
    "timestamp": "$(timestamp_iso)",
    "hostname": "$(hostname)",
    "script": "$SCRIPT_NAME",
    "queue": {
        "total": ${queue_stats[total]},
        "active": ${queue_stats[active]},
        "deferred": ${queue_stats[deferred]},
        "hold": ${queue_stats[hold]},
        "size_mb": $(bytes_to_mb ${queue_stats[size_bytes]}),
        "oldest_hours": ${queue_stats[oldest_hours]}
    },
    "thresholds": {
        "warning": $QUEUE_WARNING_THRESHOLD,
        "critical": $QUEUE_CRITICAL_THRESHOLD,
        "deferred_warning": $DEFERRED_WARNING_THRESHOLD
    },
    "status": "$(determine_status)"
}
EOF

    # Create/update latest symlink
    ln -sf "$report_file" "$latest_link"

    log_success "Report generated: $report_file"
}

determine_status() {
    local total=${queue_stats[total]}
    local deferred=${queue_stats[deferred]}

    if ((total >= QUEUE_CRITICAL_THRESHOLD)); then
        echo "critical"
    elif ((total >= QUEUE_WARNING_THRESHOLD)) || ((deferred >= DEFERRED_WARNING_THRESHOLD)); then
        echo "warning"
    else
        echo "ok"
    fi
}

display_summary() {
    echo "===================================="
    echo "  Mail Queue Status"
    echo "===================================="
    echo "  Total:    ${queue_stats[total]}"
    echo "  Active:   ${queue_stats[active]}"
    echo "  Deferred: ${queue_stats[deferred]}"
    echo "  Hold:     ${queue_stats[hold]}"
    echo "  Oldest:   ${queue_stats[oldest_hours]} hours"
    echo "===================================="
}

#===============================================================================
# Main Execution Modes
#===============================================================================

run_once() {
    log_info "Running in one-shot mode..."
    get_queue_stats
    analyze_deferred
    check_thresholds || true
    generate_report
    display_summary
}

run_daemon() {
    log_info "Starting daemon mode..."
    setup_signals

    if ! create_pid_file; then
        exit 1
    fi

    log_success "Daemon started (PID: $$)"

    while ((running)); do
        get_queue_stats
        check_thresholds || true
        generate_report

        # Sleep in background so signals work
        sleep "$CHECK_INTERVAL" &
        wait $! || true
    done

    remove_pid_file
    log_success "Daemon stopped"
}

run_status() {
    check_running
}

#===============================================================================
# Main
#===============================================================================

main() {
    local mode="${1:-once}"

    case "$mode" in
        daemon)
            run_daemon
            ;;
        once)
            run_once
            ;;
        status)
            run_status
            ;;
        *)
            echo "Usage: $0 {daemon|once|status}"
            echo "  daemon - Run as background daemon"
            echo "  once   - Run once and exit (default)"
            echo "  status - Check daemon status"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
