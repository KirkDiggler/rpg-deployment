# Local Development Setup

This guide explains how to run the entire RPG platform locally for development.

## Local Prod-Parity Stack (rpg-deployment#56)

One command to run the *exact published production images* locally --
`ghcr.io/kirkdiggler/rpg-api:latest` and `ghcr.io/kirkdiggler/rpg-dnd5e-web:latest`,
unmodified -- for answering "what does prod actually run/serve?" questions
(deployed-vs-local divergence in lighting, assets, toolkit version timing,
etc.) without waiting on a real deploy.

```bash
make local-prod       # pulls both :latest images, brings up the stack
make local-prod-logs  # follow logs
make local-prod-down  # tear down
```

Up at **http://localhost:8090**. Wires together: `redis` -> `rpg-api`
(`AUTH_DEV_MODE=true`, no Discord secrets needed) -> `envoy` (gRPC-Web
translation, reusing `envoy/envoy.yaml`) -> `nginx` (single entry point,
`nginx/nginx-local-prod.conf`) -> `rpg-web`. No `.env` required. Redis has no
volume, so `local-prod-down` + `local-prod` gives you a clean slate.

`nginx-local-prod.conf` is `nginx-local-with-web.conf` minus the `/dnd-api/`
proxy_pass -- that upstream isn't part of this stack and `DND5E_API_URL` is
unused by rpg-api's Go code -- and minus nginx's own CORS `add_header` lines
on the gRPC-Web route, which stacked a second `Access-Control-Allow-Origin`
on top of the one envoy's own `http.cors` filter already sets, producing an
invalid multi-value header the moment a caller isn't same-origin (harmless
normally since real prod traffic is same-origin, but it broke this stack's
own smoke test below).

### Known limitations of testing the published web image this way

Two characteristics of the published `rpg-dnd5e-web:latest` image mean
**opening http://localhost:8090 in an ordinary browser will not, by itself,
exercise this local `rpg-api`** for gRPC calls -- both discovered while
building this stack, and both baked into the image at CI build time, not
fixable via env vars or compose config:

1. **The `?playerId=` dev-auth override is compiled out.** `vite build`
   (what CI runs) bakes `import.meta.env.MODE` to the literal string
   `"production"`. `src/App.tsx`'s dev-auth override and `src/api/client.ts`'s
   interceptor branch that attaches `Authorization: Dev <id>` are both gated
   on `import.meta.env.MODE === 'development'`, so in the published bundle
   that whole path is dead code -- every gRPC-Web call goes out with no
   Authorization header at all, which `AUTH_DEV_MODE=true` rpg-api correctly
   rejects as Unauthenticated.
2. **`VITE_API_HOST` is baked to the real production domain.** CI
   (`rpg-dnd5e-web/.github/workflows/docker.yml`) passes `secrets.VITE_API_HOST`
   as a build arg, which resolves to `https://rpg-toolkit.app`. The bundle
   therefore calls the *live* production backend directly, not whatever's
   running next to it -- this is true for `docker-compose.local-dev.yml` too,
   since it uses the same `:latest` web image.

This stack is still fully correct and useful as-is for verifying image
provenance (pull it, inspect labels/created date, check the asset tree),
driving the real `rpg-api:latest` binary directly (`grpcurl`/`curl` with a
manual `Authorization: Dev <player_id>` header), and confirming the
envoy/nginx wiring itself works. Getting the *published web bundle* to
render against this local backend for a full click-through (done for
rpg-deployment#56's own smoke test, see PR evidence) additionally requires
intercepting the bundle's `https://rpg-toolkit.app` calls at the network
layer and redirecting them here -- a Playwright `route.continue()` with a
local self-signed TLS terminator in front of the stack (needed because
`route.continue()` requires the override URL to keep the same scheme, and
because a naive buffering proxy breaks the app's server-streaming RPCs like
`StreamLobby`/`StreamEncounter`). That workaround lives in the PR's evidence,
not in this repo, since it's test tooling rather than something the stack
itself needs to ship.

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