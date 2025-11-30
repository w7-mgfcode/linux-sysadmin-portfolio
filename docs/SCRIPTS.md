# Bash Scripts Documentation | Bash Script Dokumentáció

## Overview | Áttekintés

**English:**
This document provides comprehensive documentation for all Bash monitoring scripts in the Linux System Administrator Portfolio. All scripts follow strict coding standards with error handling, structured logging, and production-ready features.

**Magyar:**
Ez a dokumentum átfogó dokumentációt nyújt a Linux Rendszergazda Portfólió összes Bash monitoring scriptjéhez. Minden script szigorú kódolási szabványokat követ hibakezeléssel, strukturált naplózással és produkció-kész funkciókkal.

---

## Project 01: LAMP Stack Scripts

### Script Overview | Script Áttekintés

| Script | Lines | Purpose (EN) | Cél (HU) |
|--------|-------|--------------|----------|
| log-analyzer.sh | 318 | Advanced log analysis with JSON reports | Haladó naplóelemzés JSON jelentésekkel |
| backup.sh | 215 | Automated MySQL backups with retention | Automatizált MySQL mentések megőrzéssel |
| health-check.sh | 195 | Multi-service health monitoring | Több szolgáltatás állapotfigyelés |

---

## log-analyzer.sh ⭐ PRIMARY SHOWCASE

### Description | Leírás

**English:**
A sophisticated log analysis tool that parses Nginx access logs, calculates comprehensive statistics, generates JSON reports, and sends alerts when error rates exceed configured thresholds. Demonstrates advanced Bash scripting techniques including associative arrays, regex pattern matching, AWK processing, and bc floating-point calculations.

**Magyar:**
Egy kifinomult naplóelemző eszköz, amely elemzi az Nginx hozzáférési naplókat, átfogó statisztikákat számol, JSON jelentéseket generál, és riasztásokat küld, ha a hibaarány meghaladja a beállított küszöbértékeket. Haladó Bash scriptelési technikákat mutat be, beleértve az asszociatív tömböket, regex mintaillesztést, AWK feldolgozást és bc lebegőpontos számításokat.

### Features | Funkciók

**English:**
- Parse Nginx access logs with multiple data points
- Aggregate statistics using associative arrays
- Calculate error rates with bc floating-point math
- Generate JSON reports with heredocs
- Send webhook alerts for threshold violations
- Color-coded terminal output
- Configurable via environment variables
- Handles missing log files gracefully

**Magyar:**
- Nginx hozzáférési naplók elemzése több adatponttal
- Statisztikák aggregálása asszociatív tömbök használatával
- Hibaarányok számítása bc lebegőpontos matematikával
- JSON jelentések generálása heredoc-kal
- Webhook riasztások küldése küszöbérték túllépés esetén
- Színkódolt terminál kimenet
- Konfigurálható környezeti változókon keresztül
- Kecsesen kezeli a hiányzó naplófájlokat

### Usage | Használat

```bash
# Basic usage | Alap használat
docker compose exec php /scripts/log-analyzer.sh

# With custom log directory | Egyedi napló könyvtárral
LOG_DIR=/custom/path docker compose exec php /scripts/log-analyzer.sh

# With webhook alerts | Webhook riasztásokkal
WEBHOOK_URL=https://hooks.slack.com/services/XXX docker compose exec php /scripts/log-analyzer.sh
```

### Environment Variables | Környezeti Változók

| Variable | Default | Description (EN) | Leírás (HU) |
|----------|---------|------------------|-------------|
| `LOG_DIR` | `/var/log/nginx` | Directory containing logs | Naplókat tartalmazó könyvtár |
| `ACCESS_LOG` | `${LOG_DIR}/access.log` | Access log file path | Hozzáférési napló útvonala |
| `ERROR_LOG` | `${LOG_DIR}/error.log` | Error log file path | Hibanapló útvonala |
| `REPORT_DIR` | `/var/reports` | Report output directory | Jelentés kimeneti könyvtár |
| `ERROR_THRESHOLD` | `5.0` | Critical error rate (%) | Kritikus hibaarány (%) |
| `WARNING_THRESHOLD` | `2.0` | Warning error rate (%) | Figyelmeztetési hibaarány (%) |
| `WEBHOOK_URL` | - | Alert webhook URL (optional) | Riasztási webhook URL (opcionális) |

### Skills Demonstrated | Bemutatott Készségek

**Technical Skills:**
- Associative arrays (`declare -A`) for data aggregation
- Regex pattern matching with `grep -oP` (Perl-compatible)
- AWK field extraction and processing
- bc for floating-point calculations
- Heredoc syntax for clean JSON generation
- Process substitution with `while read` loops
- Conditional logic with bc comparisons
- Signal handling and error management
- Structured logging with timestamps and colors

### Output Example | Kimenet Példa

**Console Output | Konzol Kimenet:**
```
[2025-11-30 12:00:00] [GREEN] Log Analyzer v1.0.0
[2025-11-30 12:00:01] [BLUE] Analyzing access logs: /var/log/nginx/access.log
[2025-11-30 12:00:02] [GREEN] Analyzed 1247 requests
[2025-11-30 12:00:02] [GREEN] Report generated: /var/reports/analysis_2025-11-30_12-00-00.json

=== Analysis Summary ===
[2025-11-30 12:00:02] [GREEN] Total Requests: 1247
[2025-11-30 12:00:02] [GREEN] Success (2xx): 1156
[2025-11-30 12:00:02] [YELLOW] Client Errors (4xx): 83
[2025-11-30 12:00:02] [RED] Server Errors (5xx): 8
[2025-11-30 12:00:02] [BLUE] Error Rate: 0.64%
```

**JSON Report | JSON Jelentés:**
```json
{
    "timestamp": "2025-11-30T12:00:00Z",
    "analysis_period": {
        "start": "30/Nov/2025:10:00:00",
        "end": "30/Nov/2025:12:00:00"
    },
    "summary": {
        "total_requests": 1247,
        "unique_ips": 42,
        "unique_endpoints": 8
    },
    "status_codes": {
        "success_2xx": 1156,
        "redirect_3xx": 0,
        "client_error_4xx": 83,
        "server_error_5xx": 8
    },
    "metrics": {
        "error_rate_percent": 0.64,
        "success_rate_percent": 92.70
    },
    "top_ips": {
        "192.168.1.100": 523,
        "10.0.0.50": 312,
        "172.16.0.25": 145
    },
    "top_endpoints": {
        "/": 856,
        "/health.php": 234,
        "/api/stats": 89
    },
    "hourly_traffic": {
        "10:00": 387,
        "11:00": 512,
        "12:00": 348
    }
}
```

### Code Highlights | Kód Kiemelések

**Associative Arrays | Asszociatív Tömbök:**
```bash
# Data structures for aggregation
declare -A STATUS_CATEGORIES=(
    [2xx]=0 [3xx]=0 [4xx]=0 [5xx]=0
)
declare -A ip_counts
declare -A endpoint_counts
declare -A hourly_traffic
```

**Regex Pattern Matching | Regex Mintaillesztés:**
```bash
# Extract hour from timestamp using Perl-compatible regex
local hour=$(echo "$line" | grep -oP '\d{2}(?=:\d{2}:\d{2})' | head -1)
```

**Floating Point Calculations | Lebegőpontos Számítások:**
```bash
# Calculate error rate with bc
error_rate=$(echo "scale=2; ${STATUS_CATEGORIES[5xx]} * 100 / $total" | bc)
```

---

## backup.sh

### Description | Leírás

**English:**
Automated MySQL backup script with compression, retention policy, integrity verification using checksums, and manifest generation. Creates compressed database dumps, verifies their integrity, removes old backups based on configured retention period, and maintains a JSON manifest of all backups.

**Magyar:**
Automatizált MySQL biztonsági mentési script tömörítéssel, megőrzési szabályzattal, integritás ellenőrzéssel ellenőrző összegekkel, és manifest generálással. Tömörített adatbázis dump-okat hoz létre, ellenőrzi azok integritását, eltávolítja a régi mentéseket a beállított megőrzési időszak alapján, és JSON manifest-et tart fenn az összes mentésről.

### Features | Funkciók

**English:**
- MySQL database backup using mysqldump
- gzip compression for space efficiency
- Retention policy (cleanup old backups)
- SHA256 checksum verification
- JSON manifest generation
- Connection testing before backup
- Detailed logging with timestamps

**Magyar:**
- MySQL adatbázis mentés mysqldump használatával
- gzip tömörítés a helytakarékosság érdekében
- Megőrzési szabályzat (régi mentések tisztítása)
- SHA256 ellenőrző összeg verifikáció
- JSON manifest generálás
- Kapcsolat tesztelés mentés előtt
- Részletes naplózás időbélyeggel

### Usage | Használat

```bash
# Manual backup | Manuális mentés
docker compose exec php /scripts/backup.sh

# Automated backup (cron) | Automatizált mentés (cron)
# Daily at 2 AM | Naponta hajnali 2 órakor
0 2 * * * docker compose exec -T php /scripts/backup.sh

# With custom retention | Egyedi megőrzéssel
RETENTION_DAYS=14 docker compose exec php /scripts/backup.sh
```

### Environment Variables | Környezeti Változók

| Variable | Default | Description (EN) | Leírás (HU) |
|----------|---------|------------------|-------------|
| `MYSQL_HOST` | `mysql` | MySQL hostname | MySQL hostnév |
| `MYSQL_DATABASE` | `lampdb` | Database name to backup | Mentendő adatbázis neve |
| `MYSQL_USER` | `root` | MySQL user | MySQL felhasználó |
| `MYSQL_PASSWORD` | (from .env) | MySQL password | MySQL jelszó |
| `BACKUP_DIR` | `/backups` | Backup storage directory | Biztonsági mentés könyvtár |
| `RETENTION_DAYS` | `7` | Days to keep backups | Napok a mentések megőrzésére |

### Output Files | Kimeneti Fájlok

**Backup Files | Biztonsági Mentés Fájlok:**
```
/backups/
├── lampdb_20251130_020000.sql.gz
├── lampdb_20251129_020000.sql.gz
├── lampdb_20251128_020000.sql.gz
└── backup_manifest.json
```

**Manifest Example | Manifest Példa:**
```json
{
    "generated_at": "2025-11-30T02:00:00Z",
    "retention_days": 7,
    "backup_directory": "/backups",
    "backups": [
        {
            "filename": "lampdb_20251130_020000.sql.gz",
            "timestamp": "2025-11-30T02:00:00",
            "size_bytes": 2457600
        },
        {
            "filename": "lampdb_20251129_020000.sql.gz",
            "timestamp": "2025-11-29T02:00:00",
            "size_bytes": 2445312
        }
    ]
}
```

### Skills Demonstrated | Bemutatott Készségek

- MySQL backup procedures (mysqldump)
- File compression (gzip)
- Retention policy implementation (find with -mtime)
- Integrity verification (sha256sum, gzip -t)
- JSON manifest generation
- Error handling and logging
- Timestamp management

---

## health-check.sh

### Description | Leírás

**English:**
Multi-service health monitoring script that checks the health of all LAMP stack services (Nginx, PHP-FPM, MySQL), measures response times, generates JSON status reports, and provides appropriate exit codes for monitoring system integration.

**Magyar:**
Több szolgáltatás állapotfigyelő script, amely ellenőrzi az összes LAMP stack szolgáltatás állapotát (Nginx, PHP-FPM, MySQL), méri a válaszidőket, JSON állapotjelentéseket generál, és megfelelő kilépési kódokat biztosít a monitoring rendszer integrációhoz.

### Features | Funkciók

**English:**
- Check Nginx health endpoint
- Verify PHP-FPM functionality
- Test MySQL connectivity
- Measure response times (milliseconds)
- Query MySQL uptime
- Generate JSON status report
- Exit codes for monitoring integration
- Colored terminal output

**Magyar:**
- Nginx health végpont ellenőrzése
- PHP-FPM funkcionalitás verifikálása
- MySQL kapcsolat tesztelése
- Válaszidők mérése (milliszekundum)
- MySQL üzemidő lekérdezése
- JSON állapotjelentés generálása
- Kilépési kódok monitoring integrációhoz
- Színkódolt terminál kimenet

### Usage | Használat

```bash
# Run health check | Állapot ellenőrzés futtatása
docker compose exec php /scripts/health-check.sh

# Check exit code | Kilépési kód ellenőrzése
docker compose exec php /scripts/health-check.sh
echo "Exit code: $?"
# 0 = all healthy | minden egészséges
# N = N services failed | N szolgáltatás hibás

# Automated monitoring (cron) | Automatizált monitoring (cron)
*/5 * * * * docker compose exec -T php /scripts/health-check.sh >> /var/log/health.log
```

### Environment Variables | Környezeti Változók

| Variable | Default | Description (EN) | Leírás (HU) |
|----------|---------|------------------|-------------|
| `NGINX_URL` | `http://nginx/health` | Nginx health endpoint | Nginx health végpont |
| `PHP_FPM_HOST` | `localhost` | PHP-FPM hostname | PHP-FPM hostnév |
| `MYSQL_HOST` | `mysql` | MySQL hostname | MySQL hostnév |
| `MYSQL_USER` | `lampuser` | MySQL user for checks | MySQL felhasználó ellenőrzéshez |
| `MYSQL_PASSWORD` | (from .env) | MySQL password | MySQL jelszó |
| `CURL_TIMEOUT` | `5` | HTTP timeout (seconds) | HTTP időtúllépés (másodperc) |
| `MYSQL_TIMEOUT` | `5` | MySQL timeout (seconds) | MySQL időtúllépés (másodperc) |

### Output Example | Kimenet Példa

**Console Output | Konzol Kimenet:**
```
[2025-11-30 12:00:00] [GREEN] Health Check v1.0.0
[2025-11-30 12:00:00] [BLUE] Checking Nginx...
[2025-11-30 12:00:00] [GREEN] ✓ Nginx is healthy (23ms)
[2025-11-30 12:00:00] [BLUE] Checking PHP-FPM...
[2025-11-30 12:00:00] [GREEN] ✓ PHP-FPM is healthy (v8.2.13)
[2025-11-30 12:00:00] [BLUE] Checking MySQL...
[2025-11-30 12:00:00] [GREEN] ✓ MySQL is healthy (uptime: 3600s)
[2025-11-30 12:00:00] [GREEN] All services are healthy
```

**JSON Report | JSON Jelentés:**
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

### Exit Codes | Kilépési Kódok

| Exit Code | Meaning (EN) | Jelentés (HU) |
|-----------|--------------|---------------|
| 0 | All services healthy | Minden szolgáltatás egészséges |
| 1 | 1 service failed | 1 szolgáltatás hibás |
| 2 | 2 services failed | 2 szolgáltatás hibás |
| 3 | 3 services failed | 3 szolgáltatás hibás |

### Skills Demonstrated | Bemutatott Készségek

- Multi-service health testing
- Network connectivity checks (curl)
- MySQL connectivity and query testing
- Response time measurement (milliseconds)
- JSON status reporting
- Exit code conventions for monitoring
- Colored terminal output with ANSI codes
- Error handling and graceful degradation

---

## Common Standards Across All Scripts | Közös Szabványok Minden Scriptnél

### Error Handling | Hibakezelés

```bash
# Strict error handling
set -euo pipefail
```

**English:**
- `set -e`: Exit on error
- `set -u`: Exit on undefined variable
- `set -o pipefail`: Fail on pipe errors

**Magyar:**
- `set -e`: Kilépés hiba esetén
- `set -u`: Kilépés nem definiált változó esetén
- `set -o pipefail`: Hiba pipe hibák esetén

### Logging Function | Naplózási Függvény

```bash
# Color-coded logging
declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [NC]='\033[0m'
)

log() {
    local level=$1
    shift
    echo -e "${COLORS[$level]}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*${COLORS[NC]}"
}
```

### Configuration Pattern | Konfigurációs Minta

```bash
# All configuration via environment variables with defaults
readonly SCRIPT_VERSION="1.0.0"
readonly CONFIG_VAR="${CONFIG_VAR:-default_value}"
```

### JSON Generation Pattern | JSON Generálási Minta

```bash
# Clean JSON generation with heredoc
cat > "$output_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "data": "value"
}
EOF
```

---

## Testing Scripts | Scriptek Tesztelése

### Syntax Validation | Szintaxis Validáció

```bash
# Check bash syntax | Bash szintaxis ellenőrzése
bash -n scripts/*.sh

# Run shellcheck | Shellcheck futtatása
shellcheck scripts/*.sh
```

### Manual Testing | Manuális Tesztelés

```bash
# Test in container | Tesztelés konténerben
docker compose exec php /scripts/health-check.sh
docker compose exec php /scripts/log-analyzer.sh
docker compose exec php /scripts/backup.sh

# Verify output | Kimenet ellenőrzése
docker compose exec php ls -lh /backups/
docker compose exec php ls -lh /var/reports/
```

---

## Automation with Cron | Automatizálás Cron-nal

### Recommended Schedule | Ajánlott Ütemezés

```bash
# Health check every 5 minutes | Állapotellenőrzés 5 percenként
*/5 * * * * cd /path/to/project-01-lamp-monitoring && docker compose exec -T php /scripts/health-check.sh >> /var/log/health.log 2>&1

# Log analysis every hour | Naplóelemzés óránként
0 * * * * cd /path/to/project-01-lamp-monitoring && docker compose exec -T php /scripts/log-analyzer.sh >> /var/log/analysis.log 2>&1

# Backup daily at 2 AM | Biztonsági mentés naponta hajnali 2 órakor
0 2 * * * cd /path/to/project-01-lamp-monitoring && docker compose exec -T php /scripts/backup.sh >> /var/log/backup.log 2>&1
```

---

## License | Licenc

MIT License - See [LICENSE](../LICENSE) for details.

MIT Licenc - Részletekért lásd a [LICENSE](../LICENSE) fájlt.
