FROM alpine:3.19

# Install required packages for infrastructure automation testing
RUN apk add --no-cache \
    # SSH server
    openssh \
    openssh-server \
    # Networking tools
    iptables \
    ip6tables \
    iputils \
    curl \
    wget \
    bind-tools \
    netcat-openbsd \
    # System tools
    bash \
    busybox \
    procps \
    findutils \
    grep \
    sed \
    gawk \
    bc \
    coreutils \
    # Compression tools
    gzip \
    bzip2 \
    xz \
    # Text editors
    vim \
    nano

# Create required directories
RUN mkdir -p /var/run/sshd /run/sshd /var/reports /var/backups /var/log/infra

# Configure SSH
RUN ssh-keygen -A && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Set root password for testing
RUN echo 'root:test' | chpasswd

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose SSH port
EXPOSE 22

# Start via entrypoint
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
CMD ["sleep", "infinity"]
