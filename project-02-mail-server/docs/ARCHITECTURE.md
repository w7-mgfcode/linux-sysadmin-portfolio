# Mail Server Architecture Documentation

## Table of Contents

1. [System Overview](#system-overview)
2. [Network Topology](#network-topology)
3. [Service Architecture](#service-architecture)
4. [Data Flow](#data-flow)
5. [Database Schema](#database-schema)
6. [Security Architecture](#security-architecture)
7. [Storage and Volumes](#storage-and-volumes)
8. [Scalability Considerations](#scalability-considerations)

---

## System Overview

### High-Level Architecture

The mail server is built as a **microservices architecture** using Docker containers, with clear separation of concerns:

```
┌────────────────────────────────────────────────────────────────┐
│                        External Access                          │
│  SMTP (25/587/465) | IMAP (143/993) | HTTP (8025/8080)        │
└────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌────────────────────────────────────────────────────────────────┐
│                       Frontend Network                          │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │   Postfix   │  │   Dovecot   │  │  Roundcube  │            │
│  │   (SMTP)    │◄─┤  (IMAP/POP) │◄─┤  (Webmail)  │            │
│  └──────┬──────┘  └──────┬──────┘  └─────────────┘            │
│         │                 │                                      │
│  ┌──────▼──────┐         │         ┌─────────────┐            │
│  │ SpamAssassin│         │         │  Dashboard  │            │
│  │   (Milter)  │         │         │    (PHP)    │            │
│  └─────────────┘         │         └──────┬──────┘            │
└──────────────────────────┼────────────────┼───────────────────┘
                           │                │
                           ▼                ▼
┌────────────────────────────────────────────────────────────────┐
│                      Backend Network (Internal)                 │
│                                                                  │
│  ┌─────────────────────┐         ┌──────────────────────────┐ │
│  │       MySQL         │         │      Shared Volumes      │ │
│  │  (Virtual Users)    │         │  - SSL Certificates      │ │
│  │  - domains          │         │  - Mailboxes (Maildir)   │ │
│  │  - users            │         │  - Logs                  │ │
│  │  - aliases          │         │  - Reports               │ │
│  │  - quotas           │         │  - Backups               │ │
│  └─────────────────────┘         └──────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
```

### Design Principles

1. **Separation of Concerns**: Each service has a single responsibility
2. **Security by Default**: Internal backend network, TLS encryption
3. **Observability**: Centralized logging, JSON reports, dashboard
4. **Automation**: Scripts for all common operations
5. **Testability**: Comprehensive test suite for validation

---

## Network Topology

### Network Segmentation

The system uses **three Docker networks**:

#### 1. Frontend Network (`mail-frontend`)
- **Purpose**: User-facing services
- **Access**: External (exposed ports)
- **Services**:
  - Postfix (SMTP: 25, 587, 465)
  - Dovecot (IMAP: 143, 993; POP3: 110, 995)
  - Roundcube (HTTP: 8025)
  - Dashboard (HTTP: 8080)
- **Security**: Rate limiting, authentication required

#### 2. Backend Network (`mail-backend`)
- **Purpose**: Internal services and data storage
- **Access**: **Internal only** (`internal: true`)
- **Services**:
  - MySQL (3306)
  - SpamAssassin (783)
- **Security**: No external exposure, container-to-container only

#### 3. Mailnet Network (Optional)
- **Purpose**: Mail relay between Postfix and Dovecot
- **Access**: Internal
- **Protocol**: LMTP (Local Mail Transfer Protocol)

### Port Mapping

| Service      | Internal Port | External Port | Protocol | Description                |
|--------------|---------------|---------------|----------|----------------------------|
| Postfix      | 25            | 25            | SMTP     | Mail transfer              |
| Postfix      | 587           | 587           | SMTP     | Mail submission (STARTTLS) |
| Postfix      | 465           | 465           | SMTPS    | SMTP over SSL              |
| Dovecot      | 143           | 143           | IMAP     | Mail retrieval             |
| Dovecot      | 993           | 993           | IMAPS    | IMAP over SSL              |
| Dovecot      | 110           | 110           | POP3     | Mail retrieval (legacy)    |
| Dovecot      | 995           | 995           | POP3S    | POP3 over SSL              |
| Roundcube    | 80            | 8025          | HTTP     | Webmail interface          |
| Dashboard    | 80            | 8080          | HTTP     | Monitoring dashboard       |
| MySQL        | 3306          | -             | MySQL    | Internal only              |
| SpamAssassin | 783           | -             | Spamd    | Internal only              |

---

## Service Architecture

### 1. Postfix (SMTP Server)

**Role**: Mail Transfer Agent (MTA) for sending and receiving emails.

**Configuration Files**:
- `main.cf`: Main configuration (150+ directives)
- `master.cf`: Service definitions
- `mysql-virtual-*.cf`: MySQL query mappings

**Key Features**:
- Virtual mailbox support via MySQL
- SASL authentication (via Dovecot)
- TLS/SSL encryption
- SpamAssassin integration (milter)
- Queue management

**Data Flow**:
```
Incoming Mail → SMTP (25) → Postfix → SpamAssassin → MySQL (auth) → Dovecot (LMTP) → Maildir
Outgoing Mail → SMTP (587) → Postfix → SASL Auth → Relay → Internet
```

**Volumes**:
- `/etc/mail/certs`: SSL certificates (read-only)
- `/var/spool/postfix`: Mail queue
- `/var/mail/vhosts`: Maildir storage
- `/var/log/mail`: Logs

---

### 2. Dovecot (IMAP/POP3 Server)

**Role**: Mail Delivery Agent (MDA) for retrieving emails.

**Configuration Files**:
- `dovecot.conf`: Main configuration
- `dovecot-sql.conf.ext`: MySQL authentication
- `10-mail.conf`: Mailbox location
- `10-ssl.conf`: SSL/TLS settings
- `10-auth.conf`: Authentication mechanisms
- `10-master.conf`: Service definitions

**Key Features**:
- MySQL-backed virtual users
- Quota enforcement
- IMAP/POP3 protocols
- LMTP for local delivery
- SASL authentication for Postfix

**Authentication Flow**:
```
Client → IMAP (143) → Dovecot → MySQL Query → Bcrypt Verification → Access Granted
```

**Volumes**:
- `/etc/mail/certs`: SSL certificates (read-only)
- `/var/mail/vhosts`: Maildir storage
- `/var/log/mail`: Logs

---

### 3. SpamAssassin (Spam Filter)

**Role**: Content-based spam filter with scoring system.

**Integration**: Milter protocol with Postfix

**Configuration**:
- `local.cf`: Custom rules and scoring thresholds

**Features**:
- Bayes learning
- DNS blacklist checks (RBL)
- Content analysis
- Custom scoring rules

**Data Flow**:
```
Postfix → SpamAssassin (milter) → Score Analysis → Header Modification → Postfix
```

**Spam Scoring**:
- Score < 5.0: Ham (legitimate)
- Score ≥ 5.0: Spam (default threshold)
- Customizable per-user/domain

---

### 4. MySQL (Virtual User Database)

**Role**: Centralized authentication and configuration storage.

**Schema Design**:
```
virtual_domains (id, name, created_at)
       ↓
virtual_users (id, domain_id, email, password, quota_mb, enabled)
       ↓
virtual_aliases (id, domain_id, source, destination)
       ↓
mailbox_usage (email, usage_mb, last_updated)
```

**Authentication**:
- **Password Storage**: Bcrypt (BLF-CRYPT) via doveadm
- **User Lookup**: Postfix and Dovecot query MySQL
- **Quotas**: Per-user quota enforcement

**Users**:
- `root`: Full admin access
- `mailuser`: Read-write for Postfix/Dovecot
- `mailreader`: Read-only for Dashboard

---

### 5. Roundcube (Webmail)

**Role**: Modern web-based email client.

**Technology**:
- PHP 7.4+
- JavaScript (jQuery)
- HTML5/CSS3

**Features**:
- IMAP folder management
- Compose/reply/forward
- Address book
- Multi-language support

**Configuration**:
- IMAP Host: `ssl://dovecot:993`
- SMTP Host: `tls://postfix:587`
- Database: MySQL (own schema)

---

### 6. Dashboard (Monitoring Interface)

**Role**: Real-time monitoring and statistics.

**Technology Stack**:
- **Backend**: PHP 8.2 with PDO
- **Frontend**: Vanilla JS, CSS Grid/Flexbox
- **Web Server**: Nginx + PHP-FPM
- **Process Manager**: Supervisord

**Data Sources**:
1. MySQL queries (mailbox usage, domains, users)
2. JSON reports from scripts (queue stats, spam stats)
3. Service health checks (fsockopen)
4. Log file tailing (mail.log)

**Features**:
- Auto-refresh (10 seconds)
- Responsive design
- Real-time metrics
- Keyboard shortcuts

---

## Data Flow

### Incoming Mail Flow

```
1. External SMTP Server
   └─► Port 25 (Postfix)

2. Postfix Reception
   ├─► SpamAssassin (milter check)
   │   └─► Score added to headers
   ├─► MySQL (virtual user lookup)
   │   └─► Check recipient exists
   └─► Accept message

3. Local Delivery
   └─► Dovecot LMTP
       ├─► MySQL (quota check)
       ├─► Maildir write
       │   └─► /var/mail/vhosts/domain/user/{cur,new,tmp}
       └─► Update mailbox_usage

4. IMAP Retrieval
   └─► Client connects via Dovecot
       ├─► MySQL authentication
       └─► Maildir read
```

### Outgoing Mail Flow

```
1. Client Connection
   └─► Port 587 (Submission)

2. Authentication
   ├─► SASL PLAIN (base64)
   └─► Dovecot Auth → MySQL → Bcrypt verify

3. Message Acceptance
   ├─► Postfix checks SPF (if configured)
   └─► Queue for delivery

4. Relay to Internet
   └─► Postfix SMTP Client
       ├─► TLS negotiation
       └─► Delivery to recipient MX
```

### Backup Flow

```
1. backup.sh execution
   ├─► MySQL dump → /backups/mysql_*.sql.gz
   ├─► Maildir tar → /backups/maildirs_*.tar.gz
   └─► Config tar → /backups/configs_*.tar.gz

2. Verification
   └─► SHA256 checksum

3. Retention Policy
   ├─► Delete backups older than RETENTION_DAYS
   └─► Keep last KEEP_LAST_FULL full backups

4. Remote Sync (optional)
   └─► rsync to REMOTE_DEST
```

---

## Database Schema

### ER Diagram

```
┌─────────────────────┐
│  virtual_domains    │
├─────────────────────┤
│ id (PK)             │
│ name (UNIQUE)       │
│ created_at          │
└──────────┬──────────┘
           │
           │ 1:N
           ▼
┌─────────────────────┐
│  virtual_users      │
├─────────────────────┤
│ id (PK)             │
│ domain_id (FK)      │
│ email (UNIQUE)      │
│ password (bcrypt)   │
│ quota_mb            │
│ enabled             │
│ created_at          │
└──────────┬──────────┘
           │
           │ 1:1
           ▼
┌─────────────────────┐
│  mailbox_usage      │
├─────────────────────┤
│ email (PK, FK)      │
│ usage_mb            │
│ last_updated        │
└─────────────────────┘

┌─────────────────────┐
│  virtual_aliases    │
├─────────────────────┤
│ id (PK)             │
│ domain_id (FK)      │
│ source              │
│ destination         │
│ created_at          │
└─────────────────────┘
```

### SQL Schema

```sql
CREATE TABLE virtual_domains (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE virtual_users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    domain_id INT NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    quota_mb INT DEFAULT 1024,
    enabled TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE,
    INDEX idx_email (email),
    INDEX idx_domain (domain_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE virtual_aliases (
    id INT AUTO_INCREMENT PRIMARY KEY,
    domain_id INT NOT NULL,
    source VARCHAR(255) NOT NULL,
    destination VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE,
    INDEX idx_source (source)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE mailbox_usage (
    email VARCHAR(255) PRIMARY KEY,
    usage_mb DECIMAL(10,2) DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (email) REFERENCES virtual_users(email) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## Security Architecture

### 1. Authentication

**Password Storage**:
- Algorithm: Bcrypt (BLF-CRYPT)
- Salt: Automatic per-password
- Cost: 12 rounds (default)
- Generated by: `doveadm pw -s BLF-CRYPT`

**SASL Authentication Flow**:
```
Client → Postfix (AUTH PLAIN) → Dovecot (auth socket) → MySQL → Bcrypt verify → Response
```

### 2. Encryption

**TLS/SSL**:
- **Certificates**: Self-signed (development) or Let's Encrypt (production)
- **Protocols**: TLSv1.2, TLSv1.3
- **Ciphers**: Modern cipher suites only
- **HSTS**: Recommended for webmail

**Certificate Generation**:
```bash
# CA Certificate
openssl req -new -x509 -days 3650 -keyout ca.key -out ca.crt

# Server Certificate
openssl req -new -keyout server.key -out server.csr
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -out server.crt

# Combined for Dovecot
cat server.crt server.key > dovecot-combined.pem
```

### 3. Network Security

**Firewall Rules** (recommended):
```bash
# Allow SMTP
iptables -A INPUT -p tcp --dport 25 -j ACCEPT
iptables -A INPUT -p tcp --dport 587 -j ACCEPT

# Allow IMAP/IMAPS
iptables -A INPUT -p tcp --dport 143 -j ACCEPT
iptables -A INPUT -p tcp --dport 993 -j ACCEPT

# Allow HTTP (webmail, dashboard)
iptables -A INPUT -p tcp --dport 8025 -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT

# Block MySQL from external
iptables -A INPUT -p tcp --dport 3306 -j DROP
```

**Docker Network Isolation**:
```yaml
backend:
  driver: bridge
  internal: true  # No external access
```

### 4. Access Control

**Service Permissions**:
- **Postfix**: Runs as user `postfix` (UID 100)
- **Dovecot**: Runs as user `dovecot` (UID 101)
- **vmail**: Maildir owner (UID 5000)

**File Permissions**:
```
/var/mail/vhosts/domain/user/
├── cur/   (700, vmail:vmail)
├── new/   (700, vmail:vmail)
└── tmp/   (700, vmail:vmail)
```

### 5. Rate Limiting

**Postfix** (`main.cf`):
```conf
smtpd_client_connection_rate_limit = 30
smtpd_client_connection_count_limit = 10
anvil_rate_time_unit = 60s
```

**Fail2ban** (recommended, not included):
```ini
[postfix-sasl]
enabled = true
filter = postfix-sasl
action = iptables-multiport[name=postfix-sasl]
logpath = /var/log/mail/mail.log
maxretry = 3
bantime = 3600
```

---

## Storage and Volumes

### Docker Volumes

| Volume           | Purpose                    | Size (Typical) | Backup Priority |
|------------------|----------------------------|----------------|-----------------|
| mail-mysql-data  | MySQL database             | 500MB - 5GB    | Critical        |
| mail-ssl-certs   | SSL certificates           | 10MB           | High            |
| mail-mailboxes   | Maildir storage            | 10GB - 1TB     | Critical        |
| mail-queue       | Postfix mail queue         | 100MB - 10GB   | Medium          |
| mail-logs        | Centralized logs           | 1GB - 100GB    | Medium          |
| mail-reports     | JSON reports from scripts  | 10MB - 100MB   | Low             |
| mail-backups     | Backup storage             | Varies         | N/A (is backup) |
| mail-spam-data   | SpamAssassin data          | 100MB - 1GB    | Low             |

### Maildir Structure

```
/var/mail/vhosts/
└── example.com/
    ├── john/
    │   ├── cur/           # Current messages (read)
    │   ├── new/           # New messages (unread)
    │   ├── tmp/           # Temporary (delivery)
    │   └── .Sent/         # IMAP folders
    │       ├── cur/
    │       ├── new/
    │       └── tmp/
    └── jane/
        ├── cur/
        ├── new/
        └── tmp/
```

### Log Management

**Centralized Logging**:
- All services log to `/var/log/mail/mail.log`
- Shared volume mounted in multiple containers
- Rotation recommended (logrotate)

**Log Rotation** (`/etc/logrotate.d/mail`):
```
/var/log/mail/mail.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 syslog adm
    sharedscripts
    postrotate
        docker exec mail-postfix postfix reload
    endscript
}
```

---

## Scalability Considerations

### Horizontal Scaling

**Current Limitations**:
- Single Postfix instance
- Single Dovecot instance
- Shared mailbox volume (not cluster-ready)

**Scaling Strategy**:

1. **Load Balancer** (HAProxy/Nginx):
```
Internet → Load Balancer → Multiple Postfix/Dovecot instances
```

2. **Shared Storage** (NFS/GlusterFS):
```
Multiple Dovecot → Shared NFS → Maildir
```

3. **Database Replication** (MySQL Master-Slave):
```
Postfix/Dovecot → MySQL Master (write)
Dashboard       → MySQL Slave (read)
```

4. **Redis for Sessions** (Dovecot):
```conf
dict {
  redis = redis:host=redis:6379:db=0
}
```

### Vertical Scaling

**Resource Limits** (docker-compose.yml):
```yaml
postfix:
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '0.5'
        memory: 512M
```

**Recommended Specs**:
- **Small** (< 100 users): 2 CPU, 4GB RAM, 50GB storage
- **Medium** (< 1000 users): 4 CPU, 8GB RAM, 500GB storage
- **Large** (< 10000 users): 8+ CPU, 16GB+ RAM, 2TB+ storage

### Performance Optimization

**Postfix** (`main.cf`):
```conf
default_process_limit = 100
smtpd_client_connection_count_limit = 10
qmgr_message_recipient_limit = 20000
```

**Dovecot** (`10-master.conf`):
```conf
service imap-login {
  process_min_avail = 4
  process_limit = 100
}

service imap {
  process_limit = 1024
}
```

**MySQL**:
```conf
innodb_buffer_pool_size = 2G
max_connections = 500
query_cache_size = 64M
```

---

## Monitoring and Observability

### Metrics Collection

**Dashboard Metrics**:
- Service health (port checks)
- Mail queue size
- Spam detection rate
- Mailbox usage
- Disk space

**External Monitoring** (recommended):
- **Prometheus**: Metric collection
- **Grafana**: Visualization
- **Alertmanager**: Alert routing

**Prometheus Exporters**:
```yaml
node-exporter:    # System metrics
mysql-exporter:   # Database metrics
postfix-exporter: # Mail queue metrics
```

### Health Checks

**Docker Compose Health Checks**:
```yaml
postfix:
  healthcheck:
    test: ["CMD", "postfix", "status"]
    interval: 30s
    timeout: 10s
    retries: 3

dovecot:
  healthcheck:
    test: ["CMD", "doveconf", "-n"]
    interval: 30s
```

---

## Disaster Recovery

### Backup Strategy

**3-2-1 Rule**:
- **3** copies of data
- **2** different storage types
- **1** offsite copy

**Backup Schedule**:
```
Daily:   Incremental maildir backup
Weekly:  Full maildir backup + MySQL dump
Monthly: Full backup + offsite sync
```

**Recovery Time Objectives (RTO)**:
- MySQL: < 15 minutes
- Mailboxes: < 1 hour (depends on size)
- Configuration: < 5 minutes

### Restoration Procedure

```bash
# 1. Restore MySQL
gunzip < mysql_backup.sql.gz | docker exec -i mail-mysql mysql mailserver

# 2. Restore Maildir
tar -xzf maildirs_full_*.tar.gz -C /var/mail/vhosts/

# 3. Restore Configuration
tar -xzf configs_*.tar.gz -C /etc/

# 4. Restart services
docker compose restart
```

---

## Future Enhancements

### Planned Features

1. **SPF/DKIM/DMARC**: Email authentication protocols
2. **Sieve Filters**: Server-side mail filtering
3. **CalDAV/CardDAV**: Calendar and contacts sync
4. **XMPP**: Instant messaging integration
5. **Webmail 2FA**: Two-factor authentication
6. **Elasticsearch**: Advanced log search
7. **Kubernetes**: Container orchestration
8. **Let's Encrypt**: Automatic SSL certificates

### Research Areas

- **Mailpile**: Modern encrypted webmail
- **Rspamd**: Alternative spam filter
- **Haraka**: Node.js-based SMTP server
- **Mailu**: Complete mail server suite
- **Mail-in-a-Box**: Automated setup

---

**Document Version**: 1.0
**Last Updated**: 2025-11-30
**Maintained By**: Linux Sysadmin Portfolio
