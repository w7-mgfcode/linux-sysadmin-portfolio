#!/bin/bash
set -euo pipefail

#==============================================================================
# Master Test Orchestrator
# Project: Dockerized Mail Server - Project 02
# Purpose: Run all test suites in sequence and report results
#==============================================================================

# Color codes for output
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi

# Test suite statistics
SUITES_PASSED=0
SUITES_FAILED=0
TOTAL_SUITES=0

#------------------------------------------------------------------------------
# Logging Functions
#------------------------------------------------------------------------------
log() {
    local level=$1
    shift
    echo -e "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [TestRunner] [$level] $*"
}

info() {
    echo -e "${BLUE}[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [TestRunner] [INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [TestRunner] [SUCCESS]${NC} $*"
}

error() {
    echo -e "${RED}[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [TestRunner] [ERROR]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [TestRunner] [WARN]${NC} $*"
}

#------------------------------------------------------------------------------
# Wait for Services to be Ready
#------------------------------------------------------------------------------
wait_for_services() {
    info "Waiting for services to be healthy..."

    local max_wait=120
    local waited=0
    local check_interval=5

    while [[ $waited -lt $max_wait ]]; do
        local unhealthy_count=0
        local services=("mysql" "postfix" "dovecot" "spamassassin")

        for service in "${services[@]}"; do
            local container_name="mail-${service}"
            local status
            status=$(docker inspect "${container_name}" --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")

            if [[ "$status" != "healthy" ]]; then
                ((unhealthy_count++))
            fi
        done

        if [[ $unhealthy_count -eq 0 ]]; then
            success "All services are healthy"
            return 0
        fi

        info "Waiting for services... ($unhealthy_count services not yet healthy) [${waited}s/${max_wait}s]"
        sleep $check_interval
        ((waited+=check_interval))
    done

    error "Services did not become healthy within ${max_wait}s"
    error "Check service logs: docker compose logs"
    return 1
}

#------------------------------------------------------------------------------
# Run Test Suite
#------------------------------------------------------------------------------
run_test_suite() {
    local suite_name=$1
    local suite_script=$2

    echo ""
    echo -e "${CYAN}========================================================================${NC}"
    echo -e "${CYAN}  Running Test Suite: ${suite_name}${NC}"
    echo -e "${CYAN}========================================================================${NC}"
    echo ""

    ((TOTAL_SUITES++))

    if [[ ! -f "$suite_script" ]]; then
        error "Test suite script not found: $suite_script"
        ((SUITES_FAILED++))
        return 1
    fi

    if [[ ! -x "$suite_script" ]]; then
        error "Test suite script not executable: $suite_script"
        error "Run: chmod +x $suite_script"
        ((SUITES_FAILED++))
        return 1
    fi

    # Run the test suite
    if bash "$suite_script"; then
        success "Test suite '${suite_name}' PASSED"
        ((SUITES_PASSED++))
        return 0
    else
        error "Test suite '${suite_name}' FAILED"
        ((SUITES_FAILED++))
        return 1
    fi
}

#------------------------------------------------------------------------------
# Print Final Summary
#------------------------------------------------------------------------------
print_final_summary() {
    echo ""
    echo "========================================================================"
    echo "                    Final Test Summary"
    echo "========================================================================"
    echo ""
    echo -e "  ${CYAN}Total Test Suites:${NC}  $TOTAL_SUITES"
    echo -e "  ${GREEN}✓ Suites Passed:${NC}   $SUITES_PASSED"
    echo -e "  ${RED}✗ Suites Failed:${NC}   $SUITES_FAILED"
    echo ""

    if [[ $SUITES_FAILED -gt 0 ]]; then
        echo -e "${RED}========================================================================${NC}"
        echo -e "${RED}  TEST RUN FAILED - $SUITES_FAILED suite(s) failed${NC}"
        echo -e "${RED}========================================================================${NC}"
        echo ""
        echo "Troubleshooting steps:"
        echo "  1. Check service logs: docker compose logs"
        echo "  2. Verify service health: docker compose ps"
        echo "  3. Review failed test output above"
        echo "  4. Consult docs/TROUBLESHOOTING.md"
        echo ""
        return 1
    else
        echo -e "${GREEN}========================================================================${NC}"
        echo -e "${GREEN}  ALL TESTS PASSED - Mail server is fully operational${NC}"
        echo -e "${GREEN}========================================================================${NC}"
        echo ""
        echo "Next steps:"
        echo "  - Review service logs: docker compose logs"
        echo "  - Access webmail: http://localhost:80"
        echo "  - Access dashboard: http://localhost:8080"
        echo "  - Create test users via MySQL"
        echo ""
        return 0
    fi
}

#------------------------------------------------------------------------------
# Check Prerequisites
#------------------------------------------------------------------------------
check_prerequisites() {
    info "Checking prerequisites..."

    local missing_tools=()

    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
        missing_tools+=("docker-compose")
    fi

    # Check netcat (required for mail flow tests)
    if ! command -v nc &> /dev/null; then
        warn "netcat (nc) not found - some mail flow tests may be skipped"
        warn "Install: apt-get install netcat or brew install netcat"
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi

    success "All required prerequisites are available"
    return 0
}

#------------------------------------------------------------------------------
# Check Services are Running
#------------------------------------------------------------------------------
check_services_running() {
    info "Checking if services are running..."

    if ! docker compose ps | grep -q "mail-mysql"; then
        error "Services are not running"
        error "Start services first: docker compose up -d"
        return 1
    fi

    success "Services are running"
    return 0
}

#==============================================================================
# Main Execution
#==============================================================================
main() {
    local start_time
    start_time=$(date +%s)

    echo ""
    echo "========================================================================"
    echo "          Mail Server Complete Test Suite"
    echo "          Project 02: Dockerized Mail Server"
    echo "========================================================================"
    echo ""
    info "Test run started at $(date)"
    echo ""

    # Step 1: Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi

    # Step 2: Check services are running
    if ! check_services_running; then
        exit 1
    fi

    # Step 3: Wait for services to be healthy
    if ! wait_for_services; then
        exit 1
    fi

    # Step 4: Run test suites
    echo ""
    info "=========================================================================="
    info "  Starting Test Suites"
    info "=========================================================================="

    run_test_suite "Health Checks" "./tests/health-checks.sh" || true
    run_test_suite "Mail Flow Tests" "./tests/test-mail-flow-basic.sh" || true

    # Step 5: Print final summary
    echo ""
    print_final_summary

    # Calculate duration
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    info "Test run completed in ${duration} seconds"
    echo ""

    # Exit with appropriate code
    if [[ $SUITES_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"
