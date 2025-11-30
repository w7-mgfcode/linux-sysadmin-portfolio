# Generate Docs - Create Bilingual Documentation

Generate or update bilingual (English/Hungarian) documentation for portfolio projects.

**Arguments:** $ARGUMENTS (target file, script, or project)

Example:
- `/generate-docs project-01` - Document entire project
- `/generate-docs scripts/backup.sh` - Document specific script
- `/generate-docs docker-compose.yml` - Document compose file

## Instructions

### Step 1: Identify Target

Parse $ARGUMENTS to determine what to document:

| Input | Action |
|-------|--------|
| Project name | Document entire project README |
| Script path | Document script usage |
| Config file | Explain configuration options |
| `services` | Document Docker services |

### Step 2: Analyze Target

#### For Scripts:
```bash
# Read the script
cat [script-path]

# Extract:
# - Purpose from header comments
# - Usage/options from usage() function
# - Environment variables used
# - Key functions and what they do
```

#### For Docker Compose:
```bash
# Parse compose file for:
# - Services and their purposes
# - Ports exposed
# - Volumes defined
# - Environment variables
# - Health checks
```

#### For Projects:
```bash
# Gather:
# - All services from docker-compose.yml
# - All scripts in scripts/
# - Configuration files
# - Architecture (how components connect)
```

### Step 3: Generate Bilingual Content

Use this template structure:

```markdown
## [Section Name] | [Szekció Név]

**English:**
[Content in English]

**Magyar:**
[Content in Hungarian]
```

### Step 4: Content Templates

#### Script Documentation:

```markdown
### [script-name].sh

**English:**
[What the script does, when to use it, key features]

**Magyar:**
[Hungarian translation]

**Usage | Használat:**
\`\`\`bash
# [English comment]
./[script-name].sh [options]

# Example | Példa
./[script-name].sh --verbose
\`\`\`

**Options | Opciók:**
| Option | Description (EN) | Leírás (HU) |
|--------|------------------|-------------|
| `-h, --help` | Show help message | Súgó megjelenítése |
| `-v, --verbose` | Enable verbose output | Részletes kimenet |

**Environment Variables | Környezeti Változók:**
| Variable | Default | Description (EN) | Leírás (HU) |
|----------|---------|------------------|-------------|
| `VAR_NAME` | `default` | [description] | [hungarian] |
```

#### Service Documentation:

```markdown
### Services | Szolgáltatások

| Service | Port | Description (EN) | Leírás (HU) |
|---------|------|------------------|-------------|
| nginx | 80, 443 | Web server and reverse proxy | Webszerver és reverse proxy |
| php | 9000 | PHP application server | PHP alkalmazás szerver |
| mysql | 3306 | Database server | Adatbázis szerver |
```

#### Architecture Documentation:

```markdown
## Architecture | Architektúra

**English:**
[Description of how components interact]

**Magyar:**
[Hungarian translation]

\`\`\`
┌─────────────────────────────────────────────────────────────┐
│                    docker-compose.yml                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │  Nginx   │───▶│   PHP    │───▶│  MySQL   │              │
│  │  :80     │    │  :9000   │    │  :3306   │              │
│  └──────────┘    └──────────┘    └──────────┘              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
\`\`\`

**Data Flow | Adatfolyam:**
1. Client connects to Nginx (port 80/443)
   Kliens csatlakozik az Nginx-hez (80/443 port)
2. Nginx forwards PHP requests to PHP-FPM
   Az Nginx továbbítja a PHP kéréseket a PHP-FPM-nek
3. PHP-FPM queries MySQL database
   A PHP-FPM lekérdezi a MySQL adatbázist
```

#### Quick Start Documentation:

```markdown
## Quick Start | Gyors Indítás

**English:**
\`\`\`bash
# Clone the repository
git clone https://github.com/yourusername/linux-sysadmin-portfolio.git
cd linux-sysadmin-portfolio/project-XX-name

# Copy and configure environment
cp .env.example .env
# Edit .env with your values

# Start services
docker compose up -d

# Verify
docker compose ps
\`\`\`

**Magyar:**
\`\`\`bash
# Klónozd a repository-t
git clone https://github.com/yourusername/linux-sysadmin-portfolio.git
cd linux-sysadmin-portfolio/project-XX-name

# Másold és konfiguráld a környezetet
cp .env.example .env
# Szerkeszd a .env fájlt

# Indítsd el a szolgáltatásokat
docker compose up -d

# Ellenőrzés
docker compose ps
\`\`\`
```

#### Skills Documentation:

```markdown
## Skills Demonstrated | Bemutatott Készségek

| Skill | How Demonstrated (EN) | Hogyan Bemutatva (HU) |
|-------|----------------------|----------------------|
| Docker | Multi-container orchestration | Több konténeres orkesztráció |
| Bash | Advanced scripting with arrays | Haladó scriptelés tömbökkel |
| Networking | Reverse proxy configuration | Reverse proxy konfiguráció |
```

### Step 5: Hungarian Translation Guidelines

Common translations for this domain:

| English | Hungarian |
|---------|-----------|
| Server | Szerver |
| Database | Adatbázis |
| Container | Konténer |
| Network | Hálózat |
| Volume | Kötet |
| Service | Szolgáltatás |
| Script | Script |
| Configuration | Konfiguráció |
| Backup | Biztonsági mentés |
| Monitoring | Figyelés/Monitoring |
| Log | Napló |
| Error | Hiba |
| Warning | Figyelmeztetés |
| Port | Port |
| Health check | Állapotellenőrzés |
| Environment variable | Környezeti változó |

### Step 6: Output

Present the generated documentation:

```
## Generated Documentation

### Target: [what was documented]

### Content

[The actual bilingual documentation]

### Integration

To add this to your project:
1. Copy the content above
2. Paste into [appropriate README section]
3. Review and adjust as needed

### Files Updated
- [list of files that should be updated]
```

## Example Output

```
## Generated Documentation for: scripts/log-analyzer.sh

### log-analyzer.sh

**English:**
Analyzes Nginx access and error logs, generates JSON reports, and sends
alerts when error rates exceed configured thresholds. Demonstrates
advanced Bash scripting with associative arrays and JSON generation.

**Magyar:**
Elemzi az Nginx hozzáférési és hibanaplókat, JSON jelentéseket generál,
és riasztásokat küld, ha a hibaarány meghaladja a beállított
küszöbértékeket. Haladó Bash scriptelést mutat be asszociatív tömbökkel
és JSON generálással.

**Usage | Használat:**
\`\`\`bash
# Run analysis / Elemzés futtatása
docker compose exec php /scripts/log-analyzer.sh

# View report / Jelentés megtekintése
cat /var/reports/analysis_*.json
\`\`\`

**Environment Variables | Környezeti Változók:**
| Variable | Default | Description (EN) | Leírás (HU) |
|----------|---------|------------------|-------------|
| `LOG_DIR` | `/var/log/nginx` | Log directory | Napló könyvtár |
| `REPORT_DIR` | `/var/reports` | Report output dir | Jelentés kimeneti könyvtár |
| `WEBHOOK_URL` | - | Alert webhook | Riasztási webhook |

---

### Add to README.md

This documentation should be added under the "## Bash Scripts | Bash Scriptek"
section of the project README.
```
