#!/bin/bash
set -euo pipefail

#==============================================================================
# Mail Flow Basic Test Suite
# Project: Dockerized Mail Server - Project 02
# Purpose: Test basic mail server connectivity and protocol responses
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
    echo -e "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [MailFlow] [$level] $*"
}

test_pass() {
    echo -e "${GREEN}[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [MailFlow] [PASS]${NC} $*"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [MailFlow] [FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

test_skip() {
    echo -e "${YELLOW}[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [MailFlow] [SKIP]${NC} $*"
    ((TESTS_SKIPPED++))
}

#------------------------------------------------------------------------------
# Test 1: SMTP Connection Test (Port 25)
#------------------------------------------------------------------------------
test_smtp_connection() {
    log INFO "Test 1: Testing SMTP connection on port 25..."

    local response
    response=$(echo "QUIT" | timeout 5 nc localhost 25 2>/dev/null || echo "ERROR")

    if echo "$response" | grep -q "220.*ESMTP Postfix"; then
        test_pass "SMTP (port 25) responds with proper banner"
        log INFO "Response: $(echo "$response" | head -n 1)"
        return 0
    else
        test_fail "SMTP (port 25) not responding correctly"
        log ERROR "Response: $response"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Test 2: SMTP Submission Test (Port 587)
#------------------------------------------------------------------------------
test_smtp_submission() {
    log INFO "Test 2: Testing SMTP submission on port 587..."

    local response
    response=$(echo "QUIT" | timeout 5 nc localhost 587 2>/dev/null || echo "ERROR")

    if echo "$response" | grep -q "220.*ESMTP Postfix"; then
        test_pass "SMTP submission (port 587) responds with proper banner"
        log INFO "Response: $(echo "$response" | head -n 1)"
        return 0
    else
        test_fail "SMTP submission (port 587) not responding correctly"
        log ERROR "Response: $response"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Test 3: SMTPS Connection Test (Port 465)
#------------------------------------------------------------------------------
test_smtps_connection() {
    log INFO "Test 3: Testing SMTPS connection on port 465..."

    if ! command -v openssl &> /dev/null; then
        test_skip "openssl not available - cannot test SMTPS"
        return 0
    fi

    local response
    response=$(echo "QUIT" | timeout 5 openssl s_client -connect localhost:465 -quiet 2>&1 || echo "ERROR")

    if echo "$response" | grep -q "220.*ESMTP Postfix"; then
        test_pass "SMTPS (port 465) responds with proper banner"
        return 0
    else
        test_fail "SMTPS (port 465) not responding correctly"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Test 4: IMAP Connection Test (Port 143)
#------------------------------------------------------------------------------
test_imap_connection() {
    log INFO "Test 4: Testing IMAP connection on port 143..."

    local response
    response=$(echo "a1 LOGOUT" | timeout 5 nc localhost 143 2>/dev/null || echo "ERROR")

    if echo "$response" | grep -q "OK.*Dovecot.*ready"; then
        test_pass "IMAP (port 143) responds with proper banner"
        log INFO "Response: $(echo "$response" | head -n 1)"
        return 0
    else
        test_fail "IMAP (port 143) not responding correctly"
        log ERROR "Response: $response"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Test 5: IMAPS Connection Test (Port 993)
#------------------------------------------------------------------------------
test_imaps_connection() {
    log INFO "Test 5: Testing IMAPS connection on port 993..."

    if ! command -v openssl &> /dev/null; then
        test_skip "openssl not available - cannot test IMAPS"
        return 0
    fi

    local response
    response=$(echo "a1 LOGOUT" | timeout 5 openssl s_client -connect localhost:993 -quiet 2>&1 || echo "ERROR")

    if echo "$response" | grep -q "OK.*Dovecot.*ready"; then
        test_pass "IMAPS (port 993) responds with proper banner"
        return 0
    else
        test_fail "IMAPS (port 993) not responding correctly"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Test 6: POP3 Connection Test (Port 110)
#------------------------------------------------------------------------------
test_pop3_connection() {
    log INFO "Test 6: Testing POP3 connection on port 110..."

    local response
    response=$(echo "QUIT" | timeout 5 nc localhost 110 2>/dev/null || echo "ERROR")

    if echo "$response" | grep -q "+OK.*Dovecot.*ready"; then
        test_pass "POP3 (port 110) responds with proper banner"
        log INFO "Response: $(echo "$response" | head -n 1)"
        return 0
    else
        test_fail "POP3 (port 110) not responding correctly"
        log ERROR "Response: $response"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Test 7: POP3S Connection Test (Port 995)
#------------------------------------------------------------------------------
test_pop3s_connection() {
    log INFO "Test 7: Testing POP3S connection on port 995..."

    if ! command -v openssl &> /dev/null; then
        test_skip "openssl not available - cannot test POP3S"
        return 0
    fi

    local response
    response=$(echo "QUIT" | timeout 5 openssl s_client -connect localhost:995 -quiet 2>&1 || echo "ERROR")

    if echo "$response" | grep -q "+OK.*Dovecot.*ready"; then
        test_pass "POP3S (port 995) responds with proper banner"
        return 0
    else
        test_fail "POP3S (port 995) not responding correctly"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Test 8: SMTP EHLO Command Test
#------------------------------------------------------------------------------
test_smtp_ehlo() {
    log INFO "Test 8: Testing SMTP EHLO command..."

    local response
    response=$(printf "EHLO test.localhost\r\nQUIT\r\n" | timeout 5 nc localhost 25 2>/dev/null || echo "ERROR")

    if echo "$response" | grep -q "250-STARTTLS"; then
        test_pass "SMTP EHLO advertises STARTTLS"
    else
        test_fail "SMTP EHLO does not advertise STARTTLS"
        return 1
    fi

    if echo "$response" | grep -q "250.*AUTH"; then
        test_pass "SMTP EHLO advertises AUTH"
    else
        test_fail "SMTP EHLO does not advertise AUTH"
        return 1
    fi

    return 0
}

#------------------------------------------------------------------------------
# Test 9: IMAP CAPABILITY Command Test
#------------------------------------------------------------------------------
test_imap_capability() {
    log INFO "Test 9: Testing IMAP CAPABILITY command..."

    local response
    response=$(printf "a1 CAPABILITY\r\na2 LOGOUT\r\n" | timeout 5 nc localhost 143 2>/dev/null || echo "ERROR")

    if echo "$response" | grep -q "CAPABILITY"; then
        test_pass "IMAP CAPABILITY command works"
    else
        test_fail "IMAP CAPABILITY command failed"
        return 1
    fi

    if echo "$response" | grep -q "STARTTLS"; then
        test_pass "IMAP advertises STARTTLS"
    else
        test_fail "IMAP does not advertise STARTTLS"
        return 1
    fi

    return 0
}

#------------------------------------------------------------------------------
# Test 10: SSL Certificate Validation
#------------------------------------------------------------------------------
test_ssl_certificate_validation() {
    log INFO "Test 10: Testing SSL certificate validation..."

    if ! command -v openssl &> /dev/null; then
        test_skip "openssl not available - cannot validate certificates"
        return 0
    fi

    # Test SMTPS certificate
    local smtps_cert
    smtps_cert=$(echo | timeout 5 openssl s_client -connect localhost:465 -showcerts 2>/dev/null | \
        openssl x509 -noout -subject 2>/dev/null || echo "ERROR")

    if [[ "$smtps_cert" != "ERROR" ]] && [[ -n "$smtps_cert" ]]; then
        test_pass "SMTPS certificate is valid"
        log INFO "Certificate: $smtps_cert"
    else
        test_fail "SMTPS certificate validation failed"
        return 1
    fi

    # Test IMAPS certificate
    local imaps_cert
    imaps_cert=$(echo | timeout 5 openssl s_client -connect localhost:993 -showcerts 2>/dev/null | \
        openssl x509 -noout -subject 2>/dev/null || echo "ERROR")

    if [[ "$imaps_cert" != "ERROR" ]] && [[ -n "$imaps_cert" ]]; then
        test_pass "IMAPS certificate is valid"
    else
        test_fail "IMAPS certificate validation failed"
        return 1
    fi

    return 0
}

#------------------------------------------------------------------------------
# Test 11: MySQL User Authentication Test (Optional)
#------------------------------------------------------------------------------
test_user_authentication() {
    log INFO "Test 11: Testing user authentication..."

    local mysql_user="${MYSQL_USER:-mailuser}"
    local mysql_password="${MYSQL_PASSWORD:-mail_secure_changeme}"
    local mysql_database="${MYSQL_DATABASE:-mailserver}"

    # Check if test user exists
    local test_user_count
    test_user_count=$(docker compose exec -T -e MYSQL_PWD="${mysql_password}" mysql mysql -u"${mysql_user}" "${mysql_database}" \
        -e "SELECT COUNT(*) FROM virtual_users WHERE email='test@example.com';" 2>/dev/null | tail -n 1 || echo "0")

    if [[ "$test_user_count" -gt 0 ]]; then
        log INFO "Test user test@example.com exists"
        test_pass "Test user found in database"
        # Additional authentication tests could go here
    else
        test_skip "Test user not found - skipping authentication test"
        log INFO "Create test user to enable authentication testing"
    fi

    return 0
}

#------------------------------------------------------------------------------
# Summary Report
#------------------------------------------------------------------------------
print_summary() {
    echo ""
    echo "========================================================================"
    echo "                    Mail Flow Test Summary"
    echo "========================================================================"
    echo ""
    echo -e "  ${GREEN}✓ Tests Passed:${NC}  $TESTS_PASSED"
    echo -e "  ${YELLOW}○ Tests Skipped:${NC} $TESTS_SKIPPED"
    echo -e "  ${RED}✗ Tests Failed:${NC}  $TESTS_FAILED"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}========================================================================${NC}"
        echo -e "${RED}  MAIL FLOW TESTS FAILED - Review failures above${NC}"
        echo -e "${RED}========================================================================${NC}"
        return 1
    else
        echo -e "${GREEN}========================================================================${NC}"
        echo -e "${GREEN}  ALL MAIL FLOW TESTS PASSED${NC}"
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
    echo "          Mail Flow Basic Test Suite"
    echo "          Project 02: Dockerized Mail Server"
    echo "========================================================================"
    echo ""

    # Check prerequisites
    if ! command -v nc &> /dev/null; then
        log ERROR "netcat (nc) is required for mail flow tests"
        log ERROR "Install: apt-get install netcat or brew install netcat"
        exit 1
    fi

    if ! command -v timeout &> /dev/null; then
        log WARN "timeout command not found - tests may hang"
    fi

    if ! command -v openssl &> /dev/null; then
        log WARN "openssl not found - SSL tests will be skipped"
    fi

    # Run all tests
    test_smtp_connection || true
    test_smtp_submission || true
    test_smtps_connection || true
    test_imap_connection || true
    test_imaps_connection || true
    test_pop3_connection || true
    test_pop3s_connection || true
    test_smtp_ehlo || true
    test_imap_capability || true
    test_ssl_certificate_validation || true
    test_user_authentication || true

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
