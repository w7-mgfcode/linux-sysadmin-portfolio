#!/bin/sh
#===============================================================================
# PHP Container Entrypoint
#
# Purpose:
#   Ensures proper ownership of mounted volumes before starting PHP-FPM.
#   Fixes potential ownership issues with pre-existing host volumes.
#
# Reference:
#   - Addresses reports:/var/reports volume mount (docker-compose.yml line 39)
#   - Ensures phpuser:phpuser ownership for write access
#
# Author: Linux Sysadmin Portfolio
# License: MIT
#===============================================================================

set -e

# Ensure /var/reports has correct ownership for PHP writes
# This handles cases where the volume was created with wrong permissions
if [ -d /var/reports ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Ensuring correct ownership for /var/reports"
    chown -R phpuser:phpuser /var/reports
fi

# Ensure /backups has correct ownership
if [ -d /backups ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Ensuring correct ownership for /backups"
    chown -R phpuser:phpuser /backups
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Starting PHP-FPM..."

# Execute PHP-FPM (runs as root, but worker processes run as configured user)
exec "$@"
