#!/bin/bash
set -euo pipefail

#==============================================================================
# Service Health Check Test Suite
# Project: Dockerized Mail Server - Project 02
# Purpose: Verify all services are healthy and functioning correctly
#==============================================================================

# Color codes for output
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Test statistics
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

#------------------------------------------------------------------------------
# Logging Functions
#------------------------------------------------------------------------------
log() {
    local level=$1
    shift
    echo -e "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [Health] [$level] $*"
}

test_pass() {
    echo -e "${GREEN}[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [Health] [PASS]${NC} $*"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [Health] [FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

test_skip() {
    echo -e "${YELLOW}[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [Health] [SKIP]${NC} $*"
    ((TESTS_SKIPPED++))
}

#------------------------------------------------------------------------------
# Test 1: Container Health Status
#------------------------------------------------------------------------------
test_container_health() {
    log INFO "Test 1: Checking container health status..."

    local services=("mysql" "postfix" "dovecot" "spamassassin")
    local all_healthy=true

    for service in "${services[@]}"; do
        local container_name="mail-${service}"

        # Check if container exists
        if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
            test_fail "Container ${container_name} does not exist"
            all_healthy=false
            continue
        fi

        # Check health status
        local status
        status=$(docker inspect "${container_name}" --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")

        if [[ "$status" == "healthy" ]]; then
            test_pass "Service ${service} is healthy"
        elif [[ "$status" == "unknown" ]] || [[ -z "$status" ]]; then
            # No healthcheck defined
            local running
            running=$(docker inspect "${container_name}" --format='{{.State.Running}}' 2>/dev/null || echo "false")
            if [[ "$running" == "true" ]]; then
                test_pass "Service ${service} is running (no healthcheck defined)"
            else
                test_fail "Service ${service} is not running"
                all_healthy=false
            fi
        else
            test_fail "Service ${service} health status: ${status}"
            all_healthy=false
        fi
    done

    return "$([ "$all_healthy" = true ] && echo 0 || echo 1)"
}

#------------------------------------------------------------------------------
# Test 2: MySQL Connectivity
#------------------------------------------------------------------------------
test_mysql_connectivity() {
    log INFO "Test 2: Testing MySQL connectivity..."

    # Get MySQL password from environment or docker-compose
    local mysql_password="${MYSQL_ROOT_PASSWORD:-mail_root_changeme}"

    if docker compose exec -T -e MYSQL_PWD="${mysql_password}" mysql mysqladmin ping --silent 2>/dev/null; then
        test_pass "MySQL is responding to ping"
        return 0
    else
        test_fail "MySQL not responding to ping"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Test 3: MySQL Database Schema
#------------------------------------------------------------------------------
test_mysql_schema() {
    log INFO "Test 3: Validating MySQL database schema..."

    local mysql_user="${MYSQL_USER:-mailuser}"
    local mysql_password="${MYSQL_PASSWORD:-mail_secure_changeme}"
    local mysql_database="${MYSQL_DATABASE:-mailserver}"

    local tables=("virtual_domains" "virtual_users" "virtual_aliases")
    local all_tables_exist=true

    for table in "${tables[@]}"; do
        if docker compose exec -T -e MYSQL_PWD="${mysql_password}" mysql mysql -u"${mysql_user}" "${mysql_database}" \
            -e "DESCRIBE ${table};" > /dev/null 2>&1; then
            test_pass "Table ${table} exists"
        else
            test_fail "Table ${table} missing"
            all_tables_exist=false
        fi
    done

    return "$([ "$all_tables_exist" = true ] && echo 0 || echo 1)"
}

#------------------------------------------------------------------------------
# Test 4: Postfix Service Status
#------------------------------------------------------------------------------
test_postfix_status() {
    log INFO "Test 4: Checking Postfix service status..."

    if docker compose exec -T postfix postfix status > /dev/null 2>&1; then
        test_pass "Postfix is running"
        return 0
    else
        test_fail "Postfix is not running"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Test 5: Postfix Port Listening
#------------------------------------------------------------------------------
test_postfix_ports() {
    log INFO "Test 5: Checking Postfix ports..."

    local ports=(25 465 587)
    local all_listening=true

    for port in "${ports[@]}"; do
        if nc -z localhost "${port}" 2>/dev/null; then
            test_pass "Postfix port ${port} is listening"
        else
            test_fail "Postfix port ${port} not listening"
            all_listening=false
        fi
    done

    return "$([ "$all_listening" = true ] && echo 0 || echo 1)"
}

#------------------------------------------------------------------------------
# Test 6: Postfix Configuration
#------------------------------------------------------------------------------
test_postfix_configuration() {
    log INFO "Test 6: Validating Postfix configuration..."

    if docker compose exec -T postfix postfix check 2>&1 | grep -q "error"; then
        test_fail "Postfix configuration has errors"
        return 1
    else
        test_pass "Postfix configuration is valid"
        return 0
    fi
}

#------------------------------------------------------------------------------
# Test 7: Dovecot Service Status
#------------------------------------------------------------------------------
test_dovecot_status() {
    log INFO "Test 7: Checking Dovecot service status..."

    if docker compose exec -T dovecot doveadm who > /dev/null 2>&1; then
        test_pass "Dovecot is running"
        return 0
    else
        test_fail "Dovecot is not running"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Test 8: Dovecot Port Listening
#------------------------------------------------------------------------------
test_dovecot_ports() {
    log INFO "Test 8: Checking Dovecot ports..."

    local ports=(110 143 993 995)
    local all_listening=true

    for port in "${ports[@]}"; do
        if nc -z localhost "${port}" 2>/dev/null; then
            test_pass "Dovecot port ${port} is listening"
        else
            test_fail "Dovecot port ${port} not listening"
            all_listening=false
        fi
    done

    return "$([ "$all_listening" = true ] && echo 0 || echo 1)"
}

#------------------------------------------------------------------------------
# Test 9: SSL Certificate Validation
#------------------------------------------------------------------------------
test_ssl_certificates() {
    log INFO "Test 9: Checking SSL certificates..."

    local all_certs_present=true

    # Check Postfix SSL certificates
    if docker compose exec -T postfix test -f /etc/mail/certs/mail.crt 2>/dev/null; then
        test_pass "Postfix SSL certificate present"
    else
        test_fail "Postfix SSL certificate missing"
        all_certs_present=false
    fi

    if docker compose exec -T postfix test -f /etc/mail/certs/mail.key 2>/dev/null; then
        test_pass "Postfix SSL key present"
    else
        test_fail "Postfix SSL key missing"
        all_certs_present=false
    fi

    # Check Dovecot SSL certificates
    if docker compose exec -T dovecot test -f /etc/mail/certs/mail.crt 2>/dev/null; then
        test_pass "Dovecot SSL certificate present"
    else
        test_fail "Dovecot SSL certificate missing"
        all_certs_present=false
    fi

    if docker compose exec -T dovecot test -f /etc/mail/certs/mail.key 2>/dev/null; then
        test_pass "Dovecot SSL key present"
    else
        test_fail "Dovecot SSL key missing"
        all_certs_present=false
    fi

    return "$([ "$all_certs_present" = true ] && echo 0 || echo 1)"
}

#------------------------------------------------------------------------------
# Test 10: Log Files
#------------------------------------------------------------------------------
test_log_files() {
    log INFO "Test 10: Checking log files..."

    local all_logs_present=true

    # Check Postfix logs
    if docker compose exec -T postfix test -f /var/log/mail/mail.log 2>/dev/null; then
        test_pass "Postfix log file present"
    else
        test_skip "Postfix log file not yet created (normal on first start)"
    fi

    # Check Dovecot logs
    if docker compose exec -T dovecot test -f /var/log/mail/mail.log 2>/dev/null; then
        test_pass "Dovecot log file present"
    else
        test_skip "Dovecot log file not yet created (normal on first start)"
    fi

    return 0
}

#------------------------------------------------------------------------------
# Test 11: SpamAssassin Service
#------------------------------------------------------------------------------
test_spamassassin() {
    log INFO "Test 11: Checking SpamAssassin service..."

    # Check if SpamAssassin is responding
    if docker compose exec -T spamassassin spamc -K 2>/dev/null; then
        test_pass "SpamAssassin is running"
        return 0
    else
        test_fail "SpamAssassin not responding"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Test 12: Volume Mounts
#------------------------------------------------------------------------------
test_volume_mounts() {
    log INFO "Test 12: Checking volume mounts..."

    local all_volumes_mounted=true

    # Check mail directory
    if docker compose exec -T postfix test -d /var/mail/vhosts 2>/dev/null; then
        test_pass "Mail directory mounted (Postfix)"
    else
        test_fail "Mail directory not mounted (Postfix)"
        all_volumes_mounted=false
    fi

    if docker compose exec -T dovecot test -d /var/mail/vhosts 2>/dev/null; then
        test_pass "Mail directory mounted (Dovecot)"
    else
        test_fail "Mail directory not mounted (Dovecot)"
        all_volumes_mounted=false
    fi

    # Check SSL certs volume
    if docker compose exec -T postfix test -d /etc/mail/certs 2>/dev/null; then
        test_pass "SSL certs volume mounted (Postfix)"
    else
        test_fail "SSL certs volume not mounted (Postfix)"
        all_volumes_mounted=false
    fi

    return "$([ "$all_volumes_mounted" = true ] && echo 0 || echo 1)"
}

#------------------------------------------------------------------------------
# Test 13: Inter-Service Connectivity
#------------------------------------------------------------------------------
test_interservice_connectivity() {
    log INFO "Test 13: Testing inter-service connectivity..."

    # Test Postfix -> MySQL
    if docker compose exec -T postfix ping -c 1 mysql > /dev/null 2>&1; then
        test_pass "Postfix can reach MySQL"
    else
        test_fail "Postfix cannot reach MySQL"
        return 1
    fi

    # Test Dovecot -> MySQL
    if docker compose exec -T dovecot ping -c 1 mysql > /dev/null 2>&1; then
        test_pass "Dovecot can reach MySQL"
    else
        test_fail "Dovecot cannot reach MySQL"
        return 1
    fi

    # Test Postfix -> Dovecot (via shared socket directory)
    if docker compose exec -T postfix test -d /var/spool/postfix/private 2>/dev/null; then
        test_pass "Postfix socket directory exists"
    else
        test_fail "Postfix socket directory missing"
        return 1
    fi

    return 0
}

#------------------------------------------------------------------------------
# Summary Report
#------------------------------------------------------------------------------
print_summary() {
    echo ""
    echo "========================================================================"
    echo "                    Health Check Test Summary"
    echo "========================================================================"
    echo ""
    echo -e "  ${GREEN}✓ Tests Passed:${NC}  $TESTS_PASSED"
    echo -e "  ${YELLOW}○ Tests Skipped:${NC} $TESTS_SKIPPED"
    echo -e "  ${RED}✗ Tests Failed:${NC}  $TESTS_FAILED"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}========================================================================${NC}"
        echo -e "${RED}  HEALTH CHECKS FAILED - Review failures above${NC}"
        echo -e "${RED}========================================================================${NC}"
        return 1
    else
        echo -e "${GREEN}========================================================================${NC}"
        echo -e "${GREEN}  ALL HEALTH CHECKS PASSED${NC}"
        echo -e "${GREEN}========================================================================${NC}"
        return 0
    fi
}

#==============================================================================
# Main Execution
#==============================================================================
main() {
    echo ""
    echo "========================================================================"
    echo "          Mail Server Health Check Test Suite"
    echo "          Project 02: Dockerized Mail Server"
    echo "========================================================================"
    echo ""

    # Check if netcat is available
    if ! command -v nc &> /dev/null; then
        log WARN "netcat (nc) not found - port checks will be skipped"
        log WARN "Install netcat: apt-get install netcat or brew install netcat"
    fi

    # Run all tests (continue on failure to collect all issues)
    test_container_health || true
    test_mysql_connectivity || true
    test_mysql_schema || true
    test_postfix_status || true
    test_postfix_ports || true
    test_postfix_configuration || true
    test_dovecot_status || true
    test_dovecot_ports || true
    test_ssl_certificates || true
    test_log_files || true
    test_spamassassin || true
    test_volume_mounts || true
    test_interservice_connectivity || true

    # Print summary
    echo ""
    print_summary

    # Exit with appropriate code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"
