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
        
        echo "Nginx configured with SSL"
        
        # Don't start nginx here - the main entrypoint will handle it
        exit 0
    else
        echo "Certificates exist but are expired or invalid"
    fi
fi

echo "Starting certificate generation process..."

# Check if we're rate limited by looking for recent failed attempts
if [ -f /var/log/letsencrypt/letsencrypt.log ]; then
    if grep -q "too many certificates already issued" /var/log/letsencrypt/letsencrypt.log 2>/dev/null; then
        echo "WARNING: Rate limited by Let's Encrypt. Using HTTP only configuration."
        cp /etc/nginx/nginx-initial.conf /etc/nginx/nginx.conf
        sed "s/\${DOMAIN_NAME}/${DOMAIN_NAME}/g" /etc/nginx/nginx-initial.conf > /etc/nginx/nginx.conf
        echo "Nginx configured for HTTP only due to rate limits"
        exit 0
    fi
fi

# Use initial configuration for certificate generation
cp /etc/nginx/nginx-initial.conf /etc/nginx/nginx.conf

# Substitute domain name in nginx config
sed "s/\${DOMAIN_NAME}/${DOMAIN_NAME}/g" /etc/nginx/nginx-initial.conf > /etc/nginx/nginx.conf

# Start nginx temporarily for ACME challenge
nginx

# Wait for nginx to be ready
sleep 5

echo "Requesting certificate from Let's Encrypt..."

# Request certificate (without force-renewal to avoid rate limits)
certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DOMAIN_NAME"

# Check if certificate was obtained successfully
if [ ! -f "$CERT_PATH/fullchain.pem" ]; then
    echo "Error: Certificate generation failed"
    # Check if it's a rate limit error
    if grep -q "too many certificates already issued" /var/log/letsencrypt/letsencrypt.log 2>/dev/null; then
        echo "Rate limited by Let's Encrypt. Continuing with HTTP only."
        # Keep the initial config for HTTP only
        nginx -s stop
        sleep 2
        exit 0
    fi
    exit 1
fi

echo "Certificate obtained successfully"

# Switch to SSL configuration
sed "s/\${DOMAIN_NAME}/${DOMAIN_NAME}/g" /etc/nginx/nginx-ssl.conf > /etc/nginx/nginx.conf

# Test nginx configuration
nginx -t

# Stop the temporary nginx instance
nginx -s stop

# Wait for nginx to stop
sleep 2

echo "Nginx configured with SSL successfully"