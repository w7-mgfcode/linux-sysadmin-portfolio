#!/bin/bash
#===============================================================================
# Debian Container Entrypoint
# Starts SSH daemon and keeps container running
#===============================================================================

set -euo pipefail

# Create required directories
mkdir -p /run/sshd /var/reports /var/backups /var/log/infra

# Start SSH daemon
echo "Starting SSH daemon..."
/usr/sbin/sshd

# Start rsyslog (clean start)
echo "Starting rsyslog..."
rm -f /run/rsyslogd.pid 2>/dev/null || true
pkill -9 rsyslogd 2>/dev/null || true
sleep 1
rsyslogd 2>/dev/null || echo "rsyslog start skipped (may already be running)"

# Create PID file for health check
touch /run/sshd.pid

echo "Debian target container ready"
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I)"

# Keep container running
exec tail -f /dev/null
