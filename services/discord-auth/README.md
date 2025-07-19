# Discord Auth Service

A lightweight HTTP service that handles Discord OAuth token exchange for the RPG Activity app.

## Overview

This service provides a single endpoint that exchanges Discord authorization codes for access tokens. It's designed to be used by frontend applications that need to authenticate with Discord but can't securely store client secrets.

## API

### POST /api/discord/token

Exchanges a Discord authorization code for an access token.

**Request Body:**
```json
{
  "code": "string"
}
```

**Response:**
```json
{
  "access_token": "string"
}
```

**Error Response:**
```json
{
  "error": "string"
}
```

### GET /health

Health check endpoint that returns 200 OK.

## Configuration

The service requires the following environment variables:

- `DISCORD_CLIENT_ID` - Your Discord application's client ID
- `DISCORD_CLIENT_SECRET` - Your Discord application's client secret
- `DISCORD_REDIRECT_URI` - (Optional) The redirect URI configured in Discord
- `PORT` - (Optional) The port to listen on (default: 8080)

## Development

To run locally:

```bash
# Set environment variables
export DISCORD_CLIENT_ID=your_client_id
export DISCORD_CLIENT_SECRET=your_client_secret

# Run the service
go run main.go
```

## Docker

Build the image:
```bash
docker build -t discord-auth .
```

Run the container:
```bash
docker run -p 8080:8080 \
  -e DISCORD_CLIENT_ID=your_client_id \
  -e DISCORD_CLIENT_SECRET=your_client_secret \
  discord-auth
```

## Integration

The service is integrated into the RPG deployment stack via docker-compose. Nginx routes `/api/discord/` requests to this service.