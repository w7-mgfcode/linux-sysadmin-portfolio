FROM debian:bookworm-slim

# Install Dovecot and dependencies
RUN apt-get update && apt-get install -y \
    dovecot-core \
    dovecot-imapd \
    dovecot-pop3d \
    dovecot-lmtpd \
    dovecot-mysql \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Create vmail user for mailbox ownership (UID 5000 matches Postfix)
RUN groupadd -g 5000 vmail && \
    useradd -u 5000 -g vmail -s /usr/sbin/nologin -d /var/mail vmail

# Copy configuration files
COPY dovecot.conf.template /etc/dovecot/dovecot.conf.template
COPY dovecot-sql.conf.ext.template /etc/dovecot/dovecot-sql.conf.ext.template
COPY 10-mail.conf /etc/dovecot/conf.d/10-mail.conf
COPY 10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf
COPY 10-auth.conf /etc/dovecot/conf.d/10-auth.conf
COPY 10-master.conf /etc/dovecot/conf.d/10-master.conf

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create mail directory
RUN mkdir -p /var/mail/vhosts && \
    chown -R vmail:vmail /var/mail/vhosts

# Expose IMAP, POP3, and LMTP ports
EXPOSE 143 993 110 995 24 12345

# Start Dovecot via entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["dovecot", "-F"]
