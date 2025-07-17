#!/bin/bash

# Script to generate initial Let's Encrypt certificate
# Usage: ./generate-initial-cert.sh

set -e

# Check required environment variables
if [ -z "$DOMAIN_NAME" ]; then
    echo "Error: DOMAIN_NAME environment variable is not set"
    echo "Please set it in your .env file or export it"
    exit 1
fi

if [ -z "$EMAIL" ]; then
    echo "Error: EMAIL environment variable is not set"
    echo "Please set it in your .env file or export it"
    exit 1
fi

echo "Generating certificate for domain: $DOMAIN_NAME"
echo "Using email: $EMAIL"
echo ""

# Create required directories
mkdir -p nginx/certs

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed"
    exit 1
fi

echo "Step 1: Starting nginx with HTTP-only configuration..."
# First, update nginx.conf to use the initial configuration
cp nginx/nginx-initial.conf nginx/nginx.conf
sed -i "s/\${DOMAIN_NAME}/$DOMAIN_NAME/g" nginx/nginx.conf

# Start only nginx service
docker-compose -f docker-compose.prod.yml up -d nginx

echo "Waiting for nginx to start..."
sleep 5

echo "Step 2: Running certbot to obtain certificate..."
# Run certbot in standalone mode
docker run -it --rm \
    -v "$(pwd)/certbot-conf:/etc/letsencrypt" \
    -v "$(pwd)/certbot-www:/var/www/certbot" \
    --network rpg-deployment_rpg-network \
    certbot/certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DOMAIN_NAME"

echo "Step 3: Updating nginx configuration for SSL..."
# Update nginx configuration to use SSL
cp nginx/nginx-ssl.conf nginx/nginx.conf
sed -i "s/\${DOMAIN_NAME}/$DOMAIN_NAME/g" nginx/nginx.conf

echo "Step 4: Restarting services with SSL enabled..."
# Restart all services
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d

echo ""
echo "Certificate generation complete!"
echo "Your site should now be accessible at https://$DOMAIN_NAME"
echo ""
echo "Note: Certificates will be automatically renewed by the certbot service."