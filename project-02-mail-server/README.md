# Project 02: Production Mail Server Stack

## Overview | Áttekintés

**English:**
A fully containerized, production-ready mail server stack featuring Postfix, Dovecot, SpamAssassin, and Roundcube webmail. Includes comprehensive automation scripts (1,566 lines), interactive monitoring dashboard, SSL/TLS encryption, MySQL-backed virtual users, and complete test suite.

**Magyar:**
Teljesen konténerizált, produkció-kész levelezőszerver stack Postfix, Dovecot, SpamAssassin és Roundcube webmail komponensekkel. Tartalmaz átfogó automatizálási szkripteket (1,566 sor), interaktív monitoring dashboardot, SSL/TLS titkosítást, MySQL-alapú virtuális felhasználókat és teljes tesztcsomagot.

---

## 🎯 Key Features | Főbb Jellemzők

- **Full Mail Stack**: Postfix (SMTP), Dovecot (IMAP/POP3), SpamAssassin, Roundcube
- **Virtual Users**: MySQL-backed authentication with bcrypt password hashing
- **SSL/TLS**: Self-signed certificates with automatic generation
- **Spam Filtering**: SpamAssassin with Bayes learning and custom rules
- **Management Scripts**: 1,566 lines of production Bash automation
  - Mail queue monitoring with daemon mode
  - User/domain management with Git-style subcommands
  - Automated backup system with retention policies
  - Spam statistics and ASCII visualization
- **Web Dashboard**: Real-time PHP monitoring interface with service health, queue stats, mailbox usage
- **Comprehensive Testing**: 937 lines of test automation (e2e tests + mail flow validation)

---

## 📐 Architecture | Architektúra

```
┌─────────────────────────────────────────────────────────────┐
│                     Frontend Network                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │Roundcube │  │Dashboard │  │ Postfix  │  │ Dovecot  │   │
│  │  :8025   │  │  :8080   │  │ :25/587  │  │ :143/993 │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│              Backend Network (Internal Only)                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │    MySQL     │  │ SpamAssassin │  │  SSL Certs   │     │
│  │    :3306     │  │    :783      │  │   (Volume)   │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘

Volumes: mysql-data, ssl-certs, mailboxes, queue, logs, reports, backups
```

**Components:**
- **Postfix**: SMTP server with virtual mailbox support, SASL auth, TLS
- **Dovecot**: IMAP/POP3 server with MySQL auth, quota enforcement
- **SpamAssassin**: Spam filter with milter integration
- **MySQL**: Virtual user database (domains, users, aliases, quotas)
- **Roundcube**: Modern webmail interface
- **Dashboard**: Custom PHP monitoring interface
- **Init Container**: One-time SSL certificate generation

---

## 📊 Project Statistics | Projekt Statisztikák

| Metric | Value |
|--------|-------|
| **Total Files** | 48 files |
| **Bash Scripts** | 7 scripts (1,566 lines) |
| **Test Scripts** | 2 scripts (937 lines) |
| **PHP Dashboard** | 337 lines |
| **CSS/JS** | 642 lines |
| **Docker Services** | 7 services |
| **Configuration Files** | 32 files |
| **Total Lines of Code** | ~4,500+ lines |

**Primary Showcase Script:**
`scripts/mail-queue-monitor.sh` (460 lines) - Daemon mode with signal handling, PID management, queue analysis, threshold-based alerting, and JSON reporting.

---

## 🚀 Quick Start | Gyors Indítás

### Prerequisites | Előfeltételek

- Docker 20.10+
- Docker Compose 2.0+
- 4GB RAM minimum
- Linux/macOS (tested on Debian/Ubuntu)

### Installation | Telepítés

```bash
# Clone repository
git clone <repository-url>
cd project-02-mail-server

# Copy and configure environment
cp .env.example .env
nano .env  # Edit configuration

# Start all services
docker compose up -d

# Wait for initialization (SSL certs, database)
docker compose logs -f cert-init
docker compose logs -f mysql

# Check service health
docker compose ps
```

### Initial Setup | Kezdeti Beállítás

```bash
# Add a domain
./scripts/user-management.sh domain add example.com

# Create a mailbox
./scripts/user-management.sh user add john@example.com

# Set password when prompted
# Default quota: 1024 MB

# Create an alias
./scripts/user-management.sh alias add info@example.com john@example.com

# List all users
./scripts/user-management.sh user list
```

---

## 🔧 Configuration | Konfiguráció

### Environment Variables | Környezeti Változók

Key settings in `.env`:

```bash
# Project
PROJECT_NAME=mailserver
MAIL_HOSTNAME=mail.example.com
MAIL_DOMAIN=example.com

# MySQL
MYSQL_ROOT_PASSWORD=your_secure_password
MYSQL_PASSWORD=your_mailuser_password

# Ports
SMTP_PORT=25
SUBMISSION_PORT=587
IMAP_PORT=143
IMAPS_PORT=993
WEBMAIL_PORT=8025
DASHBOARD_PORT=8080

# SSL
SSL_DAYS_VALID=3650

# Backup
RETENTION_DAYS=30
BACKUP_DIR=/backups
```

### SSL Certificates | SSL Tanúsítványok

Self-signed certificates are generated automatically on first start:
- **CA Certificate**: `/etc/mail/certs/ca.crt`
- **Server Certificate**: `/etc/mail/certs/server.crt`
- **Server Key**: `/etc/mail/certs/server.key`

For production, replace with valid certificates from Let's Encrypt or commercial CA.

---

## 📝 Scripts Documentation | Szkriptek Dokumentációja

### 1. mail-queue-monitor.sh (460 lines) ⭐ PRIMARY SHOWCASE

**Purpose:** Real-time mail queue monitoring with daemon mode support.

**Features:**
- Daemon mode with signal handling (SIGTERM, SIGINT, SIGHUP)
- PID file management to prevent multiple instances
- Queue statistics (total, active, deferred, hold)
- Bounce reason categorization with associative arrays
- Threshold-based alerting (warning/critical)
- Webhook and email notifications
- JSON report generation
- Alert cooldown mechanism

**Usage:**
```bash
# One-shot mode
./scripts/mail-queue-monitor.sh

# Daemon mode (background)
./scripts/mail-queue-monitor.sh daemon

# Check daemon status
./scripts/mail-queue-monitor.sh status

# Stop daemon
kill $(cat /var/run/mail-queue-monitor.pid)
```

**Configuration:**
```bash
QUEUE_WARNING=50           # Warning threshold
QUEUE_CRITICAL=200         # Critical threshold
CHECK_INTERVAL=60          # Check every 60 seconds
ALERT_WEBHOOK=<url>        # Optional webhook URL
```

---

### 2. user-management.sh (450 lines)

**Purpose:** Manage virtual domains, mailboxes, and aliases.

**Features:**
- Git-style subcommand architecture
- MySQL CLI interaction with prepared statements
- Email validation with regex
- Bcrypt password hashing via doveadm
- Maildir creation with proper permissions
- Interactive confirmation for destructive operations

**Usage:**
```bash
# Domain management
./scripts/user-management.sh domain add example.com
./scripts/user-management.sh domain list
./scripts/user-management.sh domain delete example.com

# User management
./scripts/user-management.sh user add john@example.com
./scripts/user-management.sh user add jane@example.com --quota 2048
./scripts/user-management.sh user list [domain]
./scripts/user-management.sh user set-password john@example.com
./scripts/user-management.sh user delete john@example.com

# Alias management
./scripts/user-management.sh alias add sales@example.com john@example.com
./scripts/user-management.sh alias list [domain]
./scripts/user-management.sh alias delete sales@example.com john@example.com
```

---

### 3. backup.sh (336 lines)

**Purpose:** Automated backup system with retention policies.

**Features:**
- MySQL dump with `--single-transaction` for InnoDB
- Maildir tar backup with gzip compression
- Incremental backup support with `--listed-incremental`
- Configuration backup (Postfix, Dovecot, SpamAssassin)
- SHA256 checksum verification
- Retention policy (days + keep last N full backups)
- Remote sync with rsync
- JSON manifest generation

**Usage:**
```bash
# Full backup (default)
./scripts/backup.sh --type full

# Incremental backup
./scripts/backup.sh --type incremental

# MySQL only
./scripts/backup.sh --mysql-only

# Full backup with remote sync
./scripts/backup.sh --type full --sync
```

**Configuration:**
```bash
BACKUP_DIR=/backups
RETENTION_DAYS=30          # Delete backups older than 30 days
KEEP_LAST_FULL=3           # Keep last 3 full backups regardless
REMOTE_SYNC=true           # Enable remote sync
REMOTE_DEST=user@host:/path
```

---

### 4. spam-report.sh (320 lines)

**Purpose:** SpamAssassin statistics and visualization.

**Features:**
- Log parsing for SpamAssassin entries
- Score distribution with associative arrays (0-1, 1-2, 2-5, 5-10, 10+)
- Top spammer identification by sender
- ASCII bar chart visualization with Unicode blocks
- Detection rate calculation
- JSON report with timestamp
- Configurable spam threshold

**Usage:**
```bash
# Today's statistics
./scripts/spam-report.sh --period today

# Last 7 days
./scripts/spam-report.sh --period week

# JSON output only
./scripts/spam-report.sh --json
```

**Output Example:**
```
=== Score Distribution ===

   0-1 │████████████████████████████ 142
   1-2 │█████████████████ 85
   2-5 │██████████ 48
  5-10 │████ 18
   10+ │█ 7
```

---

### 5. test-mail-flow.sh (383 lines)

**Purpose:** End-to-end mail flow testing.

**Features:**
- SMTP protocol interaction (EHLO, AUTH, MAIL FROM, RCPT TO, DATA)
- IMAP retrieval verification
- Authentication testing (success/failure)
- STARTTLS detection
- Spam filter validation
- Message integrity checking
- Queue status monitoring

**Usage:**
```bash
# Test with default accounts
./scripts/test-mail-flow.sh

# Specify sender/receiver
./scripts/test-mail-flow.sh john@example.com jane@example.com
```

---

## 🌐 Web Interfaces | Web Felületek

### Dashboard (Port 8080)

**Access:** http://localhost:8080

**Features:**
- Service health status (MySQL, Postfix, Dovecot, SpamAssassin)
- Mail queue statistics (real-time)
- Spam detection summary
- Domain overview
- Top 10 mailbox usage with progress bars
- Recent mail logs viewer
- Auto-refresh (10 seconds)
- Keyboard shortcuts (R: refresh, T: toggle auto-refresh)

**Technology:**
- PHP 8.2 with MySQLi
- Nginx + PHP-FPM
- Gradient CSS design
- Vanilla JavaScript (no dependencies)

### Roundcube Webmail (Port 8025)

**Access:** http://localhost:8025

**Features:**
- Modern HTML5 interface
- IMAP folder management
- Compose/reply/forward
- Address book
- SSL/TLS encryption
- Multi-language support

**Login:**
- Username: `john@example.com`
- Password: `password` (default from init.sql)

---

## 🧪 Testing | Tesztelés

### Run E2E Test Suite

```bash
# Complete test suite (554 lines)
./tests/e2e-test.sh

# Quick mode (skip slow tests)
./tests/e2e-test.sh --quick

# Verbose output
./tests/e2e-test.sh --verbose
```

**Test Coverage:**
1. Docker environment validation
2. Container health checks
3. Network port accessibility
4. SSL certificate validation
5. MySQL schema verification
6. SMTP/IMAP protocol tests
7. Configuration validation
8. Web interface accessibility
9. Log file verification

### Run Mail Flow Test

```bash
# Send and receive test email
./scripts/test-mail-flow.sh

# Automated mode
./scripts/test-mail-flow.sh --auto
```

### Validate Scripts

```bash
# Install shellcheck
apt install shellcheck  # Debian/Ubuntu

# Validate all scripts
find scripts tests -name "*.sh" -exec shellcheck {} \;
```

---

## 📖 Detailed Documentation | Részletes Dokumentáció

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)**: System architecture, network topology, data flow
- **[SCRIPTS.md](docs/SCRIPTS.md)**: In-depth script documentation with examples
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**: Common issues and solutions

---

## 🔍 Skills Demonstrated | Bemutatott Készségek

### Linux System Administration
- Service configuration (Postfix, Dovecot, MySQL)
- Log analysis and monitoring
- Process management (daemon mode, PID files, signal handling)
- Filesystem operations (maildir structure, permissions)
- Network troubleshooting (port testing, protocol debugging)

### Bash Scripting (1,566 lines)
- Advanced error handling (`set -euo pipefail`)
- Associative arrays for data structures
- Process substitution and background jobs
- Signal trapping (SIGTERM, SIGINT, SIGHUP)
- Heredocs for JSON/SQL generation
- Structured logging with colors
- Argument parsing and validation

### Docker & Containerization
- Multi-container orchestration with dependencies
- Health check definitions
- Volume management (persistent data)
- Network isolation (internal backend)
- Environment variable configuration
- Entrypoint scripts with templating

### Protocols & Security
- SMTP (RFC 5321), IMAP (RFC 3501), POP3
- SASL authentication (PLAIN)
- TLS/SSL certificate management
- SPF, DKIM considerations (ready for implementation)
- Password hashing (bcrypt)
- SQL injection prevention

### Database Management
- MySQL schema design (virtual users)
- Foreign key relationships
- SQL queries via CLI
- Transaction handling
- User permission management

### Web Development
- PHP 8.2 (PDO, prepared statements)
- Nginx + PHP-FPM configuration
- Responsive CSS (Flexbox, Grid)
- Vanilla JavaScript (no frameworks)
- Auto-refresh mechanisms

### Testing & Quality Assurance
- End-to-end test automation
- Protocol-level testing
- Health check validation
- Shellcheck compliance
- Integration testing

---

## 📂 Project Structure | Projekt Struktúra

```
project-02-mail-server/
├── docker-compose.yml           # 7 services orchestration
├── .env.example                 # Configuration template
├── .gitignore
│
├── init/                        # SSL certificate generation
│   └── Dockerfile
│
├── mysql/                       # Database initialization
│   └── init.sql                 # Virtual user schema
│
├── postfix/                     # SMTP server
│   ├── Dockerfile
│   ├── main.cf.template
│   ├── master.cf
│   ├── mysql-virtual-*.cf       # Virtual mailbox queries
│   └── entrypoint.sh
│
├── dovecot/                     # IMAP/POP3 server
│   ├── Dockerfile
│   ├── dovecot.conf.template
│   ├── dovecot-sql.conf.ext.template
│   ├── 10-*.conf                # Protocol configs
│   └── entrypoint.sh
│
├── spamassassin/                # Spam filter
│   ├── Dockerfile
│   └── local.cf                 # Scoring rules
│
├── dashboard/                   # Monitoring interface
│   ├── Dockerfile
│   ├── index.php                # 337 lines
│   ├── style.css                # 371 lines
│   ├── script.js                # 271 lines
│   ├── nginx.conf
│   ├── default.conf
│   └── supervisord.conf
│
├── scripts/                     # Automation scripts (1,566 lines)
│   ├── lib/
│   │   └── common.sh            # Shared library (147 lines)
│   ├── mail-queue-monitor.sh    # PRIMARY SHOWCASE (460 lines)
│   ├── user-management.sh       # User admin (450 lines)
│   ├── backup.sh                # Backup system (336 lines)
│   ├── spam-report.sh           # Spam stats (320 lines)
│   ├── generate-ssl.sh          # SSL certs (222 lines)
│   └── test-mail-flow.sh        # Mail flow test (383 lines)
│
├── tests/                       # Test automation
│   └── e2e-test.sh              # E2E tests (554 lines)
│
├── docs/                        # Documentation
│   ├── ARCHITECTURE.md
│   ├── SCRIPTS.md
│   └── TROUBLESHOOTING.md
│
└── README.md                    # This file
```

---

## 🐛 Troubleshooting | Hibaelhárítás

### Services Not Starting

```bash
# Check logs
docker compose logs -f [service]

# Restart specific service
docker compose restart postfix

# Rebuild and restart
docker compose up -d --force-recreate postfix
```

### Cannot Send/Receive Mail

```bash
# Check Postfix queue
docker exec mail-postfix mailq

# Check Postfix logs
docker exec mail-postfix tail -f /var/log/mail/mail.log

# Test SMTP manually
telnet localhost 25
> EHLO test
> QUIT

# Test IMAP manually
telnet localhost 143
> a1 CAPABILITY
> a2 LOGOUT
```

### MySQL Connection Issues

```bash
# Check MySQL status
docker compose ps mysql

# Test connection
docker exec mail-mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW DATABASES;"

# Check users
docker exec mail-mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} mailserver -e "SELECT email FROM virtual_users;"
```

### Dashboard Not Loading

```bash
# Check PHP-FPM logs
docker compose logs dashboard

# Verify MySQL connection
docker exec mail-dashboard php -r "new PDO('mysql:host=mysql', 'mailreader', 'password');"

# Check report files
docker exec mail-dashboard ls -la /var/reports/
```

---

## 🔒 Security Considerations | Biztonsági Megfontolások

**Current Implementation (Development):**
- Self-signed SSL certificates
- Default passwords in init.sql
- No fail2ban or rate limiting
- No SPF/DKIM/DMARC configured

**Production Recommendations:**
1. Replace self-signed certs with Let's Encrypt
2. Change all default passwords
3. Implement fail2ban for brute-force protection
4. Configure SPF, DKIM, and DMARC records
5. Enable firewall (ufw/iptables)
6. Regular security updates
7. Backup encryption
8. SMTP relay authentication
9. Greylisting for spam reduction
10. Regular log auditing

---

## 📈 Performance Tuning | Teljesítmény Hangolás

**Postfix:**
```conf
# /etc/postfix/main.cf
default_process_limit = 100
smtpd_client_connection_count_limit = 10
smtpd_client_connection_rate_limit = 30
```

**Dovecot:**
```conf
# /etc/dovecot/conf.d/10-master.conf
service imap-login {
  process_min_avail = 4
  process_limit = 100
}
```

**MySQL:**
```conf
# /etc/mysql/mysql.conf.d/mysqld.cnf
innodb_buffer_pool_size = 1G
max_connections = 100
```

---

## 📜 License | Licenc

MIT License - See [LICENSE](../LICENSE) file for details.

---

## 👤 Author | Szerző

**Linux System Administrator Portfolio**
Demonstrating production-ready DevOps skills

**Contact:**
- GitHub: [Your GitHub Profile]
- Email: [Your Email]

---

## 🙏 Acknowledgments | Köszönetnyilvánítás

- **Postfix**: The fast, secure mail transfer agent
- **Dovecot**: Secure IMAP and POP3 email server
- **SpamAssassin**: Mail filter to identify spam
- **Roundcube**: Modern webmail interface
- **Docker Community**: For excellent documentation

---

## 📚 References | Referenciák

- [Postfix Documentation](http://www.postfix.org/documentation.html)
- [Dovecot Wiki](https://doc.dovecot.org/)
- [SpamAssassin Documentation](https://spamassassin.apache.org/doc/)
- [RFC 5321 - SMTP](https://tools.ietf.org/html/rfc5321)
- [RFC 3501 - IMAP](https://tools.ietf.org/html/rfc3501)

---

**Last Updated:** 2025-11-30
**Project Status:** ✅ Complete - Production Ready
