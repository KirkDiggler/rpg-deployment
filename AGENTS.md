# rpg-deployment

rpg-deployment owns how the game runs: the docker compose layering, the proxy
config, and the scripts that run the stack locally and in production.

## Where things live

- Compose layering — `docker-compose.base.yml` plus per-environment overlays
  (local, local-prod, prod, api, web, certbot, lab variants); the guide is
  `MODULAR_DEPLOYMENT.md`
- `envoy/`, `nginx/` — proxy config (gRPC-web, TLS, routing)
- `aws/`, `scripts/` — infra and deployment tooling
- Runbooks at the root: `README.md`, `SETUP.md`, `QUICKSTART.md`,
  `LOCAL_DEV.md`, `LOCAL_DEV_WORKFLOW.md`, `ENV_SETUP.md`, `SSL_SETUP.md`,
  `REPOSITORY_STRUCTURE.md`
- `docs/` — server access and Cloudflare setup runbooks
- `content/`, `tests/` — fixtures and checks

## The current container stack

The production stack is the `rpg-*` containers:

| container | image |
|---|---|
| `rpg-web` | `ghcr.io/kirkdiggler/rpg-dnd5e-web` |
| `rpg-api` | `ghcr.io/kirkdiggler/rpg-api` |
| `rpg-redis` | `redis:7-alpine` |
| `rpg-envoy` | Envoy (gRPC-web) |
| `rpg-discord-auth` | Discord auth service |
| `rpg-nginx` | nginx (TLS, routing) |

## Hard rules

- **`dnd-api` and `dnd-database` are retired.** They are the legacy
  5e-API-clone + MongoDB stack (the old `DND5E_API_URL` / `MONGODB_URI`
  wiring) and are not part of the game. New work does not reference them, and
  no compose file recreates them; the entries still sitting in the legacy
  `docker-compose.yml` are cleanup debt, not a stack to build on.
- Compose files compose — changes ship as overlays on `base`, not copies of
  whole stacks. When a service changes, check every overlay that names it.
- Environment differences are expressed in env files and overlays, never by
  editing a shared file per environment.
- Production changes are verified against `test-like-deployed.sh` and the
  health-check workflow before merge.