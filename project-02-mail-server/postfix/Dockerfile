FROM debian:bookworm-slim

# Install Postfix and dependencies
RUN apt-get update && apt-get install -y \
    postfix \
    postfix-mysql \
    libsasl2-modules \
    ca-certificates \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration templates
COPY main.cf.template /etc/postfix/main.cf.template
COPY master.cf /etc/postfix/master.cf
COPY mysql-virtual-domains.cf /etc/postfix/mysql-virtual-domains.cf
COPY mysql-virtual-mailboxes.cf /etc/postfix/mysql-virtual-mailboxes.cf
COPY mysql-virtual-aliases.cf /etc/postfix/mysql-virtual-aliases.cf

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create vmail user for mailbox ownership
RUN groupadd -g 5000 vmail && \
    useradd -u 5000 -g vmail -s /usr/sbin/nologin -d /var/mail vmail

# Create required directories
RUN mkdir -p /var/mail/vhosts /var/spool/postfix && \
    chown -R vmail:vmail /var/mail/vhosts

# Expose SMTP ports
EXPOSE 25 587 465

# Start Postfix via entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["postfix", "start-fg"]
