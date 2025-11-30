# Architecture Documentation
# Infrastructure Automation Toolkit

**Version:** 1.0.0
**Last Updated:** 2025-11-30
**Author:** Linux System Administrator Portfolio

---

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Design Principles](#design-principles)
- [Component Architecture](#component-architecture)
- [Data Flows](#data-flows)
- [Security Architecture](#security-architecture)
- [Multi-OS Support](#multi-os-support)
- [Error Handling Strategy](#error-handling-strategy)
- [Testing Architecture](#testing-architecture)
- [Deployment Models](#deployment-models)

---

## Overview

The Infrastructure Automation Toolkit is a collection of production-grade Bash scripts designed for Linux system administration, security hardening, monitoring, and maintenance. The architecture emphasizes:

- **Modularity**: Reusable components via shared library
- **Portability**: Cross-platform support (Debian, Alpine, Ubuntu)
- **Reliability**: Comprehensive error handling and validation
- **Maintainability**: Clear structure, consistent patterns, extensive documentation
- **Testability**: Docker-based test environment with comprehensive test suite

### Architecture Goals

1. **Production-Ready**: Scripts must be safe for production use
2. **Idempotent**: Operations can be safely repeated
3. **Observable**: Rich logging and reporting
4. **Configurable**: Multiple configuration methods
5. **Tested**: Comprehensive automated testing

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Infrastructure Automation                    │
│                         Toolkit System                           │
└─────────────────────────────────────────────────────────────────┘
                                  │
                  ┌───────────────┼───────────────┐
                  │               │               │
         ┌────────▼────────┐ ┌───▼────┐ ┌───────▼──────┐
         │  Common Library │ │Scripts │ │ Test Suite   │
         │  (lib/common.sh)│ │        │ │ (e2e-test.sh)│
         └────────┬────────┘ └───┬────┘ └───────┬──────┘
                  │              │               │
                  └──────────────┼───────────────┘
                                 │
         ┌───────────────────────┴────────────────────────┐
         │                                                 │
    ┌────▼────┐  ┌────────┐  ┌────────┐  ┌────────────┐  │
    │ Debian  │  │ Alpine │  │ Ubuntu │  │Docker Test │  │
    │ Target  │  │ Target │  │ Target │  │Environment │  │
    └─────────┘  └────────┘  └────────┘  └────────────┘  │
                                                          │
                    ┌──────────────────────────────┐      │
                    │   External Dependencies      │      │
                    │  - systemd/openrc/sysvinit   │      │
                    │  - iptables/ufw/firewalld    │──────┘
                    │  - Package managers          │
                    │  - Network tools             │
                    └──────────────────────────────┘
```

### Layer Architecture

The system is organized into distinct layers:

#### Layer 1: Common Library
**Location:** `scripts/lib/common.sh` (412 lines)

Provides shared functionality for all scripts:
- Logging functions with color output
- OS detection (Debian, Alpine, Ubuntu, RHEL, Arch)
- Init system detection (systemd, openrc, sysvinit)
- Package manager detection (apt, apk, yum, pacman)
- Validation functions (root check, dependencies, file existence)
- JSON utilities (escaping, timestamps, report generation)
- Network utilities (port checking, IP detection)
- Math utilities (percentage, byte conversion, duration formatting)
- String utilities (trim, case conversion)

**Key Functions:**
```bash
# Logging
log_info()      # Blue informational messages
log_success()   # Green success messages
log_warning()   # Yellow warning messages
log_error()     # Red error messages (stderr)
log_debug()     # Cyan debug messages (if LOG_LEVEL=DEBUG)

# OS Detection
detect_os()             # Returns: debian, alpine, ubuntu, rhel, arch, unknown
detect_os_version()     # Returns version ID from /etc/os-release
detect_package_manager() # Returns: apt, apk, yum, pacman, unknown
detect_init_system()    # Returns: systemd, openrc, sysvinit, unknown

# Validation
check_root()               # Ensures script is run as root
check_command()            # Verifies command exists
check_dependencies()       # Checks multiple commands at once
check_file_exists()        # Verifies file exists
check_directory_exists()   # Verifies directory exists
is_containerized()         # Detects Docker/container environment

# JSON Utilities
json_escape()       # Escapes strings for JSON
json_timestamp()    # ISO 8601 timestamp
timestamp_iso()     # ISO 8601 timestamp
timestamp_filename() # Filename-safe timestamp (YYYYMMDD_HHMMSS)
timestamp_human()    # Human-readable timestamp

# Network
check_port()           # Tests TCP port connectivity
get_ip_address()       # Returns primary IP address
get_primary_interface() # Returns default network interface

# File Operations
ensure_directory()     # Creates directory if doesn't exist
backup_file()          # Creates timestamped backup of file

# Math
percentage()           # Calculates percentage
bytes_to_kb()          # Converts bytes to kilobytes
bytes_to_mb()          # Converts bytes to megabytes
bytes_to_gb()          # Converts bytes to gigabytes
seconds_to_duration()  # Formats seconds as "Xd Yh Zm Ws"
```

#### Layer 2: Automation Scripts

Six specialized scripts, each with a specific purpose:

1. **server-hardening.sh** (781 lines) - Security hardening
2. **network-diagnostics.sh** (588 lines) - Network troubleshooting
3. **service-watchdog.sh** (647 lines) - Service monitoring
4. **backup-manager.sh** (619 lines) - Backup management
5. **log-rotation.sh** (773 lines) - Log rotation
6. **system-inventory.sh** (863 lines) - System reporting

Each script follows a consistent structure (see Component Architecture).

#### Layer 3: Test Environment

Docker-based multi-OS test environment:
- 3 target containers (Debian, Alpine, Ubuntu)
- 2 service containers (Nginx web server, CoreDNS)
- Isolated network (172.30.0.0/24)
- Volume mounts for scripts and reports
- Health checks for all services

#### Layer 4: Test Suite

Comprehensive test suite with:
- 40+ test cases
- TAP (Test Anything Protocol) output
- Docker container orchestration
- Multi-OS validation
- Integration testing

---

## Design Principles

### 1. Fail-Fast with Bash Options

All scripts use strict error handling:

```bash
set -euo pipefail
```

- `set -e`: Exit immediately if any command fails
- `set -u`: Treat unset variables as errors
- `set -o pipefail`: Fail if any command in a pipeline fails

### 2. Idempotency

Scripts can be safely run multiple times without causing issues:

**Example from server-hardening.sh:**
```bash
harden_ssh() {
    local hardening_config="/etc/ssh/sshd_config.d/99-hardening.conf"

    # Check if already hardened
    if [[ -f "$hardening_config" ]]; then
        if echo "$config_content" | diff -q - "$hardening_config" &>/dev/null; then
            log_success "SSH already hardened (no changes needed)"
            return 0
        fi
    fi

    # Apply changes...
}
```

### 3. Configuration Hierarchy

Configuration can be provided in multiple ways (priority order):

1. **Command-line arguments**: Highest priority
2. **Environment variables**: Medium priority
3. **Configuration files**: Lower priority
4. **Defaults**: Lowest priority

**Example:**
```bash
# Default value
readonly CHECK_INTERVAL="${WATCHDOG_CHECK_INTERVAL:-60}"

# Can be overridden with:
# Environment: WATCHDOG_CHECK_INTERVAL=30 ./script.sh
# Config file: CHECK_INTERVAL=45 in /etc/config
# Command-line: ./script.sh --interval 120
```

### 4. Separation of Concerns

Each script has a single, well-defined purpose:
- **server-hardening.sh**: Security configuration only
- **backup-manager.sh**: Backup operations only
- **service-watchdog.sh**: Service monitoring only

No script tries to do multiple unrelated tasks.

### 5. Defensive Programming

- Always validate inputs
- Check prerequisites before operations
- Provide helpful error messages
- Fail gracefully with cleanup

**Example:**
```bash
cmd_backup() {
    local source="$1"
    local destination="$2"

    # Validate inputs
    if [[ -z "$source" || -z "$destination" ]]; then
        log_error "Usage: backup <source> <destination>"
        return 1
    fi

    # Check source exists
    if [[ ! -e "$source" ]]; then
        log_error "Source does not exist: $source"
        return 1
    fi

    # Check destination is writable
    if [[ ! -w "$(dirname "$destination")" ]]; then
        log_error "Destination directory not writable: $(dirname "$destination")"
        return 1
    fi

    # Proceed with backup...
}
```

### 6. Observable Operations

All operations produce clear, structured output:
- Color-coded log levels
- Progress indicators
- JSON reports for automation
- Exit codes following UNIX conventions

---

## Component Architecture

### Script Structure Template

All scripts follow this consistent structure:

```bash
#!/bin/bash
#===============================================================================
# Script Name - Brief Description
#
# Purpose:
#   Detailed explanation of what the script does
#
# Usage:
#   ./script.sh command [options]
#
# Skills Demonstrated:
#   - Skill 1
#   - Skill 2
#===============================================================================

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

#===============================================================================
# Configuration
#===============================================================================
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_CONFIG="/etc/script.conf"

# Configuration variables with defaults
CONFIG_VAR="${ENV_VAR:-default_value}"

#===============================================================================
# Core Functions
#===============================================================================

# Business logic functions here

#===============================================================================
# Command Functions
#===============================================================================

cmd_command() {
    # Command implementation
}

#===============================================================================
# Usage
#===============================================================================

usage() {
    cat << EOF
Usage: $SCRIPT_NAME <command> [options]

Description of script.

Commands:
    command1    Description
    command2    Description

Examples:
    $SCRIPT_NAME command1
    $SCRIPT_NAME command2 --option value
EOF
}

#===============================================================================
# Main Entry Point
#===============================================================================

main() {
    local command="${1:-help}"

    case "$command" in
        command1) shift; cmd_command1 "$@" ;;
        command2) shift; cmd_command2 "$@" ;;
        help) usage ;;
        *) log_error "Unknown command: $command"; usage; exit 1 ;;
    esac
}

# Allow sourcing for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### Server Hardening Architecture

**Module-Based Design:**

```
server-hardening.sh
├── Module 1: SSH Hardening
│   ├── Disable root login
│   ├── Enforce key authentication
│   ├── Set cipher suites
│   └── Configure SSH options
├── Module 2: Kernel Hardening
│   ├── SYN cookies
│   ├── IP forwarding control
│   ├── ASLR configuration
│   └── Kernel pointer restriction
├── Module 3: Firewall Configuration
│   ├── UFW/iptables setup
│   ├── Default deny policy
│   └── SSH allow rules
├── Module 4: Permission Hardening
│   ├── World-writable file scan
│   ├── SUID/SGID audit
│   └── Home directory permissions
└── Module 5: User Security
    ├── Password policies
    ├── Inactive account detection
    └── Sudo configuration
```

**Execution Flow:**
```
main()
  │
  ├─> Parse arguments (--dry-run, --report, --modules)
  ├─> Validate prerequisites (root, OS support)
  ├─> Load configuration
  │
  ├─> For each selected module:
  │     ├─> Check if changes needed (idempotency)
  │     ├─> Create backups if not dry-run
  │     ├─> Apply hardening
  │     ├─> Validate changes
  │     └─> Record in report
  │
  └─> Generate final report (JSON)
```

### Network Diagnostics Architecture

**Git-Style Subcommand Pattern:**

```
network-diagnostics.sh <subcommand> [args]
├── connectivity <host>
│   ├── ICMP ping test
│   ├── TCP port test
│   └── MTU detection
├── dns <hostname>
│   ├── Forward resolution
│   ├── Reverse resolution
│   └── DNS server validation
├── routes
│   ├── Routing table display
│   ├── Default gateway detection
│   └── Traceroute
├── ports
│   ├── Listening ports
│   └── Process mapping
├── scan <host> <ports>
│   └── Port scanning
└── report
    └── Full network report (JSON)
```

**Tool Selection Logic:**
```
For each operation:
  ├─> Try primary tool (e.g., ping)
  ├─> If not found, try alternative (e.g., fping)
  ├─> If no tools available, skip with warning
  └─> Format output consistently
```

### Service Watchdog Architecture

**Daemon Architecture:**

```
service-watchdog.sh
├── Daemon Control
│   ├── start: Start daemon with PID file
│   ├── stop: Graceful shutdown (SIGTERM)
│   ├── status: Check running status
│   └── restart: Stop + Start
│
├── Signal Handling
│   ├── SIGTERM: Graceful shutdown
│   ├── SIGINT: Graceful shutdown
│   └── SIGHUP: Reload configuration
│
├── Monitoring Loop
│   ├── Load service configuration
│   ├── For each service:
│   │   ├── Run health check
│   │   ├── If failed: attempt restart
│   │   ├── Track restart count
│   │   └── Send alerts if needed
│   ├── Save state
│   └── Sleep until next check
│
└── State Management
    ├── PID file: /var/run/service-watchdog.pid
    ├── State file: /var/lib/service-watchdog/state.json
    └── Log file: /var/log/infra/service-watchdog.log
```

**Check Types:**
```
1. Process Check: pgrep -x <process_name>
2. Port Check: timeout bash -c "cat < /dev/null > /dev/tcp/host/port"
3. HTTP Check: curl/wget with status code validation
4. Custom Check: Execute custom script, check exit code
```

**Restart Logic:**
```
Service fails check
  │
  ├─> Check restart count
  │     └─> If < limit: proceed
  │     └─> If >= limit: alert and skip
  │
  ├─> Determine init system
  │     ├─> systemd: systemctl restart
  │     ├─> openrc: rc-service restart
  │     └─> sysvinit: /etc/init.d/<service> restart
  │
  ├─> Execute restart
  ├─> Wait 5 seconds
  ├─> Verify service is up
  └─> Update counters and send alert
```

### Backup Manager Architecture

**Backup Strategy:**

```
backup-manager.sh
├── Full Backup
│   ├── Create tar archive
│   ├── Compress (gzip/xz/zstd)
│   ├── Calculate SHA256
│   └── Save metadata
│
├── Incremental Backup
│   ├── Find last full backup
│   ├── Create tar with --newer-mtime
│   ├── Compress
│   ├── Calculate SHA256
│   └── Save metadata
│
├── Verification
│   ├── Read SHA256 checksum file
│   ├── Calculate actual checksum
│   └── Compare
│
├── Restoration
│   ├── Verify backup integrity
│   ├── Extract to temp location
│   ├── Validate extraction
│   └── Move to final destination
│
└── Pruning (GFS)
    ├── Keep last 7 daily backups
    ├── Keep last 4 weekly backups
    ├── Keep last 12 monthly backups
    └── Remove everything older
```

**Metadata Format:**
```json
{
  "backup_id": "unique-id",
  "timestamp": "2025-11-30T12:00:00Z",
  "type": "full",
  "source": "/var/www",
  "size_bytes": 1048576,
  "compression": "gzip",
  "checksum": "sha256:abc123...",
  "parent_backup": null
}
```

### Log Rotation Architecture

**Rotation Workflow:**

```
log-rotation.sh
├── Configuration Parsing
│   ├── Read config file
│   ├── Parse log file blocks
│   └── Store in associative arrays
│
├── Rotation Decision
│   ├── Check file size vs maxsize
│   ├── Check file age vs maxage
│   └── Return true if either threshold met
│
├── Rotation Process
│   ├── Copy log file (preserve FD)
│   ├── Truncate original to 0
│   ├── Signal process (if configured)
│   └── Run postrotate hook
│
├── Compression (Deferred)
│   ├── Find rotated logs > N days old
│   ├── Compress with configured algorithm
│   └── Remove original
│
└── Pruning
    ├── Find logs older than retention
    └── Remove
```

**Configuration Format:**
```bash
/var/log/nginx/access.log {
    maxsize 100M           # Rotate if > 100MB
    maxage 7               # Rotate if > 7 days old
    retention 90           # Keep for 90 days
    compress gzip          # Use gzip compression
    signal HUP             # Send SIGHUP after rotation
    pidfile /var/run/nginx.pid
    postrotate systemctl reload nginx
}
```

### System Inventory Architecture

**Data Collection Flow:**

```
system-inventory.sh
├── Hardware Inventory
│   ├── CPU: /proc/cpuinfo
│   ├── Memory: /proc/meminfo
│   ├── Disk: df, lsblk
│   └── Network: ip link, ifconfig
│
├── OS Inventory
│   ├── Distribution: /etc/os-release
│   ├── Kernel: uname -r
│   ├── Uptime: /proc/uptime
│   └── Init system: detect_init_system()
│
├── Software Inventory
│   ├── Packages: dpkg/apk/rpm
│   └── Services: systemctl/rc-status
│
├── Security Inventory
│   ├── Firewall: ufw/firewalld/iptables
│   ├── SELinux: getenforce
│   ├── SSH: /etc/ssh/sshd_config
│   └── Users: /etc/passwd
│
└── Report Generation
    ├── JSON: Structured data
    └── HTML: Formatted web report
```

**Report Formats:**

1. **JSON Report:**
```json
{
  "inventory_version": "1.0",
  "timestamp": "2025-11-30T12:00:00Z",
  "system": {
    "hostname": "server01",
    "ip": "192.168.1.100",
    "uptime_seconds": 86400
  },
  "hardware": {
    "cpu": {...},
    "memory": {...},
    "disk": {...}
  },
  "operating_system": {...},
  "software": {...},
  "network": {...},
  "security": {...}
}
```

2. **HTML Report:**
- Responsive web design
- CSS Grid layout
- Color-coded sections
- Embedded CSS (standalone file)
- Print-friendly

---

## Data Flows

### Script Execution Data Flow

```
┌─────────────┐
│   User      │
│   Input     │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ Argument Parsing    │
│ - Parse flags       │
│ - Validate inputs   │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Configuration Load  │
│ - Environment vars  │
│ - Config files      │
│ - Apply defaults    │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Prerequisite Check  │
│ - Root access       │
│ - Dependencies      │
│ - OS support        │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Main Logic          │
│ - Business logic    │
│ - State management  │
│ - Error handling    │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Output Generation   │
│ - Console logs      │
│ - JSON reports      │
│ - Exit codes        │
└──────┬──────────────┘
       │
       ▼
┌─────────────┐
│   Files     │
│  - Logs     │
│  - Reports  │
│  - State    │
└─────────────┘
```

### Backup Data Flow

```
Source Directory
       │
       ▼
┌──────────────┐
│ tar Archive  │◄──── File selection
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Compress    │◄──── Algorithm selection
└──────┬───────┘      (gzip/xz/zstd)
       │
       ▼
┌──────────────┐
│   Checksum   │◄──── SHA256 calculation
└──────┬───────┘
       │
       ├────────────────────┐
       │                    │
       ▼                    ▼
┌──────────────┐    ┌──────────────┐
│ Backup File  │    │ .sha256 File │
│ .tar.gz      │    │              │
└──────────────┘    └──────────────┘
       │                    │
       └────────┬───────────┘
                │
                ▼
        ┌──────────────┐
        │ Metadata File│
        │ .json        │
        └──────────────┘
```

### Watchdog Monitoring Flow

```
┌──────────────────┐
│  Configuration   │
│  Load Services   │
└────────┬─────────┘
         │
         ▼
┌────────────────────────────┐
│   Monitoring Loop          │
│   (every N seconds)        │
└────────┬───────────────────┘
         │
         ├───────────────┐
         │               │
         ▼               ▼
┌────────────────┐  ┌────────────────┐
│  Check Service │  │  Check Service │
│      #1        │  │      #2        │
└────────┬───────┘  └────────┬───────┘
         │                   │
         ├─────────┬─────────┤
         │         │         │
         ▼         ▼         ▼
     ┌─────┐   ┌─────┐   ┌─────┐
     │ OK  │   │FAIL │   │ OK  │
     └─────┘   └──┬──┘   └─────┘
                  │
                  ▼
         ┌────────────────┐
         │ Restart Logic  │
         │ - Check limit  │
         │ - Restart svc  │
         │ - Verify       │
         └────────┬───────┘
                  │
                  ├────────────┬─────────────┐
                  │            │             │
                  ▼            ▼             ▼
            ┌─────────┐  ┌─────────┐  ┌─────────┐
            │  Alert  │  │  Log    │  │ Update  │
            │         │  │         │  │ State   │
            └─────────┘  └─────────┘  └─────────┘
```

---

## Security Architecture

### Security Layers

#### 1. Script Execution Security

- **Privilege Separation**: Only operations requiring root use sudo
- **Input Validation**: All user inputs validated before use
- **Path Safety**: Use absolute paths, avoid PATH injection
- **Temp File Security**: Use mktemp with proper permissions

#### 2. Configuration Security

- **File Permissions**: Config files should be 0600 or 0644
- **Secret Management**: Never hardcode secrets
- **Environment Variables**: For sensitive values
- **Secure Defaults**: Conservative default settings

#### 3. Network Security

- **Firewall Integration**: Respects existing firewall rules
- **No Unnecessary Exposure**: Scripts don't open ports
- **TLS/SSL**: Use secure protocols when available

#### 4. Data Security

- **Backup Encryption**: Optional GPG encryption
- **Checksum Verification**: SHA256 for all backups
- **Secure Deletion**: Shred sensitive temporary files
- **Log Sanitization**: Remove sensitive data from logs

### Security Hardening Applied

**SSH Hardening:**
```bash
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,diffie-hellman-group16-sha512
```

**Kernel Hardening:**
```bash
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
```

**Firewall Rules:**
```bash
# Default policies
ufw default deny incoming
ufw default allow outgoing

# Essential services only
ufw allow 22/tcp comment 'SSH'
ufw enable
```

---

## Multi-OS Support

### OS Detection Strategy

```bash
detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "${ID:-unknown}"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/alpine-release ]]; then
        echo "alpine"
    else
        echo "unknown"
    fi
}
```

### Platform-Specific Adaptations

#### Package Management
```bash
case "$(detect_package_manager)" in
    apt)
        apt-get update && apt-get install -y package
        ;;
    apk)
        apk update && apk add package
        ;;
    yum)
        yum install -y package
        ;;
esac
```

#### Init System
```bash
case "$(detect_init_system)" in
    systemd)
        systemctl restart service
        ;;
    openrc)
        rc-service service restart
        ;;
    sysvinit)
        /etc/init.d/service restart
        ;;
esac
```

#### Tool Availability
```bash
# Try multiple tools for same operation
if command -v ping &>/dev/null; then
    ping -c 4 "$host"
elif command -v fping &>/dev/null; then
    fping -c 4 "$host"
else
    log_warning "No ping utility available"
fi
```

### Tested Platforms

| Distribution | Version | Status | Notes |
|--------------|---------|--------|-------|
| Debian | 12 (bookworm) | ✅ Fully tested | Primary target |
| Alpine | 3.19 | ✅ Fully tested | Lightweight target |
| Ubuntu | 24.04 LTS | ✅ Fully tested | Enterprise target |
| Debian | 11 (bullseye) | ⚠️ Should work | Not tested |
| Ubuntu | 22.04 LTS | ⚠️ Should work | Not tested |
| CentOS/RHEL | 8+ | ⚠️ Partial | Different tools |

---

## Error Handling Strategy

### Error Handling Patterns

#### 1. Graceful Failure

```bash
command_with_error_handling() {
    if ! some_operation; then
        log_error "Operation failed: some_operation"
        cleanup_resources
        return 1
    fi
}
```

#### 2. Transaction-Like Operations

```bash
make_changes() {
    local backup_file

    # Create backup
    backup_file=$(backup_file "/etc/config")

    # Try to make changes
    if ! apply_changes; then
        log_error "Changes failed, restoring backup"
        cp "$backup_file" "/etc/config"
        return 1
    fi

    # Validate changes
    if ! validate_changes; then
        log_error "Validation failed, restoring backup"
        cp "$backup_file" "/etc/config"
        return 1
    fi

    log_success "Changes applied successfully"
}
```

#### 3. Resource Cleanup

```bash
cleanup() {
    log_info "Cleaning up..."
    [[ -n "${TEMP_DIR:-}" ]] && rm -rf "$TEMP_DIR"
    [[ -n "${PID_FILE:-}" ]] && rm -f "$PID_FILE"
}

trap cleanup EXIT
```

### Exit Codes

Standard exit codes used throughout:

| Code | Meaning | Usage |
|------|---------|-------|
| 0 | Success | Normal successful execution |
| 1 | General error | Failed operation, validation error |
| 2 | Usage error | Invalid arguments, missing parameters |
| 3 | Not running | Daemon status check (not running) |
| 130 | Interrupted | User pressed Ctrl+C |

---

## Testing Architecture

### Test Environment

```
Docker Compose Test Stack
├── infra-debian-target (Debian 12)
│   ├── Full package set
│   ├── systemd init
│   └── apt package manager
│
├── infra-alpine-target (Alpine 3.19)
│   ├── Minimal packages
│   ├── openrc init
│   └── apk package manager
│
├── infra-ubuntu-target (Ubuntu 24.04)
│   ├── Full package set
│   ├── systemd init
│   └── apt package manager
│
├── test-webserver (Nginx)
│   └── For HTTP health checks
│
└── test-dns (CoreDNS)
    └── For DNS resolution tests
```

### Test Categories

#### 1. Syntax Tests
```bash
test_script_syntax() {
    bash -n /path/to/script.sh
}
```

#### 2. Functionality Tests
```bash
test_backup_full() {
    mkdir -p /tmp/source /tmp/dest
    echo "data" > /tmp/source/file.txt
    ./backup-manager.sh full /tmp/source /tmp/dest
    [[ -f /tmp/dest/*.tar.gz ]]
}
```

#### 3. Integration Tests
```bash
test_hardening_and_inventory() {
    ./server-hardening.sh --dry-run all
    ./system-inventory.sh collect --output /tmp/inventory.json
    [[ -f /tmp/inventory.json ]]
}
```

#### 4. Multi-OS Tests
```bash
test_multi_os_detection() {
    for container in debian alpine ubuntu; do
        docker exec "infra-${container}-target" \
            bash -c 'source /scripts/lib/common.sh && detect_os'
    done
}
```

### Test Execution Flow

```
e2e-test.sh
  │
  ├─> Ensure containers running
  │
  ├─> Run test suite
  │     ├─> Common library tests
  │     ├─> Per-script tests
  │     ├─> Multi-OS tests
  │     └─> Integration tests
  │
  ├─> Collect results
  │
  └─> Generate report
        ├─> TAP output
        ├─> Statistics
        └─> JSON summary
```

---

## Deployment Models

### Model 1: Standalone Scripts

Direct execution on target systems:

```bash
# Copy scripts to target
scp -r scripts/ user@target:/tmp/

# Run on target
ssh user@target 'sudo /tmp/scripts/server-hardening.sh all'
```

### Model 2: Centralized Management

Run from central management server:

```bash
# Inventory
for host in $(cat hosts.txt); do
    ssh root@$host './system-inventory.sh collect' > "inventory-$host.json"
done

# Hardening
for host in $(cat hosts.txt); do
    ssh root@$host './server-hardening.sh all'
done
```

### Model 3: Configuration Management Integration

Integrate with Ansible/Puppet/Chef:

```yaml
# Ansible playbook example
- name: Run server hardening
  command: /usr/local/bin/server-hardening.sh all --report /tmp/hardening-report.json
  register: hardening_result

- name: Fetch hardening report
  fetch:
    src: /tmp/hardening-report.json
    dest: ./reports/{{ inventory_hostname }}-hardening.json
```

### Model 4: Docker-Based Execution

Run scripts in containers:

```bash
docker run --rm --privileged \
    -v /:/host:ro \
    -v ./reports:/reports \
    infra-debian-target \
    /scripts/system-inventory.sh collect --output /reports/inventory.json
```

### Model 5: Scheduled Execution

Cron-based automation:

```cron
# System inventory daily at 2 AM
0 2 * * * /usr/local/bin/system-inventory.sh collect --output /var/reports/inventory-$(date +\%Y\%m\%d).json

# Log rotation daily at 3 AM
0 3 * * * /usr/local/bin/log-rotation.sh rotate /etc/logrotate-custom.conf

# Backup weekly on Sunday at 1 AM
0 1 * * 0 /usr/local/bin/backup-manager.sh full /var/www /backups
```

---

## Performance Considerations

### Script Performance

- **Minimal External Commands**: Bash built-ins preferred
- **Parallel Operations**: Where safe, operations run in parallel
- **Caching**: OS detection cached for script duration
- **Efficient Algorithms**: O(n) loops, avoid nested iterations

### Resource Usage

Typical resource consumption:

| Script | CPU | Memory | Disk I/O | Network |
|--------|-----|--------|----------|---------|
| server-hardening | Low | ~10MB | Low | None |
| network-diagnostics | Medium | ~15MB | None | Medium |
| service-watchdog | Low | ~5MB | Low | Low |
| backup-manager | Medium | ~50MB | High | None |
| log-rotation | Low | ~20MB | Medium | None |
| system-inventory | Low | ~10MB | Low | None |

---

## Conclusion

The Infrastructure Automation Toolkit demonstrates production-ready system administration through:

- **Robust Architecture**: Well-organized, modular design
- **Security Focus**: Multiple layers of security
- **Cross-Platform**: Works on major Linux distributions
- **Comprehensive Testing**: 40+ automated tests
- **Rich Documentation**: Architecture, usage, and examples

This architecture supports maintainability, extensibility, and reliability in production environments.

---

**Document Version:** 1.0.0
**Last Updated:** 2025-11-30
**Maintained By:** Linux System Administrator Portfolio
