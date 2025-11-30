FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages for infrastructure automation testing
RUN apt-get update && apt-get install -y \
    # SSH server
    openssh-server \
    # Networking and security tools
    ufw \
    iptables \
    iputils-ping \
    traceroute \
    net-tools \
    iproute2 \
    dnsutils \
    curl \
    wget \
    netcat-traditional \
    # System tools
    rsyslog \
    systemd \
    procps \
    psmisc \
    cron \
    bc \
    findutils \
    grep \
    sed \
    gawk \
    # Compression tools
    gzip \
    bzip2 \
    xz-utils \
    # Text editors
    vim \
    nano \
    # Development tools
    bash \
    && rm -rf /var/lib/apt/lists/*

# Create required directories
RUN mkdir -p /var/run/sshd /var/reports /var/backups /var/log/infra

# Configure SSH for testing
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Set root password for testing (will be hardened by scripts)
RUN echo 'root:test' | chpasswd

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose SSH port
EXPOSE 22

# Start via entrypoint
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD ["sleep", "infinity"]
