# Validate Scripts

Run shellcheck and other validations on all Bash scripts in the repository.

## Usage

```
/validate-scripts [path]
```

**Arguments:**
- `path` (optional): Specific script or directory to validate. Defaults to entire repository.

## Instructions

When this command is invoked:

1. **Find all Bash scripts:**
   ```bash
   find /home/w7-shellsnake/w7-DEV_X1/w7-JOBS/linux-sysadmin-portfolio -name "*.sh" -type f
   ```

2. **For each script, check:**

   a. **Shellcheck compliance:**
   ```bash
   shellcheck -f gcc [script]
   ```

   b. **Shebang present:**
   - Should start with `#!/bin/bash` or `#!/usr/bin/env bash`

   c. **Error handling:**
   - Should contain `set -e` or `set -euo pipefail`

   d. **No hardcoded secrets:**
   - Search for patterns like `password=`, `secret=`, `token=`
   - Flag any suspicious hardcoded values

3. **Generate report:**
   ```
   Script Validation Report
   ========================

   Scanned: X scripts
   Passed: Y
   Warnings: Z
   Errors: W

   Details:
   --------
   [script-name.sh]
   ✓ Shellcheck: passed
   ✓ Error handling: set -euo pipefail found
   ✓ No hardcoded secrets
   ⚠ Warning: SC2086 - Double quote to prevent globbing (line 45)
   ```

4. **Provide fix suggestions:**
   - For each warning/error, show the problematic line
   - Suggest the fix based on shellcheck recommendations

## Example Output

```
Validating Bash scripts...

Found 9 scripts:
  project-01-lamp-monitoring/scripts/log-analyzer.sh
  project-01-lamp-monitoring/scripts/backup.sh
  project-01-lamp-monitoring/scripts/health-check.sh
  ...

Results:
--------
✓ log-analyzer.sh - PASSED
✓ backup.sh - PASSED
⚠ health-check.sh - 2 warnings
  Line 34: SC2086 - Double quote to prevent globbing
  Line 67: SC2181 - Check exit code directly

Summary: 7 passed, 2 warnings, 0 errors
```
