# Local Development Setup

This guide explains how to run the entire RPG platform locally for development.

## Quick Start

### Using Pre-built Images (Fastest)

```bash
# Start all services using pre-built images from GitHub Container Registry
docker compose -f docker-compose.local-dev.yml up -d

# View logs
docker compose -f docker-compose.local-dev.yml logs -f

# Stop services
docker compose -f docker-compose.local-dev.yml down
```

### Using Local Source Code (Development)

```bash
# Start all services building from local source directories
docker compose -f docker-compose.local-src.yml up -d --build

# View logs
docker compose -f docker-compose.local-src.yml logs -f

# Rebuild after code changes
docker compose -f docker-compose.local-src.yml up -d --build rpg-api

# Stop services
docker compose -f docker-compose.local-src.yml down
```

## Architecture

```
                    ┌─────────────┐
                    │   Client    │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  nginx:80   │  (Single entry point)
                    └──────┬──────┘
                           │
            ┌──────────────┼──────────────┐
            │              │              │
     ┌──────▼──────┐ ┌────▼─────┐ ┌─────▼──────┐
     │  Envoy:8080 │ │ Web:3000 │ │ DND-API:3000│
     │  (gRPC-Web) │ │  (React) │ │   (REST)    │
     └──────┬──────┘ └──────────┘ └─────┬──────┘
            │                            │
     ┌──────▼──────┐              ┌─────▼──────┐
     │ RPG-API:50051│             │  MongoDB   │
     │   (gRPC)    │              └────────────┘
     └──────┬──────┘
            │
     ┌──────▼──────┐
     │   Redis     │
     └─────────────┘
```

## Available Endpoints

- **Main Entry**: http://localhost
- **Health Check**: http://localhost/health
- **gRPC-Web Services**: http://localhost/[service.name]/[method]
- **DND API Proxy**: http://localhost/dnd-api/
- **DND API Direct**: http://localhost:3002/api
- **Redis**: localhost:6380

## Configuration Files

### `docker-compose.local-dev.yml`
Uses pre-built images from GitHub Container Registry. Best for:
- Quick testing
- Running stable versions
- Minimal setup

### `docker-compose.local-src.yml`
Builds from local source code. Best for:
- Active development
- Testing local changes
- Debugging

### `nginx/nginx-local.conf`
Basic nginx configuration without web frontend. Routes:
- gRPC-Web traffic to Envoy
- DND API requests

### `nginx/nginx-local-with-web.conf`
Full nginx configuration including React web app. Adds:
- Web app proxying with hot reload support
- WebSocket support for Vite HMR

## Directory Structure Required

For local source builds, expects this directory structure:
```
/home/kirk/personal/
├── rpg-deployment/     (this repo)
├── rpg-api/           (gRPC API server)
├── rpg-dnd5e-web/     (React web app)
└── rpg-toolkit/       (optional)
```

## Testing

### Test gRPC-Web connectivity:
```bash
# Should return grpc-status header
curl -X POST http://localhost/dnd5e.api.v1alpha1.ClassService/ListClasses \
  -H 'Content-Type: application/grpc-web+proto' \
  -H 'X-Grpc-Web: 1' \
  --data-binary '' -v
```

### Test DND API:
```bash
# Through nginx proxy
curl http://localhost/dnd-api/classes

# Direct access
curl http://localhost:3002/api/classes
```

### Test Health:
```bash
curl http://localhost/health
```

## Troubleshooting

### Port Conflicts
If you get "address already in use" errors:
- Port 80: Another web server is running
- Port 6380: Another Redis instance
- Port 3002: DND API already running

Solution: Stop conflicting services or modify the port mappings in the compose files.

### Container Won't Start
Check logs for specific container:
```bash
docker logs rpg-api
docker logs rpg-envoy
docker logs rpg-nginx-local
```

### Clean Restart
```bash
# Remove everything and start fresh
docker compose -f docker-compose.local-dev.yml down -v
docker compose -f docker-compose.local-dev.yml up -d --force-recreate
```

## Development Workflow

1. Make changes to source code
2. If using `local-src.yml`, rebuild affected services:
   ```bash
   docker compose -f docker-compose.local-src.yml up -d --build rpg-api
   ```
3. Check logs for errors:
   ```bash
   docker compose -f docker-compose.local-src.yml logs -f rpg-api
   ```
4. Test your changes through nginx at http://localhost

## Notes

- All services communicate internally via Docker network
- Only nginx is exposed externally on port 80
- Envoy handles gRPC to gRPC-Web translation
- Redis is exposed on 6380 (not 6379) to avoid conflicts
- DND API is available on 3002 for direct access during development