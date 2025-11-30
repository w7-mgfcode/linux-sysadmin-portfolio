#!/bin/bash
set -e

echo "[Dovecot] Starting entrypoint..."

# Substitute environment variables in templates
echo "[Dovecot] Processing configuration templates..."
envsubst '$MAIL_DOMAIN' < /etc/dovecot/dovecot.conf.template > /etc/dovecot/dovecot.conf
envsubst '$MYSQL_HOST $MYSQL_DATABASE $MYSQL_USER $MYSQL_PASSWORD' < /etc/dovecot/dovecot-sql.conf.ext.template > /etc/dovecot/dovecot-sql.conf.ext

# Ensure proper permissions
chmod 640 /etc/dovecot/dovecot-sql.conf.ext
chown root:dovecot /etc/dovecot/dovecot-sql.conf.ext

# Create mail directory
mkdir -p /var/mail/vhosts
chown -R vmail:vmail /var/mail/vhosts

# Create Postfix spool directories for LMTP and auth sockets
mkdir -p /var/spool/postfix/private
chown postfix:postfix /var/spool/postfix/private
chmod 750 /var/spool/postfix/private

# Note: We don't run doveconf -n here because it tries to parse dovecot-sql.conf.ext
# as a main config file. Dovecot will validate the SQL config at runtime.
echo "[Dovecot] Configuration processed successfully"

# Execute CMD
exec "$@"
