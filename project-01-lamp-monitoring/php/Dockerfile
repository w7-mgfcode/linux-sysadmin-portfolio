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

# Create non-root user
RUN useradd -u 1000 -ms /bin/bash phpuser

# Set permissions
RUN mkdir -p /var/www/html /scripts /backups /var/log/nginx && \
    chown -R phpuser:phpuser /var/www/html /backups && \
    chmod +x /scripts/*.sh 2>/dev/null || true

# Switch to non-root user
USER phpuser

WORKDIR /var/www/html

EXPOSE 9000

CMD ["php-fpm"]
