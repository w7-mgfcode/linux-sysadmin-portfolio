#!/bin/sh
#===============================================================================
# Nginx Entrypoint - Configure Logging for Analysis
#
# Purpose:
#   Removes default symlinks to stdout/stderr and creates actual log files
#   for the log analyzer script to read.
#
# Author: Linux Sysadmin Portfolio
# License: MIT
#===============================================================================

set -e

echo "[INFO] Configuring Nginx logging..."

# Remove symlinks and create actual log files
rm -f /var/log/nginx/access.log /var/log/nginx/error.log

# Create new log files with proper permissions
touch /var/log/nginx/access.log /var/log/nginx/error.log
chmod 644 /var/log/nginx/access.log /var/log/nginx/error.log

echo "[INFO] Log files created: access.log, error.log"

# Also tail logs to stdout/stderr for docker logs viewing
tail -F /var/log/nginx/access.log 2>/dev/null &
tail -F /var/log/nginx/error.log >&2 2>/dev/null &

echo "[INFO] Starting Nginx..."
exec nginx -g 'daemon off;'
