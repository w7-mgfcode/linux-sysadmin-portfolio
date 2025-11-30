# Linux System Administrator Portfolio Plan

## Repository Overview

**Repository Name:** `linux-sysadmin-portfolio`

**Tagline (EN):** A collection of production-ready DevOps projects demonstrating Linux system administration, containerization, and automation skills.

**Tagline (HU):** Produkció-kész DevOps projektek gyűjteménye, amelyek Linux rendszergazdai, konténerizációs és automatizálási készségeket mutatnak be.

---

## Repository Structure

```
linux-sysadmin-portfolio/
├── README.md                          # Main portfolio overview (bilingual)
├── LICENSE                            # MIT License
├── .gitignore
│
├── project-01-lamp-monitoring/        # LAMP Stack with Monitoring
│   ├── README.md
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── nginx/
│   │   └── default.conf
│   ├── php/
│   │   └── Dockerfile
│   ├── mysql/
│   │   └── init.sql
│   ├── app/
│   │   └── index.php
│   └── scripts/
│       ├── health-check.sh
│       ├── log-analyzer.sh
│       └── backup.sh
│
├── project-02-mail-server/            # Dockerized Mail Server
│   ├── README.md
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── postfix/
│   │   ├── Dockerfile
│   │   └── main.cf
│   ├── dovecot/
│   │   ├── Dockerfile
│   │   └── dovecot.conf
│   ├── roundcube/
│   │   └── config.inc.php
│   └── scripts/
│       ├── mail-queue-monitor.sh
│       ├── spam-report.sh
│       └── user-management.sh
│
├── project-03-infra-automation/       # Infrastructure Automation Toolkit
│   ├── README.md
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── scripts/
│   │   ├── server-hardening.sh
│   │   ├── log-rotation.sh
│   │   ├── network-diagnostics.sh
│   │   └── service-watchdog.sh
│   ├── configs/
│   │   ├── sysctl.conf
│   │   ├── iptables.rules
│   │   └── cron.d/
│   └── tests/
│       └── test-runner.sh
│
└── docs/
    ├── CONTRIBUTING.md
    └── screenshots/
```

---

## Project 1: LAMP Stack with Real-Time Monitoring

### Pitch

**EN:** A production-grade LAMP stack with integrated health monitoring, automated backups, and intelligent log analysis—deployed with a single command.

**HU:** Produkció-szintű LAMP stack integrált állapotfigyeléssel, automatikus biztonsági mentéssel és intelligens naplóelemzéssel—egyetlen paranccsal telepíthető.

---

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    docker-compose.yml                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │  Nginx   │───▶│   PHP    │───▶│  MySQL   │              │
│  │  :80     │    │  FPM     │    │  :3306   │              │
│  │  :443    │    │  :9000   │    │          │              │
│  └──────────┘    └──────────┘    └──────────┘              │
│       │                               │                     │
│       ▼                               ▼                     │
│  ┌──────────┐                   ┌──────────┐               │
│  │ Adminer  │                   │  Backup  │               │
│  │  :8080   │                   │  Volume  │               │
│  └──────────┘                   └──────────┘               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Containers:**
| Container | Image | Purpose |
|-----------|-------|---------|
| `nginx` | `nginx:alpine` | Reverse proxy & static files |
| `php` | Custom (Debian-based) | PHP-FPM 8.2 application server |
| `mysql` | `mysql:8.0` | Database server |
| `adminer` | `adminer:latest` | Database management UI |

---

### The Bash Component: `log-analyzer.sh`

A sophisticated log analysis script demonstrating advanced Bash skills:

```bash
#!/bin/bash
#===============================================================================
# Log Analyzer - Real-time Nginx & PHP-FPM Log Analysis Tool
# Demonstrates: Arrays, associative arrays, regex, awk, process substitution
#===============================================================================

set -euo pipefail

# Configuration
LOG_DIR="${LOG_DIR:-/var/log/nginx}"
ACCESS_LOG="${LOG_DIR}/access.log"
ERROR_LOG="${LOG_DIR}/error.log"
REPORT_DIR="${REPORT_DIR:-/var/reports}"
DATE_FORMAT=$(date +%Y-%m-%d_%H-%M-%S)

# Color codes for terminal output
declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [NC]='\033[0m'
)

# Associative array for HTTP status code categories
declare -A STATUS_CATEGORIES=(
    [2xx]=0 [3xx]=0 [4xx]=0 [5xx]=0
)

log() {
    local level=$1
    shift
    echo -e "${COLORS[$level]}[$(date '+%Y-%m-%d %H:%M:%S')] $*${COLORS[NC]}"
}

analyze_access_logs() {
    log "BLUE" "Analyzing access logs..."

    local total_requests=0
    local -A ip_counts
    local -A endpoint_counts
    local -A hourly_traffic

    while IFS= read -r line; do
        ((total_requests++))

        # Extract IP address (first field)
        local ip=$(echo "$line" | awk '{print $1}')
        ((ip_counts[$ip]++))

        # Extract endpoint
        local endpoint=$(echo "$line" | awk '{print $7}' | cut -d'?' -f1)
        ((endpoint_counts[$endpoint]++))

        # Extract HTTP status code
        local status=$(echo "$line" | awk '{print $9}')
        case $status in
            2[0-9][0-9]) ((STATUS_CATEGORIES[2xx]++)) ;;
            3[0-9][0-9]) ((STATUS_CATEGORIES[3xx]++)) ;;
            4[0-9][0-9]) ((STATUS_CATEGORIES[4xx]++)) ;;
            5[0-9][0-9]) ((STATUS_CATEGORIES[5xx]++)) ;;
        esac

        # Extract hour for traffic analysis
        local hour=$(echo "$line" | grep -oP '\d{2}(?=:\d{2}:\d{2})' | head -1)
        ((hourly_traffic[$hour]++))

    done < "$ACCESS_LOG"

    # Generate report
    generate_report "$total_requests"
}

generate_report() {
    local total=$1
    local report_file="${REPORT_DIR}/analysis_${DATE_FORMAT}.json"

    mkdir -p "$REPORT_DIR"

    cat > "$report_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "total_requests": $total,
    "status_codes": {
        "success_2xx": ${STATUS_CATEGORIES[2xx]},
        "redirect_3xx": ${STATUS_CATEGORIES[3xx]},
        "client_error_4xx": ${STATUS_CATEGORIES[4xx]},
        "server_error_5xx": ${STATUS_CATEGORIES[5xx]}
    },
    "error_rate": $(echo "scale=2; ${STATUS_CATEGORIES[5xx]} * 100 / $total" | bc)
}
EOF

    log "GREEN" "Report generated: $report_file"

    # Alert if error rate exceeds threshold
    local error_rate=$(echo "scale=2; ${STATUS_CATEGORIES[5xx]} * 100 / $total" | bc)
    if (( $(echo "$error_rate > 5" | bc -l) )); then
        log "RED" "WARNING: Error rate ${error_rate}% exceeds 5% threshold!"
        send_alert "High error rate detected: ${error_rate}%"
    fi
}

send_alert() {
    local message=$1
    # Webhook integration placeholder
    if [[ -n "${WEBHOOK_URL:-}" ]]; then
        curl -s -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"$message\"}"
    fi
}

# Main execution
main() {
    log "GREEN" "Starting log analysis..."

    if [[ ! -f "$ACCESS_LOG" ]]; then
        log "RED" "Access log not found: $ACCESS_LOG"
        exit 1
    fi

    analyze_access_logs

    log "GREEN" "Analysis complete!"
}

main "$@"
```

**Skills Demonstrated:**
- Associative arrays (`declare -A`)
- Error handling with `set -euo pipefail`
- Process substitution and redirection
- Regex pattern matching with `grep -oP`
- JSON generation with heredocs
- Conditional alerting logic
- Modular function design

---

### Key Competencies Demonstrated

| Requirement | How This Project Proves It |
|-------------|---------------------------|
| **Debian Linux** | PHP container built on `debian:bookworm-slim` with custom configuration |
| **LAMP Stack** | Full Linux + Nginx + MySQL + PHP implementation |
| **TCP/IP Networking** | Container networking, port mapping, reverse proxy configuration |
| **Bash Scripting** | Complex log analyzer with arrays, JSON output, alerting |
| **Docker** | Multi-container orchestration with volumes and networks |
| **System Maintenance** | Automated backup script, health checks, log rotation |

---

### README.md Structure (Bilingual)

```markdown
# Project 01: LAMP Stack with Real-Time Monitoring

## Overview | Áttekintés

**English:**
This project demonstrates a production-ready LAMP stack deployment using Docker
containers. It includes automated health monitoring, log analysis, and backup
functionality—skills essential for maintaining stable server operations.

**Magyar:**
Ez a projekt egy produkció-kész LAMP stack telepítést mutat be Docker konténerek
használatával. Tartalmaz automatizált állapotfigyelést, naplóelemzést és biztonsági
mentési funkciókat—ezek a készségek elengedhetetlenek a stabil szerverüzemeltetéshez.

---

## Quick Start | Gyors Indítás

**English:**
\`\`\`bash
# Clone the repository
git clone https://github.com/yourusername/linux-sysadmin-portfolio.git
cd linux-sysadmin-portfolio/project-01-lamp-monitoring

# Copy environment file and configure
cp .env.example .env

# Start all services
docker compose up -d

# Access the application
# Web: http://localhost
# Adminer: http://localhost:8080
\`\`\`

**Magyar:**
\`\`\`bash
# Klónozd a repository-t
git clone https://github.com/yourusername/linux-sysadmin-portfolio.git
cd linux-sysadmin-portfolio/project-01-lamp-monitoring

# Másold és konfiguráld a környezeti fájlt
cp .env.example .env

# Indítsd el az összes szolgáltatást
docker compose up -d

# Alkalmazás elérése
# Web: http://localhost
# Adminer: http://localhost:8080
\`\`\`

---

## Architecture | Architektúra

[Architecture diagram here]

### Services | Szolgáltatások

| Service | Port | Description (EN) | Leírás (HU) |
|---------|------|------------------|-------------|
| Nginx | 80, 443 | Reverse proxy and static file server | Reverse proxy és statikus fájl szerver |
| PHP-FPM | 9000 | PHP application processor | PHP alkalmazás feldolgozó |
| MySQL | 3306 | Database server | Adatbázis szerver |
| Adminer | 8080 | Database management interface | Adatbázis kezelő felület |

---

## Bash Scripts | Bash Scriptek

### log-analyzer.sh

**English:**
Analyzes Nginx access and error logs, generates JSON reports, and sends alerts
when error rates exceed configured thresholds.

**Magyar:**
Elemzi az Nginx hozzáférési és hibanaplókat, JSON jelentéseket generál, és
riasztásokat küld, ha a hibaarány meghaladja a beállított küszöbértékeket.

**Usage | Használat:**
\`\`\`bash
# Run analysis
docker compose exec php /scripts/log-analyzer.sh

# View generated report
cat /var/reports/analysis_*.json
\`\`\`

### backup.sh

**English:**
Automated backup script for MySQL databases with compression, retention policy,
and optional remote sync capabilities.

**Magyar:**
Automatizált biztonsági mentési script MySQL adatbázisokhoz tömörítéssel,
megőrzési szabályzattal és opcionális távoli szinkronizálási képességekkel.

---

## Skills Demonstrated | Bemutatott Készségek

- [x] Docker containerization | Docker konténerizáció
- [x] Nginx reverse proxy configuration | Nginx reverse proxy konfiguráció
- [x] MySQL database management | MySQL adatbázis kezelés
- [x] Advanced Bash scripting | Haladó Bash scriptelés
- [x] Log analysis and monitoring | Naplóelemzés és monitoring
- [x] Automated backup systems | Automatizált biztonsági mentési rendszerek

---

## License | Licenc

MIT License - See [LICENSE](../LICENSE) for details.
```

---

## Project 2: Containerized Mail Server Stack

### Pitch

**EN:** A complete email infrastructure with Postfix, Dovecot, and Roundcube webmail—featuring queue monitoring, spam reporting, and user management automation.

**HU:** Teljes körű email infrastruktúra Postfix, Dovecot és Roundcube webmail komponensekkel—várólistafigyeléssel, spam jelentéssel és automatizált felhasználókezeléssel.

---

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      docker-compose.yml                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────┐                          ┌────────────┐         │
│  │ Roundcube  │◀─────────────────────────│   Nginx    │         │
│  │  Webmail   │                          │   :443     │         │
│  └─────┬──────┘                          └────────────┘         │
│        │                                                         │
│        ▼                                                         │
│  ┌────────────┐    ┌────────────┐    ┌────────────┐            │
│  │   Postfix  │───▶│  Dovecot   │───▶│   MySQL    │            │
│  │  SMTP:25   │    │ IMAP:993   │    │   :3306    │            │
│  │   :587     │    │ POP3:995   │    │            │            │
│  └────────────┘    └────────────┘    └────────────┘            │
│        │                                                         │
│        ▼                                                         │
│  ┌────────────┐                                                 │
│  │  SpamAssas │                                                 │
│  │    sin     │                                                 │
│  └────────────┘                                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Containers:**
| Container | Purpose | Ports |
|-----------|---------|-------|
| `postfix` | SMTP server (outgoing mail) | 25, 587 |
| `dovecot` | IMAP/POP3 server (mailbox access) | 993, 995 |
| `roundcube` | Webmail interface | 80 |
| `mysql` | User/domain database | 3306 |
| `spamassassin` | Spam filtering | internal |

---

### The Bash Component: `mail-queue-monitor.sh`

```bash
#!/bin/bash
#===============================================================================
# Mail Queue Monitor - Real-time Postfix Queue Analysis & Management
# Demonstrates: Process monitoring, signal handling, systemd integration
#===============================================================================

set -euo pipefail

# Configuration
readonly QUEUE_WARNING_THRESHOLD="${QUEUE_WARNING:-50}"
readonly QUEUE_CRITICAL_THRESHOLD="${QUEUE_CRITICAL:-200}"
readonly CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
readonly MAIL_ADMIN="${MAIL_ADMIN:-admin@localhost}"
readonly LOG_FILE="/var/log/mail-monitor.log"

# State tracking
declare -i running=1
declare -A queue_stats

# Signal handlers for graceful shutdown
trap 'running=0; log "INFO" "Received shutdown signal"' SIGTERM SIGINT

log() {
    local level=$1
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $*" | tee -a "$LOG_FILE"
}

get_queue_stats() {
    # Parse mailq output for queue statistics
    local mailq_output
    mailq_output=$(mailq 2>/dev/null || echo "Mail queue is empty")

    if [[ "$mailq_output" == "Mail queue is empty" ]]; then
        queue_stats[total]=0
        queue_stats[active]=0
        queue_stats[deferred]=0
        queue_stats[hold]=0
        return
    fi

    # Count messages by queue type
    queue_stats[total]=$(echo "$mailq_output" | grep -c "^[A-F0-9]" || echo 0)
    queue_stats[active]=$(find /var/spool/postfix/active -type f 2>/dev/null | wc -l)
    queue_stats[deferred]=$(find /var/spool/postfix/deferred -type f 2>/dev/null | wc -l)
    queue_stats[hold]=$(find /var/spool/postfix/hold -type f 2>/dev/null | wc -l)

    # Calculate queue age statistics
    local oldest_msg
    oldest_msg=$(find /var/spool/postfix/deferred -type f -printf '%T@\n' 2>/dev/null | sort -n | head -1)

    if [[ -n "$oldest_msg" ]]; then
        local now=$(date +%s)
        local age_seconds=$((now - ${oldest_msg%.*}))
        queue_stats[oldest_hours]=$((age_seconds / 3600))
    else
        queue_stats[oldest_hours]=0
    fi
}

analyze_deferred() {
    log "INFO" "Analyzing deferred queue..."

    local -A bounce_reasons

    # Parse deferred queue for common bounce reasons
    while IFS= read -r queue_id; do
        local reason
        reason=$(postcat -q "$queue_id" 2>/dev/null | grep -oP 'dsn=\K[^,]+' | head -1)

        case "$reason" in
            4.7.*)  ((bounce_reasons[spam_block]++)) ;;
            4.4.*)  ((bounce_reasons[network_issue]++)) ;;
            4.2.*)  ((bounce_reasons[mailbox_full]++)) ;;
            *)      ((bounce_reasons[other]++)) ;;
        esac
    done < <(mailq 2>/dev/null | grep "^[A-F0-9]" | awk '{print $1}' | tr -d '*!')

    # Output analysis
    for reason in "${!bounce_reasons[@]}"; do
        log "INFO" "  $reason: ${bounce_reasons[$reason]}"
    done
}

check_thresholds() {
    local total=${queue_stats[total]}

    if ((total >= QUEUE_CRITICAL_THRESHOLD)); then
        log "CRITICAL" "Queue size $total exceeds critical threshold $QUEUE_CRITICAL_THRESHOLD"
        send_alert "CRITICAL" "Mail queue critical: $total messages"
        return 2
    elif ((total >= QUEUE_WARNING_THRESHOLD)); then
        log "WARNING" "Queue size $total exceeds warning threshold $QUEUE_WARNING_THRESHOLD"
        send_alert "WARNING" "Mail queue warning: $total messages"
        return 1
    fi

    return 0
}

send_alert() {
    local severity=$1
    local message=$2

    # Generate JSON payload
    local payload
    payload=$(cat << EOF
{
    "severity": "$severity",
    "message": "$message",
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "queue_stats": {
        "total": ${queue_stats[total]},
        "active": ${queue_stats[active]},
        "deferred": ${queue_stats[deferred]},
        "hold": ${queue_stats[hold]}
    }
}
EOF
)

    # Send to webhook if configured
    if [[ -n "${ALERT_WEBHOOK:-}" ]]; then
        curl -s -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "$payload" || log "ERROR" "Failed to send webhook alert"
    fi

    # Send email alert
    echo "$message" | mail -s "[$severity] Mail Queue Alert - $(hostname)" "$MAIL_ADMIN" 2>/dev/null || true
}

generate_report() {
    local report_file="/var/reports/mail-queue-$(date +%Y%m%d).json"
    mkdir -p "$(dirname "$report_file")"

    cat > "$report_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "queue": {
        "total": ${queue_stats[total]},
        "active": ${queue_stats[active]},
        "deferred": ${queue_stats[deferred]},
        "hold": ${queue_stats[hold]},
        "oldest_message_hours": ${queue_stats[oldest_hours]}
    },
    "thresholds": {
        "warning": $QUEUE_WARNING_THRESHOLD,
        "critical": $QUEUE_CRITICAL_THRESHOLD
    }
}
EOF

    log "INFO" "Report saved to $report_file"
}

# Daemon mode
run_daemon() {
    log "INFO" "Starting mail queue monitor daemon..."

    while ((running)); do
        get_queue_stats
        check_thresholds || true
        generate_report

        log "INFO" "Queue: total=${queue_stats[total]} active=${queue_stats[active]} deferred=${queue_stats[deferred]}"

        sleep "$CHECK_INTERVAL" &
        wait $! || true
    done

    log "INFO" "Monitor stopped"
}

# One-shot mode
run_once() {
    get_queue_stats

    echo "=== Mail Queue Statistics ==="
    echo "Total:    ${queue_stats[total]}"
    echo "Active:   ${queue_stats[active]}"
    echo "Deferred: ${queue_stats[deferred]}"
    echo "Hold:     ${queue_stats[hold]}"
    echo "Oldest:   ${queue_stats[oldest_hours]} hours"
    echo ""

    if ((queue_stats[deferred] > 0)); then
        analyze_deferred
    fi

    check_thresholds
}

# Main
case "${1:-once}" in
    daemon) run_daemon ;;
    once)   run_once ;;
    *)      echo "Usage: $0 {daemon|once}"; exit 1 ;;
esac
```

**Skills Demonstrated:**
- Signal handling (`trap`) for graceful shutdown
- Daemon mode with background process management
- Mail queue parsing with `mailq` and `postcat`
- File system traversal for queue analysis
- Threshold-based alerting system
- JSON report generation

---

### Key Competencies Demonstrated

| Requirement | How This Project Proves It |
|-------------|---------------------------|
| **Email Systems (Postfix/Dovecot)** | Complete mail server implementation with both MTА and MDA |
| **Bash Scripting** | Complex queue monitoring with daemon mode, signal handling |
| **TCP/IP Networking** | SMTP/IMAP/POP3 protocols, DNS MX configuration |
| **System Maintenance** | Queue management, spam filtering, user provisioning |
| **YAML Configuration** | Docker Compose with complex service dependencies |

---

### README.md Structure (Bilingual)

```markdown
# Project 02: Containerized Mail Server Stack

## Overview | Áttekintés

**English:**
A complete, containerized email infrastructure featuring Postfix for SMTP,
Dovecot for IMAP/POP3, and Roundcube for webmail access. This project
demonstrates expertise in email server administration—a valuable bonus
skill for Linux system administrators.

**Magyar:**
Teljes körű, konténerizált email infrastruktúra Postfix SMTP szerverrel,
Dovecot IMAP/POP3 szerverrel és Roundcube webmail felülettel. Ez a projekt
az email szerver adminisztráció szakértelmét mutatja be—értékes bónusz
készség Linux rendszergazdák számára.

---

## Features | Funkciók

**English:**
- Complete SMTP/IMAP/POP3 mail server
- Webmail interface with Roundcube
- Spam filtering with SpamAssassin
- Virtual domain and mailbox support
- Automated queue monitoring and alerting
- User management automation scripts

**Magyar:**
- Teljes SMTP/IMAP/POP3 levelezőszerver
- Webmail felület Roundcube-bal
- Spam szűrés SpamAssassin-nel
- Virtuális domain és postafiók támogatás
- Automatizált várólistafigyelés és riasztás
- Felhasználókezelési automatizáló scriptek

---

## Quick Start | Gyors Indítás

\`\`\`bash
# Start the mail server stack
docker compose up -d

# Create a test mailbox
docker compose exec postfix /scripts/user-management.sh add user@example.com

# Access webmail
# https://localhost/webmail
\`\`\`

---

## Scripts | Scriptek

### mail-queue-monitor.sh

**English:**
Monitors the Postfix mail queue, analyzes deferred messages, and sends
alerts when queue size exceeds configured thresholds.

**Magyar:**
Figyeli a Postfix levélvárólistát, elemzi a késleltetett üzeneteket, és
riasztásokat küld, ha a várólistaméret meghaladja a beállított küszöbértékeket.

### user-management.sh

**English:**
Automates creation, modification, and deletion of virtual mailboxes
and aliases in the mail system.

**Magyar:**
Automatizálja a virtuális postafiókok és aliasok létrehozását, módosítását
és törlését a levelezőrendszerben.
```

---

## Project 3: Infrastructure Automation Toolkit

### Pitch

**EN:** A comprehensive collection of battle-tested Bash scripts for server hardening, network diagnostics, service monitoring, and automated maintenance—the Swiss Army knife of Linux administration.

**HU:** Átfogó gyűjtemény bevált Bash scriptekből szerverkeményítéshez, hálózati diagnosztikához, szolgáltatásfigyeléshez és automatizált karbantartáshoz—a Linux adminisztráció svájci bicskája.

---

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                Infrastructure Automation Toolkit                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Test Environment                       │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │   │
│  │  │  Debian  │  │  Alpine  │  │  Ubuntu  │              │   │
│  │  │  Target  │  │  Target  │  │  Target  │              │   │
│  │  └──────────┘  └──────────┘  └──────────┘              │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Script Collection                      │   │
│  │                                                           │   │
│  │  [server-hardening.sh]    [network-diagnostics.sh]       │   │
│  │  [log-rotation.sh]        [service-watchdog.sh]          │   │
│  │  [backup-manager.sh]      [system-inventory.sh]          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Containers (Test Environment):**
| Container | Purpose |
|-----------|---------|
| `debian-target` | Primary test environment (Debian 12) |
| `alpine-target` | Minimal environment testing |
| `ubuntu-target` | Ubuntu compatibility testing |

---

### The Bash Component: `server-hardening.sh`

```bash
#!/bin/bash
#===============================================================================
# Server Hardening Script - Automated Security Baseline Configuration
# Demonstrates: Idempotent operations, system configuration, security practices
#===============================================================================

set -euo pipefail

# Script metadata
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME=$(basename "$0")
readonly BACKUP_DIR="/var/backups/hardening/$(date +%Y%m%d_%H%M%S)"

# Logging configuration
readonly LOG_FILE="/var/log/server-hardening.log"
declare -i CHANGES_MADE=0
declare -i ERRORS=0

# Color output
declare -A C=([R]='\033[0;31m' [G]='\033[0;32m' [Y]='\033[1;33m' [B]='\033[0;34m' [N]='\033[0m')

#===============================================================================
# Utility Functions
#===============================================================================

log() {
    local level=$1 color=$2
    shift 2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${C[$color]}[$timestamp] [$level] $*${C[N]}" | tee -a "$LOG_FILE"
}

info()  { log "INFO" "B" "$*"; }
ok()    { log "OK" "G" "$*"; }
warn()  { log "WARN" "Y" "$*"; }
error() { log "ERROR" "R" "$*"; ((ERRORS++)); }

backup_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp -p "$file" "$BACKUP_DIR/"
        info "Backed up: $file"
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

#===============================================================================
# SSH Hardening
#===============================================================================

harden_ssh() {
    info "=== SSH Hardening ==="

    local sshd_config="/etc/ssh/sshd_config"
    local sshd_hardening="/etc/ssh/sshd_config.d/99-hardening.conf"

    backup_file "$sshd_config"

    # Create hardening configuration
    cat > "$sshd_hardening" << 'EOF'
# Security hardening - generated by server-hardening.sh
Protocol 2
PermitRootLogin prohibit-password
PasswordAuthentication no
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowAgentForwarding no
AllowTcpForwarding no
LoginGraceTime 60
EOF

    # Validate configuration
    if sshd -t 2>/dev/null; then
        ok "SSH configuration validated"
        ((CHANGES_MADE++))
    else
        error "SSH configuration validation failed"
        rm -f "$sshd_hardening"
        return 1
    fi
}

#===============================================================================
# Kernel Hardening (sysctl)
#===============================================================================

harden_kernel() {
    info "=== Kernel Hardening ==="

    local sysctl_hardening="/etc/sysctl.d/99-hardening.conf"

    backup_file "$sysctl_hardening"

    cat > "$sysctl_hardening" << 'EOF'
# Network security
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

# IPv6 hardening
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Kernel hardening
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.sysrq = 0
EOF

    # Apply settings
    if sysctl --system > /dev/null 2>&1; then
        ok "Kernel parameters applied"
        ((CHANGES_MADE++))
    else
        error "Failed to apply kernel parameters"
        return 1
    fi
}

#===============================================================================
# Firewall Configuration
#===============================================================================

configure_firewall() {
    info "=== Firewall Configuration ==="

    # Check for iptables
    if ! command -v iptables &> /dev/null; then
        warn "iptables not found, skipping firewall configuration"
        return 0
    fi

    local rules_file="/etc/iptables/rules.v4"
    mkdir -p "$(dirname "$rules_file")"

    backup_file "$rules_file"

    # Generate base ruleset
    cat > "$rules_file" << 'EOF'
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Loopback
-A INPUT -i lo -j ACCEPT
-A OUTPUT -o lo -j ACCEPT

# Established connections
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# SSH (rate limited)
-A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name SSH
-A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
-A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT

# HTTP/HTTPS
-A INPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW -j ACCEPT

# ICMP (ping)
-A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 4 -j ACCEPT

# Log dropped packets
-A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables-dropped: " --log-level 4

COMMIT
EOF

    # Apply rules
    if iptables-restore < "$rules_file" 2>/dev/null; then
        ok "Firewall rules applied"
        ((CHANGES_MADE++))
    else
        warn "Failed to apply firewall rules (may require different approach in container)"
    fi
}

#===============================================================================
# File Permissions Audit
#===============================================================================

audit_permissions() {
    info "=== File Permissions Audit ==="

    local -a sensitive_files=(
        "/etc/passwd:644"
        "/etc/shadow:600"
        "/etc/group:644"
        "/etc/gshadow:600"
        "/etc/ssh/sshd_config:600"
    )

    for entry in "${sensitive_files[@]}"; do
        local file="${entry%%:*}"
        local expected="${entry##*:}"

        if [[ -f "$file" ]]; then
            local current=$(stat -c "%a" "$file")
            if [[ "$current" != "$expected" ]]; then
                chmod "$expected" "$file"
                ok "Fixed permissions on $file: $current -> $expected"
                ((CHANGES_MADE++))
            else
                info "Permissions OK: $file ($current)"
            fi
        fi
    done

    # Find world-writable files
    info "Scanning for world-writable files..."
    local ww_files
    ww_files=$(find /etc /usr -xdev -type f -perm -0002 2>/dev/null | head -20)

    if [[ -n "$ww_files" ]]; then
        warn "Found world-writable files:"
        echo "$ww_files" | while read -r f; do
            warn "  $f"
        done
    else
        ok "No world-writable files found in /etc or /usr"
    fi
}

#===============================================================================
# User Security
#===============================================================================

audit_users() {
    info "=== User Security Audit ==="

    # Check for users with empty passwords
    local empty_pass
    empty_pass=$(awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null)

    if [[ -n "$empty_pass" ]]; then
        warn "Users with empty passwords:"
        echo "$empty_pass" | while read -r user; do
            warn "  $user"
        done
    else
        ok "No users with empty passwords"
    fi

    # Check for users with UID 0 (besides root)
    local uid_zero
    uid_zero=$(awk -F: '($3 == 0 && $1 != "root") {print $1}' /etc/passwd)

    if [[ -n "$uid_zero" ]]; then
        error "Non-root users with UID 0 (security risk!):"
        echo "$uid_zero" | while read -r user; do
            error "  $user"
        done
    else
        ok "No unauthorized UID 0 users"
    fi

    # Lock system accounts
    local -a system_accounts=(
        "daemon" "bin" "sys" "games" "man" "lp" "mail"
        "news" "uucp" "proxy" "www-data" "backup" "list"
    )

    for account in "${system_accounts[@]}"; do
        if id "$account" &>/dev/null; then
            usermod -L "$account" 2>/dev/null || true
            usermod -s /usr/sbin/nologin "$account" 2>/dev/null || true
        fi
    done
    ok "System accounts locked"
}

#===============================================================================
# Generate Report
#===============================================================================

generate_report() {
    local report_file="/var/reports/hardening-$(date +%Y%m%d_%H%M%S).json"
    mkdir -p "$(dirname "$report_file")"

    cat > "$report_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "script_version": "$SCRIPT_VERSION",
    "changes_made": $CHANGES_MADE,
    "errors": $ERRORS,
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

    info "Report saved: $report_file"
}

#===============================================================================
# Main
#===============================================================================

main() {
    info "========================================"
    info "Server Hardening Script v$SCRIPT_VERSION"
    info "========================================"

    check_root

    mkdir -p "$(dirname "$LOG_FILE")"

    harden_ssh || true
    harden_kernel || true
    configure_firewall || true
    audit_permissions || true
    audit_users || true
    generate_report

    echo ""
    info "========================================"
    if ((ERRORS > 0)); then
        error "Completed with $ERRORS errors. Review log: $LOG_FILE"
        exit 1
    else
        ok "Hardening complete! Changes made: $CHANGES_MADE"
        ok "Backups saved to: $BACKUP_DIR"
    fi
}

# Allow sourcing for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

**Skills Demonstrated:**
- Idempotent configuration management
- SSH, kernel, and firewall hardening
- File permission auditing
- User security assessment
- Backup management before changes
- JSON report generation
- Modular, testable design

---

### Key Competencies Demonstrated

| Requirement | How This Project Proves It |
|-------------|---------------------------|
| **Linux Server Operation** | Comprehensive system hardening and security baseline |
| **TCP/IP Networking** | Firewall rules, network kernel parameters |
| **Bash Scripting** | Advanced script with multiple security modules |
| **System Maintenance** | Automated auditing, backup, and reporting |
| **YAML/JSON** | JSON report generation, structured output |

---

### README.md Structure (Bilingual)

```markdown
# Project 03: Infrastructure Automation Toolkit

## Overview | Áttekintés

**English:**
A comprehensive collection of production-ready Bash scripts for server
administration, security hardening, and automated maintenance. Each script
follows best practices: idempotent operations, proper error handling,
logging, and backup creation before modifications.

**Magyar:**
Átfogó gyűjtemény produkció-kész Bash scriptekből szerveradminisztrációhoz,
biztonsági keményítéshez és automatizált karbantartáshoz. Minden script
követi a legjobb gyakorlatokat: idempotens műveletek, megfelelő hibakezelés,
naplózás és biztonsági mentés készítés módosítások előtt.

---

## Scripts | Scriptek

### server-hardening.sh

**English:**
Automated security hardening script that configures SSH, kernel parameters,
firewall rules, and audits file permissions and user security.

**Magyar:**
Automatizált biztonsági keményítő script, amely konfigurálja az SSH-t,
kernel paramétereket, tűzfalszabályokat, és auditálja a fájljogosultságokat
és felhasználói biztonságot.

### network-diagnostics.sh

**English:**
Comprehensive network diagnostic tool that checks connectivity, DNS
resolution, routing tables, and open ports.

**Magyar:**
Átfogó hálózati diagnosztikai eszköz, amely ellenőrzi a kapcsolatot,
DNS feloldást, útválasztási táblákat és nyitott portokat.

### service-watchdog.sh

**English:**
Service monitoring daemon that watches critical services and automatically
restarts them if they fail, with configurable alerting.

**Magyar:**
Szolgáltatásfigyelő démon, amely figyeli a kritikus szolgáltatásokat és
automatikusan újraindítja őket hiba esetén, konfigurálható riasztással.

---

## Usage | Használat

**English:**
\`\`\`bash
# Start test environment
docker compose up -d

# Run hardening script on Debian target
docker compose exec debian-target /scripts/server-hardening.sh

# Run network diagnostics
docker compose exec debian-target /scripts/network-diagnostics.sh

# View generated reports
docker compose exec debian-target cat /var/reports/hardening-*.json
\`\`\`

**Magyar:**
\`\`\`bash
# Indítsd el a teszt környezetet
docker compose up -d

# Futtasd a keményítő scriptet a Debian célgépen
docker compose exec debian-target /scripts/server-hardening.sh

# Futtass hálózati diagnosztikát
docker compose exec debian-target /scripts/network-diagnostics.sh

# Nézd meg a generált jelentéseket
docker compose exec debian-target cat /var/reports/hardening-*.json
\`\`\`
```

---

## Main Repository README.md

```markdown
# Linux System Administrator Portfolio
# Linux Rendszergazda Portfólió

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![Bash](https://img.shields.io/badge/Bash-5.0+-green.svg)](https://www.gnu.org/software/bash/)

---

## About | Rólam

**English:**
This portfolio demonstrates practical Linux system administration skills through
three production-ready projects. Each project is fully containerized and can be
deployed with a single `docker compose up` command, showcasing expertise in:

- Linux server operations (Debian-focused)
- LAMP/LEMP stack deployment
- Advanced Bash scripting
- Docker containerization
- Network administration
- System security and hardening

**Magyar:**
Ez a portfólió gyakorlati Linux rendszergazdai készségeket mutat be három
produkció-kész projekten keresztül. Minden projekt teljesen konténerizált és
egyetlen `docker compose up` paranccsal telepíthető, bemutatva a szakértelmet:

- Linux szerver üzemeltetés (Debian-fókuszú)
- LAMP/LEMP stack telepítés
- Haladó Bash scriptelés
- Docker konténerizáció
- Hálózat adminisztráció
- Rendszerbiztonság és keményítés

---

## Projects | Projektek

| # | Project | Description (EN) | Leírás (HU) |
|---|---------|------------------|-------------|
| 1 | [LAMP Monitoring](./project-01-lamp-monitoring/) | Production LAMP stack with log analysis | Produkciós LAMP stack naplóelemzéssel |
| 2 | [Mail Server](./project-02-mail-server/) | Complete Postfix/Dovecot mail system | Teljes Postfix/Dovecot levelező rendszer |
| 3 | [Automation Toolkit](./project-03-infra-automation/) | Server hardening & maintenance scripts | Szerver keményítő és karbantartó scriptek |

---

## Quick Start | Gyors Indítás

**English:**
\`\`\`bash
# Clone the repository
git clone https://github.com/yourusername/linux-sysadmin-portfolio.git
cd linux-sysadmin-portfolio

# Choose a project and start it
cd project-01-lamp-monitoring
docker compose up -d

# View logs
docker compose logs -f
\`\`\`

**Magyar:**
\`\`\`bash
# Klónozd a repository-t
git clone https://github.com/yourusername/linux-sysadmin-portfolio.git
cd linux-sysadmin-portfolio

# Válassz egy projektet és indítsd el
cd project-01-lamp-monitoring
docker compose up -d

# Nézd meg a naplókat
docker compose logs -f
\`\`\`

---

## Skills Matrix | Készség Mátrix

| Skill | Project 1 | Project 2 | Project 3 |
|-------|:---------:|:---------:|:---------:|
| Debian Linux | ✅ | ✅ | ✅ |
| Bash Scripting | ✅ | ✅ | ✅ |
| Docker/Compose | ✅ | ✅ | ✅ |
| Nginx/Apache | ✅ | ✅ | - |
| MySQL | ✅ | ✅ | - |
| PHP | ✅ | - | - |
| Postfix/Dovecot | - | ✅ | - |
| TCP/IP Networking | ✅ | ✅ | ✅ |
| Security Hardening | - | - | ✅ |
| Log Analysis | ✅ | ✅ | ✅ |

---

## Contact | Kapcsolat

- GitHub: [@yourusername](https://github.com/yourusername)
- Email: your.email@example.com
- LinkedIn: [Your Name](https://linkedin.com/in/yourprofile)

---

## License | Licenc

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Ez a projekt MIT licenc alatt áll - részletekért lásd a [LICENSE](LICENSE) fájlt.
```

---

## Implementation Checklist

### Phase 1: Repository Setup
- [ ] Create GitHub repository `linux-sysadmin-portfolio`
- [ ] Add MIT LICENSE file
- [ ] Create main README.md (bilingual)
- [ ] Set up `.gitignore` for Docker/logs/secrets

### Phase 2: Project 1 - LAMP Stack
- [ ] Create `docker-compose.yml` with Nginx, PHP-FPM, MySQL, Adminer
- [ ] Write custom PHP Dockerfile (Debian-based)
- [ ] Implement `log-analyzer.sh`
- [ ] Implement `backup.sh`
- [ ] Implement `health-check.sh`
- [ ] Write bilingual README.md

### Phase 3: Project 2 - Mail Server
- [ ] Create `docker-compose.yml` with Postfix, Dovecot, Roundcube
- [ ] Configure Postfix for virtual domains
- [ ] Implement `mail-queue-monitor.sh`
- [ ] Implement `user-management.sh`
- [ ] Write bilingual README.md

### Phase 4: Project 3 - Automation Toolkit
- [ ] Create test environment `docker-compose.yml`
- [ ] Implement `server-hardening.sh`
- [ ] Implement `network-diagnostics.sh`
- [ ] Implement `service-watchdog.sh`
- [ ] Create test runner for script validation
- [ ] Write bilingual README.md

### Phase 5: Polish
- [ ] Add screenshots to `/docs/screenshots/`
- [ ] Test all `docker compose up` commands
- [ ] Verify all scripts work in containers
- [ ] Review all documentation for consistency

---

## Why This Portfolio Impresses

1. **Single-Command Deployment** - Shows understanding of Docker best practices
2. **Production-Ready Scripts** - Not toy examples, but usable tools
3. **Bilingual Documentation** - Demonstrates communication skills for Hungarian market
4. **Security Focus** - Critical for any sysadmin role
5. **Comprehensive Coverage** - Addresses all job requirements systematically
