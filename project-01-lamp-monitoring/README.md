# Project 01: LAMP Stack with Real-Time Monitoring

## Overview | Áttekintés

**English:**
This project demonstrates a production-grade LAMP stack deployment using Docker containers. It includes automated health monitoring, comprehensive log analysis, and backup functionality—skills essential for maintaining stable server operations. The stack features an interactive dashboard, three sophisticated Bash monitoring scripts, and follows security best practices with network isolation.

**Magyar:**
Ez a projekt egy produkció-szintű LAMP stack telepítést mutat be Docker konténerek használatával. Tartalmaz automatizált állapotfigyelést, átfogó naplóelemzést és biztonsági mentési funkciókat—ezek a készségek elengedhetetlenek a stabil szerverüzemeltetéshez. A stack egy interaktív vezérlőpultot, három kifinomult Bash monitoring scriptet tartalmaz, és követi a biztonsági legjobb gyakorlatokat hálózati elkülönítéssel.

---

## Architecture | Architektúra

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
│       │                │               │                    │
│       ▼                │               ▼                    │
│  ┌──────────┐         │          ┌──────────┐              │
│  │ Adminer  │         └─────────▶│  Backup  │              │
│  │  :8080   │                    │  Volume  │              │
│  └──────────┘                    └──────────┘              │
│                                                              │
└─────────────────────────────────────────────────────────────┘

Networks:
- frontend (bridge): nginx, php, adminer
- backend (internal): php, mysql

Volumes:
- lamp_db_data: MySQL persistent storage
- lamp_backups: Automated backup storage
- lamp_nginx_logs: Shared logs for analysis
```

---

## Quick Start | Gyors Indítás

**English:**
```bash
# Clone the repository
git clone https://github.com/yourusername/linux-sysadmin-portfolio.git
cd linux-sysadmin-portfolio/project-01-lamp-monitoring

# Copy and configure environment
cp .env.example .env
# Edit .env with your passwords

# Start all services
docker compose up -d

# Verify services are running
docker compose ps

# Access the application
# Dashboard: http://localhost
# Adminer: http://localhost:8080

# Generate traffic for log analysis
for i in {1..100}; do curl -s http://localhost/ >/dev/null; done

# Run monitoring scripts
docker compose exec php /scripts/health-check.sh
docker compose exec php /scripts/log-analyzer.sh
docker compose exec php /scripts/backup.sh
```

**Magyar:**
```bash
# Klónozd a repository-t
git clone https://github.com/yourusername/linux-sysadmin-portfolio.git
cd linux-sysadmin-portfolio/project-01-lamp-monitoring

# Másold és konfiguráld a környezetet
cp .env.example .env
# Szerkeszd a .env fájlt a jelszavakkal

# Indítsd el az összes szolgáltatást
docker compose up -d

# Ellenőrizd, hogy a szolgáltatások futnak
docker compose ps

# Alkalmazás elérése
# Vezérlőpult: http://localhost
# Adminer: http://localhost:8080

# Generálj forgalmat a naplóelemzéshez
for i in {1..100}; do curl -s http://localhost/ >/dev/null; done

# Futtasd a monitoring scripteket
docker compose exec php /scripts/health-check.sh
docker compose exec php /scripts/log-analyzer.sh
docker compose exec php /scripts/backup.sh
```

---

## Services | Szolgáltatások

| Service | Port | Description (EN) | Leírás (HU) |
|---------|------|------------------|-------------|
| Nginx | 80, 443 | Reverse proxy and static file server | Reverse proxy és statikus fájl szerver |
| PHP-FPM | 9000 | PHP 8.2 application processor (Debian-based) | PHP 8.2 alkalmazás feldolgozó (Debian-alapú) |
| MySQL | 3306 | MySQL 8.0 database server (internal only) | MySQL 8.0 adatbázis szerver (csak belső) |
| Adminer | 8080 | Database management interface | Adatbázis kezelő felület |

---

## Configuration | Konfiguráció

### Environment Variables | Környezeti Változók

| Variable | Default | Description (EN) | Leírás (HU) |
|----------|---------|------------------|-------------|
| `PROJECT_NAME` | `lamp-monitoring` | Project name for containers | Konténerek projekt neve |
| `TZ` | `UTC` | Timezone | Időzóna |
| `DB_ROOT_PASSWORD` | (required) | MySQL root password | MySQL root jelszó |
| `DB_NAME` | `lampdb` | Database name | Adatbázis név |
| `DB_USER` | `lampuser` | Database user | Adatbázis felhasználó |
| `DB_PASSWORD` | (required) | Database password | Adatbázis jelszó |
| `ERROR_THRESHOLD` | `5.0` | Critical error rate threshold (%) | Kritikus hibaarány küszöb (%) |
| `WARNING_THRESHOLD` | `2.0` | Warning error rate threshold (%) | Figyelmeztetési hibaarány küszöb (%) |
| `RETENTION_DAYS` | `7` | Backup retention period (days) | Biztonsági másolat megőrzési időszak (nap) |

### Volumes | Kötetek

| Volume | Purpose (EN) | Cél (HU) |
|--------|--------------|----------|
| `lamp-db-data` | MySQL persistent storage | MySQL állandó tárolás |
| `lamp-nginx-logs` | Shared logs for analysis | Megosztott naplók elemzéshez |
| `lamp-backups` | Automated backup storage | Automatikus biztonsági másolat tárolás |

---

## Bash Scripts | Bash Scriptek

### log-analyzer.sh ⭐ PRIMARY SHOWCASE

**English:**
Advanced log analysis script (318 lines) that parses Nginx access logs, calculates comprehensive statistics, generates JSON reports, and sends alerts when error rates exceed configured thresholds. This is the primary showcase of advanced Bash scripting skills.

**Magyar:**
Haladó naplóelemző script (318 sor), amely elemzi az Nginx hozzáférési naplókat, átfogó statisztikákat számol, JSON jelentéseket generál, és riasztásokat küld, ha a hibaarány meghaladja a beállított küszöbértékeket. Ez az elsődleges bemutató a haladó Bash scriptelési készségekről.

**Skills Demonstrated | Bemutatott Készségek:**
- Associative arrays (`declare -A`) for data aggregation
- Regex pattern matching with `grep -oP`
- AWK field extraction and processing
- bc floating point calculations
- JSON generation using heredocs
- Conditional alerting logic
- Webhook integration for monitoring
- Structured logging with colored output

**Usage | Használat:**
```bash
# Run analysis
docker compose exec php /scripts/log-analyzer.sh

# View generated reports
docker compose exec php ls /var/reports/

# View JSON report
docker compose exec php cat /var/reports/analysis_*.json | jq .
```

**Example Output:**
```json
{
    "timestamp": "2025-11-30T12:00:00Z",
    "summary": {
        "total_requests": 1247,
        "unique_ips": 42,
        "unique_endpoints": 8
    },
    "status_codes": {
        "success_2xx": 1156,
        "redirect_3xx": 45,
        "client_error_4xx": 38,
        "server_error_5xx": 8
    },
    "metrics": {
        "error_rate_percent": 0.64,
        "success_rate_percent": 92.70
    }
}
```

---

### backup.sh

**English:**
Automated MySQL backup script (215 lines) with compression, retention policy, integrity verification using checksums, and manifest generation. Creates compressed backups, verifies integrity, cleans up old backups based on retention policy, and maintains a JSON manifest.

**Magyar:**
Automatizált MySQL biztonsági mentési script (215 sor) tömörítéssel, megőrzési szabályzattal, integritás ellenőrzéssel ellenőrző összegekkel, és manifest generálással. Tömörített biztonsági másolatokat hoz létre, ellenőrzi az integritást, tisztítja a régi mentéseket a megőrzési szabályzat alapján, és JSON manifest-et tart fenn.

**Skills Demonstrated | Bemutatott Készségek:**
- MySQL backup procedures with mysqldump
- File compression with gzip
- Retention policy implementation using find with -mtime
- Integrity verification with sha256sum
- JSON manifest generation
- Error handling and logging

**Usage | Használat:**
```bash
# Run backup
docker compose exec php /scripts/backup.sh

# View backup manifest
docker compose exec php cat /backups/backup_manifest.json | jq .

# List all backups
docker compose exec php ls -lh /backups/
```

---

### health-check.sh

**English:**
Service health monitoring script (195 lines) that checks the health of all LAMP stack services (Nginx, PHP-FPM, MySQL), generates JSON status reports, and provides appropriate exit codes for monitoring integration. Measures response times and uptime.

**Magyar:**
Szolgáltatás állapotfigyelő script (195 sor), amely ellenőrzi az összes LAMP stack szolgáltatás állapotát (Nginx, PHP-FPM, MySQL), JSON állapotjelentéseket generál, és megfelelő kilépési kódokat biztosít a monitoring integrációhoz. Méri a válaszidőket és üzemidőt.

**Skills Demonstrated | Bemutatott Készségek:**
- Multi-service health testing
- Network connectivity checks with curl
- MySQL connectivity testing
- Response time measurement
- JSON status reporting
- Proper exit codes for monitoring

**Usage | Használat:**
```bash
# Run health check
docker compose exec php /scripts/health-check.sh

# Check exit code
docker compose exec php /scripts/health-check.sh; echo "Exit code: $?"
```

**Example Output:**
```json
{
    "timestamp": "2025-11-30T12:00:00Z",
    "status": "healthy",
    "checks": {
        "nginx": {
            "status": "ok",
            "response_time_ms": 23
        },
        "php": {
            "status": "ok",
            "version": "8.2.13"
        },
        "mysql": {
            "status": "ok",
            "uptime_seconds": 3600,
            "response_time_ms": 15
        }
    }
}
```

---

## Skills Demonstrated | Bemutatott Készségek

### Technical Competencies | Technikai Kompetenciák

| Skill | Where Demonstrated | Hol mutatva |
|-------|-------------------|-------------|
| **Debian Linux** | Custom PHP Dockerfile (debian:bookworm-slim) | Egyedi PHP Dockerfile (debian:bookworm-slim) |
| **LAMP Stack** | Full Nginx + PHP-FPM + MySQL implementation | Teljes Nginx + PHP-FPM + MySQL implementáció |
| **Bash - Associative Arrays** | log-analyzer.sh (lines 69-73) | log-analyzer.sh (69-73. sorok) |
| **Bash - Regex** | log-analyzer.sh (grep -oP patterns) | log-analyzer.sh (grep -oP minták) |
| **Bash - JSON Generation** | All scripts use heredoc JSON | Minden script heredoc JSON-t használ |
| **Docker/Compose** | Multi-container orchestration, health checks | Multi-konténer orkesztráció, health check-ek |
| **TCP/IP Networking** | Frontend/backend networks, reverse proxy | Frontend/backend hálózatok, reverse proxy |
| **MySQL Administration** | backup.sh (mysqldump, retention) | backup.sh (mysqldump, megőrzés) |
| **Log Analysis** | log-analyzer.sh (comprehensive parsing) | log-analyzer.sh (átfogó elemzés) |
| **System Monitoring** | health-check.sh (all services) | health-check.sh (minden szolgáltatás) |
| **Security** | Backend network isolation, no hardcoded secrets | Backend hálózati elkülönítés, nincs beégetett titok |
| **Documentation** | Bilingual README, code comments | Kétnyelvű README, kód kommentek |

### Checklist

- [x] Docker containerization | Docker konténerizáció
- [x] Nginx reverse proxy configuration | Nginx reverse proxy konfiguráció
- [x] MySQL database management | MySQL adatbázis kezelés
- [x] Advanced Bash scripting (318 lines) | Haladó Bash scriptelés (318 sor)
- [x] Log analysis and monitoring | Naplóelemzés és monitoring
- [x] Automated backup systems | Automatizált biztonsági mentési rendszerek
- [x] Health check automation | Health check automatizálás
- [x] JSON report generation | JSON jelentés generálás
- [x] Network security (internal backend) | Hálózati biztonság (belső backend)
- [x] Environment-based configuration | Környezet-alapú konfiguráció

---

## Troubleshooting | Hibaelhárítás

### Common Issues | Gyakori Problémák

**Issue: Port 80 or 8080 already in use**

**English:**
Check for conflicting services and modify port mappings in `.env` file.

```bash
# Check what's using port 80
sudo ss -tlnp | grep :80

# Use alternative ports in .env
HTTP_PORT=8000
ADMINER_PORT=8081
```

**Magyar:**
Ellenőrizd az ütköző szolgáltatásokat és módosítsd a port megfeleltetéseket a `.env` fájlban.

---

**Issue: MySQL container fails to start**

**English:**
Check if the database volume has correct permissions or remove old volumes.

```bash
# Remove volumes and restart
docker compose down -v
docker compose up -d
```

**Magyar:**
Ellenőrizd, hogy az adatbázis kötet megfelelő jogosultságokkal rendelkezik, vagy távolítsd el a régi köteteket.

---

**Issue: Scripts cannot access logs**

**English:**
Ensure the nginx_logs volume is properly shared between containers.

```bash
# Verify volume mounts
docker compose exec php ls -la /var/log/nginx/

# Generate traffic to create logs
for i in {1..50}; do curl -s http://localhost/ >/dev/null; done
```

**Magyar:**
Győződj meg róla, hogy a nginx_logs kötet megfelelően meg van osztva a konténerek között.

---

## Development | Fejlesztés

### Running Tests | Tesztek Futtatása

```bash
# Validate Docker Compose configuration
docker compose config

# Test all scripts
docker compose exec php /scripts/health-check.sh
docker compose exec php /scripts/log-analyzer.sh
docker compose exec php /scripts/backup.sh

# Validate Bash scripts with shellcheck
shellcheck scripts/*.sh
```

### Building Custom Images | Egyedi Image-ek Építése

```bash
# Rebuild all containers
docker compose build

# Rebuild specific service
docker compose build php

# Rebuild without cache
docker compose build --no-cache
```

### Viewing Logs | Naplók Megtekintése

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f php
docker compose logs -f nginx

# Last 100 lines
docker compose logs --tail=100
```

---

## License | Licenc

MIT License - See [LICENSE](../LICENSE) for details.

MIT Licenc - Részletekért lásd a [LICENSE](../LICENSE) fájlt.

---

## Author | Szerző

Part of the Linux System Administrator Portfolio

A Linux Rendszergazda Portfólió része

- GitHub: [@yourusername](https://github.com/yourusername)
- Project Repository: [linux-sysadmin-portfolio](https://github.com/yourusername/linux-sysadmin-portfolio)
