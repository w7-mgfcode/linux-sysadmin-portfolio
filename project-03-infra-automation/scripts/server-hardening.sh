#!/bin/bash
#===============================================================================
# Server Hardening Script - Automated Security Baseline Configuration
#
# Purpose:
#   Applies CIS-aligned security hardening across multiple areas:
#   - SSH configuration hardening
#   - Kernel parameter security tuning
#   - Firewall baseline rules
#   - File permission auditing
#   - User security assessment
#
# Usage:
#   ./server-hardening.sh [options]
#   ./server-hardening.sh --check          # Dry-run mode (no changes)
#   ./server-hardening.sh --modules ssh,kernel  # Specific modules only
#   ./server-hardening.sh --fix            # Auto-fix issues
#
# Skills Demonstrated:
#   - Idempotent operations (safe to run multiple times)
#   - Multi-module architecture with error isolation
#   - Configuration validation before application
#   - Comprehensive backup strategy
#   - Multi-OS compatibility (Debian, Ubuntu, Alpine)
#   - JSON report generation
#   - Security best practices implementation
#
# Author: Linux Sysadmin Portfolio
# License: MIT
#===============================================================================

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

#===============================================================================
# Configuration
#===============================================================================
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly BACKUP_DIR="${BACKUP_DIR:-/var/backups/hardening}/$(timestamp_filename)"
readonly REPORT_DIR="${REPORT_DIR:-/var/reports}"
readonly LOG_FILE="/var/log/infra/server-hardening.log"

# Counters
declare -i CHANGES_MADE=0
declare -i ERRORS=0
declare -i WARNINGS=0

# Flags
DRY_RUN=false
AUTO_FIX=false
MODULES="all"

# Module tracking
declare -A MODULE_STATUS=(
    [ssh]="pending"
    [kernel]="pending"
    [firewall]="pending"
    [permissions]="pending"
    [users]="pending"
)

#===============================================================================
# Helper Functions
#===============================================================================

usage() {
    cat << EOF
Usage: $SCRIPT_NAME [options]

Automated security hardening script for Linux servers.

Options:
    --check             Dry-run mode (audit only, no changes)
    --fix               Auto-fix issues without prompting
    --modules MODULE    Comma-separated list of modules to run
                        Available: ssh,kernel,firewall,permissions,users,all
    --help              Display this help message
    --version           Display script version

Examples:
    $SCRIPT_NAME                    # Run all modules interactively
    $SCRIPT_NAME --check            # Audit only (no changes)
    $SCRIPT_NAME --modules ssh      # Harden SSH only
    $SCRIPT_NAME --fix              # Auto-fix all issues

Modules:
    ssh         - SSH daemon hardening
    kernel      - Kernel security parameters
    firewall    - Baseline firewall rules
    permissions - File permission audit
    users       - User security audit

EOF
}

version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION"
}

log_to_file() {
    echo "[$(timestamp_human)] $*" >> "$LOG_FILE"
}

track_change() {
    ((CHANGES_MADE++))
    log_to_file "CHANGE: $*"
}

track_error() {
    ((ERRORS++))
    log_to_file "ERROR: $*"
}

track_warning() {
    ((WARNINGS++))
    log_to_file "WARNING: $*"
}

should_run_module() {
    local module="$1"
    [[ "$MODULES" == "all" ]] || [[ "$MODULES" == *"$module"* ]]
}

#===============================================================================
# Pre-flight Checks
#===============================================================================

check_prerequisites() {
    log_info "Performing pre-flight checks..."

    # Must be root
    if ! check_root; then
        log_error "This script must be run as root"
        exit 1
    fi

    # Check required commands
    local -a required_commands=(
        "awk" "sed" "grep" "find" "stat" "chmod"
    )

    if ! check_dependencies "${required_commands[@]}"; then
        log_error "Missing required commands"
        exit 1
    fi

    # Detect OS
    local os
    os=$(detect_os)
    log_info "Detected OS: $os $(detect_os_version)"

    # Create required directories
    ensure_directory "$BACKUP_DIR"
    ensure_directory "$REPORT_DIR"
    ensure_directory "$(dirname "$LOG_FILE")"

    log_success "Pre-flight checks passed"
}

#===============================================================================
# Module 1: SSH Hardening
#===============================================================================

harden_ssh() {
    log_info "=== SSH Hardening Module ==="
    MODULE_STATUS[ssh]="running"

    # Check if SSH is installed
    if ! command -v sshd &>/dev/null; then
        log_warning "SSH server not installed, skipping module"
        MODULE_STATUS[ssh]="skipped"
        return 0
    fi

    local ssh_config_dir="/etc/ssh/sshd_config.d"
    local hardening_config="${ssh_config_dir}/99-hardening.conf"

    # Create config directory if it doesn't exist
    if [[ ! -d "$ssh_config_dir" ]]; then
        log_info "Creating SSH config directory: $ssh_config_dir"
        if [[ "$DRY_RUN" == "false" ]]; then
            mkdir -p "$ssh_config_dir"
        fi
    fi

    # Generate hardening configuration
    local config_content
    config_content=$(cat << 'EOF'
# SSH Hardening Configuration
# Generated by server-hardening.sh

# Protocol
Protocol 2

# Authentication
PermitRootLogin prohibit-password
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
UsePAM yes

# Security settings
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 60

# Disable unnecessary features
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PermitTunnel no

# Keep alive settings
ClientAliveInterval 300
ClientAliveCountMax 2

# Logging
LogLevel VERBOSE
EOF
)

    # Check if already hardened (idempotency)
    if [[ -f "$hardening_config" ]]; then
        if echo "$config_content" | diff -q - "$hardening_config" &>/dev/null; then
            log_success "SSH already hardened (no changes needed)"
            MODULE_STATUS[ssh]="completed"
            return 0
        else
            log_info "Existing SSH hardening config differs, updating..."
        fi
    fi

    # Backup existing SSH configuration
    if [[ "$DRY_RUN" == "false" ]]; then
        if [[ -f /etc/ssh/sshd_config ]]; then
            backup_file "/etc/ssh/sshd_config" "$BACKUP_DIR"
        fi
        if [[ -f "$hardening_config" ]]; then
            backup_file "$hardening_config" "$BACKUP_DIR"
        fi
    fi

    # Apply hardening configuration
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "$config_content" > "$hardening_config"
        chmod 600 "$hardening_config"

        # Validate SSH configuration
        if sshd -t 2>/dev/null; then
            log_success "SSH configuration validated successfully"
            track_change "SSH hardening applied"
            MODULE_STATUS[ssh]="completed"
        else
            log_error "SSH configuration validation failed, reverting..."
            rm -f "$hardening_config"
            track_error "SSH hardening failed validation"
            MODULE_STATUS[ssh]="failed"
            return 1
        fi
    else
        log_info "[DRY-RUN] Would apply SSH hardening configuration"
        MODULE_STATUS[ssh]="completed"
    fi

    log_success "SSH hardening module completed"
}

#===============================================================================
# Module 2: Kernel Hardening
#===============================================================================

harden_kernel() {
    log_info "=== Kernel Hardening Module ==="
    MODULE_STATUS[kernel]="running"

    local sysctl_dir="/etc/sysctl.d"
    local hardening_config="${sysctl_dir}/99-hardening.conf"

    # Ensure sysctl directory exists
    ensure_directory "$sysctl_dir"

    # Generate kernel hardening parameters
    local sysctl_content
    sysctl_content=$(cat << 'EOF'
# Kernel Hardening Configuration
# Generated by server-hardening.sh

# Network Security
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# IPv6 Security
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Kernel Security
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1

# Disable unused protocols
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
EOF
)

    # Check if already hardened
    if [[ -f "$hardening_config" ]]; then
        if echo "$sysctl_content" | diff -q - "$hardening_config" &>/dev/null; then
            log_success "Kernel already hardened (no changes needed)"
            MODULE_STATUS[kernel]="completed"
            return 0
        fi
    fi

    # Backup existing configuration
    if [[ "$DRY_RUN" == "false" ]]; then
        if [[ -f "$hardening_config" ]]; then
            backup_file "$hardening_config" "$BACKUP_DIR"
        fi
    fi

    # Apply kernel hardening
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "$sysctl_content" > "$hardening_config"
        chmod 644 "$hardening_config"

        # Apply sysctl settings
        if sysctl --system > /dev/null 2>&1; then
            log_success "Kernel parameters applied successfully"
            track_change "Kernel hardening applied"
            MODULE_STATUS[kernel]="completed"
        else
            log_warning "Some kernel parameters may not have applied (check dmesg)"
            track_warning "Kernel hardening partially applied"
            MODULE_STATUS[kernel]="completed"
        fi
    else
        log_info "[DRY-RUN] Would apply kernel hardening parameters"
        MODULE_STATUS[kernel]="completed"
    fi

    log_success "Kernel hardening module completed"
}

#===============================================================================
# Module 3: Firewall Configuration
#===============================================================================

configure_firewall() {
    log_info "=== Firewall Configuration Module ==="
    MODULE_STATUS[firewall]="running"

    # Detect firewall tool
    local firewall_tool=""
    if command -v iptables &>/dev/null; then
        firewall_tool="iptables"
    elif command -v nft &>/dev/null; then
        firewall_tool="nftables"
    elif command -v ufw &>/dev/null; then
        firewall_tool="ufw"
    else
        log_warning "No firewall tool found, skipping module"
        MODULE_STATUS[firewall]="skipped"
        return 0
    fi

    log_info "Detected firewall tool: $firewall_tool"

    # Container detection - firewall rules may not work
    if is_containerized; then
        log_warning "Running in container - firewall rules may not apply"
        track_warning "Firewall configuration skipped (containerized)"
        MODULE_STATUS[firewall]="skipped"
        return 0
    fi

    case "$firewall_tool" in
        iptables)
            configure_iptables
            ;;
        nftables)
            log_info "nftables detected - would configure baseline rules"
            MODULE_STATUS[firewall]="completed"
            ;;
        ufw)
            configure_ufw
            ;;
    esac

    log_success "Firewall configuration module completed"
}

configure_iptables() {
    local rules_file="/etc/iptables/rules.v4"

    ensure_directory "$(dirname "$rules_file")"

    # Generate baseline iptables rules
    local rules_content
    rules_content=$(cat << 'EOF'
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Loopback
-A INPUT -i lo -j ACCEPT
-A OUTPUT -o lo -j ACCEPT

# Established connections
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# SSH with rate limiting
-A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name SSH
-A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
-A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT

# HTTP/HTTPS (if needed)
# -A INPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW -j ACCEPT

# ICMP (ping) rate limited
-A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 4 -j ACCEPT

# Log dropped packets (rate limited)
-A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables-dropped: " --log-level 4

COMMIT
EOF
)

    if [[ "$DRY_RUN" == "false" ]]; then
        backup_file "$rules_file" "$BACKUP_DIR" 2>/dev/null || true
        echo "$rules_content" > "$rules_file"
        log_info "Firewall rules generated (apply manually with: iptables-restore < $rules_file)"
        track_change "Firewall baseline rules created"
        MODULE_STATUS[firewall]="completed"
    else
        log_info "[DRY-RUN] Would generate firewall baseline rules"
        MODULE_STATUS[firewall]="completed"
    fi
}

configure_ufw() {
    if [[ "$DRY_RUN" == "false" ]]; then
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw limit ssh
        # ufw allow http
        # ufw allow https
        ufw --force enable
        log_success "UFW firewall configured"
        track_change "UFW firewall configured"
        MODULE_STATUS[firewall]="completed"
    else
        log_info "[DRY-RUN] Would configure UFW firewall"
        MODULE_STATUS[firewall]="completed"
    fi
}

#===============================================================================
# Module 4: File Permissions Audit
#===============================================================================

audit_permissions() {
    log_info "=== File Permissions Audit Module ==="
    MODULE_STATUS[permissions]="running"

    # Define sensitive files and their required permissions
    local -A sensitive_files=(
        ["/etc/passwd"]="644"
        ["/etc/shadow"]="600"
        ["/etc/group"]="644"
        ["/etc/gshadow"]="600"
        ["/etc/ssh/sshd_config"]="600"
    )

    local issues=0

    # Check critical file permissions
    for file in "${!sensitive_files[@]}"; do
        local expected="${sensitive_files[$file]}"

        if [[ ! -f "$file" ]]; then
            continue
        fi

        local current
        current=$(stat -c "%a" "$file")

        if [[ "$current" != "$expected" ]]; then
            log_warning "Incorrect permissions on $file: $current (expected: $expected)"
            track_warning "Permission issue: $file"
            ((issues++))

            if [[ "$AUTO_FIX" == "true" && "$DRY_RUN" == "false" ]]; then
                chmod "$expected" "$file"
                log_success "Fixed permissions on $file: $current → $expected"
                track_change "Fixed permissions: $file"
            fi
        else
            log_debug "Permissions OK: $file ($current)"
        fi
    done

    # Find world-writable files in critical directories
    log_info "Scanning for world-writable files in /etc and /usr..."
    local ww_files
    ww_files=$(find /etc /usr -xdev -type f -perm -0002 2>/dev/null | head -20)

    if [[ -n "$ww_files" ]]; then
        log_warning "Found world-writable files:"
        while IFS= read -r file; do
            log_warning "  $file"
            track_warning "World-writable file: $file"
            ((issues++))
        done <<< "$ww_files"
    else
        log_success "No world-writable files found in /etc or /usr"
    fi

    if ((issues == 0)); then
        log_success "File permissions audit passed"
    else
        log_warning "Found $issues permission issues"
    fi

    MODULE_STATUS[permissions]="completed"
}

#===============================================================================
# Module 5: User Security Audit
#===============================================================================

audit_users() {
    log_info "=== User Security Audit Module ==="
    MODULE_STATUS[users]="running"

    local issues=0

    # Check for users with empty passwords
    log_info "Checking for users with empty passwords..."
    local empty_pass
    empty_pass=$(awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null)

    if [[ -n "$empty_pass" ]]; then
        log_warning "Users with empty passwords found:"
        while IFS= read -r user; do
            log_warning "  $user"
            track_warning "Empty password: $user"
            ((issues++))
        done <<< "$empty_pass"
    else
        log_success "No users with empty passwords"
    fi

    # Check for duplicate UID 0 accounts
    log_info "Checking for non-root users with UID 0..."
    local uid_zero
    uid_zero=$(awk -F: '($3 == 0 && $1 != "root") {print $1}' /etc/passwd)

    if [[ -n "$uid_zero" ]]; then
        log_error "Non-root users with UID 0 (SECURITY RISK!):"
        while IFS= read -r user; do
            log_error "  $user"
            track_error "UID 0 user: $user"
            ((issues++))
        done <<< "$uid_zero"
    else
        log_success "No unauthorized UID 0 users"
    fi

    # Lock system accounts
    log_info "Locking system accounts..."
    local -a system_accounts=(
        "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail"
        "news" "uucp" "proxy" "www-data" "backup" "list"
        "irc" "gnats" "nobody"
    )

    for account in "${system_accounts[@]}"; do
        if id "$account" &>/dev/null; then
            if [[ "$DRY_RUN" == "false" ]]; then
                usermod -L "$account" 2>/dev/null || true
                usermod -s /usr/sbin/nologin "$account" 2>/dev/null || true
                log_debug "Locked system account: $account"
            fi
        fi
    done

    if [[ "$DRY_RUN" == "false" ]]; then
        log_success "System accounts locked"
        track_change "System accounts locked"
    else
        log_info "[DRY-RUN] Would lock system accounts"
    fi

    if ((issues == 0)); then
        log_success "User security audit passed"
    else
        log_warning "Found $issues user security issues"
    fi

    MODULE_STATUS[users]="completed"
}

#===============================================================================
# Reporting
#===============================================================================

generate_report() {
    local report_file="${REPORT_DIR}/hardening-$(timestamp_filename).json"

    log_info "Generating report: $report_file"

    # Build module status JSON
    local modules_json=""
    for module in "${!MODULE_STATUS[@]}"; do
        modules_json+="\"$module\": \"${MODULE_STATUS[$module]}\", "
    done
    modules_json="${modules_json%, }"  # Remove trailing comma

    cat > "$report_file" << EOF
{
    "timestamp": "$(timestamp_iso)",
    "hostname": "$(hostname)",
    "script": "$SCRIPT_NAME",
    "version": "$SCRIPT_VERSION",
    "os": "$(detect_os)",
    "os_version": "$(detect_os_version)",
    "summary": {
        "changes_made": $CHANGES_MADE,
        "errors": $ERRORS,
        "warnings": $WARNINGS,
        "dry_run": $DRY_RUN
    },
    "modules": {
        $modules_json
    },
    "backup_location": "$BACKUP_DIR",
    "checks_performed": [
        "ssh_hardening",
        "kernel_hardening",
        "firewall_configuration",
        "permissions_audit",
        "user_security"
    ]
}
EOF

    log_success "Report saved: $report_file"
}

#===============================================================================
# Argument Parsing
#===============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check)
                DRY_RUN=true
                log_info "Running in DRY-RUN mode (no changes will be made)"
                shift
                ;;
            --fix)
                AUTO_FIX=true
                log_info "Auto-fix mode enabled"
                shift
                ;;
            --modules)
                MODULES="$2"
                log_info "Running modules: $MODULES"
                shift 2
                ;;
            --help)
                usage
                exit 0
                ;;
            --version)
                version
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

#===============================================================================
# Main Execution
#===============================================================================

main() {
    log_info "=========================================="
    log_info "Server Hardening Script v$SCRIPT_VERSION"
    log_info "=========================================="

    parse_arguments "$@"
    check_prerequisites

    # Run modules
    if should_run_module "ssh"; then
        harden_ssh || true
    fi

    if should_run_module "kernel"; then
        harden_kernel || true
    fi

    if should_run_module "firewall"; then
        configure_firewall || true
    fi

    if should_run_module "permissions"; then
        audit_permissions || true
    fi

    if should_run_module "users"; then
        audit_users || true
    fi

    # Generate report
    generate_report

    # Summary
    echo ""
    log_info "=========================================="
    log_info "Hardening Summary"
    log_info "=========================================="
    log_info "Changes made: $CHANGES_MADE"
    log_info "Warnings: $WARNINGS"
    log_info "Errors: $ERRORS"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Mode: DRY-RUN (no changes applied)"
    fi

    if [[ -d "$BACKUP_DIR" ]] && [[ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        log_info "Backups saved to: $BACKUP_DIR"
    fi

    echo ""

    if ((ERRORS > 0)); then
        log_error "Completed with $ERRORS errors"
        exit 1
    else
        log_success "Hardening completed successfully!"
        exit 0
    fi
}

# Allow sourcing for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
