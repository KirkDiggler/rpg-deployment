# Environment Variables Setup

## Required Environment Variables

Create a `.env` file in the root of rpg-deployment with the following variables:

### 1. Domain Configuration (Required for SSL)
```bash
DOMAIN_NAME=rpg-toolkit.app
EMAIL=your-admin-email@example.com  # For Let's Encrypt notifications
```

### 2. GitHub Configuration (Required for production)
```bash
GITHUB_REPOSITORY=KirkDiggler/rpg-deployment  # Used to pull Docker images from GHCR
```

### 3. Discord Configuration (Required for Discord Activity)
```bash
VITE_DISCORD_CLIENT_ID=1234567890123456789  # Your Discord Application ID
```

## Where to Get These Values

### Discord Client ID
1. Go to https://discord.com/developers/applications
2. Select your application (or create one)
3. Copy the "Application ID" from the General Information page
4. This is your `VITE_DISCORD_CLIENT_ID`

### Domain Name
- Use your registered domain that points to your server
- Ensure DNS A record points to your server's IP address

### Email
- Use a valid email for Let's Encrypt certificate notifications
- This email will receive expiration warnings if renewal fails

## Optional Variables

```bash
# API Configuration (leave empty for production to use same domain)
VITE_API_HOST=

# Service Configuration (rarely needed)
PORT=50051
LOG_LEVEL=info
REDIS_URL=redis://redis:6379
```

## Security Notes

1. **Never commit `.env` to git** - It's in .gitignore for a reason
2. **Keep production values secure** - Especially the Discord Client ID
3. **Use strong email** - Let's Encrypt notifications are important

## Deployment

After setting up your `.env` file:

```bash
# For production deployment
docker-compose -f docker-compose.prod.yml up -d

# For local development
docker-compose -f docker-compose.local.yml up -d
```

## Troubleshooting

### Discord Activity Not Loading
- Verify `VITE_DISCORD_CLIENT_ID` matches your Discord app
- Check browser console for errors
- Ensure CSP headers allow Discord domains

### SSL Certificate Issues
- Verify `DOMAIN_NAME` matches your actual domain
- Check DNS points to your server
- Ensure ports 80 and 443 are open
- Check nginx logs: `docker logs rpg-nginx`

### API Connection Issues
- Leave `VITE_API_HOST` empty for production
- API calls should go to `/api/*` on same domain
- Check envoy proxy logs: `docker logs rpg-envoy`