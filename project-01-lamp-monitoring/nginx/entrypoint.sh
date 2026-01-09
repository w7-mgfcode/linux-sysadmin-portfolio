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

set -eu

#===============================================================================
# Logging Function
#===============================================================================

# shellcheck disable=SC3043  # local is supported in Alpine's busybox ash
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
}

#===============================================================================
# Cleanup Function
#===============================================================================

cleanup() {
    log "INFO" "Shutting down gracefully..."
    
    # Kill background tail processes (ignore errors if already dead)
    pkill -P $$ tail 2>/dev/null || true
    
    # Send graceful quit signal to nginx
    nginx -s quit 2>/dev/null || true
    
    log "INFO" "Shutdown complete"
    exit 0
}

# Install signal handlers
trap cleanup TERM INT

#===============================================================================
# Main
#===============================================================================

log "INFO" "Configuring Nginx logging..."

# Remove symlinks and create actual log files
rm -f /var/log/nginx/access.log /var/log/nginx/error.log

# Create new log files with proper permissions
touch /var/log/nginx/access.log /var/log/nginx/error.log
chmod 644 /var/log/nginx/access.log /var/log/nginx/error.log

log "INFO" "Log files created: access.log, error.log"

# Also tail logs to stdout/stderr for docker logs viewing
tail -F /var/log/nginx/access.log 2>/dev/null &
tail -F /var/log/nginx/error.log >&2 2>/dev/null &

log "INFO" "Starting Nginx..."
exec nginx -g 'daemon off;'
