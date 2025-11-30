# Contributing Guide | Hozzájárulási Útmutató

## Welcome | Üdvözöljük

**English:**
Thank you for your interest in contributing to the Linux System Administrator Portfolio! This document provides guidelines for contributing to the project.

**Magyar:**
Köszönjük, hogy érdeklődik a Linux Rendszergazda Portfólióhoz való hozzájárulás iránt! Ez a dokumentum útmutatást nyújt a projekthez való hozzájáruláshoz.

---

## Getting Started | Kezdés

### Prerequisites | Előfeltételek

- Docker 24.0+
- Docker Compose 2.20+
- Bash 5.0+
- Git
- (Optional) ShellCheck for script validation

### Setup | Telepítés

```bash
# Clone the repository
git clone https://github.com/yourusername/linux-sysadmin-portfolio.git
cd linux-sysadmin-portfolio

# Test a project
cd project-01-lamp-monitoring
docker compose up -d
```

---

## Code Style | Kód Stílus

### Bash Scripts

**English:**
All Bash scripts must follow these standards:

**Magyar:**
Minden Bash scriptnek követnie kell ezeket a szabványokat:

1. **Error Handling | Hibakezelés**
   ```bash
   set -euo pipefail
   ```

2. **Shebang**
   ```bash
   #!/bin/bash
   # or
   #!/usr/bin/env bash
   ```

3. **Variable Naming | Változó Elnevezés**
   ```bash
   # Constants - UPPER_CASE
   readonly MAX_RETRIES=3

   # Local variables - lower_case
   local file_path="$1"
   ```

4. **Functions | Függvények**
   ```bash
   function_name() {
       local arg1=$1
       # Function body
   }
   ```

5. **Logging | Naplózás**
   ```bash
   log() {
       echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
   }
   ```

### Docker

1. **Base Images | Alap Képek**
   - Use official images
   - Pin to specific versions
   - Prefer Alpine or Debian-slim

2. **Compose Files**
   - Use version 3.8+ syntax
   - Include health checks
   - Use named volumes

### Documentation | Dokumentáció

**Bilingual Requirement | Kétnyelvűség**

All documentation must include both English and Hungarian versions:

```markdown
## Section Name | Szekció Név

**English:**
Description in English.

**Magyar:**
Leírás magyarul.
```

---

## Pull Request Process | Pull Request Folyamat

### Before Submitting | Beküldés Előtt

1. **Test your changes | Teszteld a változtatásokat**
   ```bash
   # Run the project
   docker compose up -d

   # Check logs for errors
   docker compose logs

   # Validate scripts
   shellcheck scripts/*.sh
   ```

2. **Update documentation | Frissítsd a dokumentációt**
   - Update README if adding features
   - Include both EN and HU versions

3. **Follow commit message format | Kövesd a commit üzenet formátumot**
   ```
   type(scope): description

   [optional body]

   [optional footer]
   ```

   Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### Submitting | Beküldés

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Run tests
5. Commit with clear messages
6. Push to your fork
7. Open a Pull Request

---

## Issue Guidelines | Issue Útmutató

### Bug Reports | Hibajelentések

Please include:
- Project name (e.g., project-01-lamp-monitoring)
- Steps to reproduce
- Expected behavior
- Actual behavior
- Docker/system versions
- Relevant logs

### Feature Requests | Funkció Kérések

Please include:
- Clear description of the feature
- Use case / why it's needed
- Proposed implementation (optional)

---

## Project Structure | Projekt Struktúra

```
project-XX-name/
├── README.md              # Bilingual documentation
├── docker-compose.yml     # Service definitions
├── .env.example          # Environment template
├── [service]/
│   ├── Dockerfile        # Container definition
│   └── config files      # Service configuration
└── scripts/
    └── *.sh              # Bash scripts
```

---

## Questions | Kérdések

**English:**
If you have questions, please open an issue with the `question` label.

**Magyar:**
Ha kérdése van, kérjük nyisson egy issue-t a `question` címkével.

---

## License | Licenc

By contributing, you agree that your contributions will be licensed under the MIT License.

A hozzájárulással beleegyezik, hogy a hozzájárulásai az MIT licenc alatt lesznek licencelve.
