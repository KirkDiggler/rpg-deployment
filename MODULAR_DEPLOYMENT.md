# Modular deployment

The game uses the RPG API and Redis. Rules live in the toolkit; an auxiliary
rules API, MongoDB and its cache are not runtime dependencies.

## Compose entry points

| File | Role |
|---|---|
| `docker-compose.base.yml` | Redis and the shared network for modular commands |
| `docker-compose.api.yml` | RPG API and Envoy |
| `docker-compose.web.yml` | Web UI and nginx |
| `docker-compose.local-dev.yml` | Named local backend stack for a host-side Vite server |
| `docker-compose.local-api-src.yml` | Override the local backend's API image |
| `docker-compose.local-lab.yml` | Optional parallel API/Envoy instances |
| `docker-compose.local-prod.yml` | Published-image production-parity stack on localhost:8090 |
| `docker-compose.prod.yml` | Production stack used by the deployment workflow |
| `docker-compose.yml` | Legacy full-stack entry point |
| `docker-compose.dnd.yml`, `docker-compose.local.yml` | Empty compatibility overlays for older command lines |

Compose files compose. Add environment-specific settings through overlays and
variables instead of copying a stack. The compatibility overlays create no
services and delete no Docker volumes.

## Normal workspace development

From the **game-dev root checkout**:

```sh
scripts/dev-env.sh up dev
scripts/dev-env.sh status dev
scripts/dev-env.sh down dev
```

The workspace supervisor selects source revisions, builds the API, owns the
Compose project and Vite process, and mirrors the assets pinned by Web. Its
persistent-Redis overlay keeps game data between restarts. That overlay must
not reintroduce any retired services.

## Named local Compose contract

For direct backend checks from this repository:

```sh
export RPG_COMPOSE_PROJECT=game-dev
export RPG_API_HOST_PORT=8080

docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml up -d
```

Only Envoy is published to the host. Redis, the RPG API and nginx-local use
service DNS on the project-derived network. There are no fixed container names.
The API depends on Redis alone.

To use a prebuilt API image:

```sh
RPG_API_IMAGE=rpg-api:local docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml \
  -f docker-compose.local-api-src.yml up -d
```

The host-side Web server's `VITE_API_HOST` points to
`http://localhost:${RPG_API_HOST_PORT:-8080}`. `docker-compose.local-src.yml` is
a separate legacy containerized-Web path, not the normal Vite supervisor.

The modular equivalent without a Web container is:

```sh
docker compose -f docker-compose.base.yml -f docker-compose.api.yml up -d
```

Add `docker-compose.web.yml` for the Web container and nginx. Internal traffic
flows through nginx → Envoy → RPG API → Redis. The API's Redis address is
`REDIS_ADDR=redis:6379`; no auxiliary rules URL is required.

## Authored dungeon content

`./content` is runtime state mounted at `/content`, not source-controlled
fixtures. The API seeds missing built-in reference dungeons from its current
image. It does not overwrite existing authored or edited files, and refuses an
incompatible dungeon rather than silently ignoring it.

Before clearing obsolete content, stop its stack and archive the selected YAMLs
outside the mounted directory. Keep Redis data and source/test YAMLs separate
from this operation. Fresh references appear on the next boot; arbitrary
operator-authored dungeons do not get restored automatically.

## Checks and production

`make test` checks the intended four-service local stack, named-project
isolation, lab tooling and guild-header routing without starting live containers.
To include the workspace's actual persistent-Redis overlays in that same stack
check, run `GAME_DEV_ROOT=/path/to/game-dev make test`. Redis lifecycle and
data-preservation tests remain in game-dev; no retired-service behavior is tested.

Use `make local-prod` for the published-image local parity stack. Production uses
`docker-compose.prod.yml`, not the legacy full-stack file. A merge to deployment
`main` triggers its production deployment workflow; treat that as an explicit
operational effect, even when a change mainly concerns local development.
