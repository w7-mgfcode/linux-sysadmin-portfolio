# Mail Server Scripts Documentation

## Table of Contents

1. [Overview](#overview)
2. [Common Library](#common-library-commonsh)
3. [mail-queue-monitor.sh](#mail-queue-monitorsh)
4. [user-management.sh](#user-managementsh)
5. [backup.sh](#backupsh)
6. [spam-report.sh](#spam-reportsh)
7. [generate-ssl.sh](#generate-sslsh)
8. [test-mail-flow.sh](#test-mail-flowsh)
9. [Best Practices](#best-practices)

---

## Overview

The mail server includes **7 production-ready Bash scripts** totaling **1,566 lines** of code, demonstrating advanced scripting techniques, error handling, and automation patterns.

### Script Statistics

| Script                   | Lines | Purpose                        | Complexity |
|--------------------------|-------|--------------------------------|------------|
| mail-queue-monitor.sh    | 460   | Queue monitoring (daemon mode) | High       |
| user-management.sh       | 450   | User/domain administration     | High       |
| backup.sh                | 336   | Automated backup system        | Medium     |
| spam-report.sh           | 320   | Spam statistics & visualization| Medium     |
| generate-ssl.sh          | 222   | SSL certificate generation     | Medium     |
| lib/common.sh            | 147   | Shared utility library         | Low        |
| test-mail-flow.sh        | 383   | Mail flow testing              | High       |
| **Total**                | **2,318** |                            |            |

### Common Patterns

All scripts follow these standards:
- **Error Handling**: `set -euo pipefail`
- **Shellcheck Compliance**: Pass with no errors
- **Structured Logging**: Color-coded output functions
- **Configuration**: Environment variables with defaults
- **Documentation**: Comprehensive header comments

---

## Common Library (common.sh)

### Purpose

Shared utility functions used across all scripts to avoid code duplication and ensure consistency.

### Location

`scripts/lib/common.sh` (147 lines)

### Functions

#### Logging Functions

```bash
log() {
    local level=$1
    shift
    echo -e "${COLORS[$level]}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*${COLORS[NC]}"
}

log_info()    # Blue color - informational messages
log_success() # Green color - success messages
log_warning() # Yellow color - warnings
log_error()   # Red color - errors (to stderr)
```

**Usage Example**:
```bash
log_info "Starting backup process..."
log_success "Backup completed successfully"
log_warning "Disk space is low"
log_error "Failed to connect to MySQL"
```

#### Docker Helper Functions

```bash
postfix_exec() {
    docker exec -i mail-postfix "$@"
}

dovecot_exec() {
    docker exec -i mail-dovecot "$@"
}

mysql_exec() {
    docker exec -i mail-mysql mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "$@"
}

mysql_query() {
    docker exec -i mail-mysql mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -sN -e "$@"
}
```

**Usage Example**:
```bash
# Execute Postfix command
postfix_exec postqueue -f

# Query MySQL
user_count=$(mysql_query "SELECT COUNT(*) FROM virtual_users")
```

#### JSON Helper Functions

```bash
json_escape()     # Escape strings for JSON
json_timestamp()  # ISO 8601 timestamp
json_header()     # Standard JSON header
json_footer()     # Standard JSON footer
```

**Usage Example**:
```bash
cat > report.json << EOF
$(json_header "backup-script")
    "status": "success",
    "timestamp": "$(json_timestamp)"
$(json_footer)
EOF
```

#### Utility Functions

```bash
is_containerized()        # Check if running in container
check_command()           # Verify command exists
check_dependencies()      # Verify multiple commands
timestamp_iso()           # ISO 8601 timestamp
timestamp_filename()      # Filename-safe timestamp (YYYYMMDD_HHMMSS)
ensure_directory()        # Create directory if not exists
check_port()              # Test TCP port connectivity
percentage()              # Calculate percentage
bytes_to_mb()             # Convert bytes to megabytes
```

**Usage Example**:
```bash
# Check dependencies
check_dependencies "docker" "mysql" "tar" || exit 1

# Ensure directory exists
ensure_directory "/var/reports"

# Test connectivity
if check_port "mysql" 3306; then
    log_success "MySQL is reachable"
fi

# Calculate percentage
spam_rate=$(percentage $spam_count $total_count)
```

---

## mail-queue-monitor.sh

### Purpose

Real-time mail queue monitoring with daemon mode support, threshold-based alerting, and comprehensive queue analysis.

### Location

`scripts/mail-queue-monitor.sh` (460 lines)

### Features

1. **Daemon Mode**: Runs as background service with PID file management
2. **Signal Handling**: Graceful shutdown on SIGTERM/SIGINT, reload on SIGHUP
3. **Queue Statistics**: Total, active, deferred, hold message counts
4. **Bounce Analysis**: Categorizes DSN codes (4.7.x spam block, 4.4.2 timeout, etc.)
5. **Threshold Alerting**: Configurable warning/critical thresholds
6. **Multiple Alert Channels**: Webhook, email, log file
7. **Alert Cooldown**: Prevents alert flooding
8. **JSON Reporting**: Machine-readable output for dashboard

### Configuration

```bash
# Queue thresholds
QUEUE_WARNING=50              # Warning at 50 messages
QUEUE_CRITICAL=200            # Critical at 200 messages
DEFERRED_WARNING=25           # Warning for deferred queue

# Daemon settings
CHECK_INTERVAL=60             # Check every 60 seconds
PID_FILE=/var/run/mail-queue-monitor.pid
LOG_FILE=/var/log/mail-queue-monitor.log

# Alert settings
MAIL_ADMIN=admin@localhost
ALERT_WEBHOOK=https://hooks.slack.com/...
ALERT_COOLDOWN=300            # 5 minutes between alerts
```

### Usage Examples

#### One-Shot Mode

```bash
# Run once and exit
./scripts/mail-queue-monitor.sh

# Output:
# [INFO] Gathering queue statistics...
# [INFO] Queue stats: total=15, active=2, deferred=10, hold=3
# [SUCCESS] Report generated: /var/reports/mail-queue-20251130_143052.json
```

#### Daemon Mode

```bash
# Start daemon
./scripts/mail-queue-monitor.sh daemon

# Check status
./scripts/mail-queue-monitor.sh status
# Output: Daemon is running (PID: 12345)

# Stop daemon
kill $(cat /var/run/mail-queue-monitor.pid)
# or
kill -TERM $(cat /var/run/mail-queue-monitor.pid)

# Reload configuration
kill -HUP $(cat /var/run/mail-queue-monitor.pid)
```

#### Systemd Integration

Create `/etc/systemd/system/mail-queue-monitor.service`:

```ini
[Unit]
Description=Mail Queue Monitor
After=docker.service
Requires=docker.service

[Service]
Type=forking
ExecStart=/path/to/scripts/mail-queue-monitor.sh daemon
ExecStop=/bin/kill -TERM $MAINPID
PIDFile=/var/run/mail-queue-monitor.pid
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
systemctl daemon-reload
systemctl enable mail-queue-monitor
systemctl start mail-queue-monitor
systemctl status mail-queue-monitor
```

### Data Structures

```bash
# Associative array for queue statistics
declare -A queue_stats=(
    [total]=0
    [active]=0
    [deferred]=0
    [hold]=0
    [size_bytes]=0
    [oldest_hours]=0
)

# Associative array for bounce reasons
declare -A bounce_reasons=(
    [spam_block_4_7_x]=0
    [connection_timeout_4_4_2]=0
    [mailbox_full_4_2_2]=0
    [user_unknown_5_1_1]=0
    [other]=0
)
```

### JSON Output Format

```json
{
    "timestamp": "2025-11-30T14:30:52+00:00",
    "hostname": "mail.example.com",
    "script": "mail-queue-monitor.sh",
    "queue": {
        "total": 15,
        "active": 2,
        "deferred": 10,
        "hold": 3,
        "size_mb": 25.34,
        "oldest_hours": 12
    },
    "thresholds": {
        "warning": 50,
        "critical": 200,
        "deferred_warning": 25
    },
    "status": "ok"
}
```

### Alert Webhook Payload

```json
{
    "severity": "WARNING",
    "message": "Queue size 75 exceeds warning threshold 50",
    "timestamp": "2025-11-30T14:30:52+00:00",
    "hostname": "mail.example.com",
    "queue_stats": {
        "total": 75,
        "active": 5,
        "deferred": 68,
        "hold": 2
    }
}
```

---

## user-management.sh

### Purpose

Comprehensive management tool for virtual domains, users, and email aliases with a Git-style subcommand architecture.

### Location

`scripts/user-management.sh` (450 lines)

### Features

1. **Git-Style Commands**: Intuitive subcommand structure (domain add, user list, etc.)
2. **Input Validation**: Email regex, domain existence checks
3. **Password Security**: Bcrypt hashing via doveadm pw
4. **Maildir Management**: Automatic creation with correct permissions
5. **MySQL Transactions**: Proper error handling
6. **Interactive Prompts**: Password confirmation, deletion confirmations

### Configuration

```bash
MYSQL_HOST=mysql
MYSQL_DATABASE=mailserver
MYSQL_USER=mailuser
MYSQL_PASSWORD=<from .env>
MAILDIR_BASE=/var/mail/vhosts
MAIL_UID=5000
MAIL_GID=5000
DEFAULT_QUOTA_MB=1024
```

### Usage Examples

#### Domain Management

```bash
# Add a domain
./scripts/user-management.sh domain add example.com
# [SUCCESS] Domain added: example.com

# List all domains
./scripts/user-management.sh domain list
# ID    | Domain                         | Users      | Created
# ------|--------------------------------|------------|---------------------
# 1     | example.com                    | 5          | 2025-11-30 10:00:00
# 2     | test.com                       | 2          | 2025-11-30 11:00:00

# Delete a domain (with confirmation)
./scripts/user-management.sh domain delete example.com
# [WARNING] Deleting domain: example.com (this will delete all users)
# Are you sure? (yes/no): yes
# [SUCCESS] Domain deleted: example.com
```

#### User Management

```bash
# Add user with default quota (1024 MB)
./scripts/user-management.sh user add john@example.com
# Enter password: ****
# Confirm password: ****
# [SUCCESS] User added: john@example.com

# Add user with custom quota
./scripts/user-management.sh user add jane@example.com --quota 2048
# [SUCCESS] User added: jane@example.com (quota: 2048MB)

# List all users
./scripts/user-management.sh user list
# Email                          | Quota (MB) | Enabled    | Created
# -------------------------------|------------|------------|---------------------
# john@example.com               | 1024       | Yes        | 2025-11-30 12:00:00
# jane@example.com               | 2048       | Yes        | 2025-11-30 12:05:00

# List users for specific domain
./scripts/user-management.sh user list example.com

# Change password
./scripts/user-management.sh user set-password john@example.com
# Enter new password: ****
# Confirm password: ****
# [SUCCESS] Password updated for: john@example.com

# Delete user (with confirmation)
./scripts/user-management.sh user delete john@example.com
# [WARNING] Deleting user: john@example.com
# Are you sure? (yes/no): yes
# [SUCCESS] User deleted: john@example.com
```

#### Alias Management

```bash
# Create alias (forward)
./scripts/user-management.sh alias add info@example.com john@example.com
# [SUCCESS] Alias added: info@example.com -> john@example.com

# Create multiple aliases for same destination
./scripts/user-management.sh alias add sales@example.com john@example.com
./scripts/user-management.sh alias add support@example.com john@example.com

# List all aliases
./scripts/user-management.sh alias list
# Source                         | Destination
# -------------------------------|--------------------------------
# info@example.com               | john@example.com
# sales@example.com              | john@example.com
# support@example.com            | john@example.com

# List aliases for specific domain
./scripts/user-management.sh alias list example.com

# Delete alias
./scripts/user-management.sh alias delete info@example.com john@example.com
# [SUCCESS] Alias deleted: info@example.com -> john@example.com
```

### Input Validation

```bash
# Email validation regex
validate_email() {
    local email="$1"
    local regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    [[ "$email" =~ $regex ]]
}

# Examples:
validate_email "john@example.com"         # Valid
validate_email "jane.doe+tag@test.co.uk"  # Valid
validate_email "invalid@"                 # Invalid
validate_email "@example.com"             # Invalid
```

### Password Hashing

```bash
# Generate bcrypt hash (cost=12)
password_hash=$(docker exec -i mail-dovecot doveadm pw -s BLF-CRYPT -p "mypassword")
# Output: {BLF-CRYPT}$2y$12$abcdefghijklmnopqrstuvwxyz...

# The hash is stored directly in MySQL
mysql_exec "UPDATE virtual_users SET password='$password_hash' WHERE email='john@example.com'"
```

### Maildir Creation

```bash
# Maildir structure created:
/var/mail/vhosts/example.com/john/
├── cur/    # Current messages (read)
├── new/    # New messages (unread)
└── tmp/    # Temporary (during delivery)

# Permissions: 700 (vmail:vmail, UID:GID 5000:5000)
```

---

## backup.sh

### Purpose

Comprehensive backup system with incremental support, retention policies, verification, and optional remote sync.

### Location

`scripts/backup.sh` (336 lines)

### Features

1. **Multiple Backup Types**: Full, incremental, MySQL-only
2. **Compression**: gzip for space efficiency
3. **Verification**: SHA256 checksum validation
4. **Retention Policy**: Age-based + keep last N full backups
5. **Remote Sync**: Rsync to remote destination
6. **JSON Manifest**: Detailed backup metadata
7. **Transaction Safety**: MySQL single-transaction dump

### Configuration

```bash
BACKUP_DIR=/backups
MAILDIR_BASE=/var/mail/vhosts
CONFIG_DIRS="/etc/postfix /etc/dovecot"
RETENTION_DAYS=30
KEEP_LAST_FULL=3
COMPRESSION=gzip
MYSQL_HOST=mysql
MYSQL_DATABASE=mailserver
MYSQL_USER=root
MYSQL_PASSWORD=<from .env>
REMOTE_SYNC=false
REMOTE_DEST=user@backup-server:/backups/mail
```

### Usage Examples

#### Full Backup

```bash
./scripts/backup.sh --type full

# Output:
# [INFO] === Mail Server Backup ===
# [INFO] Type: full
# [INFO] Timestamp: 20251130_143052
# [INFO] Backing up MySQL database...
# [SUCCESS] MySQL backup completed: mysql_20251130_143052.sql.gz
# [INFO] Backing up mailboxes (full)...
# [SUCCESS] Maildir backup completed: maildirs_full_20251130_143052.tar.gz
# [INFO] Backing up configurations...
# [SUCCESS] Config backup completed: configs_20251130_143052.tar.gz
# [INFO] Verifying backup: mysql_20251130_143052.sql.gz
# [SUCCESS] Backup verified (SHA256: a1b2c3d4...)
# [SUCCESS] Manifest generated: backup_manifest_20251130.json
# [INFO] Cleaning up old backups (retention: 30 days)...
# [SUCCESS] Cleanup completed: 3 files deleted
# [SUCCESS] === Backup Complete ===
```

#### Incremental Backup

```bash
# First run: Full backup (creates snapshot file)
./scripts/backup.sh --type full

# Subsequent runs: Incremental backup (only changed files)
./scripts/backup.sh --type incremental

# Incremental backup uses GNU tar --listed-incremental
# Creates: maildirs_incremental_20251130_143052.tar.gz
```

#### MySQL Only

```bash
./scripts/backup.sh --mysql-only

# Creates only:
# - mysql_20251130_143052.sql.gz
```

#### Backup with Remote Sync

```bash
./scripts/backup.sh --type full --sync

# After local backup completes:
# [INFO] Syncing to remote: user@backup-server:/backups/mail
# [SUCCESS] Remote sync completed
```

### Backup Verification

```bash
# Automatic verification after each backup:
verify_backup() {
    local backup_file="$1"

    # Test gzip integrity
    gzip -t "$backup_file"

    # Calculate SHA256 checksum
    sha256sum "$backup_file" | awk '{print $1}'
}
```

### Retention Policy

```bash
# Two-tier retention:

# 1. Delete backups older than RETENTION_DAYS
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete

# 2. Keep last KEEP_LAST_FULL full backups regardless of age
find "$BACKUP_DIR" -name "maildirs_full_*.tar.gz" | sort -r | tail -n +4 | xargs rm -f
```

### JSON Manifest

```json
{
    "timestamp": "2025-11-30T14:30:52+00:00",
    "hostname": "mail.example.com",
    "retention_days": 30,
    "backups": [
        {
            "filename": "mysql_20251130_143052.sql.gz",
            "size_bytes": 1234567,
            "size_mb": 1.18,
            "checksum": "a1b2c3d4e5f6...",
            "type": "mysql"
        },
        {
            "filename": "maildirs_full_20251130_143052.tar.gz",
            "size_bytes": 52428800,
            "size_mb": 50.00,
            "checksum": "f6e5d4c3b2a1...",
            "type": "maildirs"
        }
    ],
    "summary": {
        "total_backups": 3,
        "total_size_mb": 52.36
    }
}
```

### Restore Procedure

```bash
# 1. Stop services
docker compose down

# 2. Restore MySQL
gunzip < /backups/mysql_20251130_143052.sql.gz | \
    docker exec -i mail-mysql mysql -u root -p mailserver

# 3. Restore Maildir
tar -xzf /backups/maildirs_full_20251130_143052.tar.gz -C /

# 4. Restore Configuration
tar -xzf /backups/configs_20251130_143052.tar.gz -C /

# 5. Restart services
docker compose up -d
```

### Cron Schedule

```cron
# Daily incremental at 2 AM
0 2 * * * /path/to/scripts/backup.sh --type incremental >> /var/log/backup.log 2>&1

# Weekly full backup on Sunday at 3 AM
0 3 * * 0 /path/to/scripts/backup.sh --type full --sync >> /var/log/backup.log 2>&1

# MySQL-only every 6 hours
0 */6 * * * /path/to/scripts/backup.sh --mysql-only >> /var/log/backup.log 2>&1
```

---

## spam-report.sh

### Purpose

Parse SpamAssassin logs to generate statistics, identify top spammers, and create ASCII bar chart visualizations.

### Location

`scripts/spam-report.sh` (320 lines)

### Features

1. **Log Parsing**: Extract spam scores from mail logs
2. **Score Distribution**: Categorize into buckets (0-1, 1-2, 2-5, 5-10, 10+)
3. **Top Spammers**: Identify highest-volume spam senders
4. **ASCII Visualization**: Unicode bar charts
5. **Detection Rate**: Calculate spam vs. ham percentages
6. **JSON Reports**: Machine-readable output
7. **Configurable Periods**: Today, week, custom

### Configuration

```bash
MAIL_LOG=/var/log/mail/mail.log
REPORT_DIR=/var/reports
SPAM_THRESHOLD=5.0
TOP_N=10
```

### Usage Examples

#### Today's Report

```bash
./scripts/spam-report.sh --period today

# Output:
# [INFO] === SpamAssassin Report Generator ===
# [INFO] Period: today
# [INFO] Parsing SpamAssassin logs (today)...
# [SUCCESS] Parsed 1000 messages
# [INFO] Statistics:
# [INFO]   Total messages: 1000
# [INFO]   Spam detected: 150 (15.00%)
# [INFO]   Ham (legitimate): 850
#
# ╔══════════════════════════════════════════════╗
# ║       SpamAssassin Statistics Summary        ║
# ╠══════════════════════════════════════════════╣
# ║  Total Messages:                       1000  ║
# ║  Spam Detected:              150 (15.00%)    ║
# ║  Ham (Legitimate):                      850  ║
# ║  Detection Threshold:                   5.0  ║
# ╚══════════════════════════════════════════════╝
#
# === Score Distribution ===
#
#    0-1 │████████████████████████████████████████████████ 650
#    1-2 │████████████████████████ 200
#    2-5 │████████ 75
#   5-10 │██████ 50
#    10+ │████ 25
#
# [INFO] Top 10 spammers:
# [INFO]   spam@malicious.com: 45 messages
# [INFO]   bot@spam.net: 32 messages
# [INFO]   phish@scam.org: 18 messages
# [SUCCESS] JSON report generated: /var/reports/spam-report-20251130_143052.json
# [SUCCESS] === Report Complete ===
```

#### Last 7 Days

```bash
./scripts/spam-report.sh --period week
```

#### JSON Only

```bash
./scripts/spam-report.sh --json

# Outputs only JSON to stdout (no visual report)
```

### Data Structures

```bash
# Associative array for score buckets
declare -A score_buckets=(
    [0-1]=0
    [1-2]=0
    [2-5]=0
    [5-10]=0
    [10+]=0
)

# Associative array for top spammers
declare -A top_spammers=()
# Example: top_spammers["spam@example.com"]=45
```

### Score Categorization

```bash
categorize_score() {
    local score="$1"

    if (( $(echo "$score < 1" | bc -l) )); then
        ((score_buckets[0-1]++))
    elif (( $(echo "$score < 2" | bc -l) )); then
        ((score_buckets[1-2]++))
    elif (( $(echo "$score < 5" | bc -l) )); then
        ((score_buckets[2-5]++))
    elif (( $(echo "$score < 10" | bc -l) )); then
        ((score_buckets[5-10]++))
    else
        ((score_buckets[10+]++))
    fi
}
```

### ASCII Bar Chart

```bash
draw_bar_chart() {
    local title="$1"
    local max_width=50

    # Find max value for scaling
    local max_value=0
    for bucket in "${!score_buckets[@]}"; do
        if ((score_buckets[$bucket] > max_value)); then
            max_value=${score_buckets[$bucket]}
        fi
    done

    # Draw bars using Unicode block character (█)
    for bucket in "0-1" "1-2" "2-5" "5-10" "10+"; do
        local count=${score_buckets[$bucket]}
        local bar_length=$((count * max_width / max_value))

        printf "%6s │" "$bucket"
        printf "%${bar_length}s" "" | tr ' ' '█'
        printf " %d\n" "$count"
    done
}
```

### JSON Report Format

```json
{
    "timestamp": "2025-11-30T14:30:52+00:00",
    "hostname": "mail.example.com",
    "period": "24h",
    "summary": {
        "total_messages": 1000,
        "spam_detected": 150,
        "ham_detected": 850,
        "spam_rate": 15.00,
        "threshold": 5.0
    },
    "score_distribution": {
        "0-1": 650,
        "1-2": 200,
        "2-5": 75,
        "5-10": 50,
        "10+": 25
    },
    "top_spammers": [
        {"sender": "spam@malicious.com", "count": 45},
        {"sender": "bot@spam.net", "count": 32},
        {"sender": "phish@scam.org", "count": 18}
    ]
}
```

---

## generate-ssl.sh

### Purpose

Generate self-signed SSL certificates for mail server with proper SAN (Subject Alternative Names) configuration.

### Location

`scripts/generate-ssl.sh` (222 lines)

### Features

1. **CA Generation**: Create Certificate Authority
2. **Server Certificates**: With SAN for multiple hostnames
3. **Dovecot Combined**: Certificate + key in single file
4. **Idempotent**: Skip if certificates already exist
5. **Validation**: Verify certificates with openssl
6. **Configurable**: Hostname, validity period, key size

### Configuration

```bash
MAIL_HOSTNAME=mail.example.com
SSL_DAYS_VALID=3650  # 10 years
SSL_KEY_SIZE=2048
CERT_DIR=/etc/mail/certs
```

### Usage

```bash
# Run from init container (automatic on first start)
./scripts/generate-ssl.sh

# Manual run
MAIL_HOSTNAME=mail.example.com ./scripts/generate-ssl.sh

# Output:
# [INFO] Generating SSL certificates...
# [INFO] Hostname: mail.example.com
# [INFO] Validity: 3650 days
# [SUCCESS] CA certificate generated
# [SUCCESS] Server certificate generated
# [SUCCESS] Certificate verified successfully
```

### Generated Files

```
/etc/mail/certs/
├── ca.crt              # Certificate Authority certificate
├── ca.key              # CA private key
├── server.crt          # Server certificate
├── server.key          # Server private key
├── server.csr          # Certificate signing request
└── dovecot-combined.pem # Combined cert+key for Dovecot
```

### Certificate Details

```bash
# View certificate
openssl x509 -in /etc/mail/certs/server.crt -text -noout

# Key fields:
# - Subject: CN=mail.example.com
# - SAN: DNS:mail.example.com, DNS:localhost, IP:127.0.0.1
# - Validity: 3650 days (10 years)
# - Key Size: 2048 bits RSA
```

### Production Certificates

For production, replace with Let's Encrypt:

```bash
# Install certbot
apt install certbot

# Generate certificate
certbot certonly --standalone \
    -d mail.example.com \
    --agree-tos \
    --email admin@example.com

# Certificates in: /etc/letsencrypt/live/mail.example.com/
# - fullchain.pem (certificate + intermediate)
# - privkey.pem (private key)

# Update docker-compose.yml volumes:
volumes:
  - /etc/letsencrypt/live/mail.example.com:/etc/mail/certs:ro
```

---

## test-mail-flow.sh

### Purpose

End-to-end mail flow testing including SMTP sending, IMAP retrieval, authentication, and spam filtering.

### Location

`scripts/test-mail-flow.sh` (383 lines)

### Features

1. **SMTP Protocol**: Manual EHLO, AUTH, MAIL FROM, RCPT TO, DATA
2. **IMAP Protocol**: LOGIN, SELECT, SEARCH, FETCH
3. **Authentication Testing**: Valid and invalid credentials
4. **STARTTLS Detection**: Check TLS support
5. **Spam Filter Testing**: Send spam-like message
6. **Message Verification**: Check Message-ID
7. **Queue Monitoring**: Verify delivery completion

### Configuration

```bash
SMTP_HOST=localhost
SMTP_PORT=587
IMAP_HOST=localhost
IMAP_PORT=143
TEST_FROM=john@example.com
TEST_TO=jane@example.com
TEST_PASSWORD=password
```

### Usage

```bash
# Run with default test accounts
./scripts/test-mail-flow.sh

# Specify sender and recipient
./scripts/test-mail-flow.sh john@example.com jane@example.com

# Output:
# [INFO] === Mail Flow Test Suite ===
# [INFO] From: john@example.com
# [INFO] To: jane@example.com
#
# [INFO] Connecting to SMTP server...
# [SUCCESS] SMTP server responded: 220 mail.example.com ESMTP Postfix
# [INFO] Connecting to IMAP server...
# [SUCCESS] IMAP server responded: * OK [CAPABILITY IMAP4rev1...] Dovecot ready
#
# [INFO] Testing authentication with wrong password...
# [SUCCESS] Authentication correctly rejected bad password
# [INFO] Testing authentication with correct password...
# [SUCCESS] Authentication successful
#
# [INFO] Testing STARTTLS support...
# [SUCCESS] STARTTLS is advertised
#
# [INFO] Sending test email...
# [SUCCESS] Message accepted by SMTP server
#
# [INFO] Checking mail queue status...
# [SUCCESS] Mail queue is empty (all delivered)
#
# [INFO] Waiting 5 seconds for mail delivery...
# [INFO] Checking mailbox for: jane@example.com
# [SUCCESS] Test message found in mailbox
# [INFO] Message UID: 123
#
# [INFO] Testing spam filter...
# [SUCCESS] Spam message rejected/flagged
#
# [SUCCESS] === All Mail Flow Tests Completed ===
# [INFO] Test message was successfully:
# [INFO]   1. Authenticated via SMTP
# [INFO]   2. Accepted by Postfix
# [INFO]   3. Delivered to mailbox
# [INFO]   4. Retrieved via IMAP
# [SUCCESS] Mail server is functioning correctly!
```

### SMTP Session Example

```bash
# Base64 encode credentials for AUTH PLAIN
# Format: \0username\0password
auth_plain=$(printf '\0john\0password' | base64 -w0)

# Send SMTP commands via netcat
cat << EOF | nc localhost 587
EHLO test-client
AUTH PLAIN $auth_plain
MAIL FROM:<john@example.com>
RCPT TO:<jane@example.com>
DATA
From: john@example.com
To: jane@example.com
Subject: Test Message
Message-ID: <test-123@example.com>
Date: $(date -R)

This is a test message.
.
QUIT
EOF
```

### IMAP Session Example

```bash
# Login and search for message
cat << EOF | nc localhost 143
a1 LOGIN jane@example.com password
a2 SELECT INBOX
a3 SEARCH SUBJECT "Test Message"
a4 FETCH 1 BODY[HEADER]
a5 LOGOUT
EOF

# Response:
# * OK [CAPABILITY...] Dovecot ready
# a1 OK [CAPABILITY...] Logged in
# * FLAGS (\Answered \Flagged \Deleted \Seen \Draft)
# * 5 EXISTS
# * 1 RECENT
# a2 OK [READ-WRITE] Select completed
# * SEARCH 5
# a3 OK Search completed
# * 5 FETCH (BODY[HEADER] {123}
# From: john@example.com
# To: jane@example.com
# Subject: Test Message
# ...
# )
# a4 OK Fetch completed
# * BYE Logging out
# a5 OK Logout completed
```

---

## Best Practices

### 1. Error Handling

**Always use:**
```bash
set -euo pipefail

# -e: Exit on error
# -u: Treat unset variables as errors
# -o pipefail: Pipe failures propagate
```

**Handle errors explicitly:**
```bash
if ! mysql_query "SELECT 1"; then
    log_error "MySQL query failed"
    return 1
fi

# Or with || operator
mysql_query "SELECT 1" || {
    log_error "MySQL query failed"
    return 1
}
```

### 2. Variable Quoting

**Always quote variables:**
```bash
# Correct
rm -f "$backup_file"
if [[ -f "$config_file" ]]; then

# Incorrect (will fail with spaces in paths)
rm -f $backup_file
if [[ -f $config_file ]]; then
```

### 3. Command Substitution

**Prefer $() over backticks:**
```bash
# Modern (recommended)
timestamp=$(date +%s)

# Legacy (avoid)
timestamp=`date +%s`
```

### 4. Testing

**Use test framework:**
```bash
# Function to test
add() {
    echo $(($1 + $2))
}

# Test cases
test_add() {
    local result
    result=$(add 2 3)
    [[ "$result" -eq 5 ]] || echo "FAIL: Expected 5, got $result"
}

test_add
```

### 5. Logging

**Structured logging:**
```bash
log_info "Starting process..."
log_success "Process completed"
log_warning "Configuration issue detected"
log_error "Fatal error occurred"
```

### 6. Configuration

**Environment variables with defaults:**
```bash
readonly CONFIG_VAR="${CONFIG_VAR:-default_value}"
readonly REQUIRED_VAR="${REQUIRED_VAR:?ERROR: REQUIRED_VAR must be set}"
```

### 7. Documentation

**Comprehensive headers:**
```bash
#!/bin/bash
#===============================================================================
# Script Name - Brief Description
#
# Purpose:
#   Detailed explanation of what the script does
#
# Usage:
#   ./script.sh [options] <arguments>
#
# Skills Demonstrated:
#   - Bullet list of techniques used
#
# Author: Your Name
# License: MIT
#===============================================================================
```

### 8. Shellcheck

**Always validate:**
```bash
shellcheck scripts/*.sh

# Disable specific warnings with justification
# shellcheck disable=SC2086
# Reason: Word splitting is intentional here
```

---

**Document Version**: 1.0
**Last Updated**: 2025-11-30
**Total Script Lines**: 2,318 lines (production + tests)
