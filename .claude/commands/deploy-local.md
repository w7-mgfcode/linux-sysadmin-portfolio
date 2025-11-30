# Deploy Local

Deploy a project locally and provide access information.

## Usage

```
/deploy-local [project-name]
```

**Arguments:**
- `project-name`: One of `lamp`, `mail`, or `automation` (or full name)

## Instructions

When this command is invoked:

1. **Check prerequisites:**
   - Docker is running: `docker info`
   - Docker Compose available: `docker compose version`
   - Required ports are free

2. **Stop any existing instances:**
   ```bash
   cd [project-dir] && docker compose down 2>/dev/null || true
   ```

3. **Create .env from .env.example if needed:**
   ```bash
   if [ ! -f .env ] && [ -f .env.example ]; then
     cp .env.example .env
   fi
   ```

4. **Build and start services:**
   ```bash
   docker compose up -d --build
   ```

5. **Wait for health checks:**
   ```bash
   docker compose ps --format json | jq '.Health'
   ```

6. **Display access information:**

   **For LAMP (project-01):**
   ```
   Services deployed:

   Web Application:  http://localhost
   Adminer (DB UI):  http://localhost:8080
     Server: mysql
     Username: root
     Password: (see .env)

   Logs: docker compose logs -f
   Stop: docker compose down
   ```

   **For Mail (project-02):**
   ```
   Services deployed:

   Webmail:     https://localhost/webmail
   SMTP:        localhost:587
   IMAP:        localhost:993

   Test account: test@example.com (see .env for password)

   Logs: docker compose logs -f
   Stop: docker compose down
   ```

   **For Automation (project-03):**
   ```
   Test environment deployed:

   Debian target:  docker compose exec debian-target bash
   Alpine target:  docker compose exec alpine-target sh
   Ubuntu target:  docker compose exec ubuntu-target bash

   Run scripts:
     docker compose exec debian-target /scripts/server-hardening.sh

   Stop: docker compose down
   ```

7. **Show container status:**
   ```bash
   docker compose ps
   ```

## Example Output

```
Deploying project-01-lamp-monitoring locally...

✓ Docker is running
✓ Ports 80, 8080, 3306 are available
✓ Created .env from .env.example
✓ Building containers...
✓ Starting services...
✓ All services healthy

Access your application:
------------------------
Web:     http://localhost
Adminer: http://localhost:8080
  Server:   mysql
  Username: root
  Password: rootpassword

Useful commands:
  Logs:    cd project-01-lamp-monitoring && docker compose logs -f
  Stop:    cd project-01-lamp-monitoring && docker compose down
  Restart: cd project-01-lamp-monitoring && docker compose restart
```
