#!/bin/bash
#===============================================================================
# Mail Flow Test - End-to-End Email Delivery Verification
#
# Purpose:
#   Tests complete mail flow through the server including SMTP submission,
#   spam filtering, mailbox delivery, and IMAP retrieval. Validates
#   authentication, TLS, and message integrity.
#
# Usage:
#   ./test-mail-flow.sh                         # Interactive test
#   ./test-mail-flow.sh --auto                  # Automated test
#   ./test-mail-flow.sh --from user@example.com # Specify sender
#
# Skills Demonstrated:
#   - SMTP protocol interaction (EHLO, AUTH, MAIL FROM, RCPT TO, DATA)
#   - IMAP protocol commands (LOGIN, SELECT, FETCH)
#   - Base64 encoding for authentication
#   - Expect-like scripting with bash
#   - Message parsing and validation
#   - Timeout handling
#   - Test automation patterns
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

# Mail server settings
readonly SMTP_HOST="${SMTP_HOST:-localhost}"
readonly SMTP_PORT="${SMTP_PORT:-587}"
readonly IMAP_HOST="${IMAP_HOST:-localhost}"
readonly IMAP_PORT="${IMAP_PORT:-143}"

# Test accounts (from init.sql)
readonly TEST_FROM="${1:-john@example.com}"
readonly TEST_TO="${2:-jane@example.com}"
readonly TEST_PASSWORD="password"

# Test message
readonly TEST_SUBJECT="Test Mail - $(date '+%Y%m%d-%H%M%S')"
readonly TEST_BODY="This is a test message sent at $(date)"
readonly MESSAGE_ID="<test-$(date +%s)@example.com>"

# Temporary files
readonly TEMP_DIR="/tmp/mail-flow-test-$$"
mkdir -p "$TEMP_DIR"
trap 'rm -rf "$TEMP_DIR"' EXIT

#===============================================================================
# SMTP Functions
#===============================================================================

smtp_connect() {
    log_info "Connecting to SMTP server..."

    local response
    if ! response=$(timeout 5 bash -c "echo QUIT | nc $SMTP_HOST $SMTP_PORT" 2>&1 | head -1); then
        log_error "Cannot connect to SMTP server"
        return 1
    fi

    if [[ "$response" =~ ^220 ]]; then
        log_success "SMTP server responded: $response"
        return 0
    else
        log_error "Unexpected SMTP response: $response"
        return 1
    fi
}

smtp_send_mail() {
    local from="$1"
    local to="$2"
    local subject="$3"
    local body="$4"

    log_info "Sending test email..."
    log_info "  From: $from"
    log_info "  To: $to"
    log_info "  Subject: $subject"

    # Generate AUTH PLAIN token (base64 encoded \0username\0password)
    local auth_plain
    auth_plain=$(printf '\0%s\0%s' "${from%%@*}" "$TEST_PASSWORD" | base64 -w0)

    # Craft SMTP session
    local smtp_commands
    smtp_commands=$(cat << EOF
EHLO test-client
AUTH PLAIN $auth_plain
MAIL FROM:<$from>
RCPT TO:<$to>
DATA
From: $from
To: $to
Subject: $subject
Message-ID: $MESSAGE_ID
Date: $(date -R)

$body
.
QUIT
EOF
)

    # Send via netcat
    local response
    response=$(echo "$smtp_commands" | nc -w 10 "$SMTP_HOST" "$SMTP_PORT" 2>&1 || echo "ERROR")

    # Check for success
    if echo "$response" | grep -q "250.*Ok: queued"; then
        log_success "Message accepted by SMTP server"
        log_info "Response: $(echo "$response" | grep "250.*Ok")"
        return 0
    else
        log_error "SMTP sending failed"
        log_error "Response: $response"
        return 1
    fi
}

#===============================================================================
# IMAP Functions
#===============================================================================

imap_connect() {
    log_info "Connecting to IMAP server..."

    local response
    if ! response=$(timeout 5 bash -c "echo 'a1 LOGOUT' | nc $IMAP_HOST $IMAP_PORT" 2>&1 | head -1); then
        log_error "Cannot connect to IMAP server"
        return 1
    fi

    if [[ "$response" =~ ^\*.*OK ]]; then
        log_success "IMAP server responded: $response"
        return 0
    else
        log_error "Unexpected IMAP response: $response"
        return 1
    fi
}

imap_check_mailbox() {
    local user="$1"
    local password="$2"

    log_info "Checking mailbox for: $user"

    # Wait a bit for mail delivery
    log_info "Waiting 5 seconds for mail delivery..."
    sleep 5

    # IMAP commands
    local imap_commands
    imap_commands=$(cat << EOF
a1 LOGIN $user $password
a2 SELECT INBOX
a3 SEARCH SUBJECT "$TEST_SUBJECT"
a4 LOGOUT
EOF
)

    # Execute IMAP session
    local response
    response=$(echo "$imap_commands" | nc -w 10 "$IMAP_HOST" "$IMAP_PORT" 2>&1 || echo "ERROR")

    # Check for message
    if echo "$response" | grep -q "\\* SEARCH [0-9]"; then
        log_success "Test message found in mailbox"

        # Extract message UID
        local msg_uid
        msg_uid=$(echo "$response" | grep -oP '\\* SEARCH \K[0-9]+' | head -1)
        log_info "Message UID: $msg_uid"

        return 0
    else
        log_error "Test message not found in mailbox"
        log_warning "IMAP response:"
        echo "$response" | grep -E "^(\\*|a[0-9])" || echo "$response"
        return 1
    fi
}

imap_fetch_message() {
    local user="$1"
    local password="$2"
    local msg_uid="$3"

    log_info "Fetching message $msg_uid..."

    local imap_commands
    imap_commands=$(cat << EOF
a1 LOGIN $user $password
a2 SELECT INBOX
a3 FETCH $msg_uid BODY[HEADER]
a4 LOGOUT
EOF
)

    local headers
    headers=$(echo "$imap_commands" | nc -w 10 "$IMAP_HOST" "$IMAP_PORT" 2>&1 || echo "ERROR")

    if echo "$headers" | grep -q "Message-ID: $MESSAGE_ID"; then
        log_success "Message ID verified: $MESSAGE_ID"
        return 0
    else
        log_warning "Message ID mismatch or not found"
        return 1
    fi
}

#===============================================================================
# Queue Monitoring
#===============================================================================

check_mail_queue() {
    log_info "Checking mail queue status..."

    if command -v docker &>/dev/null && docker ps | grep -q mail-postfix; then
        local queue_count
        queue_count=$(docker exec mail-postfix mailq 2>/dev/null | grep -c "^[A-F0-9]" || echo "0")

        if [[ "$queue_count" -eq 0 ]]; then
            log_success "Mail queue is empty (all delivered)"
        else
            log_warning "Mail queue has $queue_count message(s)"
        fi
    else
        log_warning "Cannot check queue (docker not available)"
    fi
}

#===============================================================================
# Spam Filter Test
#===============================================================================

test_spam_filter() {
    log_info "Testing spam filter..."

    # Send a message with spam-like content
    local spam_subject="BUY NOW !!! LIMITED TIME OFFER !!!"
    local spam_body="FREE MONEY CLICK HERE NOW VIAGRA CASINO WIN BIG"

    local spam_commands
    spam_commands=$(cat << EOF
EHLO test-client
MAIL FROM:<spammer@example.com>
RCPT TO:<$TEST_TO>
DATA
From: spammer@example.com
To: $TEST_TO
Subject: $spam_subject

$spam_body
.
QUIT
EOF
)

    local response
    response=$(echo "$spam_commands" | nc -w 10 "$SMTP_HOST" "$SMTP_PORT" 2>&1 || echo "ERROR")

    # SpamAssassin might reject or flag it
    if echo "$response" | grep -qE "(550|554|rejected|spam)"; then
        log_success "Spam message rejected/flagged"
    else
        log_warning "Spam message was accepted (may still be scored)"
    fi
}

#===============================================================================
# Authentication Tests
#===============================================================================

test_auth_failure() {
    log_info "Testing authentication with wrong password..."

    local bad_auth
    bad_auth=$(printf '\0%s\0%s' "${TEST_FROM%%@*}" "wrongpassword" | base64 -w0)

    local auth_commands
    auth_commands=$(cat << EOF
EHLO test-client
AUTH PLAIN $bad_auth
QUIT
EOF
)

    local response
    response=$(echo "$auth_commands" | nc -w 10 "$SMTP_HOST" "$SMTP_PORT" 2>&1 || echo "ERROR")

    if echo "$response" | grep -qE "(535|authentication failed)"; then
        log_success "Authentication correctly rejected bad password"
        return 0
    else
        log_error "Authentication should have failed but didn't"
        return 1
    fi
}

test_auth_success() {
    log_info "Testing authentication with correct password..."

    local good_auth
    good_auth=$(printf '\0%s\0%s' "${TEST_FROM%%@*}" "$TEST_PASSWORD" | base64 -w0)

    local auth_commands
    auth_commands=$(cat << EOF
EHLO test-client
AUTH PLAIN $good_auth
QUIT
EOF
)

    local response
    response=$(echo "$auth_commands" | nc -w 10 "$SMTP_HOST" "$SMTP_PORT" 2>&1 || echo "ERROR")

    if echo "$response" | grep -q "235.*Authentication successful"; then
        log_success "Authentication successful"
        return 0
    else
        log_error "Authentication failed with correct password"
        return 1
    fi
}

#===============================================================================
# TLS Test
#===============================================================================

test_starttls() {
    log_info "Testing STARTTLS support..."

    local response
    response=$(echo "EHLO test-client" | nc -w 5 "$SMTP_HOST" "$SMTP_PORT" 2>&1 || echo "ERROR")

    if echo "$response" | grep -q "250.*STARTTLS"; then
        log_success "STARTTLS is advertised"
        return 0
    else
        log_warning "STARTTLS not advertised (might not be required on port $SMTP_PORT)"
        return 1
    fi
}

#===============================================================================
# Main Test Flow
#===============================================================================

main() {
    log_info "=== Mail Flow Test Suite ==="
    log_info "From: $TEST_FROM"
    log_info "To: $TEST_TO"
    echo ""

    # Phase 1: Connectivity
    smtp_connect || exit 1
    imap_connect || exit 1
    echo ""

    # Phase 2: Authentication
    test_auth_failure
    test_auth_success
    echo ""

    # Phase 3: TLS
    test_starttls
    echo ""

    # Phase 4: Send Test Mail
    smtp_send_mail "$TEST_FROM" "$TEST_TO" "$TEST_SUBJECT" "$TEST_BODY" || {
        log_error "Failed to send test mail"
        exit 1
    }
    echo ""

    # Phase 5: Check Queue
    check_mail_queue
    echo ""

    # Phase 6: Retrieve Mail
    imap_check_mailbox "$TEST_TO" "$TEST_PASSWORD" || {
        log_error "Failed to retrieve test mail"
        exit 1
    }
    echo ""

    # Phase 7: Spam Filter Test
    test_spam_filter
    echo ""

    log_success "=== All Mail Flow Tests Completed ==="
    log_info "Test message was successfully:"
    log_info "  1. Authenticated via SMTP"
    log_info "  2. Accepted by Postfix"
    log_info "  3. Delivered to mailbox"
    log_info "  4. Retrieved via IMAP"
    echo ""
    log_success "Mail server is functioning correctly!"
}

# Execute main
main "$@"
