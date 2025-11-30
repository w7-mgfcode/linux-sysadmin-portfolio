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
| 2 | [Mail Server](./project-02-mail-server/) | 📋 Planned | Complete Postfix/Dovecot mail system | Teljes Postfix/Dovecot levelező rendszer |
| 3 | [Automation Toolkit](./project-03-infra-automation/) | 📋 Planned | Server hardening & maintenance scripts | Szerver keményítő és karbantartó scriptek |

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

### Project 2: Containerized Mail Server Stack

**EN:** A complete email infrastructure with Postfix, Dovecot, and Roundcube webmail.

**HU:** Teljes körű email infrastruktúra Postfix, Dovecot és Roundcube webmail komponensekkel.

**Key Scripts:**
- `mail-queue-monitor.sh` - Queue analysis daemon
- `user-management.sh` - Virtual mailbox automation
- `spam-report.sh` - Spam statistics

### Project 3: Infrastructure Automation Toolkit

**EN:** A comprehensive collection of battle-tested Bash scripts for server hardening and maintenance.

**HU:** Átfogó gyűjtemény bevált Bash scriptekből szerverkeményítéshez és karbantartáshoz.

**Key Scripts:**
- `server-hardening.sh` - Automated security baseline
- `network-diagnostics.sh` - Network troubleshooting
- `service-watchdog.sh` - Service monitoring daemon

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
