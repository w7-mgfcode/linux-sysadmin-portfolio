# Changelog | Változásnapló

All notable end-to-end test/repair/validate changes to this portfolio are documented here.

Minden jelentős végponttól-végpontig teszt/javítás/validálás változás itt van dokumentálva.

---

## [2026-06-27] End-to-End Validation & Repair | Végponttól-végpontig validálás és javítás

**English:** Every project was taken through a full loop — **test → review → repair → validate** — across four gates: static analysis (`shellcheck`), container health (`docker compose up` + health checks), the project test suites, and HTTP/protocol endpoint smoke tests. All identified defects were fixed and re-validated. The work landed as four pull requests, each merged after an automated review pass.

**Magyar:** Minden projekt végigment egy teljes cikluson — **teszt → áttekintés → javítás → validálás** — négy kapun keresztül: statikus elemzés (`shellcheck`), konténer állapot (`docker compose up` + állapotellenőrzések), a projekt tesztcsomagok, és HTTP/protokoll végpont füsttesztek. Minden azonosított hibát kijavítottunk és újra-validáltunk. A munka négy pull requestként került be, mindegyik automatikus áttekintés után összefésülve.

### Pull Requests

| PR | Scope | Status |
|----|-------|--------|
| #6 | `chore`: stop tracking `.claude/` and `CLAUDE.md` | ✅ Merged |
| #7 | `fix(project-01)`: adminer reachability + valid health-check JSON | ✅ Merged |
| #8 | `fix(project-02)`: SMTP, dashboard, DB schema + shellcheck | ✅ Merged |
| #9 | `fix(project-03)`: target uptime, healthchecks, `set -e` footguns, e2e suite | ✅ Merged |

---

### Project 01 — LAMP Monitoring

**English:** Fixed Adminer host reachability and the health-check JSON report.

**Magyar:** Javítva az Adminer host elérhetősége és a health-check JSON jelentés.

| # | Root cause | Fix |
|---|-----------|-----|
| 1 | Adminer (`:8080`) returned HTTP 000 — it was on the `backend` network only, which is `internal`, so its published port could not reach the host. | Attached Adminer to the `frontend` network as well (kept `backend` for MySQL). |
| 2 | `adminer:latest` was unpinned. | Pinned to `adminer:4.8.1`. |
| 3 | Adminer reported unhealthy — its healthcheck used `curl`, which the `4.8.1` image does not ship. | Switched to a bundled-PHP probe with a short `default_socket_timeout`. |
| 4 | Adminer's published port was bound to all host interfaces — a high-privilege DB UI. | Bound the port to `127.0.0.1:8080:8080` (loopback only). |
| 5 | `health-check.sh` emitted invalid JSON — `log()` wrote to stdout, polluting the `$(check_*)` command substitutions. | `log()` now writes to **stderr**; stdout carries only machine-readable values and the JSON report. |

**Validation:** `shellcheck` 3/3 clean · 4/4 services healthy · nginx `:80` = 200, adminer `127.0.0.1:8080` = 200 · `health-check.sh`, `log-analyzer.sh`, `backup.sh` all produce valid JSON.

---

### Project 02 — Mail Server

**English:** Restored SMTP, the MySQL schema, and the monitoring dashboard; corrected the test harness; cleaned static analysis.

**Magyar:** Helyreállítva az SMTP, a MySQL séma és a monitoring vezérlőpult; javítva a tesztkeret; megtisztítva a statikus elemzés.

| # | Root cause | Fix |
|---|-----------|-----|
| 1 | **SMTP dead** (no `220` greeting on `:25`/`:587`) — `smtpd_milters = inet:spamassassin:783` pointed at SpamAssassin's `spamd`, which speaks SPAMC/SPAMD, **not** the milter protocol; the handshake failed at CONNECT and aborted every session. | Disabled the broken milter wiring. Added container logging (`maillog_file = /dev/stdout` + a `postlog` service). SpamAssassin `spamd` still runs and is reachable via `spamc`, but is no longer in the SMTP path — use `spamass-milter`/`content_filter` to re-enable SMTP-time scanning. |
| 2 | **MySQL schema missing** — `mysql/init.sql` did not exist **and** was ignored by `*.sql`, so Docker mounted an empty directory and no tables were created. | Authored `init.sql` (`virtual_domains`, `virtual_users`, `virtual_aliases`, `mailbox_usage` + seed domain); added a `!mysql/init.sql` gitignore exception. The script respects `${MYSQL_DATABASE}` (no hardcoded `USE`), and `virtual_aliases` has a composite `idx_source_enabled (source, enabled)`. |
| 3 | **Dashboard 502** — nginx used a Unix socket, but the base image's `zz-docker.conf` forces php-fpm onto TCP `9000`. | `fastcgi_pass 127.0.0.1:9000`; removed the dead socket `sed`. |
| 4 | **Test-harness false negatives** against a working stack. | `health-checks.sh`: container-root credentials for the schema check, correct SSL cert paths (`mail-cert.pem`/`mail-key.pem`/`dovecot.pem`), TCP probe for MySQL reachability (`ping` is not installed). `test-mail-flow-basic.sh`: match the hardened `220 ... ESMTP` banner. |
| 5 | **Shellcheck error (SC1105)** in `spam-report.sh` — `((score_buckets[10+]++))` failed to parse, so the `10+` score bucket was never counted. | Rewrote bucket increments with literal string keys and `:-0` defaults; cleaned all remaining warnings/notes. |

**Validation:** `shellcheck` 12/12 clean · 6/6 services healthy (cert-init one-shot exits 0) · test suites **42/42** (Health 29, Mail Flow 13) · dashboard/roundcube = 200 · SMTP/IMAP/POP3 greet.

---

### Project 03 — Infrastructure Automation

**English:** Kept the OS targets alive, fixed health checks, eliminated a recurring `set -e` footgun, and got the end-to-end suite running for the first time.

**Magyar:** Életben tartva az OS célpontok, javítva az állapotellenőrzések, megszüntetve egy visszatérő `set -e` hiba, és először futtatva a végponttól-végpontig tesztcsomag.

| # | Root cause | Fix |
|---|-----------|-----|
| 1 | OS target containers restart-looped — a compose `command:` override replaced the image CMD (`sleep infinity`), so the entrypoint ran setup and exited. | Removed the override; the entrypoint's `exec "$@"` runs `sleep infinity`. |
| 2 | The debian target healthcheck checked the wrong PID path (`/var/run/ssh/sshd.pid`). | Corrected to `/var/run/sshd.pid`. |
| 3 | CoreDNS was perpetually unhealthy — its healthcheck used `sh`/`nc`, absent from the scratch image. | Removed the impossible healthcheck; liveness via the Corefile `health :8080` plugin (verified 200) + restart policy. |
| 4 | **21 `((var++))` `set -e` footguns** across all 7 scripts — `((x++))` returns non-zero when `x` is 0, aborting the script the first time a counter goes 0→1. | Replaced every occurrence with `var=$((var+1))`. |
| 5 | `backup-manager.sh` called `print_table_header` (and row/footer), defined only in `network-diagnostics.sh` → "command not found". | Moved the table helpers into shared `lib/common.sh`. |
| 6 | The e2e suite could not run — the same footgun aborted it on the first test, and `run_test` propagated a non-zero return under `set -e`. Several tests also invoked non-existent CLIs. | Fixed both `set -e` issues; aligned tests to the real CLIs (`--check`/`--modules`, `ports <host>`, `compgen -G` for the backup archive). |

**Validation:** `shellcheck` 8/8 clean · 4 targets healthy + CoreDNS live (DNS resolves, `health:8080` = 200) · e2e suite **43/43** (was 0 — the suite never ran before).

---

### Repository hygiene | Repó higiénia

**English:** `.claude/` and `CLAUDE.md` (local assistant working files) are now `.gitignore`d and untracked. The `project-02-mail-server/.gitignore` `*.sql` rule was given a `!mysql/init.sql` exception so the database schema is tracked.

**Magyar:** A `.claude/` és `CLAUDE.md` (helyi asszisztens munkafájlok) mostantól `.gitignore`-oltak és nem követettek. A `project-02-mail-server/.gitignore` `*.sql` szabálya `!mysql/init.sql` kivételt kapott, hogy az adatbázis séma követett legyen.

---

## Final Validation Summary | Végső Validálási Összefoglaló

| Project | shellcheck | Stack health | Test suite | Endpoint smoke |
|---------|:----------:|:------------:|:----------:|:--------------:|
| 01 — LAMP | ✅ 3/3 | ✅ 4/4 | ✅ valid JSON | ✅ nginx 200, adminer 200 |
| 02 — Mail | ✅ 12/12 | ✅ 6/6 | ✅ 42/42 | ✅ web 200, SMTP/IMAP/POP3 |
| 03 — Infra | ✅ 8/8 | ✅ targets + DNS | ✅ 43/43 | ✅ nginx 200, DNS resolves |
