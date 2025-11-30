# Project 03: Infrastructure Automation Toolkit - Testing Guide

## Table of Contents | Tartalomjegyzék

- [Overview](#overview--áttekintés)
- [Test Environment](#test-environment--tesztkörnyezet)
- [Running Tests](#running-tests--tesztek-futtatása)
- [Manual Testing](#manual-testing--kézi-tesztelés)
- [Test Results](#test-results--teszteredmények)
- [Troubleshooting](#troubleshooting--hibaelhárítás)

---

## Overview | Áttekintés

**English:**
This document describes the testing infrastructure and procedures for the Infrastructure Automation Toolkit (Project 03). The project includes a Docker-based multi-OS test environment with 5 services and 6 automation scripts designed to run across Debian 12, Alpine 3.19, and Ubuntu 24.04.

**Magyar:**
Ez a dokumentum leírja az Infrastruktúra Automatizálási Eszköztár (3. Projekt) tesztelési infrastruktúráját és eljárásait. A projekt egy Docker-alapú multi-OS tesztkörnyezetet tartalmaz 5 szolgáltatással és 6 automatizálási scripttel, amelyek Debian 12, Alpine 3.19 és Ubuntu 24.04 rendszereken futnak.

---

## Test Environment | Tesztkörnyezet

### Docker Services | Docker Szolgáltatások

| Service | Base Image | Purpose (EN) | Cél (HU) |
|---------|------------|--------------|----------|
| **debian-target** | debian:bookworm-slim | Primary test target | Elsődleges teszt célpont |
| **alpine-target** | alpine:3.19 | Minimal environment testing | Minimális környezet tesztelése |
| **ubuntu-target** | ubuntu:24.04 | Enterprise environment testing | Vállalati környezet tesztelése |
| **test-webserver** | nginx:alpine | Network diagnostics target | Hálózati diagnosztikai célpont |
| **test-dns** | coredns/coredns | DNS resolution testing | DNS feloldás tesztelése |

### Network Configuration | Hálózati Konfiguráció

```
Network: infra-test-net (172.30.0.0/24)
├── Gateway: 172.30.0.1
├── debian-target: Dynamic IP
├── alpine-target: Dynamic IP
├── ubuntu-target: Dynamic IP
├── test-webserver: 172.30.0.10 (static)
└── test-dns: 172.30.0.11 (static)
```

### Mounted Volumes | Csatolt Kötetek

**English:**
- `/scripts` - Read-only mount of all automation scripts
- `/configs` - Read-only mount of configuration examples
- `/var/reports` - Named volume for generated reports
- `/var/backups` - Named volume for backup storage
- `/var/log/infra` - Named volume for centralized logs

**Magyar:**
- `/scripts` - Csak olvasható csatolás az összes automatizálási scripthez
- `/configs` - Csak olvasható csatolás a konfigurációs példákhoz
- `/var/reports` - Névvel ellátott kötet a generált jelentésekhez
- `/var/backups` - Névvel ellátott kötet a biztonsági mentések tárolásához
- `/var/log/infra` - Névvel ellátott kötet a központosított naplókhoz

---

## Running Tests | Tesztek Futtatása

### Quick Test | Gyors Teszt

**English:**
```bash
# Navigate to project directory
cd project-03-infra-automation

# Start all services
docker compose up -d

# Wait for health checks to pass
sleep 30

# Check container status
docker compose ps

# Run quick test on Debian
docker exec infra-debian-target bash -c "/scripts/system-inventory.sh --help"

# Stop services
docker compose down
```

**Magyar:**
```bash
# Navigálj a projekt könyvtárába
cd project-03-infra-automation

# Indítsd el az összes szolgáltatást
docker compose up -d

# Várj amíg az állapot ellenőrzések átmennek
sleep 30

# Ellenőrizd a konténer státuszát
docker compose ps

# Futtass gyors tesztet Debianon
docker exec infra-debian-target bash -c "/scripts/system-inventory.sh --help"

# Állítsd le a szolgáltatásokat
docker compose down
```

### Full Rebuild | Teljes Újraépítés

**English:**
Use this when you've made changes to Dockerfiles or entrypoint scripts:

**Magyar:**
Használd ezt, ha változtatásokat eszközöltél a Dockerfile-okban vagy az entrypoint scriptekben:

```bash
# Clean rebuild (no cache)
docker compose down
docker compose build --no-cache
docker compose up -d

# Verify all containers are healthy
docker ps --filter "name=infra-" --format "table {{.Names}}\t{{.Status}}"
```

### Comprehensive Testing | Átfogó Tesztelés

**English:**
Test all scripts across all target operating systems:

**Magyar:**
Tesztelj minden scriptet az összes cél operációs rendszeren:

```bash
#!/bin/bash
# comprehensive-test.sh

echo "=== Testing on Debian 12 ==="
docker exec infra-debian-target bash -c "/scripts/system-inventory.sh collect --output /tmp/inventory.json"
docker exec infra-debian-target bash -c "/scripts/server-hardening.sh --check --modules ssh"
docker exec infra-debian-target bash -c "/scripts/backup-manager.sh list"

echo "=== Testing on Alpine 3.19 ==="
docker exec infra-alpine-target sh -c "/scripts/network-diagnostics.sh connectivity 172.30.0.10"
docker exec infra-alpine-target sh -c "/scripts/network-diagnostics.sh dns google.com"

echo "=== Testing on Ubuntu 24.04 ==="
docker exec infra-ubuntu-target bash -c "/scripts/service-watchdog.sh status"
docker exec infra-ubuntu-target bash -c "/scripts/log-rotation.sh list"

echo "=== All tests completed ==="
```

---

## Manual Testing | Kézi Tesztelés

### Testing Individual Scripts | Egyedi Scriptek Tesztelése

#### 1. System Inventory | Rendszer Leltár

**English:**
```bash
# Collect system information
docker exec infra-debian-target bash -c \
  "/scripts/system-inventory.sh collect --output /tmp/inventory.json"

# Generate HTML report
docker exec infra-debian-target bash -c \
  "/scripts/system-inventory.sh report --format html --output /tmp/report.html"

# View the JSON output
docker exec infra-debian-target bash -c "cat /tmp/inventory.json | head -50"
```

**Magyar:**
```bash
# Rendszer információk gyűjtése
docker exec infra-debian-target bash -c \
  "/scripts/system-inventory.sh collect --output /tmp/inventory.json"

# HTML jelentés generálása
docker exec infra-debian-target bash -c \
  "/scripts/system-inventory.sh report --format html --output /tmp/report.html"

# JSON kimenet megtekintése
docker exec infra-debian-target bash -c "cat /tmp/inventory.json | head -50"
```

#### 2. Network Diagnostics | Hálózati Diagnosztika

**English:**
```bash
# Test connectivity to web server
docker exec infra-alpine-target sh -c \
  "/scripts/network-diagnostics.sh connectivity 172.30.0.10"

# Test DNS resolution
docker exec infra-alpine-target sh -c \
  "/scripts/network-diagnostics.sh dns google.com"

# Scan local network
docker exec infra-alpine-target sh -c \
  "/scripts/network-diagnostics.sh scan 172.30.0.0/24"

# Generate comprehensive report
docker exec infra-alpine-target sh -c \
  "/scripts/network-diagnostics.sh report"
```

**Magyar:**
```bash
# Kapcsolat tesztelése a web szerverhez
docker exec infra-alpine-target sh -c \
  "/scripts/network-diagnostics.sh connectivity 172.30.0.10"

# DNS feloldás tesztelése
docker exec infra-alpine-target sh -c \
  "/scripts/network-diagnostics.sh dns google.com"

# Helyi hálózat szkennelése
docker exec infra-alpine-target sh -c \
  "/scripts/network-diagnostics.sh scan 172.30.0.0/24"

# Átfogó jelentés generálása
docker exec infra-alpine-target sh -c \
  "/scripts/network-diagnostics.sh report"
```

#### 3. Server Hardening | Szerver Keményítés

**English:**
```bash
# Audit-only mode (no changes)
docker exec infra-ubuntu-target bash -c \
  "/scripts/server-hardening.sh --check"

# Test specific module
docker exec infra-ubuntu-target bash -c \
  "/scripts/server-hardening.sh --check --modules ssh"

# Run all modules (dry-run)
docker exec infra-ubuntu-target bash -c \
  "/scripts/server-hardening.sh --check --modules all"

# View generated report
docker exec infra-ubuntu-target bash -c \
  "cat /var/reports/hardening-*.json | head -100"
```

**Magyar:**
```bash
# Csak audit mód (nincsenek változások)
docker exec infra-ubuntu-target bash -c \
  "/scripts/server-hardening.sh --check"

# Specifikus modul tesztelése
docker exec infra-ubuntu-target bash -c \
  "/scripts/server-hardening.sh --check --modules ssh"

# Minden modul futtatása (dry-run)
docker exec infra-ubuntu-target bash -c \
  "/scripts/server-hardening.sh --check --modules all"

# Generált jelentés megtekintése
docker exec infra-ubuntu-target bash -c \
  "cat /var/reports/hardening-*.json | head -100"
```

#### 4. Service Watchdog | Szolgáltatás Watchdog

**English:**
```bash
# Check watchdog status
docker exec infra-debian-target bash -c \
  "/scripts/service-watchdog.sh status"

# Start monitoring SSH (foreground, 5 checks)
docker exec infra-debian-target bash -c \
  "/scripts/service-watchdog.sh start --services sshd --interval 5 --max-checks 5"

# List available services
docker exec infra-debian-target bash -c \
  "systemctl list-units --type=service --state=running"
```

**Magyar:**
```bash
# Watchdog státusz ellenőrzése
docker exec infra-debian-target bash -c \
  "/scripts/service-watchdog.sh status"

# SSH monitorozás indítása (előtérben, 5 ellenőrzés)
docker exec infra-debian-target bash -c \
  "/scripts/service-watchdog.sh start --services sshd --interval 5 --max-checks 5"

# Elérhető szolgáltatások listázása
docker exec infra-debian-target bash -c \
  "systemctl list-units --type=service --state=running"
```

#### 5. Backup Manager | Biztonsági Mentés Kezelő

**English:**
```bash
# Initialize backup repository
docker exec infra-debian-target bash -c \
  "/scripts/backup-manager.sh init"

# Create full backup
docker exec infra-debian-target bash -c \
  "/scripts/backup-manager.sh backup --type full --source /etc --dest /var/backups/test"

# List backups
docker exec infra-debian-target bash -c \
  "/scripts/backup-manager.sh list"

# Verify backup integrity
docker exec infra-debian-target bash -c \
  "/scripts/backup-manager.sh verify /var/backups/test/backup-*.tar.gz"
```

**Magyar:**
```bash
# Biztonsági mentés repository inicializálása
docker exec infra-debian-target bash -c \
  "/scripts/backup-manager.sh init"

# Teljes biztonsági mentés létrehozása
docker exec infra-debian-target bash -c \
  "/scripts/backup-manager.sh backup --type full --source /etc --dest /var/backups/test"

# Biztonsági mentések listázása
docker exec infra-debian-target bash -c \
  "/scripts/backup-manager.sh list"

# Biztonsági mentés integritás ellenőrzése
docker exec infra-debian-target bash -c \
  "/scripts/backup-manager.sh verify /var/backups/test/backup-*.tar.gz"
```

#### 6. Log Rotation | Napló Rotáció

**English:**
```bash
# List configured rotations
docker exec infra-debian-target bash -c \
  "/scripts/log-rotation.sh list"

# Rotate logs manually
docker exec infra-debian-target bash -c \
  "/scripts/log-rotation.sh rotate --config /configs/log-rotation.conf"

# Force rotation
docker exec infra-debian-target bash -c \
  "/scripts/log-rotation.sh rotate --force"
```

**Magyar:**
```bash
# Konfigurált rotációk listázása
docker exec infra-debian-target bash -c \
  "/scripts/log-rotation.sh list"

# Naplók manuális rotálása
docker exec infra-debian-target bash -c \
  "/scripts/log-rotation.sh rotate --config /configs/log-rotation.conf"

# Kényszerített rotáció
docker exec infra-debian-target bash -c \
  "/scripts/log-rotation.sh rotate --force"
```

### Testing Cross-Platform Compatibility | Cross-Platform Kompatibilitás Tesztelése

**English:**
Run the same command across all three operating systems:

**Magyar:**
Futtasd ugyanazt a parancsot mindhárom operációs rendszeren:

```bash
#!/bin/bash
# cross-platform-test.sh

SCRIPT="network-diagnostics.sh"
COMMAND="connectivity 172.30.0.10"

echo "=== Debian 12 ==="
docker exec infra-debian-target bash -c "/scripts/$SCRIPT $COMMAND"

echo ""
echo "=== Alpine 3.19 ==="
docker exec infra-alpine-target sh -c "/scripts/$SCRIPT $COMMAND"

echo ""
echo "=== Ubuntu 24.04 ==="
docker exec infra-ubuntu-target bash -c "/scripts/$SCRIPT $COMMAND"
```

---

## Test Results | Teszteredmények

### Latest Test Run | Legutóbbi Teszt Futás

**Date | Dátum:** 2025-11-30 *(Example output from this test run)*

**Note:** The following results are example outputs from a specific test run. Actual values (RTT, timestamps, container IDs, etc.) will vary based on your environment and test execution time.

**Megjegyzés:** Az alábbi eredmények egy konkrét teszt futás példa kimenetei. A tényleges értékek (RTT, időbélyegek, konténer azonosítók, stb.) a környezettől és a teszt végrehajtási időtől függően változnak.

#### Container Health Status | Konténer Állapot

```
✅ infra-debian-target     - healthy  (Debian 12 Bookworm)
✅ infra-alpine-target     - healthy  (Alpine 3.19)
✅ infra-ubuntu-target     - healthy  (Ubuntu 24.04 Noble)
✅ infra-test-webserver    - healthy  (Nginx Alpine)
⚠️  infra-test-dns         - unhealthy (CoreDNS - non-critical)
```

#### Script Test Results | Script Teszt Eredmények

| Script | Debian 12 | Alpine 3.19 | Ubuntu 24.04 | Notes |
|--------|-----------|-------------|--------------|-------|
| system-inventory.sh | ✅ Pass | ✅ Pass | ✅ Pass | All commands functional |
| network-diagnostics.sh | ✅ Pass | ✅ Pass | ✅ Pass | Connectivity 0% loss |
| server-hardening.sh | ✅ Pass | ✅ Pass | ✅ Pass | Dry-run mode working |
| service-watchdog.sh | ✅ Pass | ✅ Pass | ✅ Pass | Status command OK |
| backup-manager.sh | ✅ Pass | ✅ Pass | ✅ Pass | Init/list working |
| log-rotation.sh | ✅ Pass | ✅ Pass | ✅ Pass | List command OK |

#### Network Test Results | Hálózati Teszt Eredmények

**English:**
```
Source: Alpine (infra-alpine-target)
Target: Nginx (172.30.0.10)

✅ Ping Status: Success
✅ Packet Loss: 0%
✅ Average RTT: 0.091ms
✅ Gateway: 172.30.0.1 (reachable)
✅ Traceroute: 1 hop
✅ MTU Test: Pass (1500 bytes)
```

**Magyar:**
```
Forrás: Alpine (infra-alpine-target)
Cél: Nginx (172.30.0.10)

✅ Ping Státusz: Sikeres
✅ Csomagvesztés: 0%
✅ Átlagos RTT: 0.091ms
✅ Átjáró: 172.30.0.1 (elérhető)
✅ Traceroute: 1 ugrás
✅ MTU Teszt: Sikeres (1500 bájt)
```

#### Performance Metrics | Teljesítmény Mutatók

**English:**
- **Container Startup Time:** ~10-15 seconds (cold start)
- **Health Check Interval:** 30 seconds
- **Script Execution Time:**
  - system-inventory.sh: ~2-3 seconds
  - network-diagnostics.sh connectivity: ~3-4 seconds
  - server-hardening.sh --check: ~1-2 seconds

**Magyar:**
- **Konténer Indítási Idő:** ~10-15 másodperc (hideg indítás)
- **Állapot Ellenőrzés Intervallum:** 30 másodperc
- **Script Futási Idő:**
  - system-inventory.sh: ~2-3 másodperc
  - network-diagnostics.sh connectivity: ~3-4 másodperc
  - server-hardening.sh --check: ~1-2 másodperc

---

## Troubleshooting | Hibaelhárítás

### Common Issues | Gyakori Problémák

#### 1. Containers Keep Restarting | Konténerek Újraindulnak

**English:**
**Symptoms:** Containers show "Restarting (0) X seconds ago"

**Causes:**
- Entrypoint script exits immediately
- Missing directories for PID files
- rsyslog conflicts

**Solutions:**
```bash
# Check container logs
docker logs infra-debian-target --tail 50

# Rebuild with no cache
docker compose down
docker compose build --no-cache
docker compose up -d

# Verify entrypoint uses tail -f /dev/null
docker exec infra-debian-target ps aux | grep tail
```

**Magyar:**
**Tünetek:** Konténerek "Restarting (0) X másodperce" állapotot mutatnak

**Okok:**
- Entrypoint script azonnal kilép
- Hiányzó könyvtárak PID fájlokhoz
- rsyslog konfliktusok

**Megoldások:**
```bash
# Konténer naplók ellenőrzése
docker logs infra-debian-target --tail 50

# Újraépítés cache nélkül
docker compose down
docker compose build --no-cache
docker compose up -d

# Ellenőrizd hogy az entrypoint tail -f /dev/null -t használ
docker exec infra-debian-target ps aux | grep tail
```

#### 2. Health Checks Failing | Állapot Ellenőrzések Sikertelenek

**English:**
**Symptoms:** Container shows "unhealthy" status

**Causes:**
- PID file not created
- Wrong PID file path in health check
- Service not starting

**Solutions:**
```bash
# Check health check definition
docker inspect infra-debian-target | grep -A 5 Healthcheck

# Manually test health check command
docker exec infra-debian-target test -f /run/sshd.pid && echo "OK" || echo "FAIL"

# Check if SSH is running
docker exec infra-debian-target ps aux | grep sshd
```

**Magyar:**
**Tünetek:** Konténer "unhealthy" állapotot mutat

**Okok:**
- PID fájl nincs létrehozva
- Rossz PID fájl útvonal az állapot ellenőrzésben
- Szolgáltatás nem indul el

**Megoldások:**
```bash
# Állapot ellenőrzés definíció megtekintése
docker inspect infra-debian-target | grep -A 5 Healthcheck

# Manuális állapot ellenőrzés parancs tesztelése
docker exec infra-debian-target test -f /run/sshd.pid && echo "OK" || echo "FAIL"

# SSH futás ellenőrzése
docker exec infra-debian-target ps aux | grep sshd
```

#### 3. Scripts Not Found | Scriptek Nem Találhatók

**English:**
**Symptoms:** `/scripts/script-name.sh: No such file or directory`

**Causes:**
- Volume not mounted correctly
- Wrong working directory

**Solutions:**
```bash
# Verify volume mount
docker inspect infra-debian-target | grep -A 20 Mounts

# List mounted scripts
docker exec infra-debian-target ls -la /scripts/

# Check if scripts are executable
docker exec infra-debian-target find /scripts -name "*.sh" -exec ls -lh {} \;
```

**Magyar:**
**Tünetek:** `/scripts/script-name.sh: Nincs ilyen fájl vagy könyvtár`

**Okok:**
- Kötet nincs helyesen csatolva
- Rossz munkakönyvtár

**Megoldások:**
```bash
# Kötet csatolás ellenőrzése
docker inspect infra-debian-target | grep -A 20 Mounts

# Csatolt scriptek listázása
docker exec infra-debian-target ls -la /scripts/

# Scriptek futtathatóságának ellenőrzése
docker exec infra-debian-target find /scripts -name "*.sh" -exec ls -lh {} \;
```

#### 4. Permission Denied Errors | Jogosultság Megtagadva Hibák

**English:**
**Symptoms:** `Permission denied` when running scripts

**Causes:**
- Scripts not executable
- Running as wrong user

**Solutions:**
```bash
# Make scripts executable (on host)
chmod +x scripts/*.sh
chmod +x scripts/lib/*.sh

# Rebuild containers
docker compose down
docker compose up -d

# Verify permissions inside container
docker exec infra-debian-target ls -la /scripts/
```

**Magyar:**
**Tünetek:** `Jogosultság megtagadva` script futtatásakor

**Okok:**
- Scriptek nem futtathatók
- Rossz felhasználóként fut

**Megoldások:**
```bash
# Scriptek futtathatóvá tétele (hoston)
chmod +x scripts/*.sh
chmod +x scripts/lib/*.sh

# Konténerek újraépítése
docker compose down
docker compose up -d

# Jogosultságok ellenőrzése konténerben
docker exec infra-debian-target ls -la /scripts/
```

### Debugging Tips | Hibakeresési Tippek

**English:**
1. **Check all container logs simultaneously:**
   ```bash
   docker compose logs -f
   ```

2. **Inspect specific container:**
   ```bash
   docker exec -it infra-debian-target bash
   # Now you're inside the container
   ```

3. **Monitor resource usage:**
   ```bash
   docker stats
   ```

4. **Check network connectivity:**
   ```bash
   docker network inspect infra-test-net
   ```

5. **View container details:**
   ```bash
   docker inspect infra-debian-target | less
   ```

**Magyar:**
1. **Összes konténer napló egyidejű ellenőrzése:**
   ```bash
   docker compose logs -f
   ```

2. **Specifikus konténer vizsgálata:**
   ```bash
   docker exec -it infra-debian-target bash
   # Most a konténeren belül vagy
   ```

3. **Erőforrás használat monitorozása:**
   ```bash
   docker stats
   ```

4. **Hálózati kapcsolat ellenőrzése:**
   ```bash
   docker network inspect infra-test-net
   ```

5. **Konténer részletek megtekintése:**
   ```bash
   docker inspect infra-debian-target | less
   ```

---

## Test Automation | Teszt Automatizálás

### CI/CD Integration | CI/CD Integráció

**English:**
Example GitHub Actions workflow:

**Magyar:**
Példa GitHub Actions workflow:

```yaml
name: Test Project 03

on:
  push:
    paths:
      - 'project-03-infra-automation/**'
  pull_request:
    paths:
      - 'project-03-infra-automation/**'

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Start Docker Compose
        working-directory: project-03-infra-automation
        run: |
          docker compose up -d
          sleep 30

      - name: Check Container Health
        working-directory: project-03-infra-automation
        run: |
          docker compose ps
          docker ps --filter "name=infra-" --format "table {{.Names}}\t{{.Status}}"

      - name: Run Script Tests
        working-directory: project-03-infra-automation
        run: |
          docker exec infra-debian-target bash -c "/scripts/system-inventory.sh --help"
          docker exec infra-alpine-target sh -c "/scripts/network-diagnostics.sh connectivity 172.30.0.10"
          docker exec infra-ubuntu-target bash -c "/scripts/server-hardening.sh --check --modules ssh"

      - name: Cleanup
        if: always()
        working-directory: project-03-infra-automation
        run: docker compose down
```

---

## Additional Resources | További Források

**English:**
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Project README](../project-03-infra-automation/README.md)
- [Script Documentation](../project-03-infra-automation/docs/SCRIPTS.md)
- [Architecture Documentation](../project-03-infra-automation/docs/ARCHITECTURE.md)

**Magyar:**
- [Docker Compose Dokumentáció](https://docs.docker.com/compose/)
- [Projekt README](../project-03-infra-automation/README.md)
- [Script Dokumentáció](../project-03-infra-automation/docs/SCRIPTS.md)
- [Architektúra Dokumentáció](../project-03-infra-automation/docs/ARCHITECTURE.md)

---

## Changelog | Változásnapló

### 2025-11-30
- Initial documentation created
- Documented container restart loop fix
- Added comprehensive testing procedures
- Documented cross-platform testing approach

---

**License | Licenc:** MIT

**Maintainer | Karbantartó:** w7-mgfcode

**Last Updated | Utolsó Frissítés:** 2025-11-30
