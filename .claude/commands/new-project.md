# New Project - Scaffold Portfolio Project

Create the directory structure and boilerplate files for a new portfolio project.

**Arguments:** $ARGUMENTS (project number and name)

Example: `/new-project 04-vpn-server "WireGuard VPN Server with monitoring"`

## Instructions

### Step 1: Parse Arguments

Extract from $ARGUMENTS:
- Project number (e.g., 04)
- Project name (e.g., vpn-server)
- Description (optional)

If not provided, ask the user for:
- What number should this project be?
- What's a short name for the project?
- Brief description of what it will do?

### Step 2: Determine Project Type

Based on the description, identify the project type:

| Type | Characteristics |
|------|-----------------|
| **Web Stack** | Nginx/Apache, PHP/Node, MySQL, web UI |
| **Mail/Messaging** | SMTP, IMAP, message queues |
| **Networking** | VPN, DNS, proxy, firewall |
| **Automation** | Scripts collection, no long-running services |
| **Monitoring** | Metrics, logging, alerting |

### Step 3: Create Directory Structure

```bash
project-XX-[name]/
├── README.md                    # Bilingual documentation
├── docker-compose.yml           # Service definitions
├── .env.example                 # Environment template
├── scripts/                     # Bash scripts
└── [service-dirs]/              # Service-specific configs
```

For specific project types, add:

**Web Stack:**
```
├── nginx/
│   └── default.conf
├── php/
│   └── Dockerfile
├── app/
│   └── index.php
```

**Networking:**
```
├── configs/
│   ├── server.conf
│   └── client.conf
```

**Automation:**
```
├── configs/
│   └── [config files]
├── tests/
│   └── test-runner.sh
```

### Step 4: Generate Boilerplate Files

#### README.md (Bilingual)
Use `.claude/templates/readme-template.md` if available, or create:

```markdown
# Project XX: [Name]

## Overview | Áttekintés

**English:**
[Project description]

**Magyar:**
[Hungarian translation]

---

## Architecture | Architektúra

\`\`\`
[ASCII architecture diagram]
\`\`\`

---

## Quick Start | Gyors Indítás

\`\`\`bash
# Copy environment file
cp .env.example .env

# Start services
docker compose up -d

# Access
# [URLs and ports]
\`\`\`

---

## Services | Szolgáltatások

| Service | Port | Description (EN) | Leírás (HU) |
|---------|------|------------------|-------------|
| [name] | [port] | [desc] | [hungarian] |

---

## Scripts | Scriptek

### [script-name].sh

**English:**
[Description]

**Magyar:**
[Hungarian translation]

---

## Skills Demonstrated | Bemutatott Készségek

- [ ] [Skill 1]
- [ ] [Skill 2]

---

## License | Licenc

MIT License - See [LICENSE](../LICENSE) for details.
```

#### docker-compose.yml
Use `.claude/templates/docker-compose-template.yml` if available, or create:

```yaml
version: '3.8'

services:
  # Main service
  app:
    build:
      context: ./app
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME:-project}-app
    restart: unless-stopped
    ports:
      - "${APP_PORT:-8080}:8080"
    environment:
      - TZ=${TZ:-UTC}
    volumes:
      - app_data:/data
    networks:
      - internal
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

networks:
  internal:
    driver: bridge

volumes:
  app_data:
```

#### .env.example
```bash
# Project Configuration
PROJECT_NAME=project-xx-name
TZ=Europe/Budapest

# Service Ports
APP_PORT=8080

# Database (if applicable)
# DB_HOST=mysql
# DB_NAME=appdb
# DB_USER=appuser
# DB_PASSWORD=changeme

# Secrets (generate secure values!)
# SECRET_KEY=generate-a-secure-key-here
```

### Step 5: Update Main README

Add the new project to the main README.md project table:

```markdown
| X | [Project Name](./project-XX-name/) | Description (EN) | Leírás (HU) |
```

### Step 6: Report to User

```
## Created: project-XX-[name]/

### Structure
project-XX-[name]/
├── README.md           ✓ Created (bilingual template)
├── docker-compose.yml  ✓ Created (basic skeleton)
├── .env.example        ✓ Created (environment template)
└── scripts/            ✓ Created (empty directory)

### Next Steps
1. Customize docker-compose.yml with actual services
2. Add service-specific directories (nginx/, app/, etc.)
3. Create Bash scripts in scripts/
4. Update README.md with real content
5. Fill in .env.example with actual variables

### To Start Development
\`\`\`bash
cd project-XX-[name]
cp .env.example .env
# Edit .env with your values
# Add services to docker-compose.yml
docker compose up -d
\`\`\`
```
