#!/bin/bash
set -e

echo "[Postfix] Starting entrypoint..."

# Substitute environment variables in templates
echo "[Postfix] Processing configuration templates..."
envsubst < /etc/postfix/main.cf.template > /etc/postfix/main.cf
envsubst < /etc/postfix/mysql-virtual-domains.cf > /etc/postfix/mysql-virtual-domains.cf.tmp && \
    mv /etc/postfix/mysql-virtual-domains.cf.tmp /etc/postfix/mysql-virtual-domains.cf
envsubst < /etc/postfix/mysql-virtual-mailboxes.cf > /etc/postfix/mysql-virtual-mailboxes.cf.tmp && \
    mv /etc/postfix/mysql-virtual-mailboxes.cf.tmp /etc/postfix/mysql-virtual-mailboxes.cf
envsubst < /etc/postfix/mysql-virtual-aliases.cf > /etc/postfix/mysql-virtual-aliases.cf.tmp && \
    mv /etc/postfix/mysql-virtual-aliases.cf.tmp /etc/postfix/mysql-virtual-aliases.cf

# Ensure proper permissions
chmod 640 /etc/postfix/mysql-*.cf
chown root:postfix /etc/postfix/mysql-*.cf

# Create mailbox directory structure
mkdir -p /var/mail/vhosts
chown -R vmail:vmail /var/mail/vhosts

# Validate configuration
echo "[Postfix] Validating configuration..."
postfix check

echo "[Postfix] Configuration processed successfully"

# Execute CMD
exec "$@"
