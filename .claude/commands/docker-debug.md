# Docker Debug - Diagnose Docker Compose Issues

Diagnose and troubleshoot Docker Compose problems in portfolio projects.

**Arguments:** $ARGUMENTS (project name or path)

Example: `/docker-debug lamp` or `/docker-debug project-01-lamp-monitoring`

## Instructions

### Step 1: Identify Project

Parse $ARGUMENTS to find the project:
- `lamp` or `project-01` → `project-01-lamp-monitoring/`
- `mail` or `project-02` → `project-02-mail-server/`
- `automation` or `project-03` → `project-03-infra-automation/`
- Direct path → use as-is

Verify the project exists:
```bash
ls -la [project-dir]/docker-compose.yml
```

### Step 2: Gather State

Run these diagnostic commands (in the project directory):

```bash
# 1. Container status
docker compose ps -a

# 2. Recent logs (all services)
docker compose logs --tail=100

# 3. Validate compose file
docker compose config --quiet && echo "✓ Config valid" || echo "✗ Config invalid"

# 4. Check Docker daemon
docker info --format '{{.ServerVersion}}'

# 5. Network status
docker network ls | grep [project-name]

# 6. Volume status
docker volume ls | grep [project-name]

# 7. Port usage (for exposed ports)
# Check if ports are in use
ss -tlnp | grep -E ':(80|443|3306|8080)'
```

### Step 3: Analyze Issues

Check for these common problems:

#### Container Issues
| Symptom | Possible Cause | Check |
|---------|----------------|-------|
| `Exited (1)` | Application error | `docker compose logs [service]` |
| `Exited (137)` | OOM killed | `docker stats`, increase memory |
| `Exited (126)` | Permission denied | Check file permissions, entrypoint |
| `Exited (127)` | Command not found | Check Dockerfile CMD/ENTRYPOINT |
| `Restarting` | Crash loop | Check logs, health check failing |

#### Network Issues
| Symptom | Possible Cause | Check |
|---------|----------------|-------|
| Port conflict | Port already in use | `ss -tlnp \| grep [port]` |
| Can't connect | Wrong network | `docker network inspect` |
| DNS not working | Container can't resolve | Check Docker DNS settings |

#### Volume Issues
| Symptom | Possible Cause | Check |
|---------|----------------|-------|
| Permission denied | UID mismatch | Check volume permissions |
| Data missing | Volume not mounted | `docker volume inspect` |
| Stale data | Old volume | Remove and recreate |

#### Build Issues
| Symptom | Possible Cause | Check |
|---------|----------------|-------|
| Build fails | Dockerfile error | Read build output |
| Image not found | Missing base image | `docker pull` manually |
| Cache issues | Stale layers | `docker compose build --no-cache` |

### Step 4: Health Check Analysis

If services have health checks:

```bash
# Check health status
docker inspect --format='{{.State.Health.Status}}' [container-name]

# View health check logs
docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' [container-name]
```

Common health check issues:
- Service not ready within start_period
- Health check command fails
- Wrong port/path in health check

### Step 5: Generate Diagnosis Report

```markdown
## Docker Debug Report: [project-name]

### Summary
- **Status:** [HEALTHY / DEGRADED / FAILING]
- **Containers:** X running, Y stopped, Z unhealthy
- **Time:** [timestamp]

### Container Status

| Container | Status | Health | Ports |
|-----------|--------|--------|-------|
| [name] | [status] | [health] | [ports] |

### Issues Found

#### Critical
- [List critical issues]

#### Warnings
- [List warnings]

### Recent Errors
\`\`\`
[Relevant log excerpts]
\`\`\`

### Recommended Fixes

1. **[Issue 1]**
   - Problem: [description]
   - Fix: [specific command or change]
   \`\`\`bash
   [fix command]
   \`\`\`

2. **[Issue 2]**
   - Problem: [description]
   - Fix: [specific command or change]

### Useful Commands

\`\`\`bash
# Restart all services
docker compose restart

# Rebuild and restart
docker compose up -d --build

# View live logs
docker compose logs -f

# Full reset (warning: destroys data)
docker compose down -v && docker compose up -d
\`\`\`
```

### Step 6: Common Quick Fixes

Provide these if applicable:

```bash
# Fix: Port conflict
# Stop conflicting process or change port in .env

# Fix: Permission issues
docker compose exec [service] chown -R www-data:www-data /var/www

# Fix: Stale containers
docker compose down && docker compose up -d

# Fix: Network issues
docker network prune -f
docker compose up -d

# Fix: Volume permissions
docker compose down
docker volume rm [volume-name]
docker compose up -d

# Fix: Image issues
docker compose pull
docker compose up -d --build
```

## Output Format

Present findings clearly:

```
## Docker Debug: project-01-lamp-monitoring

### Quick Status
✓ Docker daemon running (v24.0.7)
✓ Compose file valid
✗ 1 container unhealthy

### Containers
┌─────────┬──────────┬───────────┬─────────────┐
│ Service │ Status   │ Health    │ Ports       │
├─────────┼──────────┼───────────┼─────────────┤
│ nginx   │ running  │ healthy   │ 80, 443     │
│ php     │ running  │ unhealthy │ 9000        │
│ mysql   │ running  │ healthy   │ 3306        │
└─────────┴──────────┴───────────┴─────────────┘

### Issue Found
PHP container health check failing

### Root Cause
PHP-FPM not responding on port 9000

### Fix
\`\`\`bash
# Check PHP-FPM config
docker compose exec php cat /usr/local/etc/php-fpm.d/www.conf | grep listen

# Restart PHP service
docker compose restart php
\`\`\`
```
