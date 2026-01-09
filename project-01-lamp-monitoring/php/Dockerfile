FROM php:8.2-fpm-bookworm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    zip \
    unzip \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    default-mysql-client \
    bc \
    jq \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install \
    pdo_mysql \
    mysqli \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd

# Configure PHP
COPY php.ini /usr/local/etc/php/conf.d/custom.ini

# Configure PHP-FPM pool to run as phpuser
COPY www.conf /usr/local/etc/php-fpm.d/www.conf

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/php-entrypoint.sh
RUN chmod +x /usr/local/bin/php-entrypoint.sh

# Create non-root user
RUN useradd -u 1000 -ms /bin/bash phpuser

# Set permissions
RUN mkdir -p /var/www/html /scripts /backups /var/log/nginx /var/reports && \
    chown -R phpuser:phpuser /var/www/html /backups /var/reports && \
    chmod +x /scripts/*.sh 2>/dev/null || true

WORKDIR /var/www/html

EXPOSE 9000

# Use custom entrypoint to fix volume ownership before starting PHP-FPM
# Note: PHP-FPM master runs as root, worker processes run as phpuser (via pool config)
ENTRYPOINT ["/usr/local/bin/php-entrypoint.sh"]
CMD ["php-fpm"]
