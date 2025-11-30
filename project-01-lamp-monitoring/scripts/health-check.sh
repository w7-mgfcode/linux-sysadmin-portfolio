#!/bin/bash
#===============================================================================
# Health Check Script - Service Health Monitoring
#
# Purpose:
#   Checks health of all LAMP stack services and generates JSON status report
#
# Skills Demonstrated:
#   - Service health testing
#   - Network connectivity checks
#   - JSON status reporting
#   - Exit codes for monitoring integration
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

# Service endpoints
readonly NGINX_URL="${NGINX_URL:-http://nginx/health}"
readonly PHP_FPM_HOST="${PHP_FPM_HOST:-localhost}"
readonly MYSQL_HOST="${MYSQL_HOST:-mysql}"
readonly MYSQL_USER="${MYSQL_USER:-lampuser}"
readonly MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"

# Timeouts
readonly CURL_TIMEOUT=5
readonly MYSQL_TIMEOUT=5

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
# Health Check Functions
#===============================================================================

check_nginx() {
    log "BLUE" "Checking Nginx..."

    local start_time=$(date +%s%3N)

    if curl -s -f --max-time $CURL_TIMEOUT "$NGINX_URL" >/dev/null 2>&1; then
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))

        log "GREEN" "✓ Nginx is healthy (${response_time}ms)"
        echo "ok:$response_time"
        return 0
    else
        log "RED" "✗ Nginx is unhealthy"
        echo "error:timeout"
        return 1
    fi
}

check_php() {
    log "BLUE" "Checking PHP-FPM..."

    if php -v >/dev/null 2>&1; then
        local php_version=$(php -r "echo PHP_VERSION;")
        log "GREEN" "✓ PHP-FPM is healthy (v$php_version)"
        echo "ok:$php_version"
        return 0
    else
        log "RED" "✗ PHP-FPM is unhealthy"
        echo "error:not_responding"
        return 1
    fi
}

check_mysql() {
    log "BLUE" "Checking MySQL..."

    local start_time=$(date +%s%3N)

    if mysqladmin ping -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --connect-timeout=$MYSQL_TIMEOUT >/dev/null 2>&1; then
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))

        # Get uptime
        local uptime
        uptime=$(mysql -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -se "SHOW STATUS LIKE 'Uptime';" 2>/dev/null | awk '{print $2}')

        log "GREEN" "✓ MySQL is healthy (uptime: ${uptime}s)"
        echo "ok:$uptime:$response_time"
        return 0
    else
        log "RED" "✗ MySQL is unhealthy"
        echo "error:connection_failed"
        return 1
    fi
}

generate_report() {
    local nginx_result=$1
    local php_result=$2
    local mysql_result=$3
    local overall_status=$4

    # Parse results
    local nginx_status=$(echo "$nginx_result" | cut -d: -f1)
    local nginx_time=$(echo "$nginx_result" | cut -d: -f2)

    local php_status=$(echo "$php_result" | cut -d: -f1)
    local php_version=$(echo "$php_result" | cut -d: -f2)

    local mysql_status=$(echo "$mysql_result" | cut -d: -f1)
    local mysql_uptime=$(echo "$mysql_result" | cut -d: -f2)
    local mysql_time=$(echo "$mysql_result" | cut -d: -f3)

    cat << EOF
{
    "timestamp": "$(date -Iseconds)",
    "status": "$overall_status",
    "checks": {
        "nginx": {
            "status": "$nginx_status",
            "response_time_ms": $nginx_time
        },
        "php": {
            "status": "$php_status",
            "version": "$php_version"
        },
        "mysql": {
            "status": "$mysql_status",
            "uptime_seconds": $mysql_uptime,
            "response_time_ms": $mysql_time
        }
    }
}
EOF
}

#===============================================================================
# Main Execution
#===============================================================================

main() {
    log "GREEN" "========================================="
    log "GREEN" "Health Check v$SCRIPT_VERSION"
    log "GREEN" "========================================="

    local failed=0

    # Run health checks
    nginx_result=$(check_nginx) || ((failed++))
    php_result=$(check_php) || ((failed++))
    mysql_result=$(check_mysql) || ((failed++))

    # Determine overall status
    local overall_status
    if [[ $failed -eq 0 ]]; then
        overall_status="healthy"
        log "GREEN" "All services are healthy"
    else
        overall_status="unhealthy"
        log "RED" "$failed service(s) are unhealthy"
    fi

    echo ""
    log "BLUE" "JSON Report:"
    generate_report "$nginx_result" "$php_result" "$mysql_result" "$overall_status"

    log "GREEN" "========================================="

    # Exit with appropriate code
    exit $failed
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
