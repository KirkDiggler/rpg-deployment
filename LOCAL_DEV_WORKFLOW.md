# Local Development Workflow

This document describes individual-service and Docker Compose flows.
For environment ownership and the supported isolated toolkit-override lab, read
[LOCAL_DEV.md](LOCAL_DEV.md#which-local-environment-to-use) first. Docker
Compose environments must use an owned project name and Envoy host port; never
silently redeploy another named environment.

## Option 1: Individual Services (coordinated primary work only)

Use this only when you intentionally own the primary environment. It is not
the safe path for an unpublished toolkit experiment; use the isolated wrapper
in `LOCAL_DEV.md` for that.

### Prerequisites
- Redis running on localhost:6379
- Go installed for rpg-api
- Node.js installed for rpg-dnd5e-web

### Steps

1. **Start Redis** (if not already running):
```bash
redis-server
```

2. **Start rpg-api with Envoy**:
```bash
cd /home/kirk/personal/rpg-api
docker compose up -d  # Starts Envoy on port 8080
make run             # Starts gRPC server on port 50051
```

3. **Start rpg-dnd5e-web**:
```bash
cd /home/kirk/personal/rpg-dnd5e-web
npm run dev          # Starts on port 5173
```

### Access Points
- Web UI: http://localhost:5173
- Envoy (gRPC-Web): http://localhost:8080
- gRPC API: localhost:50051
- Envoy Admin: http://localhost:9901

### Testing gRPC-Web
```bash
# The web app sends JSON via Connect protocol
# Envoy handles the gRPC-Web translation
curl -X POST http://localhost:8080/api.v1alpha1.DiceService/RollDice \
    -H "Content-Type: application/json" \
    -d '{"entity_id":"test","context":"test","notation":"1d20"}'
```

## Option 2: Named Docker Compose Stack (From rpg-deployment)

For an isolated fully containerized environment, choose an owned Compose name
and Envoy port. Only Envoy is host-published by this local contract; service
DNS keeps Redis, the D&D API, and nginx-local inside the named network.

### Using Pre-built Images
```bash
cd /home/kirk/personal/rpg-deployment
export RPG_COMPOSE_PROJECT=frontend-dev
export RPG_API_HOST_PORT=8080
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml up -d
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml logs -f envoy
```

### Using a Local API Image
```bash
cd /home/kirk/personal/rpg-deployment
docker build -t rpg-api:local ../rpg-api
RPG_API_IMAGE=rpg-api:local docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml \
  -f docker-compose.local-api-src.yml up -d
```

`docker-compose.local-src.yml` is a legacy containerized-web path outside this
named supervisor.

### Access Points
- Envoy / gRPC-Web: `http://localhost:${RPG_API_HOST_PORT:-8080}`
- All other services: private service-DNS endpoints on the named network

## Key Differences

### Individual Services (Option 1)
- ✅ Hot reload for Go and React code
- ✅ Direct debugging capability
- ✅ Matches current dev workflow
- ❌ Need to manage multiple terminals
- ❌ Manual dependency management

### Docker Stack (Option 2)
- ✅ Single command to start everything
- ✅ Consistent environment
- ✅ Includes all dependencies (MongoDB, DND API)
- ❌ Slower iteration (need rebuilds)
- ❌ Harder to debug

## Architecture Notes

The key insight is that **rpg-api doesn't use Connect protocol directly** - it's pure gRPC. The magic happens in the client:

1. **rpg-dnd5e-web** uses ConnectRPC client
2. ConnectRPC sends JSON over HTTP/1.1 to Envoy
3. Envoy (with grpc_web filter) translates to gRPC
4. rpg-api receives pure gRPC calls

This is why:
- You can curl with JSON (Connect protocol supports it)
- The rpg-api doesn't need Connect dependencies
- Envoy only needs the grpc_web filter, not JSON transcoder

## Troubleshooting

### "Bad Gateway" errors
- Check if rpg-api is running: `lsof -i :50051`
- Check Envoy logs: `docker compose -p "$RPG_COMPOSE_PROJECT" -f docker-compose.local-dev.yml logs envoy`
- Verify Envoy can reach rpg-api

### gRPC-Web not working
- Ensure Envoy has `grpc_web` filter configured
- Check CORS headers are set correctly
- Verify the service/method names match

### Connect/JSON requests failing
- Remember: this is NOT gRPC-JSON transcoding
- The client (ConnectRPC) handles JSON serialization
- Envoy just passes through the Connect protocol
- The format is specific to Connect, not arbitrary JSON