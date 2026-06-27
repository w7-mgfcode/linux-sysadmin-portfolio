# AGENTS.md

## Project Overview

This repository is a bilingual English/Hungarian Linux system-administration portfolio with three independent Docker Compose projects:

- `project-01-lamp-monitoring/` - LAMP/LEMP stack with nginx, PHP-FPM, MySQL, Adminer, and Bash monitoring/backup scripts.
- `project-02-mail-server/` - Postfix, Dovecot, SpamAssassin, Roundcube, dashboard, and mail-server automation tests.
- `project-03-infra-automation/` - Bash infrastructure tools with a Docker-based multi-OS test harness.

Shared documentation lives in `docs/`; project-specific documentation lives in each project directory.

## Build and Test Commands

Run commands from the repository root unless the command explicitly changes directory.

- `find . -type f -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shellcheck -x --severity=warning` - run after changing Bash scripts or tests. CI pins ShellCheck to v0.10.0 and treats warnings/errors as failures.
- `for dir in project-01-lamp-monitoring project-02-mail-server project-03-infra-automation; do [ -f "$dir/.env" ] || cp "$dir/.env.example" "$dir/.env"; docker compose -f "$dir/docker-compose.yml" --project-directory "$dir" config --quiet; done` - validate all Compose files like CI.
- `cd project-02-mail-server && bash tests/run-all-tests.sh` - run after changing the mail stack, dashboard, schema, or project-02 scripts.
- `cd project-03-infra-automation && bash tests/e2e-test.sh` - run after changing project-03 tools, containers, configs, or test harness.
- `cd <project-dir> && cp .env.example .env && docker compose up -d --build` - start a project stack for smoke testing.
- `cd <project-dir> && docker compose down -v` - tear down a project stack and remove volumes after destructive local test runs.

## Code Style

- Bash scripts should use `set -euo pipefail`, local lowercase variables, uppercase constants, and clear function names.
- When a script sources a shared library, add `# shellcheck source-path=SCRIPTDIR` and validate with `shellcheck -x`.
- Under `set -e`, do not use `((var++))` for counters because incrementing from zero returns a failing status; use `var=$((var+1))`.
- Keep stdout machine-readable when a script promises JSON output. Send logs and status messages to stderr.
- Docker images should use official, version-pinned bases where practical, health checks for long-running services, named volumes, and isolated backend networks for databases.
- Documentation is bilingual. When editing user-facing docs, update both English and Hungarian sections.

## Architecture Notes

- Each top-level `project-0*/` directory is self-contained and should be runnable with its own `.env` and `docker compose` commands.
- `project-01-lamp-monitoring/` has no dedicated test directory; validate with Compose config, stack health, endpoint smoke tests, and JSON cleanliness from `scripts/health-check.sh`.
- `project-02-mail-server/` uses `cert-init` as a one-shot SSL initializer; an exit code of 0 is expected and is not a failed service.
- SpamAssassin `spamd` speaks SPAMC/SPAMD on port 783, not the milter protocol. Do not wire Postfix `smtpd_milters` directly to `spamassassin:783`.
- Official PHP-FPM images listen on TCP `127.0.0.1:9000` through `zz-docker.conf`; nginx FastCGI configs should not assume a Unix socket unless the image is changed accordingly.
- MySQL init scripts should not hardcode `USE <db>` when the Docker image already selects `${MYSQL_DATABASE}`.
- In project 03, target container entrypoints end with `exec "$@"`; avoid Compose `command:` overrides that replace the intended `sleep infinity` keep-alive.
- CoreDNS is built from `scratch`; do not add exec health checks that require shell, `nc`, `curl`, or `wget`.

## Validation Before Completion

- For shell or Compose changes, run the matching commands from `Build and Test Commands` and report any command that could not be run.
- For project-02 and project-03 behavior changes, run their automated test suites unless the change is documentation-only or the environment lacks Docker.
- For documentation-only changes, verify Markdown content manually and preserve bilingual structure.
- Check `git status --short` before finishing so user changes are not mistaken for agent edits.

## Security and Secrets

- Do not commit `.env` files, private keys, credentials, tokens, generated certificates, or real mailbox data.
- Use `.env.example` for defaults and placeholders.
- Keep Adminer and other high-privilege admin surfaces loopback-only or internal unless the user explicitly asks for exposure.
- Do not remove network isolation that keeps databases and backend services off host-exposed networks.

## Repository-Specific Rules

- Preserve existing user changes; do not reset, overwrite, or clean unrelated work.
- Do not add AI attribution, `Generated with...` footers, or `Co-Authored-By` trailers.
- `main` is protected; expect changes to land through PRs with the `ShellCheck` and `Compose Validate` checks green.
- Closer nested `AGENTS.md` files, if added later, override these root instructions for their subtree.
