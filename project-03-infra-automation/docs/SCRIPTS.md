# Scripts Documentation
# Infrastructure Automation Toolkit

**Version:** 1.0.0
**Last Updated:** 2025-11-30
**Author:** Linux System Administrator Portfolio

---

## Table of Contents

- [Overview](#overview)
- [Common Library](#common-library)
- [Script 1: Server Hardening](#script-1-server-hardening)
- [Script 2: Network Diagnostics](#script-2-network-diagnostics)
- [Script 3: Service Watchdog](#script-3-service-watchdog)
- [Script 4: Backup Manager](#script-4-backup-manager)
- [Script 5: Log Rotation](#script-5-log-rotation)
- [Script 6: System Inventory](#script-6-system-inventory)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)

---

## Overview

This document provides comprehensive documentation for all six automation scripts in the Infrastructure Automation Toolkit, plus the shared common library. Each section includes:

- Purpose and use cases
- Command reference
- Configuration options
- Examples
- Exit codes
- Troubleshooting

### Quick Reference

| Script | Purpose | Lines | Primary Use Case |
|--------|---------|-------|------------------|
| `lib/common.sh` | Shared library | 412 | Logging, OS detection, utilities |
| `server-hardening.sh` | Security hardening | 781 | **PRIMARY SHOWCASE** - Automated security configuration |
| `network-diagnostics.sh` | Network troubleshooting | 588 | Diagnose connectivity, DNS, routing issues |
| `service-watchdog.sh` | Service monitoring | 647 | Automatic service restart and alerting |
| `backup-manager.sh` | Backup management | 619 | Full/incremental backups with verification |
| `log-rotation.sh` | Log management | 773 | Size/age-based log rotation |
| `system-inventory.sh` | System reporting | 863 | Hardware/software inventory collection |

---

## Common Library

**File:** `scripts/lib/common.sh`
**Lines:** 412
**Purpose:** Shared functions for all automation scripts

### Functions Reference

#### Logging Functions

```bash
log_info "message"      # Blue informational message
log_success "message"   # Green success message
log_warning "message"   # Yellow warning message
log_error "message"     # Red error message (to stderr)
log_debug "message"     # Cyan debug message (if LOG_LEVEL=DEBUG)
```

**Example:**
```bash
source /path/to/lib/common.sh

log_info "Starting backup process..."
if perform_backup; then
    log_success "Backup completed"
else
    log_error "Backup failed"
    exit 1
fi
```

#### OS Detection Functions

```bash
detect_os()                  # Returns: debian, alpine, ubuntu, rhel, arch, unknown
detect_os_version()          # Returns version ID (e.g., "12", "3.19", "24.04")
detect_package_manager()     # Returns: apt, apk, yum, pacman, unknown
detect_init_system()         # Returns: systemd, openrc, sysvinit, unknown
is_debian_based()            # Boolean: true if Debian or Ubuntu
is_alpine()                  # Boolean: true if Alpine Linux
is_containerized()           # Boolean: true if running in Docker/container
```

**Example:**
```bash
OS=$(detect_os)
case "$OS" in
    debian|ubuntu)
        apt-get update && apt-get install -y package
        ;;
    alpine)
        apk add package
        ;;
    *)
        log_error "Unsupported OS: $OS"
        exit 1
        ;;
esac
```

#### Validation Functions

```bash
check_root()                    # Ensures script runs as root
check_command "command"         # Checks if command exists
check_dependencies cmd1 cmd2... # Checks multiple commands
check_file_exists "file"        # Verifies file exists
check_directory_exists "dir"    # Verifies directory exists
```

**Example:**
```bash
# Ensure root access
if ! check_root; then
    exit 1
fi

# Check required commands
if ! check_dependencies curl wget; then
    log_error "Missing required tools"
    exit 1
fi
```

#### JSON Utilities

```bash
json_escape "string"       # Escapes string for JSON
json_timestamp()           # Returns ISO 8601 timestamp
timestamp_iso()            # Returns ISO 8601 timestamp
timestamp_filename()       # Returns filename-safe timestamp (YYYYMMDD_HHMMSS)
timestamp_human()          # Returns human-readable timestamp
```

**Example:**
```bash
REPORT=$(cat << EOF
{
    "timestamp": "$(timestamp_iso)",
    "hostname": "$(hostname)",
    "message": "$(json_escape "$USER_INPUT")"
}
EOF
)

echo "$REPORT" > "report-$(timestamp_filename).json"
```

#### Network Functions

```bash
check_port "host" "port" [timeout]   # Tests TCP port connectivity
get_ip_address()                     # Returns primary IP address
get_primary_interface()              # Returns default network interface
```

**Example:**
```bash
if check_port "google.com" 443 5; then
    log_success "HTTPS connectivity OK"
else
    log_error "Cannot reach google.com:443"
fi
```

#### File Operations

```bash
ensure_directory "path"              # Creates directory if doesn't exist
backup_file "file" ["backup_dir"]    # Creates timestamped backup
```

**Example:**
```bash
# Ensure log directory exists
ensure_directory "/var/log/myapp"

# Backup configuration before changes
BACKUP=$(backup_file "/etc/myapp.conf")
log_info "Configuration backed up to: $BACKUP"
```

#### Math Functions

```bash
percentage "part" "total"       # Calculates percentage
bytes_to_kb "bytes"             # Converts to kilobytes
bytes_to_mb "bytes"             # Converts to megabytes
bytes_to_gb "bytes"             # Converts to gigabytes
seconds_to_duration "seconds"   # Formats as "Xd Yh Zm Ws"
```

**Example:**
```bash
FILE_SIZE=$(stat -c %s /var/log/app.log)
SIZE_MB=$(bytes_to_mb "$FILE_SIZE")
log_info "Log file size: ${SIZE_MB} MB"

UPTIME=$(awk '{print int($1)}' /proc/uptime)
log_info "System uptime: $(seconds_to_duration $UPTIME)"
```

#### String Functions

```bash
trim "string"           # Removes leading/trailing whitespace
to_lowercase "string"   # Converts to lowercase
to_uppercase "string"   # Converts to uppercase
```

**Example:**
```bash
USER_INPUT="  HELLO WORLD  "
CLEANED=$(trim "$USER_INPUT")
LOWER=$(to_lowercase "$CLEANED")
log_info "Processed: $LOWER"  # Output: "hello world"
```

---

## Script 1: Server Hardening

**File:** `scripts/server-hardening.sh`
**Lines:** 781 (195% of 400+ target)
**Purpose:** Automated security hardening for Linux servers
**Status:** ⭐ PRIMARY SHOWCASE SCRIPT

### Overview

Comprehensive security hardening tool with five modules covering SSH, kernel parameters, firewall configuration, file permissions, and user security. Designed for production use with idempotent operations and extensive validation.

### Features

- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Dry-run mode**: Preview changes before applying
- ✅ **Module selection**: Run specific hardening modules
- ✅ **Automatic backups**: All changes backed up
- ✅ **JSON reports**: Structured output for automation
- ✅ **Multi-OS**: Debian, Ubuntu, Alpine support

### Command Reference

```bash
./server-hardening.sh [options] <module>

Modules:
    all         Run all hardening modules
    ssh         Harden SSH configuration
    kernel      Harden kernel parameters
    firewall    Configure firewall rules
    permissions Fix dangerous file permissions
    users       Harden user security

Options:
    --dry-run   Preview changes without applying
    --report    Generate JSON report (path required)
    --help      Show help message

Examples:
    # Preview full hardening
    ./server-hardening.sh --dry-run all

    # Harden SSH only
    ./server-hardening.sh ssh

    # Full hardening with report
    ./server-hardening.sh --report /tmp/report.json all
```

### Module Details

#### Module 1: SSH Hardening

**What it does:**
- Disables root login
- Enforces public key authentication
- Disables password authentication
- Sets strong cipher suites
- Configures secure key exchange algorithms
- Sets secure MACs
- Limits authentication attempts
- Sets SSH protocol to 2 only

**Configuration applied:**
```bash
# /etc/ssh/sshd_config.d/99-hardening.conf
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
Protocol 2
MaxAuthTries 3
LoginGraceTime 60
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Strong cryptography
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512
```

**Validation:**
- Syntax check with `sshd -t`
- Backup of original configuration
- Service reload after changes

**Example:**
```bash
# Preview SSH hardening
./server-hardening.sh --dry-run ssh

# Apply SSH hardening
sudo ./server-hardening.sh ssh
```

#### Module 2: Kernel Hardening

**What it does:**
- Enables SYN cookies (DDoS protection)
- Disables IP forwarding (unless router)
- Enables source address verification
- Disables ICMP redirects
- Ignores broadcast pings
- Enables TCP/IP stack hardening
- Configures ASLR (Address Space Layout Randomization)
- Restricts kernel pointer exposure
- Restricts dmesg access

**Parameters applied:**
```bash
# /etc/sysctl.d/99-hardening.conf

# Network hardening
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Kernel hardening
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
```

**Application:**
- Writes to `/etc/sysctl.d/99-hardening.conf`
- Applies with `sysctl --system`
- Validates each parameter
- Backs up existing configuration

**Example:**
```bash
# Apply kernel hardening
sudo ./server-hardening.sh kernel

# Verify
sysctl net.ipv4.tcp_syncookies
sysctl kernel.randomize_va_space
```

#### Module 3: Firewall Configuration

**What it does:**
- Installs/configures UFW (Uncomplicated Firewall)
- Sets default deny incoming policy
- Sets default allow outgoing policy
- Allows SSH (port 22/tcp)
- Enables firewall
- Handles both UFW and iptables

**Rules applied (UFW):**
```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw --force enable
```

**Rules applied (iptables fallback):**
```bash
# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow SSH
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
```

**Example:**
```bash
# Configure firewall
sudo ./server-hardening.sh firewall

# Check firewall status
sudo ufw status verbose
# or
sudo iptables -L -n -v
```

#### Module 4: Permission Hardening

**What it does:**
- Finds and reports world-writable files
- Audits SUID binaries
- Audits SGID binaries
- Checks home directory permissions
- Warns about dangerous permissions

**Checks performed:**
```bash
# World-writable files
find / -type f -perm -0002 2>/dev/null

# SUID binaries
find / -type f -perm -4000 2>/dev/null

# SGID binaries
find / -type f -perm -2000 2>/dev/null

# Overly permissive home directories
find /home -maxdepth 1 -type d -perm -0022 2>/dev/null
```

**Actions:**
- Reports findings (always)
- Optionally fixes permissions (with user confirmation)
- Creates audit log

**Example:**
```bash
# Audit permissions (dry-run)
sudo ./server-hardening.sh --dry-run permissions

# Fix dangerous permissions
sudo ./server-hardening.sh permissions
```

#### Module 5: User Security

**What it does:**
- Enforces password policies
- Identifies inactive user accounts
- Audits sudo configuration
- Checks for users without passwords
- Reviews group memberships

**Password policy (PAM):**
```bash
# /etc/security/pwquality.conf
minlen = 12
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
```

**Checks:**
```bash
# Users without passwords
awk -F: '($2 == "") {print $1}' /etc/shadow

# Inactive accounts (no login > 90 days)
lastlog -b 90 | grep -v 'Never'

# Users with UID 0 (besides root)
awk -F: '($3 == 0) {print $1}' /etc/passwd
```

**Example:**
```bash
# Review user security
sudo ./server-hardening.sh users
```

### Configuration

#### Environment Variables

```bash
HARDENING_BACKUP_DIR="/var/backups/hardening"  # Backup location
HARDENING_DRY_RUN="true"                        # Enable dry-run
HARDENING_SKIP_BACKUP="false"                   # Skip backups (not recommended)
```

#### Configuration File

Optional: `/etc/server-hardening.conf`

```bash
# SSH configuration
SSH_PORT=22
SSH_ALLOW_GROUPS="sshusers"

# Firewall additional rules
FIREWALL_ALLOW_PORTS="80,443"

# Permission checks
SKIP_SUID_CHECK=false
```

### Output Examples

#### Dry-Run Output

```
[2025-11-30 12:00:00] [INFO] Starting security hardening...
[2025-11-30 12:00:00] [INFO] Mode: DRY-RUN (no changes will be made)
[2025-11-30 12:00:00] [INFO] Module: all

=== Module 1/5: SSH Hardening ===
[2025-11-30 12:00:01] [INFO] Analyzing SSH configuration...
[2025-11-30 12:00:01] [WARNING] Would disable root login
[2025-11-30 12:00:01] [WARNING] Would disable password authentication
[2025-11-30 12:00:01] [WARNING] Would configure strong ciphers
[2025-11-30 12:00:01] [INFO] Changes would be written to: /etc/ssh/sshd_config.d/99-hardening.conf

=== Module 2/5: Kernel Hardening ===
[2025-11-30 12:00:02] [INFO] Analyzing kernel parameters...
[2025-11-30 12:00:02] [WARNING] Would enable SYN cookies
[2025-11-30 12:00:02] [WARNING] Would configure ASLR
[2025-11-30 12:00:02] [WARNING] Would restrict kernel pointers

[... more output ...]

[2025-11-30 12:00:10] [SUCCESS] Dry-run complete. No changes made.
[2025-11-30 12:00:10] [INFO] To apply changes, run without --dry-run
```

#### JSON Report Example

```json
{
    "timestamp": "2025-11-30T12:00:00Z",
    "hostname": "server01",
    "script": "server-hardening.sh",
    "version": "1.0.0",
    "modules_run": ["ssh", "kernel", "firewall", "permissions", "users"],
    "dry_run": false,
    "results": {
        "ssh": {
            "status": "success",
            "changes_made": 8,
            "backup_file": "/var/backups/hardening/sshd_config.20251130_120000"
        },
        "kernel": {
            "status": "success",
            "changes_made": 15,
            "backup_file": "/var/backups/hardening/sysctl.conf.20251130_120001"
        },
        "firewall": {
            "status": "success",
            "rules_added": 3
        },
        "permissions": {
            "status": "warning",
            "world_writable_files": 2,
            "suid_binaries": 12,
            "sgid_binaries": 8
        },
        "users": {
            "status": "success",
            "inactive_accounts": 1,
            "passwordless_accounts": 0
        }
    },
    "overall_status": "success"
}
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success - all hardening applied |
| 1 | General error (failed operation, validation error) |
| 2 | Usage error (invalid arguments) |

### Troubleshooting

#### Issue: SSH lockout after hardening

**Symptom:** Cannot login via SSH after running SSH hardening

**Solution:**
```bash
# 1. Use console access (not SSH) to login
# 2. Check SSH config syntax
sudo sshd -t

# 3. Restore backup if needed
sudo cp /var/backups/hardening/sshd_config.* /etc/ssh/sshd_config.d/99-hardening.conf

# 4. Restart SSH
sudo systemctl restart sshd
```

**Prevention:** Always test SSH config changes in dry-run mode first, and ensure you have console access before applying.

#### Issue: Firewall blocks legitimate traffic

**Symptom:** Services not accessible after firewall hardening

**Solution:**
```bash
# Allow additional ports
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# Check current rules
sudo ufw status numbered

# Delete specific rule
sudo ufw delete <rule_number>
```

#### Issue: Permission hardening breaks application

**Symptom:** Application fails after permission hardening

**Solution:**
```bash
# Review what was changed
sudo grep "permission" /var/log/infra/server-hardening.log

# Restore specific file permissions
sudo chmod 755 /path/to/file
sudo chown user:group /path/to/file
```

---

## Script 2: Network Diagnostics

**File:** `scripts/network-diagnostics.sh`
**Lines:** 588 (168% of 350+ target)
**Purpose:** Comprehensive network troubleshooting tool

### Overview

Git-style network diagnostics tool with subcommands for testing connectivity, DNS resolution, routing, port status, and generating comprehensive reports.

### Features

- ✅ **Multiple check types**: Connectivity, DNS, routes, ports, scanning
- ✅ **Tool fallback**: Tries multiple tools for same operation
- ✅ **ASCII tables**: Pretty formatted output
- ✅ **JSON reports**: Structured data for automation
- ✅ **Cross-platform**: Works with various network tools

### Command Reference

```bash
./network-diagnostics.sh <command> [arguments]

Commands:
    connectivity <host>     Test ICMP and TCP connectivity
    dns <hostname>          Test DNS resolution
    routes                  Show routing table and default gateway
    ports                   Show listening ports and services
    scan <host> [ports]     Scan ports on remote host
    report                  Generate comprehensive network report

Options:
    --timeout <seconds>     Connection timeout (default: 5)
    --verbose               Show detailed output

Examples:
    # Test connectivity to Google
    ./network-diagnostics.sh connectivity google.com

    # Check DNS resolution
    ./network-diagnostics.sh dns example.com

    # Show routing information
    ./network-diagnostics.sh routes

    # List listening ports
    ./network-diagnostics.sh ports

    # Scan web ports on host
    ./network-diagnostics.sh scan 192.168.1.1 80,443

    # Generate full report
    ./network-diagnostics.sh report > network-report.json
```

### Commands Detail

#### connectivity - Connectivity Testing

**Purpose:** Test network connectivity using multiple methods

**Tests performed:**
1. **ICMP Ping**: Tests basic network reachability
2. **TCP Port Check**: Tests if specific ports are open
3. **Packet Loss**: Measures packet loss percentage
4. **RTT Statistics**: Round-trip time min/avg/max

**Output example:**
```
╔══════════════════════════════════════════════════════════╗
║         Connectivity Test: google.com                    ║
╚══════════════════════════════════════════════════════════╝

Test           | Result                    | Status
═════════════════════════════════════════════════════════
ICMP Ping      | 4 packets transmitted     | ✓ PASS
Packet Loss    | 0%                        | ✓ PASS
RTT            | min 10.2 / avg 12.5 / max 15.3 ms | ✓ PASS
TCP Port 80    | Open                      | ✓ PASS
TCP Port 443   | Open                      | ✓ PASS
```

**Usage:**
```bash
# Basic connectivity test
./network-diagnostics.sh connectivity 8.8.8.8

# Test with custom timeout
./network-diagnostics.sh --timeout 10 connectivity google.com

# Test specific host and port
./network-diagnostics.sh connectivity 192.168.1.1:22
```

#### dns - DNS Resolution Testing

**Purpose:** Test DNS resolution and troubleshoot DNS issues

**Tests performed:**
1. **Forward Resolution**: Hostname → IP
2. **Reverse Resolution**: IP → Hostname
3. **DNS Server Validation**: Tests configured DNS servers
4. **Query Time**: Measures DNS query response time

**Output example:**
```
╔══════════════════════════════════════════════════════════╗
║         DNS Test: example.com                            ║
╚══════════════════════════════════════════════════════════╝

Test                | Result                    | Status
══════════════════════════════════════════════════════════
Forward Resolution  | 93.184.216.34             | ✓ PASS
Reverse Resolution  | example.com               | ✓ PASS
DNS Server          | 8.8.8.8                   | ✓ PASS
Query Time          | 25 ms                     | ✓ PASS
```

**Usage:**
```bash
# Test DNS resolution
./network-diagnostics.sh dns google.com

# Test with verbose output
./network-diagnostics.sh --verbose dns example.com
```

#### routes - Routing Information

**Purpose:** Display routing table and trace routes

**Information displayed:**
1. **Routing Table**: All routes
2. **Default Gateway**: Default route
3. **Route Metrics**: Priority information
4. **Traceroute**: Path to destination

**Output example:**
```
╔══════════════════════════════════════════════════════════╗
║         Routing Information                              ║
╚══════════════════════════════════════════════════════════╝

Destination     | Gateway         | Interface | Metric
═══════════════════════════════════════════════════════════
0.0.0.0         | 192.168.1.1     | eth0      | 100
192.168.1.0/24  | 0.0.0.0         | eth0      | 0
172.17.0.0/16   | 0.0.0.0         | docker0   | 0

Default Gateway: 192.168.1.1 via eth0
```

**Usage:**
```bash
# Show routing table
./network-diagnostics.sh routes

# Show routes with traceroute
./network-diagnostics.sh routes google.com
```

#### ports - Port Status

**Purpose:** List listening ports and associated processes

**Information displayed:**
1. **Listening Ports**: All TCP/UDP ports
2. **Process Names**: Which process owns each port
3. **PIDs**: Process IDs
4. **Protocol**: TCP or UDP

**Output example:**
```
╔══════════════════════════════════════════════════════════╗
║         Listening Ports                                  ║
╚══════════════════════════════════════════════════════════╝

Proto | Port  | PID   | Process          | Address
═══════════════════════════════════════════════════════════
TCP   | 22    | 1234  | sshd             | 0.0.0.0
TCP   | 80    | 5678  | nginx            | 0.0.0.0
TCP   | 443   | 5678  | nginx            | 0.0.0.0
TCP   | 3306  | 9012  | mysqld           | 127.0.0.1
UDP   | 53    | 3456  | systemd-resolve  | 127.0.0.53
```

**Usage:**
```bash
# List all listening ports
./network-diagnostics.sh ports

# Filter by specific port
./network-diagnostics.sh ports | grep 80
```

#### scan - Port Scanning

**Purpose:** Scan ports on remote hosts

**Features:**
- TCP connect scan
- Port range support
- Service identification
- Response time measurement

**Output example:**
```
╔══════════════════════════════════════════════════════════╗
║         Port Scan: 192.168.1.100                         ║
╚══════════════════════════════════════════════════════════╝

Port  | Status | Service       | Response Time
════════════════════════════════════════════════════════
22    | Open   | SSH           | 5 ms
80    | Open   | HTTP          | 10 ms
443   | Open   | HTTPS         | 12 ms
3306  | Closed |               | -
8080  | Open   | HTTP-Alt      | 15 ms
```

**Usage:**
```bash
# Scan common ports
./network-diagnostics.sh scan 192.168.1.1

# Scan specific ports
./network-diagnostics.sh scan 192.168.1.1 22,80,443,3306

# Scan port range
./network-diagnostics.sh scan 192.168.1.1 80-90
```

#### report - Full Report

**Purpose:** Generate comprehensive network report in JSON format

**Information included:**
- System network configuration
- Interface details
- Routing information
- DNS configuration
- Port status
- Connectivity tests

**Output example:**
```json
{
    "timestamp": "2025-11-30T12:00:00Z",
    "hostname": "server01",
    "interfaces": [
        {
            "name": "eth0",
            "ip": "192.168.1.100",
            "mac": "00:11:22:33:44:55",
            "status": "UP"
        }
    ],
    "routing": {
        "default_gateway": "192.168.1.1",
        "routes": [...]
    },
    "dns": {
        "servers": ["8.8.8.8", "8.8.4.4"],
        "search_domains": ["local"]
    },
    "listening_ports": [
        {"port": 22, "protocol": "tcp", "process": "sshd"}
    ],
    "connectivity_tests": [
        {"host": "8.8.8.8", "status": "reachable", "rtt_ms": 15}
    ]
}
```

**Usage:**
```bash
# Generate report to stdout
./network-diagnostics.sh report

# Save report to file
./network-diagnostics.sh report > /tmp/network-report.json

# Pretty print JSON
./network-diagnostics.sh report | python3 -m json.tool
```

### Configuration

#### Environment Variables

```bash
NET_DIAG_TIMEOUT="5"           # Connection timeout in seconds
NET_DIAG_PING_COUNT="4"        # Number of ping packets
NET_DIAG_VERBOSE="false"       # Enable verbose output
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success - test passed or report generated |
| 1 | Failure - test failed or error occurred |
| 2 | Usage error (invalid arguments) |

### Troubleshooting

#### Issue: "No ping utility available"

**Symptom:** ping command not found

**Solution:**
```bash
# Install iputils (Debian/Ubuntu)
sudo apt-get install iputils-ping

# Install iputils (Alpine)
sudo apk add iputils

# Alternative: use fping
sudo apt-get install fping
```

#### Issue: "Permission denied" for port scanning

**Symptom:** Cannot scan ports

**Solution:**
Port scanning may require elevated privileges for raw socket access:
```bash
sudo ./network-diagnostics.sh scan 192.168.1.1
```

---

## Script 3: Service Watchdog

**File:** `scripts/service-watchdog.sh`
**Lines:** 647 (185% of 350+ target)
**Purpose:** Daemon-based service monitoring with automatic recovery

### Overview

Production-ready service watchdog daemon that monitors critical services and automatically restarts them if they fail. Features PID management, signal handling, exponential backoff, and alert integration.

### Features

- ✅ **Daemon mode**: Runs in background with PID file
- ✅ **Multiple check types**: Process, port, HTTP, custom script
- ✅ **Automatic restart**: With exponential backoff
- ✅ **Alert integration**: Webhook and syslog support
- ✅ **Signal handling**: SIGTERM, SIGINT, SIGHUP
- ✅ **State persistence**: Tracks restart counts and history

### Command Reference

```bash
./service-watchdog.sh <command>

Commands:
    start       Start the watchdog daemon
    stop        Stop the watchdog daemon
    status      Check daemon status
    restart     Restart the watchdog daemon

Configuration:
    Config file: /etc/service-watchdog.conf

Environment Variables:
    WATCHDOG_CHECK_INTERVAL     Check interval in seconds (default: 60)
    WATCHDOG_RESTART_LIMIT      Max restarts per window (default: 3)
    WATCHDOG_RESTART_WINDOW     Time window in seconds (default: 300)
    WATCHDOG_ALERT_COOLDOWN     Alert cooldown in seconds (default: 600)
    ALERT_WEBHOOK               Webhook URL for alerts (optional)

Examples:
    # Start daemon
    sudo ./service-watchdog.sh start

    # Check status
    sudo ./service-watchdog.sh status

    # Reload configuration without restart
    sudo kill -HUP $(cat /var/run/service-watchdog.pid)

    # Stop daemon
    sudo ./service-watchdog.sh stop
```

### Configuration

Configuration file: `/etc/service-watchdog.conf`

```bash
# Check interval (seconds)
CHECK_INTERVAL=60

# Restart limits
RESTART_LIMIT=3           # Max restarts
RESTART_WINDOW=300        # In this time window (5 minutes)

# Alert settings
ALERT_COOLDOWN=600        # 10 minutes between alerts for same service
ALERT_WEBHOOK="https://hooks.example.com/webhook"

# Services to monitor
SERVICES=(
    # Format: "name:check_type:check_argument"

    # Process check
    "nginx:process:nginx"

    # Port check
    "mysql:port:3306"

    # HTTP check (URL:expected_code)
    "webapp:http:http://localhost:8080:200"

    # Custom script check
    "custom:custom:/usr/local/bin/check-app.sh"
)
```

### Check Types

#### 1. Process Check

**Format:** `service_name:process:process_name`

**Example:** `"nginx:process:nginx"`

**How it works:**
- Uses `pgrep -x` to find exact process name
- Returns success if process is running

**Usage:**
```bash
SERVICES=(
    "sshd:process:sshd"
    "cron:process:cron"
)
```

#### 2. Port Check

**Format:** `service_name:port:port_number[:host]`

**Example:** `"mysql:port:3306:localhost"`

**How it works:**
- Tests TCP connection to port
- Default host is localhost if not specified
- 5-second timeout

**Usage:**
```bash
SERVICES=(
    "mysql:port:3306"
    "postgresql:port:5432"
    "redis:port:6379:127.0.0.1"
)
```

#### 3. HTTP Check

**Format:** `service_name:http:url[:expected_code]`

**Example:** `"webapp:http:http://localhost:8080:200"`

**How it works:**
- Performs HTTP GET request
- Checks status code
- Default expected code is 200

**Usage:**
```bash
SERVICES=(
    "webapp:http:http://localhost:8080"
    "api:http:https://localhost:8443/health:200"
)
```

#### 4. Custom Script Check

**Format:** `service_name:custom:script_path`

**Example:** `"app:custom:/usr/local/bin/check-app.sh"`

**How it works:**
- Executes custom script
- Success if exit code is 0
- Failure if exit code is non-zero

**Custom script example:**
```bash
#!/bin/bash
# /usr/local/bin/check-app.sh

# Check application-specific conditions
if curl -sf http://localhost:8080/health | grep -q "OK"; then
    exit 0  # Healthy
else
    exit 1  # Unhealthy
fi
```

**Usage:**
```bash
SERVICES=(
    "myapp:custom:/usr/local/bin/check-myapp.sh"
)
```

### Restart Logic

When a service fails a check:

1. **Check restart count**
   - If count < RESTART_LIMIT: Proceed
   - If count >= RESTART_LIMIT: Alert and skip

2. **Determine init system**
   - systemd: `systemctl restart service`
   - openrc: `rc-service service restart`
   - sysvinit: `/etc/init.d/service restart`

3. **Execute restart**
   - Run restart command
   - Wait 5 seconds
   - Verify service is up

4. **Update counters**
   - Increment restart count
   - Record timestamp
   - Send alert

**Exponential Backoff:**
- Restart counts reset after RESTART_WINDOW expires
- Prevents boot loops
- Allows temporary failures without excessive restarts

### Alerting

#### Webhook Alerts

Configure webhook URL:
```bash
ALERT_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

Alert payload (JSON):
```json
{
    "timestamp": "2025-11-30T12:00:00Z",
    "hostname": "server01",
    "service": "nginx",
    "severity": "warning",
    "message": "Service restarted (attempt 1/3)",
    "restart_count": 1
}
```

#### Syslog Integration

Alerts are automatically sent to syslog if available:
```bash
logger -t service-watchdog -p daemon.warning "nginx: Service restarted"
```

#### Alert Cooldown

To prevent alert fatigue:
- Cooldown period between alerts for same service
- Default: 600 seconds (10 minutes)
- Configurable via `ALERT_COOLDOWN`

### Daemon Management

#### PID File

Location: `/var/run/service-watchdog.pid`

The PID file:
- Contains process ID of daemon
- Created on start
- Removed on stop
- Checked for stale processes

#### Signal Handling

**SIGTERM / SIGINT** (Graceful Shutdown):
```bash
# Via stop command
./service-watchdog.sh stop

# Direct signal
kill -TERM $(cat /var/run/service-watchdog.pid)
```

**SIGHUP** (Reload Configuration):
```bash
# Reload without restarting daemon
kill -HUP $(cat /var/run/service-watchdog.pid)
```

This reloads the configuration file without stopping monitoring.

#### State Persistence

State file: `/var/lib/service-watchdog/state.json`

Tracks:
- Service states (up/down)
- Restart counts
- Last restart timestamps
- Last alert timestamps

**Example state:**
```json
{
    "timestamp": "2025-11-30T12:00:00Z",
    "services": {
        "nginx": {
            "state": "up",
            "restart_count": 2,
            "last_restart": 1701345600
        },
        "mysql": {
            "state": "up",
            "restart_count": 0,
            "last_restart": 0
        }
    }
}
```

### Example Workflows

#### Monitoring Web Server

```bash
# /etc/service-watchdog.conf
CHECK_INTERVAL=30
RESTART_LIMIT=3
RESTART_WINDOW=300

SERVICES=(
    "nginx:process:nginx"
    "nginx:port:80"
    "nginx:http:http://localhost"
)

# Start watchdog
sudo ./service-watchdog.sh start

# Test by stopping nginx
sudo systemctl stop nginx

# Check logs - should see automatic restart
tail -f /var/log/infra/service-watchdog.log
```

#### Monitoring Database

```bash
# /etc/service-watchdog.conf
SERVICES=(
    "mysql:process:mysqld"
    "mysql:port:3306"
    "mysql:custom:/usr/local/bin/check-mysql.sh"
)

# Custom MySQL check script
cat > /usr/local/bin/check-mysql.sh << 'EOF'
#!/bin/bash
# Test MySQL connectivity
mysql -e "SELECT 1" &>/dev/null
EOF

chmod +x /usr/local/bin/check-mysql.sh

# Start monitoring
sudo ./service-watchdog.sh start
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (daemon not running, failed to start, etc.) |
| 3 | Daemon not running (status command) |

### Troubleshooting

#### Issue: Daemon won't start

**Symptom:** "Watchdog already running" or permission errors

**Solution:**
```bash
# Check for stale PID file
cat /var/run/service-watchdog.pid
ps aux | grep service-watchdog

# Remove stale PID if process not running
sudo rm /var/run/service-watchdog.pid

# Ensure proper permissions
sudo chown root:root /var/run/service-watchdog.pid
sudo chmod 644 /var/run/service-watchdog.pid

# Check logs
tail -f /var/log/infra/service-watchdog.log
```

#### Issue: Services not restarting

**Symptom:** Watchdog detects failures but doesn't restart

**Solution:**
```bash
# Check restart limit
# If limit reached, reset by waiting for RESTART_WINDOW to expire

# Or manually clear state
sudo rm /var/lib/service-watchdog/state.json
sudo ./service-watchdog.sh restart

# Check init system detection
source /scripts/lib/common.sh
detect_init_system

# Verify service name matches init system
# systemd: systemctl status <service>
# openrc: rc-service <service> status
```

#### Issue: Too many alerts

**Symptom:** Alert fatigue from frequent notifications

**Solution:**
```bash
# Increase alert cooldown
ALERT_COOLDOWN=1800  # 30 minutes

# Increase check interval
CHECK_INTERVAL=120   # 2 minutes

# Increase restart window
RESTART_WINDOW=600   # 10 minutes
```

---

## Script 4: Backup Manager

**File:** `scripts/backup-manager.sh`
**Lines:** 619 (206% of 300+ target)
**Purpose:** Intelligent backup system with retention management

### Overview

Production-grade backup solution supporting full and incremental backups, multiple compression algorithms, integrity verification, and GFS (Grandfather-Father-Son) retention policies.

### Features

- ✅ **Full & incremental backups**: Efficient storage
- ✅ **Multiple compression**: gzip, xz, zstd
- ✅ **Integrity verification**: SHA256 checksums
- ✅ **Metadata tracking**: JSON metadata for each backup
- ✅ **GFS retention**: Automated pruning
- ✅ **Restore validation**: Verify before restoring

### Command Reference

```bash
./backup-manager.sh <command> <arguments>

Commands:
    full <source> <destination>
        Create full backup

    incremental <source> <destination>
        Create incremental backup (requires previous full backup)

    list <destination>
        List all backups in destination

    verify <backup_file>
        Verify backup integrity

    restore <backup_file> <destination>
        Restore backup to destination

    prune <destination> [--retention days]
        Remove old backups per retention policy

Options:
    --compression <type>    Compression: gzip, xz, zstd (default: gzip)
    --retention <days>      Retention period in days (default: 90)
    --encrypt               Enable GPG encryption (requires GPG key)

Environment Variables:
    BACKUP_COMPRESSION      Compression type (gzip, xz, zstd)
    BACKUP_RETENTION        Retention in days
    BACKUP_GPG_KEY          GPG key ID for encryption

Examples:
    # Full backup with gzip
    ./backup-manager.sh full /var/www /backups

    # Incremental backup with xz compression
    ./backup-manager.sh --compression xz incremental /var/www /backups

    # List backups
    ./backup-manager.sh list /backups

    # Verify backup
    ./backup-manager.sh verify /backups/backup-20251130_120000.tar.gz

    # Restore backup
    ./backup-manager.sh restore /backups/backup-20251130_120000.tar.gz /restore

    # Prune backups older than 60 days
    ./backup-manager.sh prune /backups --retention 60
```

### Commands Detail

#### full - Full Backup

**Purpose:** Create complete backup of source directory

**Process:**
1. Create tar archive of source
2. Compress with selected algorithm
3. Calculate SHA256 checksum
4. Save metadata (JSON)
5. Optional: Encrypt with GPG

**Output files:**
```
backup-20251130_120000.tar.gz        # Compressed archive
backup-20251130_120000.tar.gz.sha256 # Checksum file
backup-20251130_120000.json          # Metadata file
```

**Metadata example:**
```json
{
    "backup_id": "backup-20251130_120000",
    "timestamp": "2025-11-30T12:00:00Z",
    "type": "full",
    "source": "/var/www",
    "size_bytes": 104857600,
    "size_human": "100 MB",
    "compression": "gzip",
    "compression_ratio": "65.5%",
    "checksum": "sha256:abc123...",
    "parent_backup": null,
    "files_count": 1542,
    "duration_seconds": 45
}
```

**Usage:**
```bash
# Basic full backup
./backup-manager.sh full /var/www /backups

# With xz compression (better ratio, slower)
./backup-manager.sh --compression xz full /var/www /backups

# With zstd compression (faster, good ratio)
./backup-manager.sh --compression zstd full /var/www /backups
```

#### incremental - Incremental Backup

**Purpose:** Backup only files changed since last full backup

**Requirements:**
- Previous full backup must exist
- Source directory must be unchanged location

**Process:**
1. Find last full backup
2. Create tar with `--newer-mtime` than full backup
3. Compress
4. Calculate checksum
5. Save metadata with reference to parent

**Advantages:**
- Faster than full backup
- Uses less storage space
- More frequent backups possible

**Restoration:**
- Requires both full backup and all incrementals
- Restore full backup first
- Then apply incrementals in order

**Usage:**
```bash
# Create incremental backup
./backup-manager.sh incremental /var/www /backups

# Check backup chain
./backup-manager.sh list /backups | grep "parent"
```

#### list - List Backups

**Purpose:** Display all backups with details

**Information shown:**
- Backup ID
- Timestamp
- Type (full/incremental)
- Size
- Compression
- Parent backup (for incrementals)

**Output example:**
```
╔══════════════════════════════════════════════════════════════════╗
║                     Backup List: /backups                        ║
╚══════════════════════════════════════════════════════════════════╝

ID                      | Date       | Time  | Type   | Size   | Parent
═════════════════════════════════════════════════════════════════════════
backup-20251130_120000  | 2025-11-30 | 12:00 | full   | 100 MB | -
backup-20251201_120000  | 2025-12-01 | 12:00 | incr   | 5 MB   | backup-20251130_120000
backup-20251202_120000  | 2025-12-02 | 12:00 | incr   | 3 MB   | backup-20251130_120000
backup-20251207_120000  | 2025-12-07 | 12:00 | full   | 105 MB | -
```

**Usage:**
```bash
# List all backups
./backup-manager.sh list /backups

# Filter by type
./backup-manager.sh list /backups | grep full

# Sort by size
./backup-manager.sh list /backups | sort -k5 -h
```

#### verify - Verify Integrity

**Purpose:** Verify backup integrity using checksum

**Verification steps:**
1. Read stored SHA256 checksum
2. Calculate actual checksum of backup file
3. Compare checksums
4. Report result

**When to verify:**
- Before restoration
- After backup creation
- Periodically (monthly)
- After hardware issues
- Before pruning

**Usage:**
```bash
# Verify single backup
./backup-manager.sh verify /backups/backup-20251130_120000.tar.gz

# Verify all backups
for backup in /backups/*.tar.gz; do
    ./backup-manager.sh verify "$backup"
done
```

**Output example:**
```
[2025-11-30 12:00:00] [INFO] Verifying backup: backup-20251130_120000.tar.gz
[2025-11-30 12:00:00] [INFO] Expected checksum: abc123...
[2025-11-30 12:00:10] [INFO] Actual checksum:   abc123...
[2025-11-30 12:00:10] [SUCCESS] Checksum verification passed
```

#### restore - Restore Backup

**Purpose:** Restore files from backup

**Process:**
1. Verify backup integrity
2. Extract to temporary location
3. Validate extraction
4. Move to final destination
5. Set permissions

**Safety features:**
- Verifies checksum before restoration
- Extracts to temp first (transactional)
- Preserves permissions and timestamps
- Option to restore to different location

**Usage:**
```bash
# Restore to original location
./backup-manager.sh restore /backups/backup-20251130_120000.tar.gz /var/www

# Restore to different location
./backup-manager.sh restore /backups/backup-20251130_120000.tar.gz /tmp/restore

# Restore with verification
./backup-manager.sh verify /backups/backup-20251130_120000.tar.gz && \
./backup-manager.sh restore /backups/backup-20251130_120000.tar.gz /var/www
```

**Restoring incremental backups:**
```bash
# 1. Restore full backup first
./backup-manager.sh restore /backups/backup-20251130_120000.tar.gz /restore

# 2. Apply incrementals in order
./backup-manager.sh restore /backups/backup-20251201_120000.tar.gz /restore
./backup-manager.sh restore /backups/backup-20251202_120000.tar.gz /restore
```

#### prune - Retention Management

**Purpose:** Remove old backups according to retention policy

**GFS Retention Policy:**
- **Daily**: Keep last 7 daily backups
- **Weekly**: Keep last 4 weekly backups
- **Monthly**: Keep last 12 monthly backups
- **Everything else**: Remove

**How it works:**
1. Scan all backups
2. Classify by age (daily/weekly/monthly)
3. Mark backups for retention
4. Remove unmarked backups
5. Update backup chain references

**Usage:**
```bash
# Prune with default retention (90 days)
./backup-manager.sh prune /backups

# Custom retention period
./backup-manager.sh prune /backups --retention 60

# Dry-run (see what would be deleted)
./backup-manager.sh --dry-run prune /backups
```

**Output example:**
```
[2025-11-30 12:00:00] [INFO] Analyzing backups in: /backups
[2025-11-30 12:00:00] [INFO] Retention policy: 90 days
[2025-11-30 12:00:00] [INFO] Found 45 backups
[2025-11-30 12:00:01] [INFO] Keeping 30 backups (policy)
[2025-11-30 12:00:01] [INFO] Removing 15 old backups
[2025-11-30 12:00:01] [WARNING] Removing: backup-20250801_120000.tar.gz (130 days old)
...
[2025-11-30 12:00:05] [SUCCESS] Pruned 15 backups, freed 750 MB
```

### Compression Comparison

| Algorithm | Speed | Ratio | CPU | Best For |
|-----------|-------|-------|-----|----------|
| gzip | Fast | Good | Low | General purpose, default |
| xz | Slow | Excellent | High | Long-term storage, slow networks |
| zstd | Very Fast | Very Good | Medium | Frequent backups, fast recovery |

**Benchmark example (1GB data):**
```
gzip:  Time: 45s,  Size: 350MB (65% compression), CPU: 50%
xz:    Time: 180s, Size: 250MB (75% compression), CPU: 95%
zstd:  Time: 20s,  Size: 300MB (70% compression), CPU: 65%
```

### Backup Strategies

#### Strategy 1: Daily Full Backups

**Best for:** Small to medium datasets

```bash
# Cron: Daily at 2 AM
0 2 * * * /usr/local/bin/backup-manager.sh full /var/www /backups

# Cron: Weekly pruning
0 3 * * 0 /usr/local/bin/backup-manager.sh prune /backups --retention 30
```

**Pros:** Simple, easy restoration
**Cons:** Uses more storage, slower for large datasets

#### Strategy 2: Weekly Full + Daily Incremental

**Best for:** Large datasets, frequent changes

```bash
# Cron: Full backup on Sunday at 2 AM
0 2 * * 0 /usr/local/bin/backup-manager.sh full /var/www /backups

# Cron: Incremental backup Mon-Sat at 2 AM
0 2 * * 1-6 /usr/local/bin/backup-manager.sh incremental /var/www /backups

# Cron: Monthly pruning
0 3 1 * * /usr/local/bin/backup-manager.sh prune /backups --retention 90
```

**Pros:** Efficient storage, frequent backups
**Cons:** More complex restoration

#### Strategy 3: Continuous Backups

**Best for:** Critical systems, minimal RPO

```bash
# Cron: Hourly incremental backups
0 * * * * /usr/local/bin/backup-manager.sh incremental /var/www /backups

# Cron: Daily full backup at 2 AM
0 2 * * * /usr/local/bin/backup-manager.sh full /var/www /backups

# Cron: Weekly pruning
0 3 * * 0 /usr/local/bin/backup-manager.sh prune /backups --retention 60
```

**Pros:** Minimal data loss, frequent backups
**Cons:** More management, storage overhead

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Failure (backup failed, verification failed, etc.) |
| 2 | Usage error (invalid arguments) |

### Troubleshooting

#### Issue: Backup fails with "No space left on device"

**Solution:**
```bash
# Check available space
df -h /backups

# Prune old backups
./backup-manager.sh prune /backups --retention 30

# Use higher compression
./backup-manager.sh --compression xz full /source /backups

# Move to larger filesystem
mv /backups /mnt/large-disk/backups
```

#### Issue: Verification fails

**Symptom:** Checksum mismatch

**Solution:**
```bash
# Check for disk errors
dmesg | grep -i error

# Re-create backup
./backup-manager.sh full /source /backups

# If backup medium is failing, migrate immediately
rsync -av /backups/ /new-location/backups/
```

#### Issue: Restore is slow

**Solution:**
```bash
# Use faster compression for future backups
BACKUP_COMPRESSION=zstd

# Extract in parallel (if tar supports)
tar -I pigz -xf backup.tar.gz

# Restore to local disk first, then rsync
./backup-manager.sh restore backup.tar.gz /tmp/restore
rsync -av /tmp/restore/ /final/destination/
```

---

## Script 5: Log Rotation

**File:** `scripts/log-rotation.sh`
**Lines:** 773 (309% of 250+ target)
**Purpose:** Advanced log rotation with service integration

### Overview

Sophisticated log rotation system with size and age-based policies, deferred compression, service-aware signaling, and configurable retention management.

### Features

- ✅ **Multiple rotation triggers**: Size and age-based
- ✅ **Deferred compression**: Avoid I/O spikes
- ✅ **Service integration**: Signal processes after rotation
- ✅ **Multiple compression**: gzip, bzip2, xz, zstd
- ✅ **Postrotate hooks**: Run commands after rotation
- ✅ **Statistics**: Track rotation history

### Command Reference

```bash
./log-rotation.sh <command> [arguments]

Commands:
    rotate [config]
        Rotate logs using configuration file
        Default: /etc/logrotate-custom.conf

    check <file> [size] [age]
        Check if a log file needs rotation
        size: Max size (e.g., 100M, 1G)
        age: Max age in days

    compress <dir> [delay]
        Compress rotated logs in directory
        delay: Days to wait before compression (default: 1)

    prune <dir> [retention]
        Remove logs older than retention period
        retention: Days to keep (default: 90)

    stats <dir>
        Generate rotation statistics for directory

    generate-config
        Print example configuration file

Environment Variables:
    LOG_COMPRESSION         Compression type: gzip, bzip2, xz, zstd
    COMPRESSION_DELAY       Days to wait before compressing

Examples:
    # Rotate all logs per config
    ./log-rotation.sh rotate /etc/logrotate-custom.conf

    # Check if specific log needs rotation
    ./log-rotation.sh check /var/log/app.log 100M 7

    # Compress rotated logs older than 2 days
    ./log-rotation.sh compress /var/log 2

    # Remove logs older than 60 days
    ./log-rotation.sh prune /var/log 60

    # Show statistics
    ./log-rotation.sh stats /var/log
```

### Configuration Format

Configuration file example: `/etc/logrotate-custom.conf`

```bash
# Nginx access log
/var/log/nginx/access.log {
    maxsize 100M           # Rotate if larger than 100MB
    maxage 7               # Rotate if older than 7 days
    retention 90           # Keep for 90 days
    compress gzip          # Use gzip compression
    signal HUP             # Send SIGHUP after rotation
    pidfile /var/run/nginx.pid
    postrotate systemctl reload nginx
}

# Nginx error log
/var/log/nginx/error.log {
    maxsize 50M
    maxage 7
    retention 90
    compress gzip
    signal HUP
    pidfile /var/run/nginx.pid
}

# Application log with custom postrotate
/var/log/application/app.log {
    maxsize 200M
    maxage 1               # Daily rotation
    retention 30
    compress zstd          # Fast compression
    signal USR1
    pidfile /var/run/app.pid
    postrotate /usr/local/bin/app-logrotate-hook.sh
}

# MySQL slow query log
/var/log/mysql/slow-query.log {
    maxsize 500M
    maxage 7
    retention 60
    compress xz            # Best compression
    postrotate mysqladmin flush-logs
}
```

### Configuration Directives

| Directive | Description | Example |
|-----------|-------------|---------|
| `maxsize` | Maximum file size before rotation | `100M`, `1G` |
| `maxage` | Maximum file age in days before rotation | `7`, `30` |
| `retention` | Days to keep rotated logs | `90`, `365` |
| `compress` | Compression algorithm | `gzip`, `bzip2`, `xz`, `zstd`, `none` |
| `signal` | Signal to send to process after rotation | `HUP`, `USR1`, `USR2` |
| `pidfile` | PID file of process to signal | `/var/run/nginx.pid` |
| `postrotate` | Command to run after rotation | `systemctl reload nginx` |

### Commands Detail

#### rotate - Rotate Logs

**Purpose:** Rotate logs according to configuration file

**Process:**
1. Parse configuration file
2. For each log file:
   - Check if rotation needed (size or age)
   - Create backup (copy and truncate)
   - Signal process if configured
   - Run postrotate hook if configured
3. Record rotation in state file

**Rotation method:**
```bash
# Copy-and-truncate (preserves file descriptor)
cp /var/log/app.log /var/log/app.log.20251130_120000
truncate -s 0 /var/log/app.log
```

This method is safer than move-and-create because:
- Application keeps writing to same file descriptor
- No need to restart application
- Works with applications that don't handle log reopening

**Usage:**
```bash
# Rotate using default config
sudo ./log-rotation.sh rotate

# Rotate using custom config
sudo ./log-rotation.sh rotate /etc/custom-logrotate.conf
```

#### check - Check Rotation Need

**Purpose:** Check if a specific log file needs rotation

**Checks:**
1. File size vs maxsize threshold
2. File age vs maxage threshold
3. Returns success if either threshold met

**Usage:**
```bash
# Check with default thresholds
./log-rotation.sh check /var/log/app.log

# Check with custom thresholds
./log-rotation.sh check /var/log/app.log 100M 7

# Use in scripts
if ./log-rotation.sh check /var/log/app.log 100M 7; then
    echo "Rotation needed"
else
    echo "Rotation not needed"
fi
```

**Output example:**
```
File: /var/log/app.log
Size: 125.5 MB (threshold: 100M)
Age: 5 days (threshold: 7 days)
Rotation NEEDED (size threshold exceeded)
```

#### compress - Compress Rotated Logs

**Purpose:** Compress old rotated logs (deferred compression)

**Deferred compression benefits:**
- Reduces I/O spike during rotation
- Allows recent logs to be easily readable
- Compresses when system is less busy

**Process:**
1. Find rotated logs (*.log.YYYYMMDD_HHMMSS)
2. Filter by age (older than delay days)
3. Compress with configured algorithm
4. Remove original uncompressed file

**Usage:**
```bash
# Compress logs older than 1 day (default)
sudo ./log-rotation.sh compress /var/log

# Compress logs older than 2 days
sudo ./log-rotation.sh compress /var/log 2

# Use specific compression
LOG_COMPRESSION=zstd ./log-rotation.sh compress /var/log
```

**Output example:**
```
[2025-11-30 12:00:00] [INFO] Compressing rotated logs older than 2 days in: /var/log
[2025-11-30 12:00:01] [INFO] Compressing: app.log.20251128_120000
[2025-11-30 12:00:05] [SUCCESS] Compressed: app.log.20251128_120000 → app.log.20251128_120000.gz
[2025-11-30 12:00:06] [INFO] Compressing: nginx/access.log.20251128_120000
[2025-11-30 12:00:15] [SUCCESS] Compressed: nginx/access.log.20251128_120000 → nginx/access.log.20251128_120000.gz
[2025-11-30 12:00:15] [SUCCESS] Compressed 2 log files
```

#### prune - Remove Old Logs

**Purpose:** Remove logs older than retention period

**Process:**
1. Find all rotated logs (compressed and uncompressed)
2. Check age against retention period
3. Remove logs older than retention

**Safety:**
- Only removes rotated logs (not active logs)
- Requires confirmation for large deletions
- Logs deletions for audit

**Usage:**
```bash
# Prune with default retention (90 days)
sudo ./log-rotation.sh prune /var/log

# Custom retention period
sudo ./log-rotation.sh prune /var/log 60

# Dry-run to see what would be deleted
sudo ./log-rotation.sh --dry-run prune /var/log
```

**Output example:**
```
[2025-11-30 12:00:00] [INFO] Pruning logs older than 60 days in: /var/log
[2025-11-30 12:00:01] [INFO] Found 25 rotated logs
[2025-11-30 12:00:01] [INFO] Removing: app.log.20250901_120000.gz (91 days old)
[2025-11-30 12:00:01] [INFO] Removing: app.log.20250902_120000.gz (90 days old)
...
[2025-11-30 12:00:05] [SUCCESS] Removed 10 old log files, freed 500 MB
```

#### stats - Rotation Statistics

**Purpose:** Generate statistics about rotated logs

**Information displayed:**
- Total rotated logs
- Compressed vs uncompressed
- Total size
- Compression ratio
- Space savings

**Usage:**
```bash
# Show statistics
./log-rotation.sh stats /var/log

# Save to file
./log-rotation.sh stats /var/log > /tmp/log-stats.json
```

**Output example:**
```json
{
    "timestamp": "2025-11-30T12:00:00Z",
    "directory": "/var/log",
    "statistics": {
        "total_logs": 150,
        "compressed_logs": 120,
        "uncompressed_logs": 30,
        "total_size_bytes": 5368709120,
        "compressed_size_bytes": 1073741824,
        "uncompressed_size_bytes": 4294967296,
        "compression_ratio_percent": 20,
        "total_size_human": "5.00 GB",
        "compressed_size_human": "1.00 GB",
        "uncompressed_size_human": "4.00 GB"
    }
}
```

**Human-readable output:**
```
=== Log Rotation Statistics ===
Directory: /var/log
Total log files: 150
  - Compressed: 120
  - Uncompressed: 30
Total size: 5.00 GB
  - Compressed: 1.00 GB (20%)
  - Uncompressed: 4.00 GB
```

#### generate-config - Config Template

**Purpose:** Generate example configuration file

**Usage:**
```bash
# Print example config
./log-rotation.sh generate-config

# Save to file
./log-rotation.sh generate-config > /etc/logrotate-custom.conf

# Edit and use
vi /etc/logrotate-custom.conf
./log-rotation.sh rotate /etc/logrotate-custom.conf
```

### Service Integration

#### Signaling Processes

When logs are rotated, processes need to be notified:

**Common signals:**
- **SIGHUP (1)**: Reload configuration, reopen log files
- **SIGUSR1 (10)**: Custom handler (application-specific)
- **SIGUSR2 (12)**: Custom handler (application-specific)

**Configuration:**
```bash
/var/log/nginx/access.log {
    signal HUP
    pidfile /var/run/nginx.pid
}
```

**How it works:**
```bash
# Read PID from file
PID=$(cat /var/run/nginx.pid)

# Send signal
kill -HUP $PID
```

#### Postrotate Hooks

Run custom commands after rotation:

**Examples:**
```bash
# Reload service
postrotate systemctl reload nginx

# Flush logs
postrotate mysqladmin flush-logs

# Custom notification
postrotate /usr/local/bin/notify-rotation.sh

# Multiple commands
postrotate systemctl reload nginx && echo "Rotated" | mail -s "Log Rotation" admin@example.com
```

### Scheduling

#### Cron Jobs

Recommended cron schedule:

```bash
# Daily log rotation at 3 AM
0 3 * * * /usr/local/bin/log-rotation.sh rotate /etc/logrotate-custom.conf

# Compress old logs at 4 AM
0 4 * * * /usr/local/bin/log-rotation.sh compress /var/log 2

# Weekly pruning on Sunday at 2 AM
0 2 * * 0 /usr/local/bin/log-rotation.sh prune /var/log 90
```

#### Systemd Timer

Alternative to cron:

```ini
# /etc/systemd/system/log-rotation.timer
[Unit]
Description=Daily log rotation

[Timer]
OnCalendar=daily
OnCalendar=03:00
Persistent=true

[Install]
WantedBy=timers.target
```

```ini
# /etc/systemd/system/log-rotation.service
[Unit]
Description=Log rotation service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/log-rotation.sh rotate /etc/logrotate-custom.conf
```

Enable:
```bash
sudo systemctl daemon-reload
sudo systemctl enable log-rotation.timer
sudo systemctl start log-rotation.timer
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Failure (rotation failed, permission denied, etc.) |
| 2 | Usage error (invalid arguments) |

### Troubleshooting

#### Issue: Rotation fails with permission denied

**Solution:**
```bash
# Ensure script runs as root
sudo ./log-rotation.sh rotate

# Check log file permissions
ls -la /var/log/app.log

# Fix permissions if needed
sudo chown root:adm /var/log/app.log
sudo chmod 640 /var/log/app.log
```

#### Issue: Application not reopening log files

**Symptom:** Logs stop appearing after rotation

**Solution:**
```bash
# Ensure correct signal is configured
# Try SIGHUP first
signal HUP

# If that doesn't work, try reload/restart
postrotate systemctl reload app

# Or restart if necessary
postrotate systemctl restart app
```

#### Issue: Running out of disk space

**Symptom:** Compression not working or too many old logs

**Solution:**
```bash
# Compress immediately (don't wait for delay)
LOG_COMPRESSION=xz ./log-rotation.sh compress /var/log 0

# Aggressive pruning
./log-rotation.sh prune /var/log 30

# Check space
df -h /var/log

# Move old logs to archive
tar -czf /archive/old-logs.tar.gz /var/log/*.gz
rm /var/log/*.gz
```

---

## Script 6: System Inventory

**File:** `scripts/system-inventory.sh`
**Lines:** 863 (345% of 250+ target)
**Purpose:** Comprehensive system information gathering and reporting

### Overview

Complete system inventory solution that collects hardware, software, network, and security information. Generates JSON and HTML reports, supports change detection, and provides real-time monitoring.

### Features

- ✅ **Comprehensive collection**: Hardware, OS, software, network, security
- ✅ **Multiple formats**: JSON, HTML, CSV
- ✅ **Change detection**: Diff between inventories
- ✅ **Watch mode**: Real-time monitoring
- ✅ **Beautiful reports**: HTML with embedded CSS

### Command Reference

```bash
./system-inventory.sh <command> [options]

Commands:
    collect [--output file]          Collect system inventory
    report [--format json|html]      Generate inventory report
    diff <old> <new>                 Compare two inventories
    watch                            Monitor for changes

Options:
    --output, -o <file>              Output file path
    --format, -f <format>            Report format (json, html)

Examples:
    # Collect and save inventory
    ./system-inventory.sh collect --output /tmp/inventory.json

    # Generate HTML report
    ./system-inventory.sh report --format html --output /var/www/inventory.html

    # Compare two inventories
    ./system-inventory.sh diff /tmp/old.json /tmp/new.json

    # Monitor for changes (real-time)
    ./system-inventory.sh watch
```

### Collected Information

#### Hardware Inventory

**CPU Information:**
- Model name
- Vendor (Intel, AMD, ARM)
- Architecture (x86_64, aarch64)
- Core count
- Thread count

**Memory Information:**
- Total RAM
- Free RAM
- Available RAM
- Swap total
- Swap free

**Disk Information:**
- Filesystem list
- Mount points
- Sizes and usage
- Block devices

**Network Information:**
- Hostname and FQDN
- Primary IP address
- Network interfaces
- DNS servers

#### Operating System Inventory

**System Information:**
- OS name (Debian, Alpine, Ubuntu)
- OS version
- Kernel version
- Architecture
- Uptime
- Init system (systemd, openrc, sysvinit)
- Package manager (apt, apk, yum)

#### Software Inventory

**Packages:**
- Installed package list
- Package count
- Version information

**Services:**
- Running services list
- Service count
- Service states

#### Security Inventory

**Security Configuration:**
- Firewall status (UFW, firewalld, iptables)
- SELinux status (if available)
- SSH configuration
- SSH port
- User account count

### Commands Detail

#### collect - Collect Inventory

**Purpose:** Gather complete system inventory

**Process:**
1. Collect hardware information
2. Collect OS information
3. Collect software information
4. Collect network information
5. Collect security information
6. Generate JSON report
7. Save to file

**Usage:**
```bash
# Collect and display
./system-inventory.sh collect

# Collect and save
./system-inventory.sh collect --output /tmp/inventory.json

# Automated collection
./system-inventory.sh collect --output "/var/lib/inventory/inventory-$(date +%Y%m%d).json"
```

**Output example (JSON):**
```json
{
    "inventory_version": "1.0",
    "timestamp": "2025-11-30T12:00:00Z",
    "system": {
        "hostname": "server01",
        "fqdn": "server01.example.com",
        "primary_ip": "192.168.1.100",
        "primary_interface": "eth0",
        "uptime_seconds": 86400,
        "uptime_human": "1d 0h 0m 0s"
    },
    "hardware": {
        "cpu": {
            "model": "Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz",
            "vendor": "GenuineIntel",
            "architecture": "x86_64",
            "cores": 8,
            "threads": 16
        },
        "memory": {
            "total_kb": 16777216,
            "total_gb": 16,
            "free_kb": 8388608,
            "available_kb": 12582912
        },
        "swap": {
            "total_kb": 8388608,
            "free_kb": 8388608
        },
        "disk": {
            "filesystem_count": 3
        }
    },
    "operating_system": {
        "name": "debian",
        "version": "12",
        "kernel": "6.1.0-13-amd64",
        "architecture": "x86_64",
        "init_system": "systemd",
        "package_manager": "apt"
    },
    "software": {
        "package_count": 542,
        "service_count": 23
    },
    "network": {
        "interfaces": "lo,eth0,docker0",
        "dns_servers": "8.8.8.8,8.8.4.4"
    },
    "security": {
        "firewall_status": "active",
        "selinux_status": "not-installed",
        "ssh_status": "configured",
        "ssh_port": "22",
        "user_count": 5
    }
}
```

#### report - Generate Report

**Purpose:** Generate formatted inventory report

**Formats supported:**
- **JSON**: Structured data for automation
- **HTML**: Beautiful web report with embedded CSS

**Usage:**
```bash
# JSON report
./system-inventory.sh report --format json

# HTML report
./system-inventory.sh report --format html --output inventory.html

# Save and open in browser
./system-inventory.sh report --format html --output /tmp/inventory.html
xdg-open /tmp/inventory.html
```

**HTML report features:**
- Responsive design
- Color-coded sections
- Gradient header
- Grid layout
- Print-friendly
- Standalone file (embedded CSS)

**HTML report sections:**
1. System Information (hostname, IP, uptime)
2. Hardware (CPU, memory, disk)
3. Operating System (distribution, kernel, init system)
4. Software & Services (packages, services)
5. Security (firewall, SELinux, SSH, users)

#### diff - Compare Inventories

**Purpose:** Compare two inventory snapshots and detect changes

**Comparison types:**
- Hardware changes (CPU, RAM upgrades)
- Software changes (new packages, updated packages)
- Configuration changes (network, security settings)
- Service changes (new services, stopped services)

**Usage:**
```bash
# Compare two inventories
./system-inventory.sh diff inventory-old.json inventory-new.json

# Save diff report
./system-inventory.sh diff inventory-old.json inventory-new.json > changes.txt
```

**Output example:**
```
=== Inventory Comparison ===
Old: inventory-20251101.json (2025-11-01 12:00:00)
New: inventory-20251130.json (2025-11-30 12:00:00)

Changes detected:

System:
  uptime_days: 5 → 35 (increased)

Hardware:
  memory.total_gb: 16 → 32 (increased)
  disk.filesystem_count: 3 → 4 (increased)

Software:
  package_count: 542 → 567 (increased by 25)
  service_count: 23 → 24 (increased by 1)

Security:
  user_count: 5 → 6 (increased by 1)

Summary:
  - Memory upgraded from 16GB to 32GB
  - New filesystem added
  - 25 packages installed
  - 1 new service
  - 1 new user added
```

#### watch - Monitor Changes

**Purpose:** Continuously monitor system for changes

**How it works:**
1. Collect current inventory
2. Compare with previous inventory
3. Report changes if detected
4. Sleep 60 seconds
5. Repeat

**Usage:**
```bash
# Start monitoring (runs until Ctrl+C)
./system-inventory.sh watch

# Monitor with custom interval
INVENTORY_CHECK_INTERVAL=300 ./system-inventory.sh watch  # 5 minutes
```

**Output example:**
```
[2025-11-30 12:00:00] [INFO] Starting inventory monitoring...
[2025-11-30 12:00:00] [INFO] Press Ctrl+C to stop

[2025-11-30 12:00:00] [INFO] Initial inventory collected
[2025-11-30 12:01:00] [SUCCESS] No changes detected
[2025-11-30 12:02:00] [SUCCESS] No changes detected
[2025-11-30 12:03:00] [WARNING] Changes detected at 2025-11-30 12:03:00
Changes:
  - software.package_count: 567 → 568 (increased by 1)

[2025-11-30 12:04:00] [SUCCESS] No changes detected
...
```

### Use Cases

#### Use Case 1: Asset Management

**Scenario:** Track hardware across multiple servers

```bash
# Collect inventory from all servers
for server in $(cat servers.txt); do
    ssh root@$server '/usr/local/bin/system-inventory.sh collect' \
        > "inventory-$server.json"
done

# Generate HTML reports
for json in inventory-*.json; do
    server=$(echo $json | sed 's/inventory-//;s/.json//')
    ./system-inventory.sh report --format html --output "report-$server.html" < "$json"
done

# Aggregate data
jq -s '.' inventory-*.json > inventory-all.json
```

#### Use Case 2: Change Auditing

**Scenario:** Track configuration changes over time

```bash
# Daily inventory collection (cron)
0 2 * * * /usr/local/bin/system-inventory.sh collect --output "/var/lib/inventory/$(date +\%Y\%m\%d).json"

# Weekly change report (cron)
0 3 * * 0 /usr/local/bin/generate-weekly-changes.sh

# generate-weekly-changes.sh
#!/bin/bash
LAST_WEEK=$(date -d '7 days ago' +%Y%m%d)
TODAY=$(date +%Y%m%d)

./system-inventory.sh diff \
    "/var/lib/inventory/$LAST_WEEK.json" \
    "/var/lib/inventory/$TODAY.json" \
    > "/var/reports/changes-$LAST_WEEK-$TODAY.txt"
```

#### Use Case 3: Compliance Reporting

**Scenario:** Generate compliance reports for auditors

```bash
# Collect inventory
./system-inventory.sh collect --output inventory.json

# Generate HTML report
./system-inventory.sh report --format html --output compliance-report.html

# Add to compliance package
tar -czf compliance-$(date +%Y%m%d).tar.gz \
    inventory.json \
    compliance-report.html \
    /var/log/audit/audit.log \
    /etc/ssh/sshd_config
```

#### Use Case 4: Disaster Recovery Documentation

**Scenario:** Document system configuration for DR

```bash
# Full system documentation
./system-inventory.sh collect --output dr-inventory.json
./server-hardening.sh --report dr-hardening.json --dry-run all
./backup-manager.sh list /backups > dr-backups.txt
./network-diagnostics.sh report > dr-network.json

# Package for DR site
tar -czf dr-documentation-$(date +%Y%m%d).tar.gz \
    dr-*.json \
    dr-*.txt \
    /etc/ \
    /root/.ssh/
```

### Scheduling

#### Daily Collection

```bash
# Cron: Daily at 2 AM
0 2 * * * /usr/local/bin/system-inventory.sh collect --output "/var/lib/inventory/daily-$(date +\%Y\%m\%d).json"
```

#### Weekly HTML Report

```bash
# Cron: Weekly on Monday at 8 AM
0 8 * * 1 /usr/local/bin/system-inventory.sh report --format html --output "/var/www/html/inventory.html"
```

#### Monthly Comparison

```bash
# Cron: First of month at 3 AM
0 3 1 * * /usr/local/bin/system-inventory.sh diff \
    "/var/lib/inventory/monthly-$(date -d 'last month' +\%Y\%m).json" \
    "/var/lib/inventory/monthly-$(date +\%Y\%m).json" \
    > "/var/reports/monthly-changes.txt"
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success or no changes detected |
| 1 | Failure or changes detected (diff command) |
| 2 | Usage error (invalid arguments) |

### Troubleshooting

#### Issue: Incomplete inventory data

**Symptom:** Some information missing or "unknown"

**Solution:**
```bash
# Ensure required tools are installed
sudo apt-get install lsb-release dmidecode lshw

# Check permissions
sudo ./system-inventory.sh collect

# Some hardware info requires root
sudo chown root:root system-inventory.sh
sudo chmod +x system-inventory.sh
```

#### Issue: HTML report not displaying correctly

**Symptom:** Broken layout or missing styles

**Solution:**
```bash
# Ensure full HTML file is generated
./system-inventory.sh report --format html --output inventory.html

# Check file size
ls -lh inventory.html

# Verify it's valid HTML
tidy -q -e inventory.html

# Open in different browser
firefox inventory.html
```

#### Issue: Watch mode using too much CPU

**Symptom:** High CPU usage during continuous monitoring

**Solution:**
```bash
# Increase check interval
INVENTORY_CHECK_INTERVAL=300 ./system-inventory.sh watch  # 5 minutes

# Or use systemd timer instead
# Create timer that runs every hour
```

---

## Common Patterns

### Error Handling Pattern

All scripts follow this error handling pattern:

```bash
set -euo pipefail  # Strict error handling

function_with_error_handling() {
    local source="$1"

    # Validate input
    if [[ -z "$source" ]]; then
        log_error "Source path required"
        return 1
    fi

    # Check prerequisites
    if [[ ! -e "$source" ]]; then
        log_error "Source does not exist: $source"
        return 1
    fi

    # Perform operation
    if ! perform_operation "$source"; then
        log_error "Operation failed"
        cleanup_on_error
        return 1
    fi

    log_success "Operation completed"
    return 0
}
```

### Configuration Hierarchy Pattern

```bash
# 1. Define defaults
readonly DEFAULT_VALUE="default"

# 2. Override with environment variable
CONFIG_VALUE="${ENV_VAR:-$DEFAULT_VALUE}"

# 3. Override with config file
if [[ -f /etc/config.conf ]]; then
    source /etc/config.conf
fi

# 4. Override with command-line argument
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config-value)
            CONFIG_VALUE="$2"
            shift 2
            ;;
    esac
done
```

### JSON Generation Pattern

```bash
generate_json_report() {
    local timestamp
    timestamp=$(timestamp_iso)

    cat << EOF
{
    "timestamp": "$timestamp",
    "hostname": "$(hostname)",
    "data": {
        "key": "value",
        "count": 42
    }
}
EOF
}
```

### Idempotency Pattern

```bash
idempotent_operation() {
    local config_file="/etc/app.conf"
    local desired_content="setting=value"

    # Check current state
    if [[ -f "$config_file" ]]; then
        if grep -q "^${desired_content}$" "$config_file"; then
            log_success "Already configured (no changes needed)"
            return 0
        fi
    fi

    # Apply changes
    echo "$desired_content" >> "$config_file"
    log_success "Configuration applied"
}
```

### Backup Before Change Pattern

```bash
safe_modification() {
    local file="$1"
    local backup_file

    # Create backup
    backup_file=$(backup_file "$file")
    log_info "Backup created: $backup_file"

    # Try modification
    if ! modify_file "$file"; then
        log_error "Modification failed, restoring backup"
        cp "$backup_file" "$file"
        return 1
    fi

    # Validate modification
    if ! validate_file "$file"; then
        log_error "Validation failed, restoring backup"
        cp "$backup_file" "$file"
        return 1
    fi

    log_success "Modification successful"
    return 0
}
```

---

## Troubleshooting

### General Issues

#### Issue: "Permission denied"

**Solution:**
```bash
# Run with sudo
sudo ./script.sh

# Or make script setuid (not recommended)
sudo chmod u+s script.sh
```

#### Issue: "Command not found"

**Solution:**
```bash
# Check if script is executable
chmod +x script.sh

# Check if script is in PATH
echo $PATH
export PATH=$PATH:/path/to/scripts

# Or use absolute path
/full/path/to/script.sh
```

#### Issue: "Bad interpreter"

**Symptom:** `/bin/bash^M: bad interpreter`

**Solution:**
```bash
# Convert line endings from Windows to Unix
dos2unix script.sh

# Or use sed
sed -i 's/\r$//' script.sh
```

### Performance Issues

#### Issue: Scripts running slowly

**Solution:**
```bash
# Enable debug mode to see what's slow
LOG_LEVEL=DEBUG ./script.sh

# Profile script execution
time ./script.sh

# Check for unnecessary external commands
# Replace with Bash built-ins where possible
```

### Logging Issues

#### Issue: No log output

**Solution:**
```bash
# Check log directory exists
ls -la /var/log/infra/

# Create if missing
sudo mkdir -p /var/log/infra
sudo chmod 755 /var/log/infra

# Check permissions
sudo chown root:adm /var/log/infra
```

### Common Errors

#### Error: "set: -e: invalid option"

**Cause:** Using old Bash version

**Solution:**
```bash
# Check Bash version
bash --version

# Upgrade Bash (Debian/Ubuntu)
sudo apt-get update && sudo apt-get install bash

# Upgrade Bash (Alpine)
sudo apk add bash
```

#### Error: "[[: not found"

**Cause:** Script executed with sh instead of bash

**Solution:**
```bash
# Use bash explicitly
bash script.sh

# Or ensure shebang is correct
head -1 script.sh
# Should be: #!/bin/bash
```

---

**Document Version:** 1.0.0
**Last Updated:** 2025-11-30
**Maintained By:** Linux System Administrator Portfolio

For architecture details, see [ARCHITECTURE.md](ARCHITECTURE.md).
For testing documentation, see [TESTING.md](TESTING.md).
