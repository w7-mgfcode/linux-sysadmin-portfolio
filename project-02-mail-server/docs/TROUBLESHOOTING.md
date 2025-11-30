# Troubleshooting Guide | Hibaelhárítási Útmutató

**Project 02: Mail Server**

## Overview | Áttekintés

**English:** This document details common issues encountered during mail server deployment and their solutions. All fixes have been tested and verified in production-ready configurations.

**Magyar:** Ez a dokumentum a levelezőszerver telepítése során felmerülő gyakori problémákat és azok megoldásait tartalmazza. Minden javítás tesztelt és ellenőrzött produkció-kész konfigurációkban.

---

## Table of Contents | Tartalomjegyzék

1. [Postfix Configuration Issues](#postfix-configuration-issues--postfix-konfigurációs-problémák)
2. [Dovecot Configuration Issues](#dovecot-configuration-issues--dovecot-konfigurációs-problémák)
3. [MySQL Database Issues](#mysql-database-issues--mysql-adatbázis-problémák)
4. [Docker Compose Issues](#docker-compose-issues--docker-compose-problémák)
5. [Port Conflicts](#port-conflicts--port-ütközések)

---

## Postfix Configuration Issues | Postfix Konfigurációs Problémák

### Issue 1: Invalid Configuration Variable Syntax

**English:**

**Symptom:**
```
postfix check
fatal: /etc/postfix/main.cf, line 55: bad string length
```

**Root Cause:**
The `envsubst` command was processing ALL variables including Postfix internal variables like `${data_directory}`. When `data_directory` wasn't set as an environment variable, it expanded to empty string, breaking the configuration.

**Solution:**
Explicitly specify which environment variables `envsubst` should process:

```bash
# Before (WRONG - processes all ${} variables)
envsubst < /etc/postfix/main.cf.template > /etc/postfix/main.cf

# After (CORRECT - only processes specified variables)
envsubst '$MAIL_HOSTNAME $MAIL_DOMAIN' < /etc/postfix/main.cf.template > /etc/postfix/main.cf
```

**Files Modified:**
- `postfix/entrypoint.sh:8`

**Magyar:**

**Tünet:**
```
postfix check
fatal: /etc/postfix/main.cf, line 55: bad string length
```

**Alapvető Ok:**
Az `envsubst` parancs MINDEN változót feldolgozott, beleértve a Postfix belső változóit is, mint például a `${data_directory}`. Amikor a `data_directory` nem volt környezeti változóként beállítva, üres sztringgé bontotta ki, ezzel tönkretéve a konfigurációt.

**Megoldás:**
Kifejezetten meg kell határozni, hogy mely környezeti változókat dolgozza fel az `envsubst`:

```bash
# Előtte (HIBÁS - minden ${} változót feldolgoz)
envsubst < /etc/postfix/main.cf.template > /etc/postfix/main.cf

# Utána (HELYES - csak a megadott változókat dolgozza fel)
envsubst '$MAIL_HOSTNAME $MAIL_DOMAIN' < /etc/postfix/main.cf.template > /etc/postfix/main.cf
```

**Módosított Fájlok:**
- `postfix/entrypoint.sh:8`

---

### Issue 2: Unused Parameter Warnings

**English:**

**Symptom:**
```
/usr/sbin/postconf: warning: /etc/postfix/main.cf: unused parameter: virtual_mailbox_limit_maps
```

**Root Cause:**
Configuration referenced unimplemented mailbox quota features. The `vhost_mailbox_limit_maps` hash file didn't exist.

**Solution:**
Comment out the unimplemented features in `postfix/main.cf.template`:

```bash
# Mailbox format (Maildir with trailing slash)
virtual_mailbox_limit = 512000000
# virtual_mailbox_limit_maps = hash:/etc/postfix/vhost_mailbox_limit_maps  # Feature not implemented
# virtual_mailbox_limit_override = yes
# virtual_mailbox_limit_inbox = no
# virtual_overquota_bounce = yes
```

**Files Modified:**
- `postfix/main.cf.template:34-37`

**Magyar:**

**Tünet:**
```
/usr/sbin/postconf: warning: /etc/postfix/main.cf: unused parameter: virtual_mailbox_limit_maps
```

**Alapvető Ok:**
A konfiguráció nem implementált postafiók kvóta funkciókra hivatkozott. A `vhost_mailbox_limit_maps` hash fájl nem létezett.

**Megoldás:**
A nem implementált funkciók kikommentezése a `postfix/main.cf.template` fájlban:

```bash
# Mailbox format (Maildir with trailing slash)
virtual_mailbox_limit = 512000000
# virtual_mailbox_limit_maps = hash:/etc/postfix/vhost_mailbox_limit_maps  # Feature not implemented
# virtual_mailbox_limit_override = yes
# virtual_mailbox_limit_inbox = no
# virtual_overquota_bounce = yes
```

**Módosított Fájlok:**
- `postfix/main.cf.template:34-37`

---

## Dovecot Configuration Issues | Dovecot Konfigurációs Problémák

### Issue 3: Unknown Setting Error in SQL Config

**English:**

**Symptom:**
```
doveconf: Fatal: Error in configuration file /etc/dovecot/dovecot-sql.conf.ext line 5: Unknown setting: driver
```

**Root Cause:**
The main Dovecot configuration incorrectly included `dovecot-sql.conf.ext` using `!include` directive. SQL backend configuration files should NOT be included directly; they're referenced via `args` parameter in `auth-sql.conf.ext`.

**Solution:**
Remove the incorrect `!include` directive from `dovecot.conf.template`:

```bash
# Before (WRONG)
!include conf.d/*.conf
!include dovecot-sql.conf.ext

# After (CORRECT)
!include conf.d/*.conf
# Note: dovecot-sql.conf.ext is NOT included here - it's referenced
# by auth-sql.conf.ext via the args parameter in passdb/userdb blocks
```

**Files Modified:**
- `dovecot/dovecot.conf.template:19`

**Magyar:**

**Tünet:**
```
doveconf: Fatal: Error in configuration file /etc/dovecot/dovecot-sql.conf.ext line 5: Unknown setting: driver
```

**Alapvető Ok:**
A fő Dovecot konfiguráció helytelenül tartalmazta a `dovecot-sql.conf.ext` fájlt `!include` direktívával. Az SQL háttér konfigurációs fájlokat NEM szabad közvetlenül beilleszteni; ezekre az `auth-sql.conf.ext` fájlban található `args` paraméter hivatkozik.

**Megoldás:**
A hibás `!include` direktíva eltávolítása a `dovecot.conf.template` fájlból:

```bash
# Előtte (HIBÁS)
!include conf.d/*.conf
!include dovecot-sql.conf.ext

# Utána (HELYES)
!include conf.d/*.conf
# Megjegyzés: dovecot-sql.conf.ext NEM kerül ide beillesztésre - az
# auth-sql.conf.ext hivatkozik rá az args paraméterrel a passdb/userdb blokkokban
```

**Módosított Fájlok:**
- `dovecot/dovecot.conf.template:19`

---

### Issue 4: User Doesn't Exist Error

**English:**

**Symptom:**
```
Fatal: service(lmtp) User doesn't exist: postfix
```

**Root Cause:**
Dovecot LMTP and auth services configured to run as `postfix` user, but that user didn't exist in the Dovecot container.

**Solution:**
Create the `postfix` user in the Dovecot Dockerfile:

```dockerfile
# Create postfix user/group for LMTP and auth sockets
RUN groupadd -g 5001 postfix && \
    useradd -u 5001 -g postfix -s /usr/sbin/nologin -d /var/spool/postfix postfix
```

**Files Modified:**
- `dovecot/Dockerfile:18-19`

**Magyar:**

**Tünet:**
```
Fatal: service(lmtp) User doesn't exist: postfix
```

**Alapvető Ok:**
A Dovecot LMTP és hitelesítési szolgáltatások `postfix` felhasználóként voltak konfigurálva, de ez a felhasználó nem létezett a Dovecot konténerben.

**Megoldás:**
A `postfix` felhasználó létrehozása a Dovecot Dockerfile-ban:

```dockerfile
# Create postfix user/group for LMTP and auth sockets
RUN groupadd -g 5001 postfix && \
    useradd -u 5001 -g postfix -s /usr/sbin/nologin -d /var/spool/postfix postfix
```

**Módosított Fájlok:**
- `dovecot/Dockerfile:18-19`

---

### Issue 5: Socket Directory Missing

**English:**

**Symptom:**
```
Error: bind(/var/spool/postfix/private/auth) failed: No such file or directory
Fatal: Failed to start listeners
```

**Root Cause:**
Dovecot tried to create UNIX sockets in `/var/spool/postfix/private/` but the directory didn't exist.

**Solution:**
Create the socket directories in the Dovecot entrypoint:

```bash
# Create Postfix spool directories for LMTP and auth sockets
mkdir -p /var/spool/postfix/private
chown postfix:postfix /var/spool/postfix/private
chmod 750 /var/spool/postfix/private
```

**Files Modified:**
- `dovecot/entrypoint.sh:20-22`

**Magyar:**

**Tünet:**
```
Error: bind(/var/spool/postfix/private/auth) failed: No such file or directory
Fatal: Failed to start listeners
```

**Alapvető Ok:**
A Dovecot UNIX socketeket próbált létrehozni a `/var/spool/postfix/private/` könyvtárban, de a könyvtár nem létezett.

**Megoldás:**
A socket könyvtárak létrehozása a Dovecot belépési pontban:

```bash
# Create Postfix spool directories for LMTP and auth sockets
mkdir -p /var/spool/postfix/private
chown postfix:postfix /var/spool/postfix/private
chmod 750 /var/spool/postfix/private
```

**Módosított Fájlok:**
- `dovecot/entrypoint.sh:20-22`

---

### Issue 6: envsubst Processing SQL Config Variables

**English:**

**Symptom:**
Dovecot SQL configuration had empty connection strings after template processing.

**Root Cause:**
Same as Postfix Issue 1 - unrestricted `envsubst` was processing all variables.

**Solution:**
Specify only the required environment variables:

```bash
# Before (WRONG)
envsubst < /etc/dovecot/dovecot.conf.template > /etc/dovecot/dovecot.conf
envsubst < /etc/dovecot/dovecot-sql.conf.ext.template > /etc/dovecot/dovecot-sql.conf.ext

# After (CORRECT)
envsubst '$MAIL_DOMAIN' < /etc/dovecot/dovecot.conf.template > /etc/dovecot/dovecot.conf
envsubst '$MYSQL_HOST $MYSQL_DATABASE $MYSQL_USER $MYSQL_PASSWORD' < /etc/dovecot/dovecot-sql.conf.ext.template > /etc/dovecot/dovecot-sql.conf.ext
```

**Files Modified:**
- `dovecot/entrypoint.sh:8-9`

**Magyar:**

**Tünet:**
A Dovecot SQL konfiguráció üres kapcsolati sztringeket tartalmazott a sablon feldolgozása után.

**Alapvető Ok:**
Ugyanaz, mint a Postfix 1-es hiba - a korlátozás nélküli `envsubst` minden változót feldolgozott.

**Megoldás:**
Csak a szükséges környezeti változók megadása:

```bash
# Előtte (HIBÁS)
envsubst < /etc/dovecot/dovecot.conf.template > /etc/dovecot/dovecot.conf
envsubst < /etc/dovecot/dovecot-sql.conf.ext.template > /etc/dovecot/dovecot-sql.conf.ext

# Utána (HELYES)
envsubst '$MAIL_DOMAIN' < /etc/dovecot/dovecot.conf.template > /etc/dovecot/dovecot.conf
envsubst '$MYSQL_HOST $MYSQL_DATABASE $MYSQL_USER $MYSQL_PASSWORD' < /etc/dovecot/dovecot-sql.conf.ext.template > /etc/dovecot/dovecot-sql.conf.ext
```

**Módosított Fájlok:**
- `dovecot/entrypoint.sh:8-9`

---

## MySQL Database Issues | MySQL Adatbázis Problémák

### Issue 7: Empty MySQL Password

**English:**

**Symptom:**
```
Access denied for user 'mailuser'@'%' (using password: NO)
```

**Root Cause:**
When `.env` file was missing, `${MYSQL_PASSWORD}` expanded to empty string, causing authentication failures across all services.

**Solution:**
Add default values to all password references in `docker-compose.yml`:

```yaml
# Before (WRONG - no defaults)
environment:
  - MYSQL_PASSWORD=${MYSQL_PASSWORD}

# After (CORRECT - with defaults)
environment:
  - MYSQL_PASSWORD=${MYSQL_PASSWORD:-mail_secure_changeme}
  - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-mail_root_changeme}
```

**Locations Updated (6 total):**
- `docker-compose.yml:21` - MySQL service
- `docker-compose.yml:65` - Postfix service
- `docker-compose.yml:104` - Dovecot service
- `docker-compose.yml:158` - Roundcube service
- `docker-compose.yml:193` - Dashboard service
- `docker-compose.yml:24` - MySQL root password

**Files Modified:**
- `docker-compose.yml` (6 locations)

**Magyar:**

**Tünet:**
```
Access denied for user 'mailuser'@'%' (using password: NO)
```

**Alapvető Ok:**
Amikor a `.env` fájl hiányzott, a `${MYSQL_PASSWORD}` üres sztringgé bontódott ki, hitelesítési hibákat okozva az összes szolgáltatásban.

**Megoldás:**
Alapértelmezett értékek hozzáadása minden jelszó hivatkozáshoz a `docker-compose.yml` fájlban:

```yaml
# Előtte (HIBÁS - nincs alapértelmezett érték)
environment:
  - MYSQL_PASSWORD=${MYSQL_PASSWORD}

# Utána (HELYES - alapértelmezett értékekkel)
environment:
  - MYSQL_PASSWORD=${MYSQL_PASSWORD:-mail_secure_changeme}
  - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-mail_root_changeme}
```

**Frissített Helyek (összesen 6):**
- `docker-compose.yml:21` - MySQL szolgáltatás
- `docker-compose.yml:65` - Postfix szolgáltatás
- `docker-compose.yml:104` - Dovecot szolgáltatás
- `docker-compose.yml:158` - Roundcube szolgáltatás
- `docker-compose.yml:193` - Dashboard szolgáltatás
- `docker-compose.yml:24` - MySQL root jelszó

**Módosított Fájlok:**
- `docker-compose.yml` (6 helyen)

---

### Issue 8: Permission Denied on init.sql

**English:**

**Symptom:**
MySQL container logs showed:
```
ERROR: /docker-entrypoint-initdb.d/init.sql: Permission denied
```

**Root Cause:**
The `init.sql` file had restrictive permissions (0600) preventing the MySQL Docker entrypoint from reading it.

**Solution:**
Change file permissions to allow reading:

```bash
chmod 644 mysql/init.sql
```

**Files Modified:**
- `mysql/init.sql` (permissions only)

**Magyar:**

**Tünet:**
A MySQL konténer naplók mutatták:
```
ERROR: /docker-entrypoint-initdb.d/init.sql: Permission denied
```

**Alapvető Ok:**
Az `init.sql` fájl korlátozó jogosultságokkal (0600) rendelkezett, megakadályozva a MySQL Docker belépési pont olvasását.

**Megoldás:**
Fájl jogosultságok módosítása olvashatóvá:

```bash
chmod 644 mysql/init.sql
```

**Módosított Fájlok:**
- `mysql/init.sql` (csak jogosultságok)

---

## Docker Compose Issues | Docker Compose Problémák

### Issue 9: Obsolete Version Directive

**English:**

**Symptom:**
```
WARNING: the attribute `version` is obsolete, it will be ignored
```

**Root Cause:**
Docker Compose v2 deprecated the `version` directive. While not causing failures, it clutters logs with warnings.

**Solution:**
Remove the version line from `docker-compose.yml`:

```yaml
# Before
version: '3.8'

services:
  ...

# After
services:
  ...
```

**Files Modified:**
- `docker-compose.yml:1`

**Magyar:**

**Tünet:**
```
WARNING: the attribute `version` is obsolete, it will be ignored
```

**Alapvető Ok:**
A Docker Compose v2 elavultnak jelölte a `version` direktívát. Bár nem okoz hibát, a naplókat figyelmeztetésekkel szennyezi.

**Megoldás:**
A verzió sor eltávolítása a `docker-compose.yml` fájlból:

```yaml
# Előtte
version: '3.8'

services:
  ...

# Utána
services:
  ...
```

**Módosított Fájlok:**
- `docker-compose.yml:1`

---

## Port Conflicts | Port Ütközések

### Issue 10: Port 80 Already Allocated

**English:**

**Symptom:**
```
Error: Bind for 0.0.0.0:80 failed: port is already allocated
```

**Root Cause:**
Another service (e.g., Project 01 LAMP stack) is using port 80.

**Solution:**
Either:
1. Stop the conflicting service: `docker compose -f ../project-01-lamp-monitoring/docker-compose.yml down`
2. Change Roundcube port in `.env`: `WEBMAIL_PORT=8081`
3. Use different projects on different machines

**Files to Modify (if changing port):**
- `.env:45`

**Magyar:**

**Tünet:**
```
Error: Bind for 0.0.0.0:80 failed: port is already allocated
```

**Alapvető Ok:**
Egy másik szolgáltatás (pl. Projekt 01 LAMP stack) használja a 80-as portot.

**Megoldás:**
Vagy:
1. Ütköző szolgáltatás leállítása: `docker compose -f ../project-01-lamp-monitoring/docker-compose.yml down`
2. Roundcube port módosítása a `.env` fájlban: `WEBMAIL_PORT=8081`
3. Különböző projektek használata különböző gépeken

**Módosítandó Fájlok (port módosítása esetén):**
- `.env:45`

---

## Best Practices | Legjobb Gyakorlatok

### envsubst Usage

**English:**
Always specify which variables `envsubst` should process to avoid accidentally expanding internal application variables:

```bash
# GOOD - Explicit variable list
envsubst '$VAR1 $VAR2 $VAR3' < template > output

# BAD - Processes all ${} variables
envsubst < template > output
```

**Magyar:**
Mindig adja meg, hogy mely változókat dolgozza fel az `envsubst`, hogy elkerülje a belső alkalmazás változók véletlen kibontását:

```bash
# JÓ - Explicit változólista
envsubst '$VAR1 $VAR2 $VAR3' < template > output

# ROSSZ - Minden ${} változót feldolgoz
envsubst < template > output
```

---

### Docker Compose Environment Variables

**English:**
Always provide default values for critical configuration:

```yaml
# GOOD - Has sensible defaults
environment:
  - MYSQL_PASSWORD=${MYSQL_PASSWORD:-secure_default_changeme}

# BAD - Fails if variable not set
environment:
  - MYSQL_PASSWORD=${MYSQL_PASSWORD}
```

**Warning:** Change default passwords before production deployment!

**Magyar:**
Mindig adjon meg alapértelmezett értékeket a kritikus konfigurációhoz:

```yaml
# JÓ - Ésszerű alapértelmezésekkel
environment:
  - MYSQL_PASSWORD=${MYSQL_PASSWORD:-secure_default_changeme}

# ROSSZ - Sikertelen, ha a változó nincs beállítva
environment:
  - MYSQL_PASSWORD=${MYSQL_PASSWORD}
```

**Figyelmeztetés:** Változtassa meg az alapértelmezett jelszavakat éles üzembe helyezés előtt!

---

### File Permissions in Docker

**English:**
Files mounted into Docker containers need appropriate permissions:

- **Init scripts** (SQL, shell): `0644` (readable by all)
- **Configuration files**: `0644` (readable by all)
- **Secret files** (keys, passwords): `0600` (owner only)

**Magyar:**
A Docker konténerekbe csatolt fájloknak megfelelő jogosultságokra van szükségük:

- **Init szkriptek** (SQL, shell): `0644` (mindenki által olvasható)
- **Konfigurációs fájlok**: `0644` (mindenki által olvasható)
- **Titkos fájlok** (kulcsok, jelszavak): `0600` (csak tulajdonos)

---

## Verification Commands | Ellenőrző Parancsok

### Check Service Health

```bash
# English: View all container statuses
# Magyar: Összes konténer állapotának megtekintése
docker ps -a --filter name=mail-

# English: Check specific service logs
# Magyar: Konkrét szolgáltatás naplóinak ellenőrzése
docker logs mail-postfix
docker logs mail-dovecot
docker logs mail-mysql

# English: Test Postfix configuration
# Magyar: Postfix konfiguráció tesztelése
docker exec mail-postfix postfix check

# English: Test Dovecot configuration
# Magyar: Dovecot konfiguráció tesztelése
docker exec mail-dovecot doveconf -n

# English: Check MySQL connectivity
# Magyar: MySQL kapcsolat ellenőrzése
docker exec mail-mysql mysql -u mailuser -pmail_secure_changeme mailserver -e "SELECT * FROM virtual_domains;"
```

---

## Summary of Changes | Változások Összefoglalása

### Files Modified | Módosított Fájlok

| File | Changes | Lines |
|------|---------|-------|
| `docker-compose.yml` | Removed version, added password defaults | 1, 21, 24, 65, 104, 158, 193 |
| `postfix/entrypoint.sh` | Restricted envsubst variables | 8 |
| `postfix/main.cf.template` | Commented unused features | 34-37 |
| `dovecot/Dockerfile` | Added postfix user | 18-19 |
| `dovecot/entrypoint.sh` | Restricted envsubst, created socket dirs | 8-9, 20-22 |
| `dovecot/dovecot.conf.template` | Removed incorrect !include | 19 |
| `mysql/init.sql` | Changed permissions to 0644 | permissions |

### Skills Demonstrated | Bemutatott Készségek

**English:**
- Docker container debugging and troubleshooting
- Postfix and Dovecot configuration management
- Shell script debugging (envsubst, variable expansion)
- Linux user/group management
- File permission management
- Docker Compose orchestration
- Production-ready security practices

**Magyar:**
- Docker konténer hibakeresés és hibaelhárítás
- Postfix és Dovecot konfiguráció kezelés
- Shell szkript hibakeresés (envsubst, változó kibontás)
- Linux felhasználó/csoport kezelés
- Fájl jogosultság kezelés
- Docker Compose orchestráció
- Produkció-kész biztonsági gyakorlatok

---

## Additional Resources | További Források

**English:**
- [Postfix Documentation](http://www.postfix.org/documentation.html)
- [Dovecot Wiki](https://doc.dovecot.org/)
- [Docker Compose Environment Variables](https://docs.docker.com/compose/environment-variables/)
- [envsubst Manual](https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html)

**Magyar:**
- [Postfix Dokumentáció](http://www.postfix.org/documentation.html)
- [Dovecot Wiki](https://doc.dovecot.org/)
- [Docker Compose Környezeti Változók](https://docs.docker.com/compose/environment-variables/)
- [envsubst Kézikönyv](https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html)

---

**Last Updated | Utolsó Frissítés:** 2025-11-30

**Status | Állapot:** Production-Ready | Produkció-Kész ✓
