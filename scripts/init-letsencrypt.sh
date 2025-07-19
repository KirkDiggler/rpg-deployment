#!/bin/bash

set -e

# Check if domain is set
if [ -z "$DOMAIN_NAME" ]; then
    echo "Error: DOMAIN_NAME environment variable is not set"
    exit 1
fi

if [ -z "$EMAIL" ]; then
    echo "Error: EMAIL environment variable is not set"
    exit 1
fi

# Path to certificates
CERT_PATH="/etc/letsencrypt/live/$DOMAIN_NAME"

echo "Checking for existing certificates..."

# Check if certificates already exist
if [ -d "$CERT_PATH" ]; then
    echo "Certificates already exist for $DOMAIN_NAME"
    
    # Check if certificates are valid
    if openssl x509 -checkend 86400 -noout -in "$CERT_PATH/fullchain.pem" 2>/dev/null; then
        echo "Certificates are valid"
        
        # Use SSL configuration
        cp /etc/nginx/nginx-ssl.conf /etc/nginx/nginx.conf
        
        # Substitute domain name in nginx config
        sed "s/\${DOMAIN_NAME}/${DOMAIN_NAME}/g" /etc/nginx/nginx-ssl.conf > /etc/nginx/nginx.conf
        
        # Test nginx configuration
        nginx -t
        
        # Reload nginx
        nginx -s reload || nginx
        
        echo "Nginx configured with SSL"
        exit 0
    else
        echo "Certificates exist but are expired or invalid"
    fi
fi

echo "Starting certificate generation process..."

# Use initial configuration for certificate generation
cp /etc/nginx/nginx-initial.conf /etc/nginx/nginx.conf

# Substitute domain name in nginx config
sed -i "s|\${DOMAIN_NAME}|$DOMAIN_NAME|g" /etc/nginx/nginx.conf

# Start nginx with initial configuration
nginx

# Wait for nginx to be ready
sleep 5

echo "Requesting certificate from Let's Encrypt..."

# Request certificate
certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d "$DOMAIN_NAME"

# Check if certificate was obtained successfully
if [ ! -f "$CERT_PATH/fullchain.pem" ]; then
    echo "Error: Certificate generation failed"
    exit 1
fi

echo "Certificate obtained successfully"

# Switch to SSL configuration
cp /etc/nginx/nginx-ssl.conf /etc/nginx/nginx.conf

# Substitute domain name in nginx config
sed -i "s|\${DOMAIN_NAME}|$DOMAIN_NAME|g" /etc/nginx/nginx.conf

# Test nginx configuration
nginx -t

# Reload nginx with SSL configuration
nginx -s reload

echo "Nginx configured with SSL successfully"