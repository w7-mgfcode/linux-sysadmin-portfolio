#!/bin/bash
set -e

echo "[Dovecot] Starting entrypoint..."

# Substitute environment variables in templates
echo "[Dovecot] Processing configuration templates..."
envsubst < /etc/dovecot/dovecot.conf.template > /etc/dovecot/dovecot.conf
envsubst < /etc/dovecot/dovecot-sql.conf.ext.template > /etc/dovecot/dovecot-sql.conf.ext

# Ensure proper permissions
chmod 640 /etc/dovecot/dovecot-sql.conf.ext
chown root:dovecot /etc/dovecot/dovecot-sql.conf.ext

# Create mail directory
mkdir -p /var/mail/vhosts
chown -R vmail:vmail /var/mail/vhosts

# Validate configuration
echo "[Dovecot] Validating configuration..."
doveconf -n > /dev/null

echo "[Dovecot] Configuration processed successfully"

# Execute CMD
exec "$@"
