# Architecture Overview | Architektúra Áttekintés

## Introduction | Bevezetés

**English:**
This document provides a comprehensive architectural overview of the Linux System Administrator Portfolio projects. Each project demonstrates production-ready containerized infrastructure with a focus on security, maintainability, and operational excellence.

**Magyar:**
Ez a dokumentum átfogó architektúra áttekintést nyújt a Linux Rendszergazda Portfólió projektekről. Minden projekt produkció-kész konténerizált infrastruktúrát mutat be, a biztonságra, karbantarthatóságra és működési kiválóságra összpontosítva.

---

## Project 01: LAMP Stack with Real-Time Monitoring

### High-Level Architecture | Magas Szintű Architektúra

```
┌─────────────────────────────────────────────────────────────────────┐
│                         External Access                              │
│                    (Internet / Local Network)                        │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                    ┌───────────▼────────────┐
                    │   Host Machine         │
                    │   Docker Engine        │
                    └───────────┬────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        │                       │                       │
┌───────▼────────┐      ┌──────▼───────┐      ┌───────▼────────┐
│  Frontend Net  │      │  Backend Net  │      │   Volumes      │
│   (bridge)     │      │  (internal)   │      │  (persistent)  │
└────────────────┘      └───────────────┘      └────────────────┘
```

### Container Architecture | Konténer Architektúra

```
┌─────────────────────────────────────────────────────────────────────┐
│                     LAMP Stack Containers                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  Nginx (nginx:1.25-alpine)                                 │    │
│  │  ───────────────────────────────────────────────────────   │    │
│  │  Role: Reverse Proxy & Web Server                          │    │
│  │  Ports: 80 (HTTP), 443 (HTTPS)                            │    │
│  │  Networks: frontend                                         │    │
│  │  Volumes: nginx_logs (shared), app (read-only)            │    │
│  └───────────────────┬────────────────────────────────────────┘    │
│                      │ FastCGI (port 9000)                         │
│                      ▼                                              │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  PHP-FPM (custom: php:8.2-fpm-bookworm)                    │    │
│  │  ───────────────────────────────────────────────────────   │    │
│  │  Role: Application Server                                  │    │
│  │  Networks: frontend, backend                               │    │
│  │  Volumes: app, scripts (ro), nginx_logs (ro), backups     │    │
│  │  Tools: mysql-client, bc, jq, curl                        │    │
│  └───────────────────┬────────────────────────────────────────┘    │
│                      │ MySQL Protocol (port 3306)                  │
│                      ▼                                              │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  MySQL (mysql:8.0)                                          │    │
│  │  ───────────────────────────────────────────────────────   │    │
│  │  Role: Database Server                                      │    │
│  │  Networks: backend (internal only)                          │    │
│  │  Volumes: db_data (persistent)                             │    │
│  │  Isolation: NOT exposed to host                            │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  Adminer (adminer:4.8.1)                                    │    │
│  │  ───────────────────────────────────────────────────────   │    │
│  │  Role: Database Management UI                               │    │
│  │  Port: 127.0.0.1:8080 (HTTP, loopback only)               │    │
│  │  Networks: frontend, backend                                │    │
│  │  Reason: frontend to publish port, backend to reach MySQL │    │
│  │  Note: Development/admin tool only                         │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Network Topology | Hálózati Topológia

**English:**

The LAMP stack uses a dual-network architecture for security:

1. **Frontend Network (bridge mode)**
   - Accessible from host
   - Contains: Nginx, PHP-FPM, Adminer
   - Allows external HTTP/HTTPS traffic
   - Enables inter-container communication
   - Adminer joins this network so its published port can be reached from the host

2. **Backend Network (internal mode)**
   - NOT accessible from host
   - Contains: PHP-FPM, MySQL, Adminer
   - Isolated database access
   - Security: MySQL cannot be directly accessed from outside
   - Adminer also joins this network so it can reach MySQL (which is backend-only)

**Magyar:**

A LAMP stack kettős hálózati architektúrát használ a biztonság érdekében:

1. **Frontend Hálózat (bridge mód)**
   - Elérhető a host-ról
   - Tartalmazza: Nginx, PHP-FPM, Adminer
   - Engedélyezi a külső HTTP/HTTPS forgalmat
   - Lehetővé teszi a konténerek közötti kommunikációt
   - Az Adminer ehhez a hálózathoz csatlakozik, hogy a publikált portja elérhető legyen a host-ról

2. **Backend Hálózat (internal mód)**
   - NEM elérhető a host-ról
   - Tartalmazza: PHP-FPM, MySQL, Adminer
   - Elkülönített adatbázis hozzáférés
   - Biztonság: A MySQL nem érhető el közvetlenül kívülről
   - Az Adminer ehhez a hálózathoz is csatlakozik, hogy elérje a MySQL-t (amely csak backend)

```
┌──────────────────────────────────────────────────────┐
│                   Host Machine                        │
│                                                       │
│   Port 80 ──────────┐                                │
│   Port 443 ─────────┼──▶ Frontend Network            │
│   127.0.0.1:8080 ───┘     │  (Adminer, loopback only)│
│                           │                          │
│   ┌───────────────────────▼─────────────────┐        │
│   │  Frontend Network (bridge)              │        │
│   │  ────────────────────────────────────   │        │
│   │  - Nginx       (accessible)            │        │
│   │  - PHP-FPM     (accessible)            │        │
│   │  - Adminer     (accessible)            │        │
│   └───────────────────┬─────────────────────┘        │
│                       │                              │
│                       │ Internal routing             │
│                       │                              │
│   ┌───────────────────▼─────────────────┐            │
│   │  Backend Network (internal)         │            │
│   │  ────────────────────────────────   │            │
│   │  - PHP-FPM     (bridged)           │            │
│   │  - MySQL       (isolated)          │            │
│   │  - Adminer     (bridged)           │            │
│   └─────────────────────────────────────┘            │
│                                                       │
└──────────────────────────────────────────────────────┘
```

### Data Flow | Adatfolyam

**English:**

1. **HTTP Request Flow:**
   ```
   Client → Nginx (port 80/443)
        → FastCGI → PHP-FPM (port 9000)
             → MySQL Query → MySQL (port 3306)
             ← MySQL Response
        ← PHP Response
   ← HTTP Response
   ```

2. **Logging Flow:**
   ```
   Nginx → access.log/error.log (nginx_logs volume)
        → PHP-FPM reads logs
             → log-analyzer.sh processes
                  → JSON report generated
                       → Alert sent (optional webhook)
   ```

3. **Backup Flow:**
   ```
   Cron/Manual trigger
        → backup.sh script
             → mysqldump (MySQL)
                  → gzip compression
                       → /backups volume
                            → Retention cleanup
                                 → Manifest update
   ```

**Magyar:**

1. **HTTP Kérés Folyamat:**
   ```
   Kliens → Nginx (80/443 port)
        → FastCGI → PHP-FPM (9000 port)
             → MySQL Lekérdezés → MySQL (3306 port)
             ← MySQL Válasz
        ← PHP Válasz
   ← HTTP Válasz
   ```

2. **Naplózási Folyamat:**
   ```
   Nginx → access.log/error.log (nginx_logs kötet)
        → PHP-FPM beolvassa a naplókat
             → log-analyzer.sh feldolgozza
                  → JSON jelentés generálása
                       → Riasztás küldése (opcionális webhook)
   ```

3. **Biztonsági Mentés Folyamat:**
   ```
   Cron/Manuális indítás
        → backup.sh script
             → mysqldump (MySQL)
                  → gzip tömörítés
                       → /backups kötet
                            → Megőrzési tisztítás
                                 → Manifest frissítés
   ```

### Volume Architecture | Kötet Architektúra

```
┌─────────────────────────────────────────────────────────┐
│                    Persistent Volumes                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  lamp-db-data                                           │
│  ─────────────────────────────────────────────────────  │
│  Type: Named volume                                     │
│  Purpose: MySQL database persistence                    │
│  Mount: /var/lib/mysql (mysql container)               │
│  Backup: Included in backup.sh                         │
│                                                          │
│  lamp-nginx-logs (SHARED)                              │
│  ─────────────────────────────────────────────────────  │
│  Type: Named volume (shared between containers)         │
│  Purpose: Log aggregation and analysis                  │
│  Mounts:                                                │
│    - /var/log/nginx (nginx container, read-write)     │
│    - /var/log/nginx (php container, read-only)        │
│  Used by: log-analyzer.sh                              │
│                                                          │
│  lamp-backups                                           │
│  ─────────────────────────────────────────────────────  │
│  Type: Named volume                                     │
│  Purpose: Database backup storage                       │
│  Mount: /backups (php container)                       │
│  Managed by: backup.sh (retention policy)              │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Security Architecture | Biztonsági Architektúra

**English:**

**Network Isolation:**
- MySQL is on internal-only backend network
- No direct host access to MySQL port 3306
- Frontend services isolated from database

**Secrets Management:**
- All passwords via environment variables (.env)
- .env excluded from git (.gitignore)
- No hardcoded credentials in code

**Container Security:**
- PHP-FPM runs as non-root user (phpuser)
- Read-only mounts for scripts
- Minimal base images (Alpine, Debian-slim)

**Access Control:**
- Nginx health endpoint (no authentication)
- Adminer for development only (remove in production)
- Adminer port bound to 127.0.0.1 (loopback) so the DB admin UI is not exposed to untrusted networks
- Scripts require container exec access

**Magyar:**

**Hálózati Elkülönítés:**
- A MySQL csak belső backend hálózaton van
- Nincs közvetlen host hozzáférés a MySQL 3306 porthoz
- A frontend szolgáltatások elkülönítve az adatbázistól

**Titok Kezelés:**
- Minden jelszó környezeti változókon keresztül (.env)
- .env kizárva a git-ből (.gitignore)
- Nincs beégetett hitelesítő adat a kódban

**Konténer Biztonság:**
- A PHP-FPM nem root felhasználóként fut (phpuser)
- Csak olvasható mount-ok a scripteknél
- Minimális alap image-ek (Alpine, Debian-slim)

**Hozzáférés Vezérlés:**
- Nginx health végpont (nincs hitelesítés)
- Adminer csak fejlesztéshez (távolítsd el produkciós környezetből)
- Az Adminer port a 127.0.0.1-hez (loopback) van kötve, így az adatbázis admin felület nincs kitéve a nem megbízható hálózatoknak
- A scriptek konténer exec hozzáférést igényelnek

### Monitoring Architecture | Figyelési Architektúra

```
┌──────────────────────────────────────────────────────────────┐
│                   Monitoring Scripts                          │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  health-check.sh (195 lines)                                │
│  ───────────────────────────────────────────────────────────│
│  │                                                           │
│  ├─▶ Check Nginx (curl http://nginx/health)                │
│  ├─▶ Check PHP-FPM (php -v)                                │
│  ├─▶ Check MySQL (mysqladmin ping)                         │
│  │                                                           │
│  └─▶ Output: JSON status report                            │
│      Exit code: 0 (healthy) or N (N services failed)       │
│                                                               │
│  log-analyzer.sh (318 lines) ⭐ PRIMARY SHOWCASE            │
│  ───────────────────────────────────────────────────────────│
│  │                                                           │
│  ├─▶ Read nginx_logs volume (shared)                       │
│  ├─▶ Parse access.log with AWK/grep                        │
│  ├─▶ Aggregate data (associative arrays)                   │
│  │   - Status codes (2xx, 3xx, 4xx, 5xx)                  │
│  │   - Top IPs                                             │
│  │   - Top endpoints                                       │
│  │   - Hourly traffic                                      │
│  ├─▶ Calculate error rate (bc floating point)             │
│  ├─▶ Generate JSON report (heredoc)                        │
│  └─▶ Send alert if threshold exceeded (webhook)           │
│                                                               │
│  backup.sh (215 lines)                                      │
│  ───────────────────────────────────────────────────────────│
│  │                                                           │
│  ├─▶ Check MySQL connectivity                              │
│  ├─▶ Execute mysqldump                                     │
│  ├─▶ Compress with gzip                                    │
│  ├─▶ Verify integrity (sha256sum)                          │
│  ├─▶ Cleanup old backups (find -mtime)                    │
│  └─▶ Generate manifest (JSON with all backups)            │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### Health Check Flow | Állapot Ellenőrzési Folyamat

```
Docker Compose health checks ──┬──▶ Nginx: nginx -t
                               │
                               ├──▶ PHP-FPM: php-fpm -t
                               │
                               └──▶ MySQL: mysqladmin ping

health-check.sh script ────────┬──▶ Nginx: curl health endpoint
                               │
                               ├──▶ PHP: php -v
                               │
                               └──▶ MySQL: mysqladmin ping
                                    └──▶ Query uptime

                               ▼
                          JSON Report
                               │
                               ├──▶ Console output (colored)
                               ├──▶ Exit code (monitoring integration)
                               └──▶ Timestamp and metrics
```

---

## Technology Stack | Technológiai Stack

### Container Images | Konténer Image-ek

| Component | Image | Version | Size | Purpose |
|-----------|-------|---------|------|---------|
| Nginx | nginx:1.25-alpine | Alpine-based | ~40MB | Web server |
| PHP-FPM | Custom Debian | Bookworm-slim | ~500MB | App server |
| MySQL | mysql:8.0 | Official | ~580MB | Database |
| Adminer | adminer:4.8.1 | Official | ~90MB | DB admin |

### Bash Scripts Technology | Bash Script Technológia

**Advanced Features Used:**
- Associative arrays (`declare -A`)
- Process substitution
- Regex pattern matching (grep -oP, grep -E)
- AWK field processing
- bc floating-point calculations
- Heredoc JSON generation
- Signal handling (trap)
- Color-coded logging

---

## Design Decisions | Tervezési Döntések

### Why Debian for PHP? | Miért Debian a PHP-nél?

**English:**
- Specification requirement (demonstrates Debian expertise)
- Better tool availability (bc, jq, mysql-client)
- Production-aligned (many enterprises use Debian)
- Stable, well-documented

**Magyar:**
- Specifikációs követelmény (Debian szakértelmet mutat)
- Jobb eszköz elérhetőség (bc, jq, mysql-client)
- Produkciós környezethez igazított (sok vállalat Debiant használ)
- Stabil, jól dokumentált

### Why Internal Backend Network? | Miért Belső Backend Hálózat?

**English:**
- Security: Database not exposed to host
- Production best practice
- Defense in depth strategy
- Demonstrates network security understanding
- Note: Adminer joins the backend network only to reach MySQL; it is never reachable from the host through the internal network, its UI is published solely via its loopback-bound frontend port (127.0.0.1:8080)

**Magyar:**
- Biztonság: Az adatbázis nincs kitéve a host-nak
- Produkciós legjobb gyakorlat
- Többrétegű védelmi stratégia
- Hálózati biztonsági ismeretet mutat
- Megjegyzés: Az Adminer csak a MySQL elérése miatt csatlakozik a backend hálózathoz; a belső hálózaton keresztül soha nem érhető el a host-ról, a felülete kizárólag a loopback-hez kötött frontend portján (127.0.0.1:8080) van publikálva

### Why Shared nginx_logs Volume? | Miért Megosztott nginx_logs Kötet?

**English:**
- Enables log analysis from PHP container
- Demonstrates volume sharing patterns
- Clean separation of concerns (Nginx logs, PHP analyzes)
- Read-only mount for PHP (security)

**Magyar:**
- Lehetővé teszi a naplóelemzést a PHP konténerből
- Kötet megosztási mintákat mutat
- Világos szétválasztás (Nginx naplóz, PHP elemez)
- Csak olvasható mount a PHP-nek (biztonság)

---

## Performance Considerations | Teljesítménybeli Megfontolások

**Resource Limits (docker-compose.yml):**
```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 512M
    reservations:
      cpus: '0.25'
      memory: 128M
```

**MySQL Buffer Pool:**
- Default: 256M (configured in custom.cnf)
- Recommendation: 50-80% of available RAM for production

**PHP Memory:**
- Default: 256M (configured in php.ini)
- Adjust based on application requirements

---

## Future Enhancements | Jövőbeli Fejlesztések

**English:**
- HTTPS with Let's Encrypt certificates
- Redis caching layer
- Prometheus/Grafana metrics
- Horizontal scaling with load balancer
- CI/CD pipeline integration

**Magyar:**
- HTTPS Let's Encrypt tanúsítványokkal
- Redis cache réteg
- Prometheus/Grafana metrikák
- Horizontális skálázás load balancer-rel
- CI/CD pipeline integráció

---

## License | Licenc

MIT License - See [LICENSE](../LICENSE) for details.

MIT Licenc - Részletekért lásd a [LICENSE](../LICENSE) fájlt.
