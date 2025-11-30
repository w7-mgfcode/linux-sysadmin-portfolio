#!/bin/bash
#===============================================================================
# SSL Certificate Generator - Self-Signed Certificates for Mail Server
#
# Purpose:
#   Generates self-signed SSL/TLS certificates for Postfix and Dovecot.
#   Idempotent: only generates if certificates don't already exist.
#
# Skills Demonstrated:
#   - OpenSSL certificate generation
#   - Subject Alternative Names (SAN) for multiple hostnames
#   - Idempotent script design
#   - Proper file permissions for security
#
# Author: Linux Sysadmin Portfolio
# License: MIT
#===============================================================================

set -euo pipefail

#===============================================================================
# Configuration
#===============================================================================
readonly CERT_DIR="/etc/mail/certs"
readonly MAIL_HOSTNAME="${MAIL_HOSTNAME:-mail.example.com}"
readonly SSL_DAYS="${SSL_DAYS_VALID:-3650}"

readonly CA_KEY="${CERT_DIR}/ca-key.pem"
readonly CA_CERT="${CERT_DIR}/ca-cert.pem"
readonly SERVER_KEY="${CERT_DIR}/mail-key.pem"
readonly SERVER_CSR="${CERT_DIR}/mail-csr.pem"
readonly SERVER_CERT="${CERT_DIR}/mail-cert.pem"
readonly DOVECOT_PEM="${CERT_DIR}/dovecot.pem"

#===============================================================================
# Logging Functions
#===============================================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ $*" >&2
}

#===============================================================================
# Certificate Functions
#===============================================================================

check_existing_certs() {
    if [[ -f "$SERVER_CERT" ]] && [[ -f "$SERVER_KEY" ]]; then
        log "SSL certificates already exist"

        # Show expiration date
        local expiry
        expiry=$(openssl x509 -in "$SERVER_CERT" -noout -enddate | cut -d= -f2)
        log "Certificate expires: $expiry"

        # Check if certificate is still valid for at least 30 days
        if openssl x509 -in "$SERVER_CERT" -checkend $((30 * 86400)) -noout; then
            log_success "Certificates are valid, skipping generation"
            return 0
        else
            log "Certificates expire soon, regenerating..."
            return 1
        fi
    fi

    return 1
}

generate_ca() {
    log "Generating Certificate Authority (CA)..."

    openssl req -new -x509 \
        -days "$SSL_DAYS" \
        -keyout "$CA_KEY" \
        -out "$CA_CERT" \
        -nodes \
        -subj "/C=US/ST=State/L=City/O=Mail Server/OU=IT/CN=Mail Server CA"

    log_success "CA certificate generated"
}

generate_server_cert() {
    log "Generating server certificate with SAN..."

    # Generate private key
    openssl genrsa -out "$SERVER_KEY" 4096

    # Create SAN configuration
    local san_config="${CERT_DIR}/san.cnf"
    cat > "$san_config" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Mail Server
OU = IT
CN = ${MAIL_HOSTNAME}

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${MAIL_HOSTNAME}
DNS.2 = localhost
DNS.3 = mail
IP.1 = 127.0.0.1
EOF

    # Generate Certificate Signing Request (CSR) with SAN
    openssl req -new \
        -key "$SERVER_KEY" \
        -out "$SERVER_CSR" \
        -config "$san_config"

    log_success "Server certificate request generated"
}

sign_certificate() {
    log "Signing server certificate with CA..."

    local san_config="${CERT_DIR}/san.cnf"

    # Sign the CSR with our CA
    openssl x509 -req \
        -days "$SSL_DAYS" \
        -in "$SERVER_CSR" \
        -CA "$CA_CERT" \
        -CAkey "$CA_KEY" \
        -CAcreateserial \
        -out "$SERVER_CERT" \
        -extensions v3_req \
        -extfile "$san_config"

    # Cleanup
    rm -f "$san_config" "$SERVER_CSR"

    log_success "Server certificate signed"
}

create_dovecot_pem() {
    log "Creating Dovecot combined PEM file..."

    # Dovecot prefers a single PEM file with both cert and key
    cat "$SERVER_CERT" "$SERVER_KEY" > "$DOVECOT_PEM"

    log_success "Dovecot PEM file created"
}

set_permissions() {
    log "Setting secure file permissions..."

    # Private keys: only readable by owner
    chmod 600 "$CA_KEY" "$SERVER_KEY" "$DOVECOT_PEM"

    # Certificates: readable by all (public keys)
    chmod 644 "$CA_CERT" "$SERVER_CERT"

    log_success "Permissions set"
}

verify_certificates() {
    log "Verifying generated certificates..."

    # Verify server certificate against CA
    if openssl verify -CAfile "$CA_CERT" "$SERVER_CERT" > /dev/null 2>&1; then
        log_success "Certificate verification passed"
    else
        log_error "Certificate verification failed"
        return 1
    fi

    # Show certificate details
    log "Certificate subject:"
    openssl x509 -in "$SERVER_CERT" -noout -subject

    log "Certificate SAN:"
    openssl x509 -in "$SERVER_CERT" -noout -text | grep -A1 "Subject Alternative Name"
}

#===============================================================================
# Main Execution
#===============================================================================
main() {
    log "=== SSL Certificate Generator ==="
    log "Hostname: $MAIL_HOSTNAME"
    log "Validity: $SSL_DAYS days"
    log "Directory: $CERT_DIR"

    # Create certificate directory
    mkdir -p "$CERT_DIR"
    cd "$CERT_DIR"

    # Check if certificates already exist and are valid
    if check_existing_certs; then
        exit 0
    fi

    # Generate new certificates
    generate_ca
    generate_server_cert
    sign_certificate
    create_dovecot_pem
    set_permissions
    verify_certificates

    log_success "SSL certificates generated successfully"
    log "Certificates location: $CERT_DIR"
}

# Execute main function
main "$@"
