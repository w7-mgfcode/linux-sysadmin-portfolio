#!/bin/bash
#===============================================================================
# Debian Container Entrypoint
# Starts SSH daemon and keeps container running
#===============================================================================

set -e

# Create required directories
mkdir -p /var/run/sshd /var/reports /var/backups /var/log/infra

# Start SSH daemon
echo "Starting SSH daemon..."
/usr/sbin/sshd

# Start rsyslog
echo "Starting rsyslog..."
rsyslogd || true

# Create PID file for health check
touch /var/run/ssh/sshd.pid

echo "Debian target container ready"
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I)"

# Keep container running
exec "$@"
