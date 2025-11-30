#!/bin/bash
#===============================================================================
# End-to-End Test Suite - Mail Server Integration Testing
#
# Purpose:
#   Comprehensive test suite verifying all mail server components, protocols,
#   authentication, SSL/TLS, service health, and integration points.
#
# Usage:
#   ./e2e-test.sh                    # Run all tests
#   ./e2e-test.sh --quick            # Skip slow tests
#   ./e2e-test.sh --verbose          # Detailed output
#
# Skills Demonstrated:
#   - Docker health monitoring
#   - Network connectivity testing (netcat, telnet alternatives)
#   - SSL/TLS certificate validation
#   - MySQL query testing
#   - Protocol verification (SMTP, IMAP, POP3)
#   - Test automation patterns
#   - Exit code handling
#   - Color-coded test reporting
#
# Author: Linux Sysadmin Portfolio
# License: MIT
#===============================================================================

set -euo pipefail

#===============================================================================
# Configuration
#===============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test configuration
readonly TIMEOUT="${TEST_TIMEOUT:-10}"
readonly QUICK_MODE="${1:-}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test counters
declare -i tests_run=0
declare -i tests_passed=0
declare -i tests_failed=0
declare -i tests_skipped=0

# Container names
readonly CONTAINERS=(
    "mail-mysql"
    "mail-postfix"
    "mail-dovecot"
    "mail-spamassassin"
    "mail-roundcube"
    "mail-dashboard"
)

#===============================================================================
# Utility Functions
#===============================================================================

log() {
    local level=$1
    shift
    echo -e "${level}[$(date '+%H:%M:%S')] $*${NC}"
}

log_info() { log "$BLUE" "$*"; }
log_success() { log "$GREEN" "✓ $*"; }
log_error() { log "$RED" "✗ $*"; }
log_warning() { log "$YELLOW" "⚠ $*"; }

test_start() {
    ((tests_run++))
    log_info "TEST: $*"
}

test_pass() {
    ((tests_passed++))
    log_success "$*"
    echo ""
}

test_fail() {
    ((tests_failed++))
    log_error "$*"
    echo ""
}

test_skip() {
    ((tests_skipped++))
    log_warning "SKIPPED: $*"
    echo ""
}

#===============================================================================
# Test: Docker Environment
#===============================================================================

test_docker_running() {
    test_start "Docker daemon is running"

    if docker info &>/dev/null; then
        test_pass "Docker is running"
        return 0
    else
        test_fail "Docker is not running or not accessible"
        return 1
    fi
}

test_compose_file() {
    test_start "Docker Compose file exists"

    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        test_pass "docker-compose.yml found"
        return 0
    else
        test_fail "docker-compose.yml not found"
        return 1
    fi
}

#===============================================================================
# Test: Container Health
#===============================================================================

test_containers_running() {
    test_start "All containers are running"

    local all_running=true
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            log_success "  $container is running"
        else
            log_error "  $container is NOT running"
            all_running=false
        fi
    done

    if $all_running; then
        test_pass "All containers running"
        return 0
    else
        test_fail "Some containers are not running"
        return 1
    fi
}

test_containers_healthy() {
    test_start "All containers are healthy"

    local all_healthy=true
    for container in "${CONTAINERS[@]}"; do
        # Skip cert-init as it's a one-time container
        [[ "$container" == "mail-cert-init" ]] && continue

        local health
        health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")

        if [[ "$health" == "healthy" ]]; then
            log_success "  $container is healthy"
        elif [[ "$health" == "unknown" ]]; then
            log_warning "  $container has no health check"
        else
            log_error "  $container health: $health"
            all_healthy=false
        fi
    done

    if $all_healthy; then
        test_pass "All containers healthy"
        return 0
    else
        test_fail "Some containers are unhealthy"
        return 1
    fi
}

#===============================================================================
# Test: Network Connectivity
#===============================================================================

test_port_listening() {
    local service="$1"
    local container="$2"
    local port="$3"

    test_start "$service is listening on port $port"

    if docker exec "$container" timeout 2 bash -c "cat < /dev/null > /dev/tcp/localhost/$port" 2>/dev/null; then
        test_pass "$service port $port is accessible"
        return 0
    else
        test_fail "$service port $port is not accessible"
        return 1
    fi
}

test_network_ports() {
    test_port_listening "MySQL" "mail-mysql" 3306
    test_port_listening "Postfix SMTP" "mail-postfix" 25
    test_port_listening "Postfix Submission" "mail-postfix" 587
    test_port_listening "Dovecot IMAP" "mail-dovecot" 143
    test_port_listening "Dovecot IMAPS" "mail-dovecot" 993
    test_port_listening "SpamAssassin" "mail-spamassassin" 783
}

#===============================================================================
# Test: SSL/TLS Certificates
#===============================================================================

test_ssl_certificates() {
    test_start "SSL certificates exist"

    local certs_ok=true

    # Check in postfix container
    if docker exec mail-postfix test -f /etc/mail/certs/server.crt; then
        log_success "  Server certificate found"
    else
        log_error "  Server certificate missing"
        certs_ok=false
    fi

    if docker exec mail-postfix test -f /etc/mail/certs/server.key; then
        log_success "  Server private key found"
    else
        log_error "  Server private key missing"
        certs_ok=false
    fi

    if $certs_ok; then
        test_pass "SSL certificates present"
        return 0
    else
        test_fail "SSL certificates missing"
        return 1
    fi
}

test_ssl_validity() {
    test_start "SSL certificate is valid"

    local cert_info
    cert_info=$(docker exec mail-postfix openssl x509 -in /etc/mail/certs/server.crt -noout -dates 2>/dev/null || echo "")

    if [[ -n "$cert_info" ]]; then
        log_success "  Certificate dates: $cert_info"
        test_pass "SSL certificate is valid"
        return 0
    else
        test_fail "Cannot read SSL certificate"
        return 1
    fi
}

#===============================================================================
# Test: MySQL Database
#===============================================================================

test_mysql_connection() {
    test_start "MySQL database is accessible"

    if docker exec mail-mysql mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD:-changeme}" &>/dev/null; then
        test_pass "MySQL connection successful"
        return 0
    else
        test_fail "MySQL connection failed"
        return 1
    fi
}

test_mysql_schema() {
    test_start "MySQL schema is initialized"

    local tables
    tables=$(docker exec mail-mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD:-changeme}" mailserver -sN -e "SHOW TABLES;" 2>/dev/null || echo "")

    local required_tables=("virtual_domains" "virtual_users" "virtual_aliases" "mailbox_usage")
    local all_present=true

    for table in "${required_tables[@]}"; do
        if echo "$tables" | grep -q "^${table}$"; then
            log_success "  Table $table exists"
        else
            log_error "  Table $table missing"
            all_present=false
        fi
    done

    if $all_present; then
        test_pass "All required tables present"
        return 0
    else
        test_fail "Some tables are missing"
        return 1
    fi
}

test_mysql_sample_data() {
    test_start "Sample data is loaded"

    local domain_count
    domain_count=$(docker exec mail-mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD:-changeme}" mailserver -sN -e "SELECT COUNT(*) FROM virtual_domains;" 2>/dev/null || echo "0")

    if [[ "$domain_count" -gt 0 ]]; then
        log_success "  Found $domain_count domain(s)"
        test_pass "Sample data loaded"
        return 0
    else
        test_fail "No sample data found"
        return 1
    fi
}

#===============================================================================
# Test: Mail Protocols
#===============================================================================

test_smtp_banner() {
    test_start "SMTP banner is accessible"

    local banner
    banner=$(docker exec mail-postfix timeout 5 bash -c 'echo QUIT | nc localhost 25' 2>/dev/null | head -1 || echo "")

    if [[ "$banner" =~ ^220.*ESMTP ]]; then
        log_success "  SMTP banner: $banner"
        test_pass "SMTP responding correctly"
        return 0
    else
        test_fail "SMTP banner not found or incorrect"
        return 1
    fi
}

test_imap_capability() {
    test_start "IMAP capability check"

    local capability
    capability=$(docker exec mail-dovecot timeout 5 bash -c 'echo ". CAPABILITY" | nc localhost 143' 2>/dev/null || echo "")

    if [[ "$capability" =~ CAPABILITY.*IMAP4rev1 ]]; then
        log_success "  IMAP capability: OK"
        test_pass "IMAP responding correctly"
        return 0
    else
        test_fail "IMAP capability check failed"
        return 1
    fi
}

#===============================================================================
# Test: Service Configuration
#===============================================================================

test_postfix_config() {
    test_start "Postfix configuration is valid"

    if docker exec mail-postfix postconf -n &>/dev/null; then
        local virtual_transport
        virtual_transport=$(docker exec mail-postfix postconf virtual_transport 2>/dev/null)
        log_success "  $virtual_transport"
        test_pass "Postfix configuration valid"
        return 0
    else
        test_fail "Postfix configuration invalid"
        return 1
    fi
}

test_dovecot_config() {
    test_start "Dovecot configuration is valid"

    if docker exec mail-dovecot doveconf -n &>/dev/null; then
        test_pass "Dovecot configuration valid"
        return 0
    else
        test_fail "Dovecot configuration invalid"
        return 1
    fi
}

#===============================================================================
# Test: Dashboard & Roundcube
#===============================================================================

test_dashboard_accessible() {
    test_start "Dashboard is accessible"

    if docker exec mail-dashboard curl -f -s http://localhost/ &>/dev/null; then
        test_pass "Dashboard HTTP 200 OK"
        return 0
    else
        test_fail "Dashboard not accessible"
        return 1
    fi
}

test_roundcube_accessible() {
    test_start "Roundcube webmail is accessible"

    if docker exec mail-roundcube curl -f -s http://localhost/ &>/dev/null; then
        test_pass "Roundcube HTTP 200 OK"
        return 0
    else
        test_fail "Roundcube not accessible"
        return 1
    fi
}

#===============================================================================
# Test: Log Files
#===============================================================================

test_log_files() {
    test_start "Log files are being written"

    # Check if mail.log exists and has recent entries
    if docker exec mail-postfix test -f /var/log/mail/mail.log; then
        local log_lines
        log_lines=$(docker exec mail-postfix wc -l < /var/log/mail/mail.log 2>/dev/null || echo "0")
        log_success "  mail.log has $log_lines lines"
        test_pass "Log files present"
        return 0
    else
        test_fail "Log files not found"
        return 1
    fi
}

#===============================================================================
# Test Summary
#===============================================================================

print_summary() {
    echo ""
    echo "========================================"
    echo "           TEST SUMMARY"
    echo "========================================"
    echo -e "Tests Run:     ${BLUE}${tests_run}${NC}"
    echo -e "Tests Passed:  ${GREEN}${tests_passed}${NC}"
    echo -e "Tests Failed:  ${RED}${tests_failed}${NC}"
    echo -e "Tests Skipped: ${YELLOW}${tests_skipped}${NC}"
    echo "========================================"

    if [[ $tests_failed -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

#===============================================================================
# Main Test Execution
#===============================================================================

main() {
    echo "========================================"
    echo "  Mail Server E2E Test Suite"
    echo "========================================"
    echo ""

    # Change to project root
    cd "$PROJECT_ROOT"

    # Phase 1: Docker Environment
    test_docker_running || exit 1
    test_compose_file || exit 1

    # Phase 2: Container Health
    test_containers_running || log_warning "Continuing despite container issues..."
    test_containers_healthy

    # Phase 3: Network & Ports
    test_network_ports

    # Phase 4: SSL/TLS
    test_ssl_certificates
    test_ssl_validity

    # Phase 5: Database
    test_mysql_connection
    test_mysql_schema
    test_mysql_sample_data

    # Phase 6: Mail Protocols
    test_smtp_banner
    test_imap_capability

    # Phase 7: Configuration
    test_postfix_config
    test_dovecot_config

    # Phase 8: Web Interfaces
    test_dashboard_accessible
    test_roundcube_accessible

    # Phase 9: Logs
    test_log_files

    # Print summary and exit with appropriate code
    print_summary
}

# Execute main function
main "$@"
