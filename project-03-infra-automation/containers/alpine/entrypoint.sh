#!/bin/sh
#===============================================================================
# Alpine Container Entrypoint
# Starts SSH daemon and keeps container running
#===============================================================================

set -e

# Create required directories
mkdir -p /var/run/sshd /run/sshd /var/reports /var/backups /var/log/infra

# Generate SSH host keys if not exists
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Generating SSH host keys..."
    ssh-keygen -A
fi

# Start SSH daemon
echo "Starting SSH daemon..."
/usr/sbin/sshd

# Create PID file for health check
touch /run/sshd.pid

echo "Alpine target container ready"
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -i)"

# Keep container running
exec "$@"
