# Linux System Administrator Portfolio
# Linux Rendszergazda Portfólió

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![Bash](https://img.shields.io/badge/Bash-5.0+-green.svg)](https://www.gnu.org/software/bash/)

---

## About | Rólam

**English:**
This portfolio demonstrates practical Linux system administration skills through three production-ready projects. Each project is fully containerized and can be deployed with a single `docker compose up` command, showcasing expertise in:

- Linux server operations (Debian-focused)
- LAMP/LEMP stack deployment
- Advanced Bash scripting
- Docker containerization
- Network administration
- System security and hardening

**Magyar:**
Ez a portfólió gyakorlati Linux rendszergazdai készségeket mutat be három produkció-kész projekten keresztül. Minden projekt teljesen konténerizált és egyetlen `docker compose up` paranccsal telepíthető, bemutatva a szakértelmet:

- Linux szerver üzemeltetés (Debian-fókuszú)
- LAMP/LEMP stack telepítés
- Haladó Bash scriptelés
- Docker konténerizáció
- Hálózat adminisztráció
- Rendszerbiztonság és keményítés

---

## Projects | Projektek

| # | Project | Status | Description (EN) | Leírás (HU) |
|---|---------|--------|------------------|-------------|
| 1 | [LAMP Monitoring](./project-01-lamp-monitoring/) | ✅ **Complete** | Production LAMP stack with log analysis | Produkciós LAMP stack naplóelemzéssel |
| 2 | [Mail Server](./project-02-mail-server/) | ✅ **Complete** | Complete Postfix/Dovecot mail system with monitoring | Teljes Postfix/Dovecot levelező rendszer monitoringgal |
| 3 | [Automation Toolkit](./project-03-infra-automation/) | ✅ **Complete** | Advanced automation scripts for security & maintenance | Haladó automatizálási scriptek biztonsághoz és karbantartáshoz |

---

## Quick Start | Gyors Indítás

**English:**
```bash
# Clone the repository
git clone https://github.com/yourusername/linux-sysadmin-portfolio.git
cd linux-sysadmin-portfolio

# Choose a project and start it
cd project-01-lamp-monitoring
docker compose up -d

# View logs
docker compose logs -f
```

**Magyar:**
```bash
# Klónozd a repository-t
git clone https://github.com/yourusername/linux-sysadmin-portfolio.git
cd linux-sysadmin-portfolio

# Válassz egy projektet és indítsd el
cd project-01-lamp-monitoring
docker compose up -d

# Nézd meg a naplókat
docker compose logs -f
```

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

## Project Highlights | Projekt Kiemelések

### Project 1: LAMP Stack with Real-Time Monitoring ✅ **COMPLETE**

**EN:** A production-grade LAMP stack with integrated health monitoring, automated backups, and intelligent log analysis. Features an interactive dashboard, 728 lines of advanced Bash scripts, and Docker orchestration with network isolation. Fully documented in English and Hungarian.

**HU:** Produkció-szintű LAMP stack integrált állapotfigyeléssel, automatikus biztonsági mentéssel és intelligens naplóelemzéssel. Tartalmaz interaktív vezérlőpultot, 728 sor haladó Bash scriptet, és Docker orkesztrációt hálózati elkülönítéssel. Teljes mértékben dokumentált angolul és magyarul.

**Implementation Stats:**
- 16 files created
- 728 lines of Bash scripts (3 scripts)
- 4 Docker services (Nginx, PHP-FPM 8.2, MySQL 8.0, Adminer)
- Interactive PHP dashboard with live metrics
- Production-ready with health checks

**Key Scripts:**
- `log-analyzer.sh` (318 lines) - ⭐ PRIMARY SHOWCASE - Associative arrays, regex, JSON, alerting
- `backup.sh` (215 lines) - Automated MySQL backups with retention and integrity checks
- `health-check.sh` (195 lines) - Multi-service health monitoring with JSON reports

**[View Full Documentation →](./project-01-lamp-monitoring/README.md)**

### Project 2: Production Mail Server Stack ✅ **COMPLETE**

**EN:** A fully containerized, production-ready mail server stack featuring Postfix (SMTP), Dovecot (IMAP/POP3), SpamAssassin, and Roundcube webmail. Includes comprehensive automation scripts with daemon mode monitoring, interactive dashboard, SSL/TLS encryption, MySQL-backed virtual users, and complete test suite. Demonstrates advanced Bash scripting (1,949 lines), protocol implementation (SMTP/IMAP), and enterprise-level system administration.

**HU:** Teljesen konténerizált, produkció-kész levelezőszerver stack Postfix (SMTP), Dovecot (IMAP/POP3), SpamAssassin és Roundcube webmail komponensekkel. Tartalmaz átfogó automatizálási szkripteket daemon módú monitoringgal, interaktív vezérlőpultot, SSL/TLS titkosítást, MySQL-alapú virtuális felhasználókat és teljes tesztcsomagot. Bemutatja a haladó Bash scriptелést (1,949 sor), protokoll implementációt (SMTP/IMAP) és vállalati szintű rendszeradminisztrációt.

**Implementation Stats:**
- 48 files created
- 1,949 lines of Bash scripts (7 scripts)
- 937 lines of test automation (2 scripts)
- 979 lines of dashboard code (PHP, CSS, JS)
- 2,564 lines of documentation (3 comprehensive docs)
- 7 Docker services (Postfix, Dovecot, MySQL, SpamAssassin, Roundcube, Dashboard, SSL init)
- Production-ready with health checks and network isolation

**Key Scripts:**
- `mail-queue-monitor.sh` (460 lines) - ⭐ PRIMARY SHOWCASE - Daemon mode, signal handling, PID management, threshold alerting
- `user-management.sh` (450 lines) - Git-style CLI for domain/user/alias management with MySQL integration
- `backup.sh` (336 lines) - Incremental backups with SHA256 verification and retention policies
- `spam-report.sh` (320 lines) - SpamAssassin statistics with ASCII bar charts
- `generate-ssl.sh` (222 lines) - Self-signed certificate generation with SAN
- `test-mail-flow.sh` (383 lines) - End-to-end SMTP/IMAP protocol testing
- `lib/common.sh` (147 lines) - Shared utility library

**Key Features:**
- MySQL-backed virtual users with bcrypt password hashing
- SSL/TLS encryption (self-signed, Let's Encrypt ready)
- Spam filtering with Bayes learning
- Real-time monitoring dashboard (PHP 8.2)
- Comprehensive test suite (e2e + mail flow)
- Network isolation (backend internal only)
- Auto-refresh dashboard with keyboard shortcuts

**[View Full Documentation →](./project-02-mail-server/README.md)**

### Project 3: Infrastructure Automation Toolkit ✅ **COMPLETE**

**EN:** A production-grade infrastructure automation toolkit featuring six sophisticated Bash scripts for security hardening, network diagnostics, service monitoring, backup management, log rotation, and system inventory. Includes comprehensive test suite (40+ tests), Docker-based multi-OS validation (Debian, Alpine, Ubuntu), and extensive documentation (5,989 lines). Demonstrates advanced system administration, daemon programming, and enterprise-level automation.

**HU:** Produkció-szintű infrastruktúra automatizálási eszköztár hat kifinomult Bash scripttel biztonsági keményítéshez, hálózati diagnosztikához, szolgáltatás monitorozáshoz, biztonsági mentés kezeléshez, log rotációhoz és rendszer leltárhoz. Tartalmaz átfogó tesztcsomagot (40+ teszt), Docker-alapú multi-OS validációt (Debian, Alpine, Ubuntu) és kiterjedt dokumentációt (5,989 sor). Bemutatja a haladó rendszeradminisztrációt, daemon programozást és vállalati szintű automatizálást.

**Implementation Stats:**
- 60+ files created
- 4,400+ lines of Bash scripts (6 scripts + 1 library)
- 691 lines of test automation (40+ test cases)
- 5,989 lines of documentation (4 comprehensive docs - bilingual)
- 5 Docker services (Debian, Alpine, Ubuntu targets + Nginx + CoreDNS)
- Production-ready with TAP test output and multi-OS support

**Key Scripts:**
- `server-hardening.sh` (781 lines) - ⭐ PRIMARY SHOWCASE - 5 security modules (SSH, kernel, firewall, permissions, users), idempotent, dry-run mode
- `network-diagnostics.sh` (588 lines) - Git-style subcommands for connectivity, DNS, routes, ports, scanning with ASCII tables
- `service-watchdog.sh` (647 lines) - Daemon mode monitoring with PID management, signal handling, exponential backoff, webhook alerts
- `backup-manager.sh` (619 lines) - Full/incremental backups, SHA256 verification, GFS retention, multiple compression (gzip/xz/zstd)
- `log-rotation.sh` (773 lines) - Size/age-based rotation, deferred compression, service signaling, postrotate hooks
- `system-inventory.sh` (863 lines) - Hardware/software/security inventory, JSON/HTML reports, change detection
- `lib/common.sh` (412 lines) - Shared utility library with OS detection, logging, JSON, validation
- `e2e-test.sh` (691 lines) - Comprehensive test suite with TAP output, Docker orchestration

**Key Features:**
- Multi-OS compatibility (Debian 12, Alpine 3.19, Ubuntu 24.04)
- Idempotent operations (safe to run multiple times)
- JSON structured output for all scripts
- Comprehensive error handling and validation
- Docker-based isolated testing environment
- Bilingual documentation (English/Hungarian)
- Cross-platform tool detection and fallback
- Production-ready security hardening
- Automated service recovery with restart limits

**[View Full Documentation →](./project-03-infra-automation/README.md)**

---

## Requirements | Követelmények

- Docker 24.0+
- Docker Compose 2.20+
- Bash 5.0+
- 4GB RAM minimum

---

## Contact | Kapcsolat

- GitHub: [@w7-mgfcode](https://github.com/w7-mgfcode)
- Email: gabor@w7-7.net
- LinkedIn: [w7-mgfcode](https://linkedin.com/in/saborobag)

---

## License | Licenc

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Ez a projekt MIT licenc alatt áll - részletekért lásd a [LICENSE](LICENSE) fájlt.
