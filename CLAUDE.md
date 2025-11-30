# Linux System Administrator Portfolio

## Project Overview

This is a bilingual (English/Hungarian) portfolio showcasing production-ready Linux system administration skills through containerized DevOps projects.

**Repository:** `linux-sysadmin-portfolio`

**Tagline (EN):** A collection of production-ready DevOps projects demonstrating Linux system administration, containerization, and automation skills.

**Tagline (HU):** Produkció-kész DevOps projektek gyűjteménye, amelyek Linux rendszergazdai, konténerizációs és automatizálási készségeket mutatnak be.

---

## Repository Structure

```
linux-sysadmin-portfolio/
├── CLAUDE.md                          # This file - project context
├── README.md                          # Main portfolio overview (bilingual)
├── LICENSE                            # MIT License
├── .gitignore
│
├── project-01-lamp-monitoring/        # ✅ COMPLETED - LAMP Stack with Monitoring
│   ├── docker-compose.yml             # 4 services: Nginx, PHP, MySQL, Adminer
│   ├── scripts/                       # 728 lines of Bash (3 scripts)
│   │   ├── log-analyzer.sh            # 318 lines - PRIMARY SHOWCASE
│   │   ├── backup.sh                  # 215 lines
│   │   └── health-check.sh            # 195 lines
│   ├── app/                           # Interactive PHP dashboard
│   ├── nginx/                         # Reverse proxy configs
│   ├── php/                           # Custom Debian Dockerfile
│   └── mysql/                         # Database initialization
│
├── project-02-mail-server/            # Dockerized Mail Server (planned)
├── project-03-infra-automation/       # Infrastructure Automation Toolkit (planned)
│
├── docs/
│   ├── CONTRIBUTING.md
│   └── screenshots/
│
└── plans/
    └── 00-start_plan.md               # Detailed implementation specs
```

---

## Coding Standards

### Bash Scripts

All Bash scripts in this project MUST follow these standards:

1. **Error Handling**
   ```bash
   set -euo pipefail
   ```

2. **Shellcheck Compliance**
   - All scripts must pass `shellcheck` without errors
   - Use `# shellcheck disable=SC####` only when absolutely necessary with explanation

3. **Structured Logging**
   ```bash
   log() {
       local level=$1
       shift
       echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
   }
   ```

4. **Configuration via Environment Variables**
   ```bash
   readonly CONFIG_VAR="${CONFIG_VAR:-default_value}"
   ```

5. **JSON Output for Reports**
   - Use heredocs for JSON generation
   - Include timestamps in ISO 8601 format

6. **Signal Handling for Daemons**
   ```bash
   trap 'cleanup; exit 0' SIGTERM SIGINT
   ```

### Docker & Docker Compose

1. **Base Images**
   - Use official images where possible
   - Prefer Alpine or Debian-slim for custom builds
   - Pin versions (e.g., `nginx:1.25-alpine`, not `nginx:latest`)

2. **Compose Files**
   - Use version 3.8+ syntax
   - Define health checks for all services
   - Use named volumes for persistent data
   - Configure proper restart policies

3. **Security**
   - Never hardcode secrets in Dockerfiles
   - Use `.env` files (not committed) for sensitive values
   - Run containers as non-root where possible

### Documentation

1. **Bilingual Format**
   - All READMEs must include both English and Hungarian sections
   - Use clear section headers: `## Section Name | Szekció Név`
   - Code examples don't need translation

2. **Structure**
   ```markdown
   # Project Title

   ## Overview | Áttekintés
   **English:** [description]
   **Magyar:** [description]

   ## Quick Start | Gyors Indítás
   [code blocks - same for both languages]

   ## Features | Funkciók
   [bilingual list]
   ```

---

## Project Status

| Project | Status | Files | Scripts | Lines of Code |
|---------|--------|-------|---------|---------------|
| Project 01: LAMP Monitoring | ✅ **COMPLETE** | 16 files | 3 scripts | 728 lines |
| Project 02: Mail Server | 📋 Planned | - | - | - |
| Project 03: Infrastructure Automation | 📋 Planned | - | - | - |

**Project 01 Highlights:**
- Production-ready LAMP stack (Nginx, PHP-FPM 8.2, MySQL 8.0)
- Interactive dashboard with live metrics
- Advanced log analyzer (318 lines) with associative arrays, regex, JSON output
- Automated backup system with retention policy
- Health check monitoring for all services
- Bilingual documentation (English/Hungarian)
- Network isolation (frontend/backend)
- All coding standards followed

---

## Key Files Reference

- **Detailed Plan:** `plans/00-start_plan.md` - Contains comprehensive specs for all three projects including architecture diagrams, script examples, and implementation checklists
- **Project 01:** `project-01-lamp-monitoring/README.md` - Complete documentation for the LAMP stack implementation

---

## Custom Commands

- `/test-project [project-name]` - Run Docker tests for a specific project
- `/validate-scripts` - Run shellcheck on all Bash scripts
- `/deploy-local [project-name]` - Deploy a project locally

---

## Custom Agents

- `script-validator` - Analyzes Bash scripts for quality and security
- `security-auditor` - Reviews Docker configs and security settings

---

## Skills Demonstrated

| Skill | Projects |
|-------|----------|
| Debian Linux | All |
| Bash Scripting | All |
| Docker/Compose | All |
| Nginx/Apache | P1, P2 |
| MySQL | P1, P2 |
| PHP | P1 |
| Postfix/Dovecot | P2 |
| TCP/IP Networking | All |
| Security Hardening | P3 |
| Log Analysis | All |
