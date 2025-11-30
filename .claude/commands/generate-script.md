# Generate Bash Script

Generate a new Bash script following the portfolio's coding standards.

**Arguments:** $ARGUMENTS (script name and purpose)

Example: `/generate-script backup-database "Automated MySQL backup with retention policy"`

## Instructions

### Phase 1: Research

1. **Parse Arguments**
   - Extract script name from $ARGUMENTS
   - Extract purpose/description
   - Determine target project (ask if unclear)

2. **Check Existing Patterns**
   - Search for similar scripts in the repository:
     ```bash
     find . -name "*.sh" -type f
     ```
   - Read 1-2 existing scripts to understand the style
   - Note patterns: logging, error handling, configuration

3. **Review Standards**
   - Read `CLAUDE.md` for Bash scripting requirements
   - Check `.claude/templates/script-template.sh` if available

### Phase 2: Generation

Create the script following this structure:

```bash
#!/bin/bash
#===============================================================================
# [Script Name] - [Brief Description]
#
# Purpose: [What this script does]
# Usage: [script-name].sh [options]
#
# Skills Demonstrated:
# - [List relevant Bash skills this script showcases]
#===============================================================================

set -euo pipefail

#===============================================================================
# Configuration
#===============================================================================

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Configuration via environment variables with defaults
readonly CONFIG_VAR="${CONFIG_VAR:-default_value}"

#===============================================================================
# Colors & Logging
#===============================================================================

declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [NC]='\033[0m'
)

log() {
    local level=$1
    shift
    local color="${COLORS[$level]:-${COLORS[NC]}}"
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*${COLORS[NC]}"
}

info()  { log "INFO" "$*"; }
ok()    { log "OK" "$*"; }
warn()  { log "WARN" "$*"; }
error() { log "ERROR" "$*" >&2; }

#===============================================================================
# Functions
#===============================================================================

usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

[Description of what the script does]

Options:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    [Add more options as needed]

Examples:
    $SCRIPT_NAME
    $SCRIPT_NAME --verbose

EOF
}

cleanup() {
    # Cleanup code here (runs on exit)
    :
}

# Trap for cleanup on exit
trap cleanup EXIT

#===============================================================================
# Main
#===============================================================================

main() {
    info "Starting $SCRIPT_NAME..."

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Main logic here

    ok "Completed successfully!"
}

# Run main if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### Phase 3: Customize

Based on the script's purpose, add:

1. **For Daemon Scripts:**
   ```bash
   declare -i running=1
   trap 'running=0; info "Received shutdown signal"' SIGTERM SIGINT

   run_daemon() {
       while ((running)); do
           # Work here
           sleep "$CHECK_INTERVAL" &
           wait $! || true
       done
   }
   ```

2. **For Analysis/Report Scripts:**
   ```bash
   declare -A stats

   generate_report() {
       local report_file="${REPORT_DIR}/report_$(date +%Y%m%d_%H%M%S).json"
       cat > "$report_file" << EOF
   {
       "timestamp": "$(date -Iseconds)",
       "data": {}
   }
   EOF
   }
   ```

3. **For Backup Scripts:**
   ```bash
   backup_file() {
       local file=$1
       local backup_dir="${BACKUP_DIR:-/var/backups}"
       mkdir -p "$backup_dir"
       cp -p "$file" "$backup_dir/$(basename "$file").$(date +%Y%m%d)"
   }
   ```

### Phase 4: Validation

1. **Run Shellcheck:**
   ```bash
   shellcheck [script-name].sh
   ```

2. **Verify Standards:**
   - [ ] Has `set -euo pipefail`
   - [ ] Uses `readonly` for constants
   - [ ] Has logging functions
   - [ ] Includes usage/help
   - [ ] Has cleanup trap
   - [ ] No hardcoded secrets

3. **Report to User:**
   - Show the generated script
   - Explain key features
   - Provide usage examples
   - Mention where to place it

## Output Format

```
## Generated: [script-name].sh

**Location:** project-XX-[name]/scripts/[script-name].sh
**Purpose:** [description]

### Features
- Error handling with set -euo pipefail
- Configurable via environment variables
- Colored logging output
- [Additional features]

### Usage
\`\`\`bash
# Basic usage
./[script-name].sh

# With options
./[script-name].sh --verbose
\`\`\`

### Shellcheck
✓ Passed with no errors

### Next Steps
1. Review and customize the script
2. Add to version control
3. Document in project README
```
