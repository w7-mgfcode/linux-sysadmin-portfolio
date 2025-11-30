FROM debian:bookworm-slim

# Install SpamAssassin
RUN apt-get update && apt-get install -y \
    spamassassin \
    spamc \
    && rm -rf /var/lib/apt/lists/*

# Update SpamAssassin rules
RUN sa-update || true

# Copy configuration
COPY local.cf /etc/spamassassin/local.cf

# Create SpamAssassin user
RUN groupadd -r spamd && useradd -r -g spamd spamd

# Expose SpamAssassin daemon port
EXPOSE 783

# Start SpamAssassin daemon
CMD ["spamd", \
     "--max-children", "5", \
     "--helper-home-dir", "/var/lib/spamassassin", \
     "--listen", "0.0.0.0:783", \
     "--allowed-ips", "0.0.0.0/0", \
     "--pidfile", "/var/run/spamd.pid"]
