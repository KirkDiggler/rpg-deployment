FROM nginx:alpine

# Install certbot and dependencies
RUN apk add --no-cache certbot certbot-nginx openssl bash

# Create certbot webroot directory
RUN mkdir -p /var/www/certbot

# Copy nginx configurations
COPY nginx/nginx-initial.conf /etc/nginx/nginx-initial.conf
COPY nginx/nginx-ssl.conf /etc/nginx/nginx-ssl.conf

# Copy scripts
COPY scripts/init-letsencrypt.sh /usr/local/bin/init-letsencrypt.sh
COPY scripts/renew-certificates.sh /usr/local/bin/renew-certificates.sh
RUN chmod +x /usr/local/bin/init-letsencrypt.sh /usr/local/bin/renew-certificates.sh

# Add cron job for certificate renewal (runs twice daily)
RUN echo "0 2,14 * * * /usr/local/bin/renew-certificates.sh >> /var/log/certbot-renew.log 2>&1" | crontab -

# Create entrypoint script
RUN echo '#!/bin/sh' > /docker-entrypoint.sh && \
    echo 'set -e' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Start crond in background' >> /docker-entrypoint.sh && \
    echo 'crond' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Initialize certificates and nginx' >> /docker-entrypoint.sh && \
    echo '/usr/local/bin/init-letsencrypt.sh' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Keep nginx in foreground' >> /docker-entrypoint.sh && \
    echo 'exec nginx -g "daemon off;"' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

EXPOSE 80 443

ENTRYPOINT ["/docker-entrypoint.sh"]