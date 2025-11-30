#!/bin/bash
set -euo pipefail

#==============================================================================
# Postfix Production Entrypoint Script
# Project: Dockerized Mail Server - Project 02
# Purpose: Initialize Postfix with comprehensive validation
#==============================================================================

#------------------------------------------------------------------------------
# Structured Logging
#------------------------------------------------------------------------------
log() {
    local level=$1
    shift
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [Postfix] [$level] $*"
}

#------------------------------------------------------------------------------
# Error Trap
#------------------------------------------------------------------------------
trap 'log ERROR "Failed at line $LINENO: $BASH_COMMAND"; exit 1' ERR

#------------------------------------------------------------------------------
# Environment Variable Validation
#------------------------------------------------------------------------------
validate_environment() {
    log INFO "Validating environment variables..."

    local required_vars=(
        "MAIL_HOSTNAME"
        "MAIL_DOMAIN"
        "MYSQL_HOST"
        "MYSQL_DATABASE"
        "MYSQL_USER"
        "MYSQL_PASSWORD"
    )

    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log ERROR "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi

    log INFO "All required environment variables present"
    log INFO "MAIL_HOSTNAME: ${MAIL_HOSTNAME}"
    log INFO "MAIL_DOMAIN: ${MAIL_DOMAIN}"
    log INFO "MYSQL_HOST: ${MYSQL_HOST}"
    log INFO "MYSQL_DATABASE: ${MYSQL_DATABASE}"
    log INFO "MYSQL_USER: ${MYSQL_USER}"

    return 0
}

#------------------------------------------------------------------------------
# Template Validation
#------------------------------------------------------------------------------
validate_templates() {
    log INFO "Validating configuration templates..."

    local templates=(
        "/etc/postfix/main.cf.template"
        "/etc/postfix/mysql-virtual-domains.cf"
        "/etc/postfix/mysql-virtual-mailboxes.cf"
        "/etc/postfix/mysql-virtual-aliases.cf"
    )

    for template in "${templates[@]}"; do
        if [[ ! -f "$template" ]]; then
            log ERROR "Template not found: $template"
            return 1
        fi
        if [[ ! -r "$template" ]]; then
            log ERROR "Template not readable: $template"
            return 1
        fi
        log INFO "Template OK: $template"
    done

    return 0
}

#------------------------------------------------------------------------------
# MySQL Connectivity Test
#------------------------------------------------------------------------------
test_mysql_connection() {
    log INFO "Testing MySQL connectivity..."

    local max_attempts=30
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        log INFO "MySQL connection attempt $attempt/$max_attempts"

        if mysqladmin ping -h"${MYSQL_HOST}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent 2>/dev/null; then
            log INFO "MySQL connection successful"
            return 0
        fi

        if [[ $attempt -eq $max_attempts ]]; then
            log ERROR "MySQL connection failed after $max_attempts attempts"
            return 1
        fi

        log WARN "MySQL not ready, waiting 2 seconds..."
        sleep 2
        ((attempt++))
    done

    return 1
}

#------------------------------------------------------------------------------
# Process Configuration Templates
#------------------------------------------------------------------------------
process_templates() {
    log INFO "Processing configuration templates..."

    # Process main.cf with explicit variable list (prevents internal variable corruption)
    log INFO "Processing main.cf.template..."
    if ! envsubst '$MAIL_HOSTNAME $MAIL_DOMAIN' < /etc/postfix/main.cf.template > /etc/postfix/main.cf; then
        log ERROR "Failed to process main.cf.template"
        return 1
    fi

    # Process MySQL lookup files
    local mysql_configs=(
        "mysql-virtual-domains.cf"
        "mysql-virtual-mailboxes.cf"
        "mysql-virtual-aliases.cf"
    )

    for config in "${mysql_configs[@]}"; do
        log INFO "Processing $config..."
        if ! envsubst < "/etc/postfix/$config" > "/etc/postfix/$config.tmp"; then
            log ERROR "Failed to process $config"
            return 1
        fi
        if ! mv "/etc/postfix/$config.tmp" "/etc/postfix/$config"; then
            log ERROR "Failed to replace $config"
            return 1
        fi
    done

    log INFO "All templates processed successfully"
    return 0
}

#------------------------------------------------------------------------------
# Set File Permissions
#------------------------------------------------------------------------------
set_permissions() {
    log INFO "Setting file permissions..."

    # Secure MySQL configuration files (contain password)
    if ! chmod 640 /etc/postfix/mysql-*.cf; then
        log ERROR "Failed to set permissions on MySQL config files"
        return 1
    fi
    if ! chown root:postfix /etc/postfix/mysql-*.cf; then
        log ERROR "Failed to set ownership on MySQL config files"
        return 1
    fi

    # Create mailbox directory structure
    if ! mkdir -p /var/mail/vhosts; then
        log ERROR "Failed to create /var/mail/vhosts"
        return 1
    fi
    if ! chown -R vmail:vmail /var/mail/vhosts; then
        log ERROR "Failed to set ownership on /var/mail/vhosts"
        return 1
    fi

    log INFO "File permissions set successfully"
    return 0
}

#------------------------------------------------------------------------------
# Validate Postfix Configuration
#------------------------------------------------------------------------------
validate_postfix_config() {
    log INFO "Validating Postfix configuration..."

    if ! postfix check; then
        log ERROR "Postfix configuration validation failed"
        return 1
    fi

    log INFO "Postfix configuration validation successful"
    return 0
}

#==============================================================================
# Main Execution
#==============================================================================
main() {
    log INFO "==================== Postfix Entrypoint Starting ===================="

    # Step 1: Validate environment
    validate_environment || exit 1

    # Step 2: Validate templates
    validate_templates || exit 1

    # Step 3: Test MySQL connectivity
    test_mysql_connection || exit 1

    # Step 4: Process templates
    process_templates || exit 1

    # Step 5: Set permissions
    set_permissions || exit 1

    # Step 6: Validate Postfix configuration
    validate_postfix_config || exit 1

    log INFO "==================== Postfix Initialization Complete ===================="
    log INFO "Starting Postfix service..."

    # Execute CMD (starts Postfix)
    exec "$@"
}

# Run main function with all arguments
main "$@"
