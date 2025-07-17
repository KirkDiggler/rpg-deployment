#!/bin/bash

set -e

echo "$(date): Starting certificate renewal check..."

# Attempt to renew certificates
certbot renew --webroot --webroot-path=/var/www/certbot --quiet --post-hook "nginx -s reload"

echo "$(date): Certificate renewal check completed"