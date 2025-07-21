# Cloudflare Setup Guide

This guide explains how to use rpg-deployment with Cloudflare for SSL/TLS.

## Why Use Cloudflare?

- **Instant SSL**: No Let's Encrypt rate limits
- **DDoS Protection**: Free protection against attacks
- **Global CDN**: Faster loading times worldwide
- **Hide Server IP**: Additional security layer

## Setup Instructions

### 1. Configure Cloudflare

1. Sign up at [cloudflare.com](https://cloudflare.com)
2. Add your domain
3. Update nameservers at your registrar
4. In Cloudflare dashboard:
   - Go to **SSL/TLS** → **Overview**
   - Set encryption mode to **"Flexible"** (temporarily)

### 2. Deploy with HTTP Mode

```bash
# Set environment variable
export SSL_MODE=http

# Deploy
docker-compose -f docker-compose.prod.yml up -d
```

### 3. After Getting Let's Encrypt Certificates

Once you have valid certificates (no rate limits):

1. Remove the SSL_MODE variable:
   ```bash
   unset SSL_MODE
   ```

2. Redeploy:
   ```bash
   docker-compose -f docker-compose.prod.yml up -d nginx
   ```

3. In Cloudflare, change SSL mode to **"Full"** for end-to-end encryption

## Environment Variables

- `SSL_MODE=http` - Use HTTP-only mode (for Cloudflare Flexible SSL)
- `SSL_MODE=ssl` (default) - Use HTTPS with Let's Encrypt

## Features

The HTTP mode configuration includes:
- Cloudflare IP detection for accurate visitor IPs
- Proper security headers
- Rate limiting
- Health check endpoints
- ACME challenge support (for future certificate generation)

## Troubleshooting

### Rate Limited by Let's Encrypt
The system automatically falls back to HTTP mode if rate limited.

### Real Visitor IPs
The configuration automatically detects and logs real visitor IPs when behind Cloudflare.

### CORS Issues
The HTTP configuration includes proper CORS headers for gRPC-Web support.