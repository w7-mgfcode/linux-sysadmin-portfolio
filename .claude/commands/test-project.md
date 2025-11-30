# Test Project

Test a specific project by running its Docker Compose stack and executing health checks.

## Usage

```
/test-project [project-name]
```

**Arguments:**
- `project-name`: One of `lamp`, `mail`, or `automation` (or full name like `project-01-lamp-monitoring`)

## Instructions

When this command is invoked:

1. **Identify the project directory:**
   - `lamp` or `project-01` → `project-01-lamp-monitoring/`
   - `mail` or `project-02` → `project-02-mail-server/`
   - `automation` or `project-03` → `project-03-infra-automation/`

2. **Check if project exists:**
   ```bash
   ls -la /home/w7-shellsnake/w7-DEV_X1/w7-JOBS/linux-sysadmin-portfolio/[project-dir]/
   ```

3. **Validate docker-compose.yml:**
   ```bash
   docker compose -f [project-dir]/docker-compose.yml config --quiet
   ```

4. **Start the stack:**
   ```bash
   cd [project-dir] && docker compose up -d
   ```

5. **Wait for services to be healthy:**
   ```bash
   docker compose ps
   ```

6. **Run health checks:**
   - For LAMP: Check nginx on port 80, adminer on 8080
   - For Mail: Check SMTP on 25, IMAP on 993
   - For Automation: Execute test-runner.sh

7. **Report results:**
   - List running containers
   - Show any failing health checks
   - Provide cleanup command: `docker compose down`

## Example Output

```
Testing project-01-lamp-monitoring...

✓ docker-compose.yml is valid
✓ Starting containers...
✓ nginx is healthy (port 80)
✓ php-fpm is healthy (port 9000)
✓ mysql is healthy (port 3306)
✓ adminer is accessible (port 8080)

All 4 services are running.

To stop: cd project-01-lamp-monitoring && docker compose down
```
