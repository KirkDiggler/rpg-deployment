# SSL Setup with Let's Encrypt

This deployment now includes automatic SSL certificate management using Let's Encrypt. There are two approaches available:

## Prerequisites

1. A domain name pointing to your server's IP address
2. Ports 80 and 443 open and accessible
3. Docker and Docker Compose installed

## Environment Variables

Create a `.env` file in the root directory with:

```bash
DOMAIN_NAME=your-domain.com
EMAIL=your-email@example.com
GITHUB_REPOSITORY=your-github-username/your-repo-name
```

## Option 1: Integrated Nginx/Certbot (Recommended)

This approach uses a custom nginx image with certbot built-in for automatic certificate management.

### Initial Setup

1. Ensure your `.env` file is configured with your domain and email
2. Deploy the services:
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

The nginx container will:
- Start with a temporary HTTP-only configuration
- Automatically request a certificate from Let's Encrypt
- Switch to HTTPS configuration once the certificate is obtained
- Set up automatic renewal via cron (runs twice daily)

### How It Works

1. **Initial Boot**: The custom nginx container checks for existing certificates
2. **Certificate Generation**: If no certificates exist, it:
   - Configures nginx for HTTP-only with ACME challenge support
   - Requests a certificate from Let's Encrypt
   - Switches to full SSL configuration
3. **Automatic Renewal**: A cron job runs twice daily to check and renew certificates

### Logs

Monitor the certificate process:
```bash
docker logs rpg-nginx
```

## Option 2: Standalone Certbot Service

For those who prefer running certbot as a separate service:

### Initial Certificate Generation

1. Run the initial certificate generation script:
   ```bash
   ./scripts/generate-initial-cert.sh
   ```

2. Once the certificate is obtained, run with the certbot override:
   ```bash
   docker-compose -f docker-compose.prod.yml -f docker-compose.certbot.yml up -d
   ```

This approach runs certbot as a separate container that handles renewal.

## Certificate Storage

Certificates are stored in Docker volumes:
- `certbot-conf`: Let's Encrypt configuration and certificates
- `certbot-www`: Webroot for ACME challenges

To backup certificates:
```bash
docker run --rm -v rpg-deployment_certbot-conf:/data -v $(pwd):/backup alpine tar czf /backup/letsencrypt-backup.tar.gz -C /data .
```

## Testing SSL Configuration

Once certificates are obtained, test your SSL configuration:

1. Check HTTPS access:
   ```bash
   curl -I https://your-domain.com
   ```

2. Test SSL rating:
   Visit https://www.ssllabs.com/ssltest/ and enter your domain

## Troubleshooting

### Certificate Generation Fails

1. Check DNS is properly configured:
   ```bash
   dig +short your-domain.com
   ```

2. Ensure ports 80 and 443 are accessible:
   ```bash
   curl http://your-domain.com/.well-known/acme-challenge/test
   ```

3. Check nginx logs:
   ```bash
   docker logs rpg-nginx
   ```

### Force Certificate Renewal

To manually trigger renewal:
```bash
docker exec rpg-nginx /usr/local/bin/renew-certificates.sh
```

### Reset Certificates

To start fresh:
```bash
# Stop services
docker-compose -f docker-compose.prod.yml down

# Remove certificate volumes
docker volume rm rpg-deployment_certbot-conf rpg-deployment_certbot-www

# Start services (will generate new certificates)
docker-compose -f docker-compose.prod.yml up -d
```

## Security Features

The SSL configuration includes:
- TLS 1.2 and 1.3 only
- Strong cipher suites
- OCSP stapling
- HSTS (HTTP Strict Transport Security)
- Session caching for performance

## Monitoring

Certificate expiration is logged. To check certificate status:
```bash
docker exec rpg-nginx certbot certificates
```

## Rate Limits

Let's Encrypt has rate limits:
- 50 certificates per domain per week
- 5 failed validations per account per hour

Plan accordingly and use Let's Encrypt staging environment for testing if needed.