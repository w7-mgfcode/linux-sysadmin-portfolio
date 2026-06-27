FROM php:8.2-fpm-alpine

# Install PHP extensions
RUN apk add --no-cache \
    nginx \
    supervisor \
    mysql-client \
    && docker-php-ext-install mysqli pdo pdo_mysql

# Configure Nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/http.d/default.conf

# PHP-FPM listens on TCP 127.0.0.1:9000 (default from the base image's
# zz-docker.conf); nginx connects to it over TCP — see default.conf.

# Copy application files
COPY index.php /var/www/html/
COPY style.css /var/www/html/
COPY script.js /var/www/html/

# Set permissions
RUN chown -R nginx:nginx /var/www/html \
    && chmod -R 755 /var/www/html

# Supervisor configuration
COPY supervisord.conf /etc/supervisord.conf

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
