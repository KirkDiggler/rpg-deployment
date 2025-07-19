# Modular Deployment Guide

This guide explains how to use the modular Docker Compose setup for flexible deployment options.

## Overview

The deployment is split into modular components:
- `docker-compose.base.yml` - Core services (Redis, networking)
- `docker-compose.dnd.yml` - D&D 5e API services
- `docker-compose.api.yml` - RPG API and Envoy proxy
- `docker-compose.web.yml` - Web UI and Nginx
- `docker-compose.yml` - Full stack (includes all above)

## Common Use Cases

### 1. Full Stack Deployment
```bash
# Using the main compose file (recommended)
docker compose up -d

# Or explicitly with all modules
docker compose -f docker-compose.base.yml \
               -f docker-compose.dnd.yml \
               -f docker-compose.api.yml \
               -f docker-compose.web.yml up -d
```

### 2. API Development Mode
When developing the API locally but need the D&D services:
```bash
# Start only Redis and D&D API
docker compose -f docker-compose.base.yml -f docker-compose.dnd.yml up -d

# Run your API locally
export DND5E_API_URL=http://localhost:3001/api/
export REDIS_URL=redis://localhost:6380
go run cmd/server/main.go server
```

### 3. Frontend Development Mode
When developing the web UI:
```bash
# Start backend services
docker compose -f docker-compose.base.yml \
               -f docker-compose.dnd.yml \
               -f docker-compose.api.yml up -d

# Run your frontend locally
cd rpg-dnd5e-web
npm run dev
```

### 4. D&D API Testing Only
```bash
# Just the D&D services
docker compose -f docker-compose.dnd.yml up -d

# Test the API
curl http://localhost:3001/api/races
curl http://localhost:3001/api/classes
```

### 5. Minimal API Stack
Run API without the web UI:
```bash
docker compose -f docker-compose.base.yml \
               -f docker-compose.dnd.yml \
               -f docker-compose.api.yml up -d
```

## Service Dependencies

```
┌─────────────┐
│    nginx    │ (docker-compose.web.yml)
└──────┬──────┘
       │ depends on
┌──────▼──────┐     ┌─────────────┐
│   rpg-web   │     │    envoy    │ (docker-compose.api.yml)
└──────┬──────┘     └──────┬──────┘
       │ depends on        │ depends on
       └──────┬────────────┘
              ▼
       ┌─────────────┐
       │   rpg-api   │ (docker-compose.api.yml)
       └──────┬──────┘
              │ depends on
       ┌──────▼──────┐     ┌─────────────┐
       │    redis    │     │   dnd-api   │
       └─────────────┘     └──────┬──────┘
    (compose.base.yml)            │ depends on
                           ┌──────▼──────┐
                           │dnd-database │
                           └─────────────┘
                        (compose.dnd.yml)
```

## Environment Variables

### For Local Development
```bash
# When running rpg-api locally
export DND5E_API_URL=http://localhost:3001/api/  # D&D API
export REDIS_URL=redis://localhost:6380           # Redis
export PORT=50051                                 # gRPC port
export LOG_LEVEL=debug                           # Logging
```

### For Docker Deployment
These are set in the compose files but can be overridden:
```bash
# Create .env file
cat > .env << EOF
DND5E_API_URL=http://dnd-api:3000/api/
REDIS_URL=redis://redis:6379
LOG_LEVEL=info
EOF

docker compose up -d
```

## Ports Reference

| Service | Internal Port | External Port | Purpose |
|---------|--------------|---------------|---------|
| Redis | 6379 | 6380 | Data storage |
| MongoDB | 27017 | - | D&D data |
| D&D API | 3000 | 3001 | REST API |
| RPG API | 50051 | - | gRPC |
| Envoy | 8080 | - | gRPC-Web |
| Web UI | 80 | - | React app |
| Nginx | 80 | 80 | Load balancer |

## Tips

1. **Check what's running:**
   ```bash
   docker compose ps
   ```

2. **View logs for specific service:**
   ```bash
   docker compose logs -f rpg-api
   ```

3. **Stop specific services:**
   ```bash
   docker compose stop rpg-web nginx
   ```

4. **Update specific services:**
   ```bash
   docker compose pull rpg-api
   docker compose up -d rpg-api
   ```

5. **Clean up:**
   ```bash
   # Stop all services
   docker compose down
   
   # Stop and remove volumes
   docker compose down -v
   ```

## Production vs Development

For production, use the main `docker-compose.yml` with production overrides:
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

For local development, use the modular approach described above.