FROM php:8.3.17-fpm AS php

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    libzip-dev \
    libmagickwand-dev \
    libc-client-dev \
    libkrb5-dev \
    librdkafka-dev \
    libsasl2-dev \
    supervisor

# Install PHP extensions
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
    docker-php-ext-install \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip \
    soap \
    sockets \
    imap

# Install ImageMagick
RUN curl -L -o /tmp/imagick.tar.gz https://github.com/Imagick/imagick/archive/7088edc353f53c4bc644573a79cdcd67a726ae16.tar.gz \
    && tar --strip-components=1 -xf /tmp/imagick.tar.gz \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && echo "extension=imagick.so" > /usr/local/etc/php/conf.d/ext-imagick.ini \
    && rm -rf /tmp/* 

# Install Redis extension
RUN pecl install redis && \
    docker-php-ext-enable redis

# Install rdkafka
RUN pecl install rdkafka && \
    docker-php-ext-enable rdkafka

# Install Node.js 16.18.1
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@8.9

# Install Composer
COPY --from=composer:2.6.5 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Create system user
RUN useradd -G www-data,root -u 1000 -d /home/processmaker processmaker
RUN mkdir -p /home/processmaker/.composer && \
    chown -R processmaker:processmaker /home/processmaker

# Create directory structure
RUN mkdir -p \
    /var/www/storage/app/public \
    /var/www/storage/framework/cache \
    /var/www/storage/framework/sessions \
    /var/www/storage/framework/views \
    /var/www/storage/logs \
    /var/www/bootstrap/cache \
    /var/www/vendor && \
    chown -R processmaker:processmaker /var/www

# Copy composer files first
COPY composer.json composer.lock ./

RUN mkdir -p /var/www/public/builds && \
    chown -R processmaker:processmaker /var/www/public/builds && \
    chmod -R 775 /var/www/public/builds

# Switch to non-root user
USER processmaker

# Install composer dependencies
RUN COMPOSER_MEMORY_LIMIT=-1 composer install --no-scripts --no-autoloader --no-interaction

# Copy application files
COPY --chown=processmaker:processmaker . .

# Generate optimized autoloader
RUN composer dump-autoload --optimize

# Set permissions
USER root
RUN chown -R processmaker:processmaker /var/www && \
    chmod -R 775 /var/www/storage /var/www/bootstrap/cache

# Switch back to non-root user
USER processmaker

# Expose port 9000
EXPOSE 9000

# Start PHP-FPM
CMD ["php-fpm"] 