# Project 02: Mail Server - Testing & Validation Results
# Projekt 02: Mail Szerver - Tesztelési és Validálási Eredmények

---

## Test Summary | Teszt Összefoglaló

**English:**
This document details the end-to-end testing, troubleshooting, and validation process for Project 02 (Dockerized Mail Server). The stack was validated through four gates: static analysis (shellcheck), full stack startup, automated test suites, and live smoke testing. All long-running services were verified healthy and the complete stack was confirmed production-ready. The testing process identified and resolved five distinct issues spanning the SMTP path, the database schema, the monitoring dashboard, the test harness, and a shellcheck defect.

**Magyar:**
Ez a dokumentum részletezi a Projekt 02 (Konténerizált Mail Szerver) végpontok közötti tesztelési, hibaelhárítási és validálási folyamatát. A stacket négy ellenőrzési kapun keresztül validáltuk: statikus elemzés (shellcheck), a teljes stack indítása, automatizált tesztcsomagok és élő smoke teszt. Az összes hosszan futó szolgáltatás egészségesnek bizonyult, és a teljes stack produkció-késznek igazolódott. A tesztelési folyamat öt különálló problémát azonosított és oldott meg, amelyek érintették az SMTP útvonalat, az adatbázis sémát, a monitoring dashboardot, a teszt keretrendszert és egy shellcheck hibát.

**Test Date:** 2026-06-27
**Status:** ✅ **ALL TESTS PASSED**
**Merged via:** PR #8

---

## Validation Gates | Validálási Kapuk

### 1. Static Analysis (shellcheck) | Statikus Elemzés (shellcheck)

**English:**
All Bash scripts and test files were linted with `shellcheck`. After the fixes described below, **12/12 scripts and tests passed clean** with no remaining errors, warnings, or notes.

**Magyar:**
Az összes Bash scriptet és teszt fájlt `shellcheck`-kel ellenőriztük. Az alább leírt javítások után **12/12 script és teszt hibátlanul átment**, nem maradt hiba, figyelmeztetés vagy megjegyzés.

---

### 2. Stack Startup | Stack Indítás

**English:**
`docker compose up` was executed for the full stack. All **6 long-running services reported healthy**: mysql, postfix, dovecot, spamassassin, roundcube, and dashboard. The `cert-init` container is a one-shot SSL initializer that exits 0 after generating certificates — this is expected behavior, not a failure.

**Magyar:**
A teljes stackre lefuttattuk a `docker compose up` parancsot. Mind a **6 hosszan futó szolgáltatás egészségesnek jelentette magát**: mysql, postfix, dovecot, spamassassin, roundcube és dashboard. A `cert-init` konténer egy egyszer lefutó SSL inicializáló, amely a tanúsítványok generálása után 0 kóddal kilép — ez elvárt viselkedés, nem hiba.

---

### 3. Automated Test Suites | Automatizált Tesztcsomagok

**English:**
```bash
tests/run-all-tests.sh
```
**Result:** ✅ Health Checks **29/29** and Mail Flow **13/13** = **42/42 tests passed**

**Magyar:**
**Eredmény:** ✅ Health Check-ek **29/29** és Mail Flow **13/13** = **42/42 teszt sikeres**

---

### 4. Live Smoke Testing | Élő Smoke Teszt

**English:**
- Dashboard on `:8080` → **HTTP 200**
- Roundcube webmail on `:80` → **HTTP 200**
- SMTP `:25` and submission `:587` greet with `220 mail.example.com ESMTP`
- IMAP `:143` and POP3 `:110` return Dovecot banners
- IMAPS / POP3S / SMTPS TLS ports validate their certificates

**Magyar:**
- Dashboard a `:8080` porton → **HTTP 200**
- Roundcube webmail a `:80` porton → **HTTP 200**
- SMTP `:25` és submission `:587` köszönés: `220 mail.example.com ESMTP`
- IMAP `:143` és POP3 `:110` Dovecot bannereket ad vissza
- IMAPS / POP3S / SMTPS TLS portok validálják a tanúsítványaikat

---

## Issues Identified & Resolved | Azonosított és Megoldott Problémák

### Issue 1: SMTP Completely Non-Functional (No Greeting)
### Probléma 1: SMTP Teljesen Működésképtelen (Nincs Köszönés)

**English:**

**Problem:**
- No `220` greeting was returned on SMTP port `25` or submission port `587`
- The SMTP service appeared completely non-functional to any connecting client

**Root Cause:**
- Postfix was configured with `smtpd_milters = inet:spamassassin:783`
- However, SpamAssassin's `spamd` on port `783` speaks the SPAMC/SPAMD protocol, **not** the milter protocol
- On every connection the milter handshake failed (`unreasonable packet length`) and Postfix aborted the SMTP session before sending the greeting

**Solution:**
- Disabled the broken milter wiring in `postfix/main.cf.template`
- Proper milter integration would require a separate `spamass-milter` bridge daemon, which is not deployed
- Added container logging since the image has no syslog daemon: `maillog_file = /dev/stdout` plus a `postlog` service in `master.cf`

**Note:** SpamAssassin's `spamd` still runs and is reachable via `spamc`, but it is no longer wired into the inbound SMTP path. SMTP-time scanning would require `spamass-milter` or a `content_filter`.

**Magyar:**

**Probléma:**
- Nem érkezett `220` köszönés az SMTP `25`-ös vagy a submission `587`-es porton
- Az SMTP szolgáltatás bármely csatlakozó kliens számára teljesen működésképtelennek tűnt

**Kiváltó Ok:**
- A Postfix `smtpd_milters = inet:spamassassin:783` beállítással volt konfigurálva
- Azonban a SpamAssassin `spamd` a `783`-as porton a SPAMC/SPAMD protokollt beszéli, **nem** a milter protokollt
- Minden kapcsolatnál a milter kézfogás meghiúsult (`unreasonable packet length`), és a Postfix megszakította az SMTP munkamenetet a köszönés elküldése előtt

**Megoldás:**
- Letiltottuk a hibás milter bekötést a `postfix/main.cf.template` fájlban
- A megfelelő milter integráció külön `spamass-milter` híd daemont igényelne, amely nincs telepítve
- Konténer naplózást adtunk hozzá, mivel az image-nek nincs syslog daemonja: `maillog_file = /dev/stdout` és egy `postlog` szolgáltatás a `master.cf`-ben

**Megjegyzés:** A SpamAssassin `spamd` továbbra is fut és elérhető a `spamc`-on keresztül, de már nincs bekötve a bejövő SMTP útvonalba. Az SMTP-idejű ellenőrzés `spamass-milter`-t vagy egy `content_filter`-t igényelne.

---

### Issue 2: MySQL Schema Missing
### Probléma 2: Hiányzó MySQL Séma

**English:**

**Problem:**
- The mail server tables were absent: `virtual_domains`, `virtual_users`, `virtual_aliases`, and `mailbox_usage`
- Without the schema, Postfix lookups and virtual user authentication had no backing data

**Root Cause:**
- The schema file `mysql/init.sql` did not exist
- It was additionally excluded by the `*.sql` rule in `project-02-mail-server/.gitignore`
- Docker therefore bind-mounted an empty directory at `/docker-entrypoint-initdb.d/init.sql` and the schema never loaded

**Solution:**
- Authored `mysql/init.sql` (4 tables plus a seeded primary domain)
- Added a `!mysql/init.sql` exception to the project `.gitignore`
- The script does **not** hardcode `USE mailserver`; the MySQL image already selects `${MYSQL_DATABASE}`, so the schema loads into the configured database
- `virtual_aliases` uses a composite index `idx_source_enabled (source, enabled)` matching the Postfix lookup; `domains.name` and `users.email` are `UNIQUE` so they need no composite index

**Magyar:**

**Probléma:**
- A mail szerver táblái hiányoztak: `virtual_domains`, `virtual_users`, `virtual_aliases` és `mailbox_usage`
- A séma nélkül a Postfix lekérdezéseknek és a virtuális felhasználó hitelesítésnek nem volt mögöttes adata

**Kiváltó Ok:**
- A `mysql/init.sql` séma fájl nem létezett
- Ráadásul kizárta a `*.sql` szabály a `project-02-mail-server/.gitignore`-ban
- A Docker emiatt egy üres könyvtárat csatolt a `/docker-entrypoint-initdb.d/init.sql` helyre, és a séma sosem töltődött be

**Megoldás:**
- Megírtuk a `mysql/init.sql`-t (4 tábla plus egy beágyazott elsődleges domain)
- Hozzáadtunk egy `!mysql/init.sql` kivételt a projekt `.gitignore`-jához
- A script **nem** kódolja be fixen a `USE mailserver`-t; a MySQL image már kiválasztja a `${MYSQL_DATABASE}`-t, így a séma a konfigurált adatbázisba töltődik
- A `virtual_aliases` egy `idx_source_enabled (source, enabled)` összetett indexet használ, amely megfelel a Postfix lekérdezésnek; a `domains.name` és a `users.email` `UNIQUE`, ezért nem igényelnek összetett indexet

---

### Issue 3: Monitoring Dashboard Returned HTTP 502
### Probléma 3: A Monitoring Dashboard HTTP 502-t Adott Vissza

**English:**

**Problem:**
- The monitoring dashboard returned `HTTP 502 (Bad Gateway)`
- The PHP application was unreachable through nginx

**Root Cause:**
- The dashboard nginx used `fastcgi_pass unix:/var/run/php-fpm.sock`
- The official php-fpm base image ships a `zz-docker.conf` that forces php-fpm to listen on TCP `127.0.0.1:9000`
- The Unix socket therefore never existed, so nginx had no upstream to reach

**Solution:**
- Pointed nginx at `fastcgi_pass 127.0.0.1:9000`
- Removed the dead socket-conversion `sed` from the dashboard Dockerfile

**Magyar:**

**Probléma:**
- A monitoring dashboard `HTTP 502 (Bad Gateway)` hibát adott vissza
- A PHP alkalmazás nem volt elérhető az nginx-en keresztül

**Kiváltó Ok:**
- A dashboard nginx `fastcgi_pass unix:/var/run/php-fpm.sock`-ot használt
- A hivatalos php-fpm alap image tartalmaz egy `zz-docker.conf`-ot, amely arra kényszeríti a php-fpm-et, hogy a TCP `127.0.0.1:9000` porton figyeljen
- A Unix socket emiatt sosem létezett, így az nginxnek nem volt elérhető upstreamje

**Megoldás:**
- Az nginx-et a `fastcgi_pass 127.0.0.1:9000`-re irányítottuk
- Eltávolítottuk a használhatatlan socket-konvertáló `sed`-et a dashboard Dockerfile-ból

---

### Issue 4: Test Harness False-Negatives Against a Working Stack
### Probléma 4: A Teszt Keretrendszer Téves Negatív Eredményei Egy Működő Stack Ellen

**English:**

**Problem:**
- Several tests reported failures even though the server itself was working correctly
- These were bugs in the tests, not the mail server

**Root Cause & Solution:**

In `tests/health-checks.sh`:
- The schema check used wrong default credentials → now uses the container's own root credentials
- The SSL-certificate checks used wrong filenames → corrected to `mail-cert.pem` / `mail-key.pem` / `dovecot.pem`
- The MySQL-reachability probe used `ping` (ICMP), which is not installed in slim images → switched to a TCP probe to port `3306`

In `tests/test-mail-flow-basic.sh`:
- The SMTP tests grepped for `220 ... ESMTP Postfix`, but the banner is intentionally hardened to `220 mail.example.com ESMTP` (no software name) → the pattern was relaxed to `220 ... ESMTP`

**Magyar:**

**Probléma:**
- Több teszt hibát jelzett, annak ellenére, hogy maga a szerver helyesen működött
- Ezek a tesztek hibái voltak, nem a mail szerveré

**Kiváltó Ok és Megoldás:**

A `tests/health-checks.sh`-ban:
- A séma ellenőrzés rossz alapértelmezett hitelesítő adatokat használt → most a konténer saját root hitelesítő adatait használja
- Az SSL-tanúsítvány ellenőrzések rossz fájlneveket használtak → javítva `mail-cert.pem` / `mail-key.pem` / `dovecot.pem`-re
- A MySQL-elérhetőség próba `ping`-et (ICMP) használt, amely nincs telepítve a slim image-ekben → áttértünk egy TCP próbára a `3306`-os portra

A `tests/test-mail-flow-basic.sh`-ban:
- Az SMTP tesztek a `220 ... ESMTP Postfix` mintát keresték, de a banner szándékosan keményítve van `220 mail.example.com ESMTP`-re (szoftvernév nélkül) → a mintát `220 ... ESMTP`-re lazítottuk

---

### Issue 5: Shellcheck Error in spam-report.sh
### Probléma 5: Shellcheck Hiba a spam-report.sh-ban

**English:**

**Problem:**
- `scripts/spam-report.sh` contained `((score_buckets[10+]++))`
- The `+` in the `"10+"` associative-array key broke arithmetic parsing (SC1105)
- As a result, the highest spam-score bucket was never counted

**Solution:**
- Rewrote the bucket increments to use literal string keys, e.g.:
```bash
score_buckets["10+"]=$(( ${score_buckets["10+"]:-0} + 1 ))
```
- All remaining shellcheck warnings and notes across the scripts and tests were also cleaned

**Magyar:**

**Probléma:**
- A `scripts/spam-report.sh` tartalmazta a `((score_buckets[10+]++))` sort
- A `"10+"` asszociatív tömb kulcsban lévő `+` megtörte az aritmetikai elemzést (SC1105)
- Ennek eredményeként a legmagasabb spam-pontszám rekesz sosem lett megszámolva

**Megoldás:**
- Átírtuk a rekesz növeléseket literális string kulcsok használatára, pl.:
```bash
score_buckets["10+"]=$(( ${score_buckets["10+"]:-0} + 1 ))
```
- A scriptekben és tesztekben maradt összes shellcheck figyelmeztetést és megjegyzést szintén kitisztítottuk

---

## Final Service Status | Végső Szolgáltatás Állapot

### Service Health Check Results | Szolgáltatás Állapot Ellenőrzés Eredményei

| Service | Status | Health | Notes |
|---------|--------|--------|-------|
| **MySQL** | ✅ Running | Healthy | Schema loaded (4 tables + seeded domain) |
| **Postfix** | ✅ Running | Healthy | SMTP `:25`, submission `:587` |
| **Dovecot** | ✅ Running | Healthy | IMAP `:143`, POP3 `:110` + TLS ports |
| **SpamAssassin** | ✅ Running | Healthy | `spamd` reachable via `spamc` |
| **Roundcube** | ✅ Running | Healthy | Webmail `:80` |
| **Dashboard** | ✅ Running | Healthy | Monitoring `:8080` |
| **cert-init** | ✅ Exited 0 | N/A | One-shot SSL initializer (expected) |

**Note:** *The `cert-init` container is a one-shot SSL initializer; exiting 0 after certificate generation is expected, not a failure.*

**Megjegyzés:** *A `cert-init` konténer egy egyszer lefutó SSL inicializáló; a 0 kóddal való kilépés a tanúsítvány generálása után elvárt, nem hiba.*

---

## Test Procedures Executed | Végrehajtott Teszt Eljárások

### 1. Static Analysis | Statikus Elemzés

**English:**
```bash
shellcheck scripts/*.sh scripts/lib/*.sh tests/*.sh
```
**Result:** ✅ 12/12 scripts and tests clean (after fixes)

**Magyar:**
**Eredmény:** ✅ 12/12 script és teszt tiszta (a javítások után)

---

### 2. Stack Startup | Stack Indítás

**English:**
```bash
docker compose up -d
docker compose ps
```
**Result:** ✅ All 6 long-running services healthy; `cert-init` exited 0 (expected)

**Magyar:**
**Eredmény:** ✅ Mind a 6 hosszan futó szolgáltatás egészséges; a `cert-init` 0 kóddal kilépett (elvárt)

---

### 3. Automated Test Suites | Automatizált Tesztcsomagok

**English:**
```bash
tests/run-all-tests.sh
```
**Result:** ✅ Health Checks 29/29 + Mail Flow 13/13 = 42/42 passed

**Magyar:**
**Eredmény:** ✅ Health Check-ek 29/29 + Mail Flow 13/13 = 42/42 sikeres

---

### 4. HTTP Endpoint Smoke Tests | HTTP Végpont Smoke Tesztek

**English:**
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080   # dashboard
curl -s -o /dev/null -w "%{http_code}" http://localhost:80     # roundcube
```
**Result:** ✅ Dashboard HTTP 200, Roundcube HTTP 200

**Magyar:**
**Eredmény:** ✅ Dashboard HTTP 200, Roundcube HTTP 200

---

### 5. SMTP / Submission Greeting Test | SMTP / Submission Köszönés Teszt

**English:**
```bash
nc -w2 localhost 25
nc -w2 localhost 587
```
**Result:** ✅ Both greet with `220 mail.example.com ESMTP`

**Magyar:**
**Eredmény:** ✅ Mindkettő `220 mail.example.com ESMTP` köszönéssel válaszol

---

### 6. IMAP / POP3 Banner Test | IMAP / POP3 Banner Teszt

**English:**
```bash
nc -w2 localhost 143   # IMAP
nc -w2 localhost 110   # POP3
```
**Result:** ✅ Both return Dovecot banners

**Magyar:**
**Eredmény:** ✅ Mindkettő Dovecot bannert ad vissza

---

### 7. TLS Certificate Validation | TLS Tanúsítvány Validálás

**English:**
```bash
openssl s_client -connect localhost:993   # IMAPS
openssl s_client -connect localhost:995   # POP3S
openssl s_client -connect localhost:465   # SMTPS
```
**Result:** ✅ IMAPS / POP3S / SMTPS ports validate their certificates

**Magyar:**
**Eredmény:** ✅ Az IMAPS / POP3S / SMTPS portok validálják a tanúsítványaikat

---

## Validation Checklist | Validálási Ellenőrzőlista

**English:**
- [x] All Bash scripts and tests pass shellcheck (12/12)
- [x] All 6 long-running services healthy under `docker compose up`
- [x] `cert-init` one-shot initializer exits 0 (expected)
- [x] Health Checks suite passes (29/29)
- [x] Mail Flow suite passes (13/13)
- [x] Dashboard endpoint returns HTTP 200
- [x] Roundcube webmail endpoint returns HTTP 200
- [x] SMTP `:25` and submission `:587` greet correctly
- [x] IMAP `:143` and POP3 `:110` return Dovecot banners
- [x] IMAPS / POP3S / SMTPS TLS ports validate certificates
- [x] SMTP greeting issue resolved (milter wiring disabled)
- [x] MySQL schema authored and loading correctly
- [x] Dashboard 502 resolved (fastcgi over TCP)
- [x] Test harness false-negatives fixed
- [x] spam-report.sh shellcheck error (SC1105) resolved

**Magyar:**
- [x] Az összes Bash script és teszt átmegy a shellcheck-en (12/12)
- [x] Mind a 6 hosszan futó szolgáltatás egészséges `docker compose up` alatt
- [x] A `cert-init` egyszer lefutó inicializáló 0 kóddal kilép (elvárt)
- [x] A Health Check csomag átmegy (29/29)
- [x] A Mail Flow csomag átmegy (13/13)
- [x] A dashboard végpont HTTP 200-at ad vissza
- [x] A Roundcube webmail végpont HTTP 200-at ad vissza
- [x] Az SMTP `:25` és submission `:587` helyesen köszön
- [x] Az IMAP `:143` és POP3 `:110` Dovecot bannert ad vissza
- [x] Az IMAPS / POP3S / SMTPS TLS portok validálják a tanúsítványokat
- [x] Az SMTP köszönés probléma megoldva (milter bekötés letiltva)
- [x] A MySQL séma megírva és helyesen betöltődik
- [x] A dashboard 502 megoldva (fastcgi TCP-n keresztül)
- [x] A teszt keretrendszer téves negatív eredményei javítva
- [x] A spam-report.sh shellcheck hiba (SC1105) megoldva

---

**Test Date:** 2026-06-27
**Final Status:** ✅ **PRODUCTION READY**
**Merged via:** PR #8

---

## Related Documentation | Kapcsolódó Dokumentáció

- [Project 02 README](../project-02-mail-server/README.md)
- [Project 02 Architecture](../project-02-mail-server/docs/ARCHITECTURE.md)
- [Project 02 Scripts](../project-02-mail-server/docs/SCRIPTS.md)
- [Project 01 Testing](./PROJECT-01-TESTING.md)
