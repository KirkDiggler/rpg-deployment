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

## Which local environment to use

Treat the primary stack (`rpg-api` / `rpg-envoy`, normally `:8080`) as the
shared stable baseline. Do not redeploy it for an experiment while another
session may be using it. The fixed `lab` and `lab2` services on `:8081` and
`:8082` are shared playtest slots; use them only when you have coordinated
ownership of that slot.

For an unpublished `rpg-toolkit/encounter` change, use the isolated wrapper
below instead of following `rpg-api`'s standalone override guide all the way
to its primary-container redeploy example. The API guide remains authoritative
for how its single-module override works; this wrapper invokes that helper and
owns the safe Docker lifecycle around it.

### Isolated toolkit-override lab

Prerequisites:

- Docker, `curl`, and Python 3 available locally;
- fresh/dispensable API worktree with `Dockerfile.local-toolkit` and
  `scripts/toolkit-local-override.sh`;
- toolkit worktree containing the unpublished `encounter` change;
- the normal local dependency stack already running, including the Docker
  network `rpg-deployment_rpg-network`, Redis, and the D&D API;
- unused Envoy and (optionally) Vite ports.

From this repository:

```bash
scripts/toolkit-override-lab.sh up \
  --api /path/to/rpg-api-worktree \
  --toolkit /path/to/rpg-toolkit-worktree \
  --name movement-893 \
  --envoy-port 8183 \
  --vite-port 5183
```

The command validates the worktrees, lab name, Docker network, container
names, and ports before touching the API worktree. It then invokes the
existing API override helper, verifies that only the approved `encounter`
module is active, builds with `Dockerfile.local-toolkit`, and starts uniquely
named API and Envoy containers. It prints the API URL, exact Vite command,
and cleanup command. It never runs Compose and therefore never recreates the
primary, `lab`, or `lab2` services.

After each toolkit edit, cleanly cycle the lab and run `up` again so the
existing override helper re-syncs the source:

```bash
scripts/toolkit-override-lab.sh down \
  --api /path/to/rpg-api-worktree --name movement-893
# then repeat the up command
```

`down` is idempotent. It removes only the two name-scoped containers, their
lab-specific API image, and the generated Envoy config; invokes the API
helper's `off` path; and verifies each resource and all override residue are
absent before reporting success. Startup failures follow the same verified
rollback, including when the helper mutates and then fails; an approved
override that was already active before `up` is restored byte-for-byte instead
of being removed. The lab shares the existing Redis dependency, so tests that
create fixture keys still own deletion of those keys.

Collision failures are intentional. Do not remove or rename someone else's
container: choose another `--name` or port. `--network` can override the
network name when the dependency stack was started under another Compose
project.

Run the wrapper regression suite with:

```bash
make test
```

## Quick Start

### Named pre-built environment (fastest)

Each local environment must have its own Compose project name and host Envoy
port. The local Compose contract publishes **only Envoy**; Redis, the D&D API,
and nginx-local remain private to the project network.

```bash
export RPG_COMPOSE_PROJECT=my-rpg
export RPG_API_HOST_PORT=8080

# Start all services using pre-built images from GitHub Container Registry.
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml up -d

# Follow one service's logs.
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml logs -f envoy

# Stop this named environment.
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml down
```

### Named local API source environment

Build the API image from a sibling API worktree, then use the source-image
overlay with the same named supervisor:

```bash
docker build -t rpg-api:local ../rpg-api
export RPG_COMPOSE_PROJECT=api-dev
export RPG_API_HOST_PORT=8080
RPG_API_IMAGE=rpg-api:local docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml \
  -f docker-compose.local-api-src.yml up -d

docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml \
  -f docker-compose.local-api-src.yml logs -f rpg-api
```

`docker-compose.local-src.yml` is the legacy containerized-web path. It is
outside this named local supervisor and is not the supported path for isolated
local environments.

## Architecture

```
                    ┌─────────────┐
                    │   Client    │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │ Envoy:8080  │  (only host-published service)
                    │  (gRPC-Web) │
                    └──────┬──────┘
                           │
     ┌───────────────┬─────┴─────┬────────────────┐
     │               │           │                │
┌────▼─────┐  ┌──────▼──────┐ ┌──▼───────┐ ┌──────▼──────┐
│RPG-API   │  │ nginx-local  │ │ DND-API  │ │   Redis     │
│:50051    │  │ (internal)   │ │ :3000    │ │   :6379     │
└──────────┘  └─────────────┘ └────┬─────┘ └─────────────┘
                                    │
                              ┌─────▼──────┐
                              │  MongoDB   │
                              └────────────┘
```

## Available Endpoints

- **Envoy / gRPC-Web**: `http://localhost:${RPG_API_HOST_PORT:-8080}`
- **RPG API, Redis, D&D API, MongoDB, and nginx-local**: private service-DNS
  endpoints on the named Compose network

Only Envoy is host-published by this local contract.

## Configuration Files

### `docker-compose.local-dev.yml`
Uses pre-built images from GitHub Container Registry. Best for:
- Quick testing
- Running stable versions
- Minimal setup

### `docker-compose.local-api-src.yml`
Overrides `rpg-api` with `${RPG_API_IMAGE:-rpg-api:local}` for the named local
supervisor. Build the image in the API worktree before starting the stack.

### `docker-compose.local-src.yml`
Legacy containerized-web path. It is outside the named local supervisor and is
not part of the isolated local environment contract.

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
curl -X POST http://localhost:${RPG_API_HOST_PORT:-8080}/dnd5e.api.v1alpha1.ClassService/ListClasses \
  -H 'Content-Type: application/grpc-web+proto' \
  -H 'X-Grpc-Web: 1' \
  --data-binary '' -v
```

### Test the named Envoy endpoint:
```bash
curl http://localhost:${RPG_API_HOST_PORT:-8080}/health
```

### Test Health:
```bash
curl http://localhost:${RPG_API_HOST_PORT:-8080}/health
```

## Troubleshooting

### Port Conflicts
The only host port in this local contract is Envoy's
`${RPG_API_HOST_PORT:-8080}`. Choose a different `RPG_API_HOST_PORT` for a
second named environment.

### Service Won't Start
Check the service through its named Compose project:
```bash
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml logs envoy
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml logs rpg-api
```

### Clean Restart
```bash
# Remove and recreate only this named environment.
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml down -v
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml up -d --force-recreate
```

## Development Workflow

1. Make changes to source code and rebuild `rpg-api:local` in its API worktree.
2. Recreate the named API service with the source-image overlay:
   ```bash
   RPG_API_IMAGE=rpg-api:local docker compose -p "$RPG_COMPOSE_PROJECT" \
     -f docker-compose.local-dev.yml \
     -f docker-compose.local-api-src.yml up -d rpg-api
   ```
3. Check logs through the named project:
   ```bash
   docker compose -p "$RPG_COMPOSE_PROJECT" \
     -f docker-compose.local-dev.yml \
     -f docker-compose.local-api-src.yml logs -f rpg-api
   ```
4. Test through Envoy at `http://localhost:${RPG_API_HOST_PORT:-8080}`.

## Notes

- All services communicate internally by service DNS on the named Docker network.
- Only Envoy is published on `${RPG_API_HOST_PORT:-8080}`.
- Envoy handles gRPC to gRPC-Web translation.
- Redis, D&D API, and nginx-local are not host-published by this contract.