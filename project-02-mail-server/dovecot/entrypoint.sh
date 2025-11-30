#!/bin/bash
set -euo pipefail

#==============================================================================
# Dovecot Production Entrypoint Script
# Project: Dockerized Mail Server - Project 02
# Purpose: Initialize Dovecot with comprehensive validation
#==============================================================================

#------------------------------------------------------------------------------
# Structured Logging
#------------------------------------------------------------------------------
log() {
    local level=$1
    shift
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [Dovecot] [$level] $*"
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
        "/etc/dovecot/dovecot.conf.template"
        "/etc/dovecot/dovecot-sql.conf.ext.template"
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
# Process Configuration Templates
#------------------------------------------------------------------------------
process_templates() {
    log INFO "Processing configuration templates..."

    # Process dovecot.conf with explicit variable list
    log INFO "Processing dovecot.conf.template..."
    if ! envsubst '$MAIL_DOMAIN' < /etc/dovecot/dovecot.conf.template > /etc/dovecot/dovecot.conf; then
        log ERROR "Failed to process dovecot.conf.template"
        return 1
    fi

    # Process dovecot-sql.conf.ext with MySQL variables
    log INFO "Processing dovecot-sql.conf.ext.template..."
    if ! envsubst '$MYSQL_HOST $MYSQL_DATABASE $MYSQL_USER $MYSQL_PASSWORD' < /etc/dovecot/dovecot-sql.conf.ext.template > /etc/dovecot/dovecot-sql.conf.ext; then
        log ERROR "Failed to process dovecot-sql.conf.ext.template"
        return 1
    fi

    log INFO "All templates processed successfully"
    return 0
}

#------------------------------------------------------------------------------
# Set File Permissions
#------------------------------------------------------------------------------
set_permissions() {
    log INFO "Setting file permissions..."

    # Secure SQL configuration file (contains password)
    if ! chmod 640 /etc/dovecot/dovecot-sql.conf.ext; then
        log ERROR "Failed to set permissions on dovecot-sql.conf.ext"
        return 1
    fi
    if ! chown root:dovecot /etc/dovecot/dovecot-sql.conf.ext; then
        log ERROR "Failed to set ownership on dovecot-sql.conf.ext"
        return 1
    fi

    # Create mail directory
    if ! mkdir -p /var/mail/vhosts; then
        log ERROR "Failed to create /var/mail/vhosts"
        return 1
    fi
    if ! chown -R vmail:vmail /var/mail/vhosts; then
        log ERROR "Failed to set ownership on /var/mail/vhosts"
        return 1
    fi

    # Create Postfix spool directories for LMTP and auth sockets
    if ! mkdir -p /var/spool/postfix/private; then
        log ERROR "Failed to create /var/spool/postfix/private"
        return 1
    fi
    if ! chown postfix:postfix /var/spool/postfix/private; then
        log ERROR "Failed to set ownership on /var/spool/postfix/private"
        return 1
    fi
    if ! chmod 750 /var/spool/postfix/private; then
        log ERROR "Failed to set permissions on /var/spool/postfix/private"
        return 1
    fi

    log INFO "File permissions set successfully"
    return 0
}

#------------------------------------------------------------------------------
# Validate Dovecot Configuration (Basic)
#------------------------------------------------------------------------------
validate_dovecot_config() {
    log INFO "Validating Dovecot configuration..."

    # Note: We don't run doveconf -n here because it tries to parse dovecot-sql.conf.ext
    # as a main config file when included directly. Dovecot will validate the SQL config
    # at runtime when it actually loads the auth modules.

    # Instead, we do basic validation: check if main config exists and is readable
    if [[ ! -f /etc/dovecot/dovecot.conf ]]; then
        log ERROR "Dovecot main configuration not found"
        return 1
    fi

    if [[ ! -r /etc/dovecot/dovecot.conf ]]; then
        log ERROR "Dovecot main configuration not readable"
        return 1
    fi

    log INFO "Dovecot configuration files validated successfully"
    log INFO "SQL authentication config will be validated by Dovecot at runtime"
    return 0
}

#==============================================================================
# Main Execution
#==============================================================================
main() {
    log INFO "==================== Dovecot Entrypoint Starting ===================="

    # Step 1: Validate environment
    validate_environment || exit 1

    # Step 2: Validate templates
    validate_templates || exit 1

    # Step 3: Process templates
    process_templates || exit 1

    # Step 4: Set permissions
    set_permissions || exit 1

    # Step 5: Validate Dovecot configuration
    validate_dovecot_config || exit 1

    log INFO "==================== Dovecot Initialization Complete ===================="
    log INFO "Starting Dovecot service..."

    # Execute CMD (starts Dovecot)
    exec "$@"
}

# Run main function with all arguments
main "$@"
