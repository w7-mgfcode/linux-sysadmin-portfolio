#!/bin/bash
set -euo pipefail

#==============================================================================
# Pre-Flight Environment Validation Script
# Project: Dockerized Mail Server - Project 02
# Purpose: Validate system readiness before starting containers
#==============================================================================

# Color codes for output (if terminal supports it)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Statistics counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

#------------------------------------------------------------------------------
# Logging Functions
#------------------------------------------------------------------------------
log() {
    local level=$1
    shift
    echo -e "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [Validation] [$level] $*"
}

info() {
    echo -e "${BLUE}[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [Validation] [INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [Validation] [WARN]${NC} $*"
}

error() {
    echo -e "${RED}[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [Validation] [ERROR]${NC} $*"
}

success() {
    echo -e "${GREEN}[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [Validation] [SUCCESS]${NC} $*"
}

#------------------------------------------------------------------------------
# Check 1: Docker Availability
#------------------------------------------------------------------------------
check_docker() {
    log INFO "Checking Docker availability..."

    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
        error "Install Docker: https://docs.docker.com/get-docker/"
        ((CHECKS_FAILED++))
        return 1
    fi

    if ! docker ps &> /dev/null; then
        error "Docker daemon is not running or not accessible"
        error "Start Docker: sudo systemctl start docker"
        error "Or check permissions: sudo usermod -aG docker \$USER"
        ((CHECKS_FAILED++))
        return 1
    fi

    local docker_version
    docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
    info "Docker is available (version: ${docker_version})"
    ((CHECKS_PASSED++))
    return 0
}

#------------------------------------------------------------------------------
# Check 2: Docker Compose Availability
#------------------------------------------------------------------------------
check_docker_compose() {
    log INFO "Checking Docker Compose availability..."

    local compose_cmd=""
    local compose_version=""

    # Check for docker compose (v2)
    if docker compose version &> /dev/null; then
        compose_cmd="docker compose"
        compose_version=$(docker compose version --short 2>/dev/null || echo "v2.x")
    # Check for docker-compose (v1)
    elif command -v docker-compose &> /dev/null; then
        compose_cmd="docker-compose"
        compose_version=$(docker-compose --version | cut -d' ' -f4 | tr -d ',')
    else
        error "Docker Compose is not available"
        error "Install Docker Compose: https://docs.docker.com/compose/install/"
        ((CHECKS_FAILED++))
        return 1
    fi

    info "Docker Compose is available (${compose_cmd} ${compose_version})"
    ((CHECKS_PASSED++))
    return 0
}

#------------------------------------------------------------------------------
# Check 3: Required Configuration Files
#------------------------------------------------------------------------------
check_config_files() {
    log INFO "Checking required configuration files..."

    local required_files=(
        "docker-compose.yml"
        "postfix/Dockerfile"
        "postfix/main.cf.template"
        "postfix/master.cf"
        "postfix/mysql-virtual-domains.cf"
        "postfix/mysql-virtual-mailboxes.cf"
        "postfix/mysql-virtual-aliases.cf"
        "postfix/entrypoint.sh"
        "dovecot/Dockerfile"
        "dovecot/dovecot.conf.template"
        "dovecot/dovecot-sql.conf.ext.template"
        "dovecot/10-mail.conf"
        "dovecot/10-ssl.conf"
        "dovecot/10-auth.conf"
        "dovecot/10-master.conf"
        "dovecot/entrypoint.sh"
        "mysql/init.sql"
        "init/Dockerfile"
        "init/generate-ssl.sh"
    )

    local missing_files=()

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        error "Required files missing (${#missing_files[@]}):"
        for file in "${missing_files[@]}"; do
            error "  - $file"
        done
        ((CHECKS_FAILED++))
        return 1
    fi

    info "All ${#required_files[@]} required configuration files present"
    ((CHECKS_PASSED++))
    return 0
}

#------------------------------------------------------------------------------
# Check 4: Environment File Validation
#------------------------------------------------------------------------------
check_env_file() {
    log INFO "Checking environment file..."

    local required_vars=(
        "MAIL_HOSTNAME"
        "MAIL_DOMAIN"
        "MYSQL_ROOT_PASSWORD"
        "MYSQL_PASSWORD"
    )
    local has_warnings=false

    if [[ ! -f .env ]]; then
        warn ".env file not found - will use docker-compose.yml defaults"
        warn "Create .env file for custom configuration"
        ((CHECKS_WARNING++))
        return 0
    fi

    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" .env 2>/dev/null; then
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        warn "Variables not set in .env (will use defaults):"
        for var in "${missing_vars[@]}"; do
            warn "  - $var"
        done
        has_warnings=true
    else
        info "Environment file validated - all required variables present"
    fi

    # Check for default passwords
    if grep -q "changeme" .env 2>/dev/null; then
        warn "Default passwords detected in .env file"
        warn "Change default passwords before production deployment"
        has_warnings=true
    fi

    if [[ "$has_warnings" = true ]]; then
        ((CHECKS_WARNING++))
    else
        ((CHECKS_PASSED++))
    fi

    return 0
}

#------------------------------------------------------------------------------
# Check 5: Port Availability
#------------------------------------------------------------------------------
check_ports() {
    log INFO "Checking port availability..."

    local ports=(
        "25:SMTP"
        "110:POP3"
        "143:IMAP"
        "465:SMTPS"
        "587:Submission"
        "993:IMAPS"
        "995:POP3S"
        "8080:Dashboard"
    )

    local ports_in_use=()

    for port_info in "${ports[@]}"; do
        local port="${port_info%%:*}"
        local service="${port_info##*:}"

        # Check if port is in use (Linux-specific, using ss or lsof)
        if command -v ss &> /dev/null; then
            if ss -tuln | grep -q ":${port} "; then
                ports_in_use+=("${port} (${service})")
            fi
        elif command -v lsof &> /dev/null; then
            if lsof -Pi ":${port}" -sTCP:LISTEN -t >/dev/null 2>&1; then
                ports_in_use+=("${port} (${service})")
            fi
        fi
    done

    if [[ ${#ports_in_use[@]} -gt 0 ]]; then
        warn "Ports already in use (${#ports_in_use[@]}):"
        for port in "${ports_in_use[@]}"; do
            warn "  - $port"
        done
        warn "Services may fail to start if ports are occupied"
        ((CHECKS_WARNING++))
    else
        info "All required ports are available"
        ((CHECKS_PASSED++))
    fi

    return 0
}

#------------------------------------------------------------------------------
# Check 6: File Permissions
#------------------------------------------------------------------------------
check_permissions() {
    log INFO "Checking file permissions..."

    local scripts=(
        "postfix/entrypoint.sh"
        "dovecot/entrypoint.sh"
        "init/generate-ssl.sh"
    )

    local non_executable=()
    local has_warnings=false

    for script in "${scripts[@]}"; do
        if [[ ! -x "$script" ]]; then
            non_executable+=("$script")
        fi
    done

    if [[ ${#non_executable[@]} -gt 0 ]]; then
        error "Scripts not executable (${#non_executable[@]}):"
        for script in "${non_executable[@]}"; do
            error "  - $script"
        done
        error "Run: chmod +x <script>"
        ((CHECKS_FAILED++))
        return 1
    fi

    info "All entrypoint scripts are executable"

    # Check MySQL init.sql permissions
    if [[ -f mysql/init.sql ]]; then
        local perms
        perms=$(stat -c "%a" mysql/init.sql 2>/dev/null || stat -f "%Lp" mysql/init.sql 2>/dev/null || echo "unknown")

        if [[ "$perms" == "600" ]]; then
            warn "mysql/init.sql has restrictive permissions (600)"
            warn "Docker may not be able to read it. Recommended: chmod 644 mysql/init.sql"
            has_warnings=true
        fi
    fi

    if [[ "$has_warnings" = true ]]; then
        ((CHECKS_WARNING++))
    else
        ((CHECKS_PASSED++))
    fi

    return 0
}

#------------------------------------------------------------------------------
# Check 7: docker-compose.yml Syntax
#------------------------------------------------------------------------------
check_compose_syntax() {
    log INFO "Checking docker-compose.yml syntax..."

    local output
    local has_warnings=false

    if ! output=$(docker compose config 2>&1); then
        error "docker-compose.yml has syntax errors:"
        error "$output"
        ((CHECKS_FAILED++))
        return 1
    fi

    # Check for version directive (obsolete in Compose v2)
    if grep -q "^version:" docker-compose.yml; then
        warn "docker-compose.yml uses 'version' directive (obsolete in Compose v2)"
        warn "Remove 'version:' line to avoid warnings"
        has_warnings=true
    fi

    info "docker-compose.yml syntax is valid"

    if [[ "$has_warnings" = true ]]; then
        ((CHECKS_WARNING++))
    else
        ((CHECKS_PASSED++))
    fi

    return 0
}

#------------------------------------------------------------------------------
# Check 8: Template Variable Validation
#------------------------------------------------------------------------------
check_template_variables() {
    log INFO "Checking template variables..."

    local has_warnings=false

    # Check Postfix main.cf.template
    if [[ -f postfix/main.cf.template ]]; then
        # Look for ${} variables that aren't standard Postfix internal vars
        local suspicious_vars
        suspicious_vars=$(grep -o '\${[^}]*}' postfix/main.cf.template 2>/dev/null | \
            grep -v '\${data_directory}' | \
            grep -v '\${queue_directory}' | \
            grep -v '\${command_directory}' | \
            grep -v '\${daemon_directory}' | \
            grep -v '\${config_directory}' | \
            sort -u || true)

        if [[ -n "$suspicious_vars" ]]; then
            warn "Postfix template contains variables that may need explicit substitution:"
            echo "$suspicious_vars" | while read -r var; do
                warn "  - $var"
            done
            warn "Verify these are in entrypoint.sh envsubst list"
            has_warnings=true
        fi
    fi

    # Check Dovecot templates
    if [[ -f dovecot/dovecot.conf.template ]]; then
        local dovecot_vars
        dovecot_vars=$(grep -o '\$[A-Z_]*' dovecot/dovecot.conf.template 2>/dev/null | sort -u || true)

        if [[ -n "$dovecot_vars" ]]; then
            # This is expected - just verify they're in the entrypoint
            : # No warning needed for expected variables
        fi
    fi

    info "Template variables checked"

    if [[ "$has_warnings" = true ]]; then
        ((CHECKS_WARNING++))
    else
        ((CHECKS_PASSED++))
    fi

    return 0
}

#------------------------------------------------------------------------------
# Check 9: Disk Space
#------------------------------------------------------------------------------
check_disk_space() {
    log INFO "Checking available disk space..."

    local available_gb
    available_gb=$(df -BG . | awk 'NR==2 {print $4}' | tr -d 'G')

    if [[ "$available_gb" -lt 5 ]]; then
        warn "Low disk space: ${available_gb}GB available"
        warn "Mail server images and volumes require at least 5GB"
        ((CHECKS_WARNING++))
    else
        info "Sufficient disk space available (${available_gb}GB)"
        ((CHECKS_PASSED++))
    fi

    return 0
}

#------------------------------------------------------------------------------
# Check 10: Docker Resource Limits
#------------------------------------------------------------------------------
check_docker_resources() {
    log INFO "Checking Docker resources..."

    # Check if Docker Desktop is running (has resource limits)
    if docker info 2>/dev/null | grep -q "Operating System.*Docker Desktop"; then
        info "Docker Desktop detected - verify resource allocation in settings"
        warn "Recommended: 4GB RAM, 2 CPUs for mail server"
        ((CHECKS_WARNING++))
    else
        info "Docker resources checked (native Docker)"
        ((CHECKS_PASSED++))
    fi

    return 0
}

#------------------------------------------------------------------------------
# Summary Report
#------------------------------------------------------------------------------
print_summary() {
    echo ""
    echo "========================================================================"
    echo "                    Pre-Flight Validation Summary"
    echo "========================================================================"
    echo ""
    echo -e "  ${GREEN}✓ Checks Passed:${NC}  $CHECKS_PASSED"
    echo -e "  ${YELLOW}⚠ Warnings:${NC}       $CHECKS_WARNING"
    echo -e "  ${RED}✗ Checks Failed:${NC}  $CHECKS_FAILED"
    echo ""

    if [[ $CHECKS_FAILED -gt 0 ]]; then
        echo -e "${RED}========================================================================${NC}"
        echo -e "${RED}  VALIDATION FAILED - Fix errors above before starting services${NC}"
        echo -e "${RED}========================================================================${NC}"
        return 1
    elif [[ $CHECKS_WARNING -gt 0 ]]; then
        echo -e "${YELLOW}========================================================================${NC}"
        echo -e "${YELLOW}  VALIDATION PASSED WITH WARNINGS - Review warnings above${NC}"
        echo -e "${YELLOW}========================================================================${NC}"
        return 0
    else
        echo -e "${GREEN}========================================================================${NC}"
        echo -e "${GREEN}  ALL CHECKS PASSED - System ready for deployment${NC}"
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
    echo "          Mail Server Pre-Flight Validation"
    echo "          Project 02: Dockerized Mail Server"
    echo "========================================================================"
    echo ""
    log INFO "Starting pre-flight validation checks..."
    echo ""

    # Run all checks (continue on failure to collect all issues)
    check_docker || true
    check_docker_compose || true
    check_config_files || true
    check_env_file || true
    check_ports || true
    check_permissions || true
    check_compose_syntax || true
    check_template_variables || true
    check_disk_space || true
    check_docker_resources || true

    # Print summary
    echo ""
    print_summary

    # Exit with appropriate code
    if [[ $CHECKS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"
