# Local Development Workflow

This document describes how to run the RPG platform locally for development, matching the actual development workflow.

## Option 1: Individual Services (Like Current Dev Workflow)

This matches how you currently develop locally:

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

## Option 2: Docker Compose Stack (From rpg-deployment)

For a fully containerized setup:

### Using Pre-built Images
```bash
cd /home/kirk/personal/rpg-deployment
docker compose -f docker-compose.local-dev.yml up -d
```

### Using Local Source Code
```bash
cd /home/kirk/personal/rpg-deployment
docker compose -f docker-compose.local-src.yml up -d --build
```

### Access Points
- All services through nginx: http://localhost
- DND API: http://localhost:3002
- Redis: localhost:6380

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
- Check Envoy logs: `docker logs <envoy-container>`
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