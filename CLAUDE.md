# CLAUDE.md

Project context for Claude Code. A bilingual (EN/HU) Linux system-administration
portfolio of three independent, fully containerized projects. Each project runs
standalone via `docker compose`.

## Repository layout

| Path | What |
|------|------|
| `project-01-lamp-monitoring/` | LAMP stack (nginx, php-fpm 8.2, mysql 8.0, adminer) + Bash monitoring/backup scripts |
| `project-02-mail-server/` | Postfix/Dovecot/SpamAssassin/Roundcube mail stack + PHP dashboard + test suite |
| `project-03-infra-automation/` | 6 sysadmin Bash tools + Docker multi-OS test harness (debian/alpine/ubuntu/coredns) |
| `docs/` | Cross-project docs (ARCHITECTURE, DEPLOYMENT, SCRIPTS, CHANGELOG, PROJECT-0X-TESTING) — all bilingual |
| `plans/00-start_plan.md` | Original full implementation spec (47 KB) |
| `.github/` | CI (`workflows/ci.yml`), PR/issue templates, CODEOWNERS, dependabot, SECURITY |

## Common commands

Each project is self-contained; `cd` into it first.

```bash
cp .env.example .env                 # required before first run (sets DB passwords etc.)
docker compose up -d --build         # start the stack
docker compose ps                    # check health
docker compose logs -f <service>
docker compose down -v               # tear down + remove volumes (full reset)
```

Validation gates (what CI also runs — keep all four green):

```bash
shellcheck -x <script.sh>            # static analysis; CI uses v0.10.0, --severity=warning
docker compose -f <proj>/docker-compose.yml --project-directory <proj> config -q
cd project-02-mail-server && bash tests/run-all-tests.sh   # 42 tests
cd project-03-infra-automation && bash tests/e2e-test.sh   # 43 tests (TAP output)
```

## Per-project notes

**project-01** — scripts: `log-analyzer.sh` (showcase), `backup.sh`, `health-check.sh`. No `tests/` dir; validate by health + valid JSON output. Endpoints: nginx `:80`, Adminer `127.0.0.1:8080`.

**project-02** — services: `cert-init` (one-shot SSL init, exits 0), `mysql`, `postfix`, `dovecot`, `spamassassin`, `roundcube`, `dashboard`. Scripts under `scripts/` (+ `lib/common.sh`). Tests under `tests/`. Schema: `mysql/init.sql`.

**project-03** — tools: `server-hardening.sh` (showcase), `network-diagnostics.sh`, `service-watchdog.sh`, `backup-manager.sh`, `log-rotation.sh`, `system-inventory.sh` (+ shared `lib/common.sh`). Test harness: `tests/e2e-test.sh` drives debian/alpine/ubuntu/nginx/coredns containers. `server-hardening.sh` CLI: `--check` (audit/dry-run), `--fix`, `--modules ssh,kernel`.

## Gotchas (non-obvious, learned the hard way)

- **`set -euo pipefail` + `((var++))` aborts the script** when `var` is 0 (post-increment returns the old value → non-zero exit). Always use `var=$((var+1))`.
- **Scripts that emit JSON** (e.g. `health-check.sh`): send `log()` to **stderr**, keep stdout clean — command substitutions that capture stdout otherwise corrupt the JSON.
- **Sourcing the shared lib**: add `# shellcheck source-path=SCRIPTDIR` and run `shellcheck -x` so sources resolve. Shared table/format helpers (`print_table_*`) live in `scripts/lib/common.sh`, not in individual scripts.
- **P01 Adminer** needs **both** networks: `frontend` (to publish its port) and `backend` (to reach MySQL; `backend` is `internal: true` and cannot expose ports). Its port is bound to `127.0.0.1:8080` (loopback) on purpose — it's a high-privilege DB UI. The `adminer:4.8.1` image ships no curl/wget, so its healthcheck uses bundled PHP.
- **P02 Postfix milter**: SpamAssassin `spamd` (port 783) speaks SPAMC/SPAMD, **not** the milter protocol — never point `smtpd_milters` at it (it aborts every SMTP session). SMTP-time scanning needs `spamass-milter` or a `content_filter`. Container logging needs `maillog_file = /dev/stdout` + a `postlog` service (no syslog in the image).
- **P02 php-fpm** official image forces TCP via `zz-docker.conf` (`listen = 9000`); nginx must use `fastcgi_pass 127.0.0.1:9000`, not a unix socket.
- **P02 MySQL `init.sql`**: do **not** hardcode `USE <db>` — the image already selects `${MYSQL_DATABASE}`. Note `mysql/*.sql` is gitignored, so `init.sql` is tracked only via the `!mysql/init.sql` exception in that project's `.gitignore`.
- **P03 target containers**: don't add a compose `command:` override — it replaces the image CMD (`sleep infinity`) and the container exits/restart-loops. Let the entrypoint's `exec "$@"` keep it alive.
- **P03 CoreDNS** is built `FROM scratch` (no shell/nc/curl) → an exec healthcheck is impossible; rely on the Corefile `health :8080` plugin + restart policy instead.

## Conventions

- **Bash**: `set -euo pipefail`; must pass `shellcheck -x --severity=warning` (advisory info/style notes like intentional SC2016 single-quoting are acceptable).
- **Docs**: bilingual English + Magyar; mirror both when editing prose.
- **`main` is protected**: no force-push, no deletion; required status checks **ShellCheck** + **Compose Validate** (`.github/workflows/ci.yml`). Land changes via PR.
- **Commits/PRs**: do **not** add Claude Code / AI attribution (no `Co-Authored-By` trailer, no "Generated with…" footer) — project owner's preference.
