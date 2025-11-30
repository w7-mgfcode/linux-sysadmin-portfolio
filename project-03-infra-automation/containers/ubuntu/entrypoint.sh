#!/bin/bash
#===============================================================================
# Ubuntu Container Entrypoint
# Starts SSH daemon and keeps container running
#===============================================================================

set -euo pipefail

# Create required directories
mkdir -p /run/sshd /var/reports /var/backups /var/log/infra

# Start SSH daemon
echo "Starting SSH daemon..."
/usr/sbin/sshd

# Start rsyslog (clean start if needed)
echo "Starting rsyslog..."
if [ -f /run/rsyslogd.pid ] || pgrep rsyslogd >/dev/null 2>&1; then
    echo "Cleaning up existing rsyslog instance..."
    pkill -9 rsyslogd 2>/dev/null || true
    rm -f /run/rsyslogd.pid 2>/dev/null || true
    sleep 1
fi
rsyslogd 2>/dev/null || echo "rsyslog start skipped (may already be running)"

# Disable UFW by default (will be configured by scripts)
ufw --force disable 2>/dev/null || true

# Create PID file for health check
touch /run/sshd.pid

echo "Ubuntu target container ready"
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I)"

# Keep container running (allow custom commands via docker run)
if [ "$#" -gt 0 ]; then
  exec "$@"
else
  exec tail -f /dev/null
fi
