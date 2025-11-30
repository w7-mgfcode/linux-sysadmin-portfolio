# Review Security - Comprehensive Security Audit

Run a comprehensive security audit on portfolio projects.

**Arguments:** $ARGUMENTS (project name or "all")

Example: `/review-security lamp` or `/review-security all`

## Instructions

### Step 1: Determine Scope

Parse $ARGUMENTS:
- `all` → Audit all projects in repository
- `lamp` / `project-01` → project-01-lamp-monitoring
- `mail` / `project-02` → project-02-mail-server
- `automation` / `project-03` → project-03-infra-automation

### Step 2: File Discovery

Find all files to audit:

```bash
# Dockerfiles
find [project-dir] -name "Dockerfile*" -type f

# Compose files
find [project-dir] -name "docker-compose*.yml" -o -name "compose*.yml"

# Environment files
find [project-dir] -name ".env*" -o -name "*.env"

# Bash scripts
find [project-dir] -name "*.sh" -type f

# Config files
find [project-dir] -name "*.conf" -o -name "*.cfg" -o -name "*.ini"
```

### Step 3: Security Checks

#### A. Docker Security

**Dockerfile Checks:**
```
[ ] Using official/trusted base images
[ ] Images pinned to specific versions (not :latest)
[ ] Non-root USER specified
[ ] No secrets in ENV or ARG
[ ] HEALTHCHECK defined
[ ] Minimal packages installed
[ ] Multi-stage build (if applicable)
```

**Patterns to flag:**
```dockerfile
# BAD: Latest tag
FROM nginx:latest

# BAD: Root user (no USER directive)
# Missing USER instruction

# BAD: Secrets in build
ARG DB_PASSWORD=secret
ENV API_KEY=abc123

# BAD: Unnecessary packages
RUN apt-get install -y vim nano curl wget
```

**docker-compose.yml Checks:**
```
[ ] No privileged: true
[ ] No hardcoded secrets in environment
[ ] Resource limits defined
[ ] Internal networks for service communication
[ ] Exposed ports minimized
[ ] Read-only root filesystem (where applicable)
```

**Patterns to flag:**
```yaml
# BAD: Privileged container
privileged: true

# BAD: Hardcoded password
environment:
  - MYSQL_ROOT_PASSWORD=password123

# BAD: Exposing to all interfaces
ports:
  - "0.0.0.0:3306:3306"

# BAD: No resource limits
# (missing deploy.resources)
```

#### B. Bash Script Security

**Script Checks:**
```
[ ] No hardcoded passwords/tokens/keys
[ ] Input validation for user-provided values
[ ] Variables properly quoted ("$var" not $var)
[ ] No dangerous eval usage
[ ] Safe temporary file creation (mktemp)
[ ] No command injection vulnerabilities
```

**Patterns to flag:**
```bash
# BAD: Hardcoded secret
PASSWORD="secretpassword"
API_KEY="sk-abc123"

# BAD: Unquoted variable
rm -rf $USER_INPUT

# BAD: Unsafe eval
eval "$user_input"

# BAD: Predictable temp file
TMPFILE=/tmp/myapp.tmp

# BAD: Command injection
curl "http://example.com/$USER_INPUT"
```

#### C. Environment File Security

**Checks:**
```
[ ] .env files in .gitignore
[ ] .env.example has placeholders only
[ ] No real secrets in example files
[ ] Restrictive file permissions
```

**Patterns to flag:**
```bash
# BAD: Real password in .env.example
DB_PASSWORD=actualpassword

# GOOD: Placeholder
DB_PASSWORD=changeme_generate_secure_password
```

#### D. Network Security (Project 03)

**Firewall Rules Checks:**
```
[ ] Default DROP policy
[ ] SSH rate limiting
[ ] Loopback allowed
[ ] Established connections allowed
[ ] Unnecessary ports blocked
```

#### E. File Permissions

**Checks:**
```
[ ] Scripts are 755 (not 777)
[ ] Config files not world-readable
[ ] Sensitive files are 600/400
[ ] No SUID/SGID unless necessary
```

### Step 4: Generate Report

```markdown
## Security Audit Report

### Executive Summary
- **Risk Level:** [LOW / MEDIUM / HIGH / CRITICAL]
- **Projects Scanned:** [count]
- **Files Analyzed:** [count]
- **Issues Found:** X critical, Y high, Z medium, W low

### Findings by Severity

#### Critical (Must Fix)
Issues that pose immediate security risk.

| # | Location | Issue | Remediation |
|---|----------|-------|-------------|
| 1 | [file:line] | [issue] | [fix] |

#### High (Should Fix)
Significant security weaknesses.

| # | Location | Issue | Remediation |
|---|----------|-------|-------------|

#### Medium (Recommended)
Issues that should be addressed.

| # | Location | Issue | Remediation |
|---|----------|-------|-------------|

#### Low (Nice to Have)
Minor improvements.

| # | Location | Issue | Remediation |
|---|----------|-------|-------------|

### Detailed Analysis

#### Docker Configuration
[Findings for Dockerfiles and compose files]

#### Bash Scripts
[Findings for shell scripts]

#### Secrets Management
[Findings for environment files and hardcoded secrets]

#### Network Security
[Findings for firewall rules and exposed ports]

### Recommendations

1. **Immediate Actions**
   - [Critical fixes to do now]

2. **Short-term**
   - [High priority fixes]

3. **Long-term**
   - [Improvements for future]

### Compliance Notes
- OWASP Docker Security: [status]
- CIS Benchmarks: [status]
- Shellcheck Security: [status]
```

### Step 5: Remediation Examples

Provide specific fixes for common issues:

```bash
# Fix: Hardcoded secret in script
# Before:
PASSWORD="secret123"
# After:
PASSWORD="${DB_PASSWORD:?DB_PASSWORD must be set}"

# Fix: Unquoted variable
# Before:
rm -rf $BACKUP_DIR/*
# After:
rm -rf "${BACKUP_DIR:?}"/*

# Fix: Unsafe temp file
# Before:
TMPFILE=/tmp/myapp.tmp
# After:
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
```

```yaml
# Fix: Remove privileged mode
# Before:
privileged: true
# After:
# Remove the line, or use specific capabilities:
cap_add:
  - NET_ADMIN

# Fix: Use secrets properly
# Before:
environment:
  - DB_PASSWORD=secret
# After:
environment:
  - DB_PASSWORD=${DB_PASSWORD}
# And add to .env (which is gitignored)
```

```dockerfile
# Fix: Add non-root user
# Before:
FROM nginx:alpine
# After:
FROM nginx:1.25-alpine
RUN adduser -D -u 1000 appuser
USER appuser
```

## Output Format

```
## Security Audit: project-01-lamp-monitoring

### Risk Level: MEDIUM

### Summary
- Files scanned: 12
- Issues found: 1 high, 3 medium, 2 low

### Critical/High Issues

1. **[HIGH] Hardcoded database password**
   - File: docker-compose.yml:15
   - Issue: `MYSQL_ROOT_PASSWORD=rootpassword`
   - Fix: Use environment variable from .env file
   \`\`\`yaml
   environment:
     - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
   \`\`\`

### Medium Issues
[List medium issues]

### Low Issues
[List low issues]

### Next Steps
1. Fix the HIGH issue immediately
2. Address medium issues before deployment
3. Consider low issues for future improvements
```
