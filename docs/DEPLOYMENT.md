# Deployment Guide | Telepítési Útmutató

## Overview | Áttekintés

**English:**
This guide provides detailed instructions for deploying the Linux System Administrator Portfolio projects in various environments. Each project is designed to work out-of-the-box with Docker Compose, but this guide covers advanced deployment scenarios.

**Magyar:**
Ez az útmutató részletes utasításokat nyújt a Linux Rendszergazda Portfólió projektek különböző környezetekben való telepítéséhez. Minden projekt úgy van tervezve, hogy Docker Compose-zal azonnal működjön, de ez az útmutató haladó telepítési forgatókönyveket is lefed.

---

## Prerequisites | Előfeltételek

**Required | Kötelező:**
- Docker 24.0+
- Docker Compose 2.20+
- 4GB RAM minimum
- 20GB disk space

**Optional | Opcionális:**
- Bash 5.0+ for script execution
- Git for cloning repository
- shellcheck for script validation

---

## Quick Deployment | Gyors Telepítés

### Project 01: LAMP Stack with Monitoring

**English:**
```bash
# Navigate to project directory
cd project-01-lamp-monitoring

# Create environment file
cp .env.example .env

# IMPORTANT: Edit .env and set secure passwords
nano .env
# Set DB_ROOT_PASSWORD and DB_PASSWORD

# Start all services
docker compose up -d

# Verify deployment
docker compose ps

# Check service health
docker compose exec php /scripts/health-check.sh

# Access services
# Dashboard: http://localhost
# Adminer: http://localhost:8080
```

**Magyar:**
```bash
# Navigálj a projekt könyvtárba
cd project-01-lamp-monitoring

# Hozd létre a környezeti fájlt
cp .env.example .env

# FONTOS: Szerkeszd a .env fájlt és állíts be biztonságos jelszavakat
nano .env
# Állítsd be a DB_ROOT_PASSWORD és DB_PASSWORD értékeket

# Indítsd el az összes szolgáltatást
docker compose up -d

# Ellenőrizd a telepítést
docker compose ps

# Ellenőrizd a szolgáltatások állapotát
docker compose exec php /scripts/health-check.sh

# Szolgáltatások elérése
# Vezérlőpult: http://localhost
# Adminer: http://localhost:8080
```

---

## Environment Configuration | Környezet Konfiguráció

### Project 01 Environment Variables

**English:**
Create a `.env` file with these required variables:

**Magyar:**
Hozz létre egy `.env` fájlt ezekkel a kötelező változókkal:

```bash
# Project Configuration
PROJECT_NAME=lamp-monitoring
TZ=UTC

# MySQL Configuration (REQUIRED - SET SECURE PASSWORDS!)
DB_ROOT_PASSWORD=your_secure_root_password_here
DB_NAME=lampdb
DB_USER=lampuser
DB_PASSWORD=your_secure_user_password_here

# Ports (modify if defaults are in use)
HTTP_PORT=80
HTTPS_PORT=443
ADMINER_PORT=8080

# Script Configuration
ERROR_THRESHOLD=5.0
WARNING_THRESHOLD=2.0
RETENTION_DAYS=7

# Optional: Webhook for alerts
# WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

**Security Notes | Biztonsági Megjegyzések:**

**English:**
- Use strong passwords (min 16 characters, mix of letters, numbers, symbols)
- Never commit `.env` to version control (included in `.gitignore`)
- Change default passwords immediately
- Use environment-specific configurations for prod/dev/test

**Magyar:**
- Használj erős jelszavakat (min 16 karakter, betűk, számok, szimbólumok keveréke)
- Soha ne commitold a `.env` fájlt a verziókezelőbe (benne van a `.gitignore`-ban)
- Azonnal változtasd meg az alapértelmezett jelszavakat
- Használj környezet-specifikus konfigurációkat prod/dev/test környezetekhez

---

## Port Configuration | Port Konfiguráció

### Checking Available Ports | Szabad Portok Ellenőrzése

**English:**
```bash
# Check if ports are available
sudo ss -tlnp | grep -E ':80|:8080|:3306'

# If ports are in use, modify .env:
HTTP_PORT=8000
ADMINER_PORT=8081
# MySQL port is internal only, no conflict
```

**Magyar:**
```bash
# Ellenőrizd, hogy a portok szabadok-e
sudo ss -tlnp | grep -E ':80|:8080|:3306'

# Ha a portok foglaltak, módosítsd a .env fájlt:
HTTP_PORT=8000
ADMINER_PORT=8081
# A MySQL port csak belső, nincs ütközés
```

---

## Health Checks | Állapotellenőrzések

### Verifying Deployment | Telepítés Ellenőrzése

**English:**
```bash
# Check all containers are running
docker compose ps

# Expected output: All services "Up" with healthy status
# nginx     Up (healthy)
# php       Up (healthy)
# mysql     Up (healthy)
# adminer   Up

# Run health check script
docker compose exec php /scripts/health-check.sh

# Expected: JSON output with "status": "healthy"
```

**Magyar:**
```bash
# Ellenőrizd, hogy minden konténer fut
docker compose ps

# Elvárt kimenet: Minden szolgáltatás "Up" állapottal és healthy státusszal
# nginx     Up (healthy)
# php       Up (healthy)
# mysql     Up (healthy)
# adminer   Up

# Futtasd az állapotellenőrző scriptet
docker compose exec php /scripts/health-check.sh

# Elvárt: JSON kimenet "status": "healthy" értékkel
```

### Automated Health Monitoring | Automatizált Állapotfigyelés

**English:**
Set up a cron job for continuous monitoring:

**Magyar:**
Állíts be cron feladatot a folyamatos figyeléshez:

```bash
# Edit crontab
crontab -e

# Add this line (check health every 5 minutes)
*/5 * * * * cd /path/to/project-01-lamp-monitoring && docker compose exec -T php /scripts/health-check.sh >> /var/log/lamp-health.log 2>&1
```

---

## Backup Configuration | Biztonsági Mentés Konfiguráció

### Automated Backups | Automatizált Biztonsági Mentések

**English:**
```bash
# Test backup manually
docker compose exec php /scripts/backup.sh

# Verify backup was created
docker compose exec php ls -lh /backups/

# Set up automated backups with cron
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /path/to/project-01-lamp-monitoring && docker compose exec -T php /scripts/backup.sh >> /var/log/lamp-backup.log 2>&1
```

**Magyar:**
```bash
# Teszteld a biztonsági mentést manuálisan
docker compose exec php /scripts/backup.sh

# Ellenőrizd, hogy a mentés létrejött
docker compose exec php ls -lh /backups/

# Állíts be automatikus mentéseket cron-nal
crontab -e

# Adj hozzá napi mentést hajnali 2 órakor
0 2 * * * cd /path/to/project-01-lamp-monitoring && docker compose exec -T php /scripts/backup.sh >> /var/log/lamp-backup.log 2>&1
```

### Backup Retention | Biztonsági Mentés Megőrzése

**English:**
Backups are automatically cleaned up based on `RETENTION_DAYS` (default: 7 days).

To change retention period:

**Magyar:**
A biztonsági mentések automatikusan törlődnek a `RETENTION_DAYS` alapján (alapértelmezett: 7 nap).

A megőrzési időszak módosításához:

```bash
# In .env file
RETENTION_DAYS=14  # Keep backups for 14 days
```

---

## Log Analysis | Naplóelemzés

### Manual Log Analysis | Manuális Naplóelemzés

**English:**
```bash
# Generate traffic for testing
for i in {1..100}; do curl -s http://localhost/ >/dev/null; done

# Run log analyzer
docker compose exec php /scripts/log-analyzer.sh

# View generated report
docker compose exec php cat /var/reports/analysis_*.json | jq .
```

**Magyar:**
```bash
# Generálj forgalmat teszteléshez
for i in {1..100}; do curl -s http://localhost/ >/dev/null; done

# Futtasd a naplóelemzőt
docker compose exec php /scripts/log-analyzer.sh

# Nézd meg a generált jelentést
docker compose exec php cat /var/reports/analysis_*.json | jq .
```

### Automated Log Analysis | Automatizált Naplóelemzés

**English:**
```bash
# Analyze logs hourly
0 * * * * cd /path/to/project-01-lamp-monitoring && docker compose exec -T php /scripts/log-analyzer.sh >> /var/log/lamp-analysis.log 2>&1
```

**Magyar:**
```bash
# Elemezd a naplókat óránként
0 * * * * cd /path/to/project-01-lamp-monitoring && docker compose exec -T php /scripts/log-analyzer.sh >> /var/log/lamp-analysis.log 2>&1
```

---

## Monitoring & Alerts | Figyelés és Riasztások

### Webhook Integration | Webhook Integráció

**English:**
To receive alerts when error rates exceed thresholds, configure a webhook:

**Magyar:**
Hogy riasztásokat kapj, amikor a hibaarány meghaladja a küszöbértékeket, állíts be webhook-ot:

```bash
# In .env file
WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Or for Discord
WEBHOOK_URL=https://discord.com/api/webhooks/YOUR/WEBHOOK
```

**Alert Thresholds | Riasztási Küszöbök:**

```bash
# Warning alert at 2% error rate
WARNING_THRESHOLD=2.0

# Critical alert at 5% error rate
ERROR_THRESHOLD=5.0
```

---

## Troubleshooting | Hibaelhárítás

### Common Issues | Gyakori Problémák

#### Issue 1: Containers won't start | A konténerek nem indulnak

**English:**
```bash
# Check Docker daemon
sudo systemctl status docker

# Check logs
docker compose logs

# Remove old volumes and restart
docker compose down -v
docker compose up -d
```

**Magyar:**
```bash
# Ellenőrizd a Docker daemon-t
sudo systemctl status docker

# Ellenőrizd a naplókat
docker compose logs

# Távolítsd el a régi köteteket és indítsd újra
docker compose down -v
docker compose up -d
```

#### Issue 2: Permission denied on scripts | Jogosultság megtagadva a scripteknél

**English:**
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Rebuild PHP container
docker compose build php
docker compose up -d
```

**Magyar:**
```bash
# Tedd futtathatóvá a scripteket
chmod +x scripts/*.sh

# Építsd újra a PHP konténert
docker compose build php
docker compose up -d
```

#### Issue 3: Cannot connect to MySQL | Nem lehet csatlakozni a MySQL-hez

**English:**
```bash
# Check MySQL is healthy
docker compose ps mysql

# Check MySQL logs
docker compose logs mysql

# Verify passwords in .env match
cat .env | grep DB_PASSWORD

# Test connection
docker compose exec php mysql -h mysql -u lampuser -p
```

**Magyar:**
```bash
# Ellenőrizd, hogy a MySQL healthy állapotban van
docker compose ps mysql

# Ellenőrizd a MySQL naplókat
docker compose logs mysql

# Ellenőrizd, hogy a .env jelszavai egyeznek
cat .env | grep DB_PASSWORD

# Teszteld a kapcsolatot
docker compose exec php mysql -h mysql -u lampuser -p
```

---

## Performance Tuning | Teljesítmény Hangolás

### MySQL Configuration | MySQL Konfiguráció

**English:**
For production use, adjust MySQL settings in `mysql/conf.d/custom.cnf`:

**Magyar:**
Produkciós használathoz módosítsd a MySQL beállításokat a `mysql/conf.d/custom.cnf` fájlban:

```ini
[mysqld]
# Adjust based on available RAM
innodb_buffer_pool_size = 512M  # 50-80% of available RAM
max_connections = 200
innodb_log_file_size = 128M
```

### PHP Configuration | PHP Konfiguráció

**English:**
Adjust PHP settings in `php/php.ini`:

**Magyar:**
Módosítsd a PHP beállításokat a `php/php.ini` fájlban:

```ini
[PHP]
memory_limit = 512M  # Increase for heavy workloads
max_execution_time = 600  # Adjust for long-running scripts
```

---

## Security Best Practices | Biztonsági Legjobb Gyakorlatok

**English:**
1. **Always use strong passwords** in `.env`
2. **Never expose MySQL port** to the host (keep backend network internal)
3. **Enable HTTPS** in production (add SSL certificates)
4. **Regular backups** - Test restoration periodically
5. **Monitor logs** - Set up alerts for suspicious activity
6. **Keep Docker updated** - Regular security updates
7. **Limit Adminer access** - Remove in production or use VPN

**Magyar:**
1. **Mindig használj erős jelszavakat** a `.env` fájlban
2. **Soha ne tedd ki a MySQL portot** a host-ra (tartsd a backend hálózatot belsőnek)
3. **Engedélyezd a HTTPS-t** produkciós környezetben (adj hozzá SSL tanúsítványokat)
4. **Rendszeres biztonsági mentések** - Teszteld a visszaállítást időszakosan
5. **Figyeld a naplókat** - Állíts be riasztásokat gyanús tevékenységekre
6. **Tartsd naprakészen a Dockert** - Rendszeres biztonsági frissítések
7. **Korlátozd az Adminer hozzáférést** - Távolítsd el produkciós környezetben vagy használj VPN-t

---

## Scaling | Skálázás

### Horizontal Scaling | Horizontális Skálázás

**English:**
To scale PHP workers:

**Magyar:**
PHP worker-ek skálázásához:

```bash
# Scale to 3 PHP containers
docker compose up -d --scale php=3

# Load balancer configuration required (not included)
```

---

## Maintenance | Karbantartás

### Regular Tasks | Rendszeres Feladatok

**English:**
```bash
# Weekly: Check disk space
df -h

# Weekly: Prune old Docker images
docker system prune -a

# Monthly: Review logs for issues
docker compose logs --since 720h | grep -i error

# Quarterly: Test backup restoration
# Stop services, restore backup, verify data
```

**Magyar:**
```bash
# Hetente: Ellenőrizd a lemezterületet
df -h

# Hetente: Tisztítsd meg a régi Docker image-eket
docker system prune -a

# Havonta: Ellenőrizd a naplókat hibák után
docker compose logs --since 720h | grep -i error

# Negyedévente: Teszteld a biztonsági mentés visszaállítást
# Állítsd le a szolgáltatásokat, állítsd vissza a mentést, ellenőrizd az adatokat
```

---

## Support | Támogatás

**English:**
For issues or questions:
- Check the project README
- Review troubleshooting section above
- Open an issue on GitHub
- Check Docker and system logs

**Magyar:**
Problémák vagy kérdések esetén:
- Ellenőrizd a projekt README-jét
- Nézd át a fenti hibaelhárítási részt
- Nyiss egy issue-t a GitHub-on
- Ellenőrizd a Docker és rendszer naplókat

---

## License | Licenc

This documentation is part of the Linux System Administrator Portfolio.

MIT License - See [LICENSE](../LICENSE) for details.

Ez a dokumentáció a Linux Rendszergazda Portfólió része.

MIT Licenc - Részletekért lásd a [LICENSE](../LICENSE) fájlt.
