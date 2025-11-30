#!/bin/bash
#===============================================================================
# Spam Report - SpamAssassin Statistics and Visualization
#
# Purpose:
#   Parse SpamAssassin logs to generate statistics, identify top spammers,
#   calculate detection rates, and create visual reports with ASCII charts.
#
# Usage:
#   ./spam-report.sh --period today      # Today's statistics
#   ./spam-report.sh --period week       # Last 7 days
#   ./spam-report.sh --json              # JSON output only
#
# Skills Demonstrated:
#   - Log parsing with awk and grep
#   - Spam score analysis and histogram generation
#   - Data aggregation (top spammers by IP/domain)
#   - ASCII bar chart visualization
#   - Time-series data processing
#   - JSON report generation
#
# Author: Linux Sysadmin Portfolio
# License: MIT
#===============================================================================

set -euo pipefail

#===============================================================================
# Configuration
#===============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common library
# shellcheck source=./lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

readonly MAIL_LOG="${MAIL_LOG:-/var/log/mail/mail.log}"
readonly REPORT_DIR="${REPORT_DIR:-/var/reports}"
readonly SPAM_THRESHOLD="${SPAM_THRESHOLD:-5.0}"
readonly TOP_N="${TOP_N:-10}"

# Statistics storage
declare -i total_messages=0
declare -i spam_detected=0
declare -i ham_detected=0
declare -A score_buckets=(
    [0-1]=0
    [1-2]=0
    [2-5]=0
    [5-10]=0
    [10+]=0
)
declare -A top_spammers=()

#===============================================================================
# Log Parsing Functions
#===============================================================================

parse_spam_logs() {
    local period="${1:-today}"
    local date_filter=""

    log_info "Parsing SpamAssassin logs ($period)..."

    # Determine date filter
    case "$period" in
        today)
            date_filter=$(date +"%b %d")
            ;;
        week)
            # Last 7 days - more complex, parse all recent
            date_filter=""
            ;;
        *)
            date_filter=$(date +"%b %d")
            ;;
    esac

    # Parse mail log for SpamAssassin entries
    if [[ ! -f "$MAIL_LOG" ]]; then
        log_warning "Mail log not found: $MAIL_LOG"
        return 1
    fi

    while IFS= read -r line; do
        # Extract spam score
        local score
        score=$(echo "$line" | grep -oP 'score=\K[0-9.]+' || echo "0")

        if [[ -z "$score" || "$score" == "0" ]]; then
            continue
        fi

        ((total_messages++))

        # Classify as spam or ham
        if (( $(echo "$score >= $SPAM_THRESHOLD" | bc -l) )); then
            ((spam_detected++))

            # Extract sender IP/domain for top spammers
            local sender
            sender=$(echo "$line" | grep -oP 'from=<[^>]+>' | tr -d '<>' || echo "unknown")

            if [[ -n "$sender" && "$sender" != "unknown" ]]; then
                ((top_spammers[$sender]++))
            fi
        else
            ((ham_detected++))
        fi

        # Categorize score into buckets
        categorize_score "$score"

    done < <(grep "spamd:" "$MAIL_LOG" 2>/dev/null | grep "score=" | tail -1000)

    log_success "Parsed $total_messages messages"
}

categorize_score() {
    local score="$1"

    if (( $(echo "$score < 1" | bc -l) )); then
        ((score_buckets[0-1]++))
    elif (( $(echo "$score < 2" | bc -l) )); then
        ((score_buckets[1-2]++))
    elif (( $(echo "$score < 5" | bc -l) )); then
        ((score_buckets[2-5]++))
    elif (( $(echo "$score < 10" | bc -l) )); then
        ((score_buckets[5-10]++))
    else
        ((score_buckets[10+]++))
    fi
}

#===============================================================================
# Statistics Functions
#===============================================================================

calculate_stats() {
    if ((total_messages == 0)); then
        log_warning "No SpamAssassin data found"
        return 1
    fi

    local spam_rate
    spam_rate=$(percentage "$spam_detected" "$total_messages")

    log_info "Statistics:"
    log_info "  Total messages: $total_messages"
    log_info "  Spam detected: $spam_detected (${spam_rate}%)"
    log_info "  Ham (legitimate): $ham_detected"
}

identify_top_spammers() {
    log_info "Top $TOP_N spammers:"

    # Sort spammers by count
    for sender in "${!top_spammers[@]}"; do
        echo "${top_spammers[$sender]} $sender"
    done | sort -rn | head -"$TOP_N" | while read -r count sender; do
        log_info "  $sender: $count messages"
    done
}

#===============================================================================
# Visualization Functions
#===============================================================================

draw_bar_chart() {
    local title="$1"
    local max_width=50

    echo ""
    echo "=== $title ==="
    echo ""

    # Find max value for scaling
    local max_value=0
    for bucket in "${!score_buckets[@]}"; do
        if ((score_buckets[$bucket] > max_value)); then
            max_value=${score_buckets[$bucket]}
        fi
    done

    if ((max_value == 0)); then
        echo "No data"
        return
    fi

    # Draw bars
    for bucket in "0-1" "1-2" "2-5" "5-10" "10+"; do
        local count=${score_buckets[$bucket]}
        local bar_length=$((count * max_width / max_value))

        printf "%6s │" "$bucket"
        printf "%${bar_length}s" "" | tr ' ' '█'
        printf " %d\n" "$count"
    done

    echo ""
}

draw_summary_box() {
    local spam_rate
    spam_rate=$(percentage "$spam_detected" "$total_messages")

    cat << EOF

╔══════════════════════════════════════════════╗
║       SpamAssassin Statistics Summary        ║
╠══════════════════════════════════════════════╣
║  Total Messages:      $(printf "%20s" "$total_messages")  ║
║  Spam Detected:       $(printf "%20s" "$spam_detected ($spam_rate%)")  ║
║  Ham (Legitimate):    $(printf "%20s" "$ham_detected")  ║
║  Detection Threshold: $(printf "%20s" "$SPAM_THRESHOLD")  ║
╚══════════════════════════════════════════════╝

EOF
}

#===============================================================================
# Report Generation
#===============================================================================

generate_json_report() {
    ensure_directory "$REPORT_DIR"

    local report_file="${REPORT_DIR}/spam-report-$(timestamp_filename).json"
    local latest_link="${REPORT_DIR}/spam-report-latest.json"

    # Build top spammers JSON array
    local spammers_json="["
    local first=true
    for sender in "${!top_spammers[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            spammers_json+=","
        fi
        spammers_json+="{\"sender\":\"$sender\",\"count\":${top_spammers[$sender]}}"
    done
    spammers_json+="]"

    # Generate JSON report
    cat > "$report_file" << EOF
{
    "timestamp": "$(timestamp_iso)",
    "hostname": "$(hostname)",
    "period": "24h",
    "summary": {
        "total_messages": $total_messages,
        "spam_detected": $spam_detected,
        "ham_detected": $ham_detected,
        "spam_rate": $(percentage "$spam_detected" "$total_messages"),
        "threshold": $SPAM_THRESHOLD
    },
    "score_distribution": {
        "0-1": ${score_buckets[0-1]},
        "1-2": ${score_buckets[1-2]},
        "2-5": ${score_buckets[2-5]},
        "5-10": ${score_buckets[5-10]},
        "10+": ${score_buckets[10+]}
    },
    "top_spammers": $spammers_json
}
EOF

    # Create/update latest symlink
    ln -sf "$report_file" "$latest_link"

    log_success "JSON report generated: $report_file"
}

#===============================================================================
# Main Execution
#===============================================================================

main() {
    local period="today"
    local json_only=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --period)
                period="$2"
                shift 2
                ;;
            --json)
                json_only=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    log_info "=== SpamAssassin Report Generator ==="
    log_info "Period: $period"

    # Parse logs
    parse_spam_logs "$period" || exit 1

    # Generate reports
    if [[ "$json_only" == "false" ]]; then
        calculate_stats
        draw_summary_box
        draw_bar_chart "Score Distribution"
        identify_top_spammers
    fi

    generate_json_report

    log_success "=== Report Complete ==="
}

# Execute main
main "$@"
