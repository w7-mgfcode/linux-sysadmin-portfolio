# Project XX: [Project Name]

## Overview | Áttekintés

**English:**
[Detailed description of what this project does, its purpose, and key features.
Explain what skills are demonstrated and why this project is valuable for
showcasing Linux system administration expertise.]

**Magyar:**
[Hungarian translation of the description above. Részletes leírás arról, hogy mit
csinál ez a projekt, mi a célja és milyen főbb funkciókkal rendelkezik. Magyarázd
el, milyen készségeket mutat be és miért értékes a Linux rendszergazdai szakértelem
bemutatásához.]

---

## Architecture | Architektúra

```
┌─────────────────────────────────────────────────────────────┐
│                    docker-compose.yml                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │ Service1 │───▶│ Service2 │───▶│ Service3 │              │
│  │  :PORT   │    │  :PORT   │    │  :PORT   │              │
│  └──────────┘    └──────────┘    └──────────┘              │
│       │                               │                     │
│       ▼                               ▼                     │
│  ┌──────────┐                   ┌──────────┐               │
│  │ Service4 │                   │  Volume  │               │
│  │  :PORT   │                   │          │               │
│  └──────────┘                   └──────────┘               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Quick Start | Gyors Indítás

**English:**
```bash
# Clone the repository
git clone https://github.com/yourusername/linux-sysadmin-portfolio.git
cd linux-sysadmin-portfolio/project-XX-name

# Copy and configure environment
cp .env.example .env
# Edit .env with your values

# Start all services
docker compose up -d

# Verify services are running
docker compose ps

# View logs
docker compose logs -f
```

**Magyar:**
```bash
# Klónozd a repository-t
git clone https://github.com/yourusername/linux-sysadmin-portfolio.git
cd linux-sysadmin-portfolio/project-XX-name

# Másold és konfiguráld a környezetet
cp .env.example .env
# Szerkeszd a .env fájlt az értékeiddel

# Indítsd el az összes szolgáltatást
docker compose up -d

# Ellenőrizd, hogy a szolgáltatások futnak
docker compose ps

# Naplók megtekintése
docker compose logs -f
```

---

## Services | Szolgáltatások

| Service | Port | Description (EN) | Leírás (HU) |
|---------|------|------------------|-------------|
| [service1] | [port] | [description] | [hungarian] |
| [service2] | [port] | [description] | [hungarian] |
| [service3] | [port] | [description] | [hungarian] |

---

## Configuration | Konfiguráció

### Environment Variables | Környezeti Változók

| Variable | Default | Description (EN) | Leírás (HU) |
|----------|---------|------------------|-------------|
| `PROJECT_NAME` | `project-xx` | Project name for containers | Konténerek projekt neve |
| `TZ` | `UTC` | Timezone | Időzóna |
| [more vars] | [default] | [description] | [hungarian] |

### Volumes | Kötetek

| Volume | Mount Point | Purpose (EN) | Cél (HU) |
|--------|-------------|--------------|----------|
| [volume] | [path] | [purpose] | [hungarian] |

---

## Bash Scripts | Bash Scriptek

### [script-name-1].sh

**English:**
[Description of what the script does, when to use it, and what makes it notable]

**Magyar:**
[Hungarian translation]

**Usage | Használat:**
```bash
# Run the script
docker compose exec [service] /scripts/[script-name-1].sh

# With options
docker compose exec [service] /scripts/[script-name-1].sh --verbose
```

**Skills Demonstrated | Bemutatott Készségek:**
- [Skill 1]
- [Skill 2]
- [Skill 3]

---

### [script-name-2].sh

**English:**
[Description]

**Magyar:**
[Hungarian translation]

**Usage | Használat:**
```bash
docker compose exec [service] /scripts/[script-name-2].sh
```

---

## Skills Demonstrated | Bemutatott Készségek

| Requirement | How This Project Proves It |
|-------------|---------------------------|
| **[Skill 1]** | [Specific demonstration] |
| **[Skill 2]** | [Specific demonstration] |
| **[Skill 3]** | [Specific demonstration] |

**Checklist:**
- [x] Docker containerization | Docker konténerizáció
- [x] [Skill 2] | [Hungarian]
- [x] [Skill 3] | [Hungarian]
- [ ] [Planned skill] | [Hungarian]

---

## Troubleshooting | Hibaelhárítás

### Common Issues | Gyakori Problémák

**Issue 1: [Problem description]**

**English:**
[Solution explanation]

```bash
# Fix command
[command]
```

**Magyar:**
[Hungarian solution]

---

**Issue 2: [Problem description]**

**English:**
[Solution explanation]

**Magyar:**
[Hungarian solution]

---

## Development | Fejlesztés

### Running Tests | Tesztek Futtatása

```bash
# Run all tests
docker compose exec [service] /scripts/test-runner.sh

# Run specific test
docker compose exec [service] /scripts/test-runner.sh [test-name]
```

### Building Custom Images | Egyedi Image-ek Építése

```bash
# Rebuild all
docker compose build

# Rebuild specific service
docker compose build [service-name]

# Rebuild without cache
docker compose build --no-cache
```

---

## License | Licenc

MIT License - See [LICENSE](../LICENSE) for details.

MIT Licenc - Részletekért lásd a [LICENSE](../LICENSE) fájlt.
