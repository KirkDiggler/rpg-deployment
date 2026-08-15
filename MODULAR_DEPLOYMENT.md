# Modular Deployment Guide

This guide explains how to use the modular Docker Compose setup for flexible deployment options.

## Overview

The deployment is split into modular components:
- `docker-compose.base.yml` - Core services (Redis, networking)
- `docker-compose.dnd.yml` - D&D 5e API services
- `docker-compose.api.yml` - RPG API and Envoy proxy
- `docker-compose.web.yml` - Web UI and Nginx
- `docker-compose.yml` - Full stack (includes all above)
- `docker-compose.local-dev.yml` + `docker-compose.local-api-src.yml` - named
  local supervisor and optional local API image overlay

## Named Local Compose Contract

For isolated local environments, use `docker-compose.local-dev.yml` with an
owned project name and Envoy host port. This contract publishes **only Envoy**;
Redis, the D&D API, nginx-local, and their data services communicate solely by
service DNS on the project-derived network.

```bash
export RPG_COMPOSE_PROJECT=game-dev
export RPG_API_HOST_PORT=8080

docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml up -d
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml logs -f envoy
```

Use a prebuilt local API image with the overlay when needed:

```bash
RPG_API_IMAGE=rpg-api:local docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml \
  -f docker-compose.local-api-src.yml up -d
```

`docker-compose.local-src.yml` is the legacy containerized-web path. It is
outside the named local supervisor and not part of this isolated local contract.

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

### 2. API Image Development Mode
Build the API in its worktree, then run it through the named local supervisor:
```bash
docker build -t rpg-api:local ../rpg-api
RPG_API_IMAGE=rpg-api:local docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml \
  -f docker-compose.local-api-src.yml up -d rpg-api
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

### 4. D&D API Service
The D&D API is private service DNS in the named local contract. Test through
the Envoy endpoint or from a container attached to the named project network;
it has no direct host publication.

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

### For Named Local Development
```bash
# Choose these at the Compose boundary.
export RPG_COMPOSE_PROJECT=game-dev
export RPG_API_HOST_PORT=8080
export RPG_API_IMAGE=rpg-api:local
```

The Compose files provide service-DNS URLs for internal dependencies; hosts use
only Envoy at `http://localhost:${RPG_API_HOST_PORT:-8080}`.

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
| Redis | 6379 | - | Data storage (private service DNS) |
| MongoDB | 27017 | - | D&D data (private service DNS) |
| D&D API | 3000 | - | REST API (private service DNS) |
| RPG API | 50051 | - | gRPC (private service DNS) |
| Envoy | 8080 | `${RPG_API_HOST_PORT:-8080}` | gRPC-Web and only host publication |
| nginx-local | 80 | - | Internal local route |

## Tips

1. **Check one named local environment:**
   ```bash
   docker compose -p "$RPG_COMPOSE_PROJECT" \
     -f docker-compose.local-dev.yml ps
   ```

2. **View logs for one service:**
   ```bash
   docker compose -p "$RPG_COMPOSE_PROJECT" \
     -f docker-compose.local-dev.yml logs -f rpg-api
   ```

3. **Stop the named local environment:**
   ```bash
   docker compose -p "$RPG_COMPOSE_PROJECT" \
     -f docker-compose.local-dev.yml down
   ```

4. **Recreate a local API image service:**
   ```bash
   RPG_API_IMAGE=rpg-api:local docker compose -p "$RPG_COMPOSE_PROJECT" \
     -f docker-compose.local-dev.yml \
     -f docker-compose.local-api-src.yml up -d rpg-api
   ```

5. **Clean up a named local environment:**
   ```bash
   docker compose -p "$RPG_COMPOSE_PROJECT" \
     -f docker-compose.local-dev.yml down -v
   ```

## Production vs Development

For production, use the main `docker-compose.yml` with production overrides:
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

For local development, use the modular approach described above.