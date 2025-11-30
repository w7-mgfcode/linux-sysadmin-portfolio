#!/bin/bash
#===============================================================================
# User Management - Virtual Mailbox and Domain Administration
#
# Purpose:
#   Manage virtual domains, mailboxes, and aliases in the mail server.
#   Provides subcommand architecture for user-friendly administration.
#
# Usage:
#   ./user-management.sh domain add <domain>
#   ./user-management.sh user add <email> [--quota <size>]
#   ./user-management.sh user list [domain]
#   ./user-management.sh alias add <source> <destination>
#
# Skills Demonstrated:
#   - MySQL CLI interaction with error handling
#   - Subcommand architecture (Git-style)
#   - Input validation (email regex, domain validation)
#   - Password hashing (bcrypt via doveadm)
#   - Filesystem operations (maildir creation)
#   - Transaction handling
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

readonly MYSQL_HOST="${MYSQL_HOST:-mysql}"
readonly MYSQL_DATABASE="${MYSQL_DATABASE:-mailserver}"
readonly MYSQL_USER="${MYSQL_USER:-mailuser}"
readonly MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
readonly MAILDIR_BASE="${MAILDIR_BASE:-/var/mail/vhosts}"
readonly MAIL_UID="${MAIL_UID:-5000}"
readonly MAIL_GID="${MAIL_GID:-5000}"
readonly DEFAULT_QUOTA_MB="${DEFAULT_QUOTA_MB:-1024}"

#===============================================================================
# MySQL Helper Functions
#===============================================================================

mysql_exec() {
    local query="$1"
    docker exec -i mail-mysql mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "$query" 2>&1
}

mysql_query() {
    local query="$1"
    docker exec -i mail-mysql mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -sN -e "$query" 2>&1
}

check_mysql_connection() {
    if ! docker exec -i mail-mysql mysqladmin -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" ping &>/dev/null; then
        log_error "Cannot connect to MySQL"
        return 1
    fi
}

#===============================================================================
# Validation Functions
#===============================================================================

validate_email() {
    local email="$1"
    local regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"

    if [[ ! "$email" =~ $regex ]]; then
        log_error "Invalid email format: $email"
        return 1
    fi
}

validate_domain() {
    local domain="$1"
    local result
    result=$(mysql_query "SELECT COUNT(*) FROM virtual_domains WHERE name='$domain'")

    if [[ "$result" -eq 0 ]]; then
        log_error "Domain not found: $domain"
        return 1
    fi
}

extract_domain() {
    local email="$1"
    echo "${email##*@}"
}

parse_quota() {
    local quota_str="$1"
    local size="${quota_str%[MGmg]*}"
    local unit="${quota_str##*[0-9]}"

    case "${unit^^}" in
        G) echo $((size * 1024)) ;;
        M) echo "$size" ;;
        *) echo "$DEFAULT_QUOTA_MB" ;;
    esac
}

#===============================================================================
# Domain Management
#===============================================================================

domain_add() {
    local domain="$1"

    log_info "Adding domain: $domain"

    local result
    result=$(mysql_exec "INSERT INTO virtual_domains (name) VALUES ('$domain')" 2>&1)

    if [[ "$result" == *"Duplicate entry"* ]]; then
        log_error "Domain already exists: $domain"
        return 1
    elif [[ "$result" == *"ERROR"* ]]; then
        log_error "Failed to add domain: $result"
        return 1
    fi

    log_success "Domain added: $domain"
}

domain_delete() {
    local domain="$1"

    log_warning "Deleting domain: $domain (this will delete all users)"
    read -p "Are you sure? (yes/no): " -r

    if [[ ! "$REPLY" == "yes" ]]; then
        log_info "Cancelled"
        return 0
    fi

    mysql_exec "DELETE FROM virtual_domains WHERE name='$domain'"
    log_success "Domain deleted: $domain"
}

domain_list() {
    log_info "Virtual Domains:"
    echo ""
    printf "%-5s | %-30s | %-10s | %-20s\n" "ID" "Domain" "Users" "Created"
    echo "------|--------------------------------|------------|----------------------"

    mysql_query "
        SELECT
            d.id,
            d.name,
            COUNT(u.id) as user_count,
            d.created_at
        FROM virtual_domains d
        LEFT JOIN virtual_users u ON d.id = u.domain_id
        GROUP BY d.id, d.name, d.created_at
        ORDER BY d.name
    " | while IFS=$'\t' read -r id name count created; do
        printf "%-5s | %-30s | %-10s | %-20s\n" "$id" "$name" "$count" "$created"
    done
}

#===============================================================================
# User Management
#===============================================================================

user_add() {
    local email="$1"
    local quota="${2:-$DEFAULT_QUOTA_MB}"

    validate_email "$email" || return 1

    local domain
    domain=$(extract_domain "$email")
    validate_domain "$domain" || return 1

    log_info "Adding user: $email (quota: ${quota}MB)"

    # Get domain ID
    local domain_id
    domain_id=$(mysql_query "SELECT id FROM virtual_domains WHERE name='$domain'")

    # Generate password hash
    read -s -p "Enter password: " password
    echo
    read -s -p "Confirm password: " password2
    echo

    if [[ "$password" != "$password2" ]]; then
        log_error "Passwords do not match"
        return 1
    fi

    # Use doveadm to hash password (BLF-CRYPT)
    local password_hash
    password_hash=$(docker exec -i mail-dovecot doveadm pw -s BLF-CRYPT -p "$password")

    # Insert user
    mysql_exec "INSERT INTO virtual_users (domain_id, email, password, quota_mb) VALUES ($domain_id, '$email', '$password_hash', $quota)"

    # Create maildir
    create_maildir "$email"

    log_success "User added: $email"
}

user_delete() {
    local email="$1"

    validate_email "$email" || return 1

    log_warning "Deleting user: $email"
    read -p "Are you sure? (yes/no): " -r

    if [[ ! "$REPLY" == "yes" ]]; then
        log_info "Cancelled"
        return 0
    fi

    mysql_exec "DELETE FROM virtual_users WHERE email='$email'"
    delete_maildir "$email"

    log_success "User deleted: $email"
}

user_list() {
    local domain="${1:-}"

    log_info "Virtual Users:"
    echo ""
    printf "%-30s | %-10s | %-10s | %-20s\n" "Email" "Quota (MB)" "Enabled" "Created"
    echo "--------------------------------|------------|------------|----------------------"

    local where_clause=""
    if [[ -n "$domain" ]]; then
        where_clause="WHERE d.name='$domain'"
    fi

    mysql_query "
        SELECT
            u.email,
            u.quota_mb,
            u.enabled,
            u.created_at
        FROM virtual_users u
        JOIN virtual_domains d ON u.domain_id = d.id
        $where_clause
        ORDER BY u.email
    " | while IFS=$'\t' read -r email quota enabled created; do
        local enabled_str="Yes"
        [[ "$enabled" == "0" ]] && enabled_str="No"
        printf "%-30s | %-10s | %-10s | %-20s\n" "$email" "$quota" "$enabled_str" "$created"
    done
}

user_set_password() {
    local email="$1"

    validate_email "$email" || return 1

    log_info "Setting password for: $email"

    read -s -p "Enter new password: " password
    echo
    read -s -p "Confirm password: " password2
    echo

    if [[ "$password" != "$password2" ]]; then
        log_error "Passwords do not match"
        return 1
    fi

    local password_hash
    password_hash=$(docker exec -i mail-dovecot doveadm pw -s BLF-CRYPT -p "$password")

    mysql_exec "UPDATE virtual_users SET password='$password_hash' WHERE email='$email'"

    log_success "Password updated for: $email"
}

#===============================================================================
# Alias Management
#===============================================================================

alias_add() {
    local source="$1"
    local destination="$2"

    validate_email "$source" || return 1
    validate_email "$destination" || return 1

    local domain
    domain=$(extract_domain "$source")
    validate_domain "$domain" || return 1

    local domain_id
    domain_id=$(mysql_query "SELECT id FROM virtual_domains WHERE name='$domain'")

    log_info "Adding alias: $source -> $destination"

    mysql_exec "INSERT INTO virtual_aliases (domain_id, source, destination) VALUES ($domain_id, '$source', '$destination')"

    log_success "Alias added: $source -> $destination"
}

alias_delete() {
    local source="$1"
    local destination="$2"

    mysql_exec "DELETE FROM virtual_aliases WHERE source='$source' AND destination='$destination'"

    log_success "Alias deleted: $source -> $destination"
}

alias_list() {
    local domain="${1:-}"

    log_info "Virtual Aliases:"
    echo ""
    printf "%-30s | %-30s\n" "Source" "Destination"
    echo "--------------------------------|--------------------------------"

    local where_clause=""
    if [[ -n "$domain" ]]; then
        where_clause="WHERE d.name='$domain'"
    fi

    mysql_query "
        SELECT
            a.source,
            a.destination
        FROM virtual_aliases a
        JOIN virtual_domains d ON a.domain_id = d.id
        $where_clause
        ORDER BY a.source
    " | while IFS=$'\t' read -r source dest; do
        printf "%-30s | %-30s\n" "$source" "$dest"
    done
}

#===============================================================================
# Maildir Operations
#===============================================================================

create_maildir() {
    local email="$1"
    local domain
    domain=$(extract_domain "$email")
    local user="${email%%@*}"

    local maildir_path="$MAILDIR_BASE/$domain/$user"

    log_info "Creating maildir: $maildir_path"

    # Create directory structure
    docker exec -i mail-postfix mkdir -p "$maildir_path"/{cur,new,tmp}
    docker exec -i mail-postfix chown -R vmail:vmail "$maildir_path"
    docker exec -i mail-postfix chmod -R 700 "$maildir_path"

    log_success "Maildir created"
}

delete_maildir() {
    local email="$1"
    local domain
    domain=$(extract_domain "$email")
    local user="${email%%@*}"

    local maildir_path="$MAILDIR_BASE/$domain/$user"

    log_info "Deleting maildir: $maildir_path"

    docker exec -i mail-postfix rm -rf "$maildir_path"

    log_success "Maildir deleted"
}

#===============================================================================
# Main Command Dispatcher
#===============================================================================

main() {
    check_mysql_connection || exit 1

    local command="${1:-}"
    local subcommand="${2:-}"

    case "$command" in
        domain)
            case "$subcommand" in
                add) domain_add "$3" ;;
                delete) domain_delete "$3" ;;
                list) domain_list ;;
                *) echo "Usage: $0 domain {add|delete|list} <domain>"; exit 1 ;;
            esac
            ;;
        user)
            case "$subcommand" in
                add) user_add "$3" "${4:-$DEFAULT_QUOTA_MB}" ;;
                delete) user_delete "$3" ;;
                list) user_list "${3:-}" ;;
                set-password) user_set_password "$3" ;;
                *) echo "Usage: $0 user {add|delete|list|set-password} <email>"; exit 1 ;;
            esac
            ;;
        alias)
            case "$subcommand" in
                add) alias_add "$3" "$4" ;;
                delete) alias_delete "$3" "$4" ;;
                list) alias_list "${3:-}" ;;
                *) echo "Usage: $0 alias {add|delete|list} <source> <destination>"; exit 1 ;;
            esac
            ;;
        *)
            cat << EOF
Usage: $0 <command> <subcommand> [arguments]

Commands:
  domain add <domain>              Add a new virtual domain
  domain delete <domain>           Delete a domain and all users
  domain list                      List all domains

  user add <email> [--quota <MB>]  Add a new mailbox
  user delete <email>              Delete a mailbox
  user list [domain]               List all users (optionally filtered)
  user set-password <email>        Change user password

  alias add <source> <dest>        Add email alias/forward
  alias delete <source> <dest>     Delete email alias
  alias list [domain]              List all aliases

Examples:
  $0 domain add example.com
  $0 user add john@example.com
  $0 user add jane@example.com --quota 2048
  $0 alias add info@example.com john@example.com
EOF
            exit 1
            ;;
    esac
}

# Execute main
main "$@"
