# RPG Platform - Quick Start Guide for Developers

Get the entire RPG platform running locally in under 5 minutes!

## 🚀 TL;DR - Just Get It Running

```bash
# Clone and start an isolated environment.
git clone https://github.com/KirkDiggler/rpg-deployment.git
cd rpg-deployment
export RPG_COMPOSE_PROJECT=my-rpg
export RPG_API_HOST_PORT=8080
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml up -d

# Test the only host-published endpoint, then follow its logs.
curl http://localhost:${RPG_API_HOST_PORT:-8080}/health
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml logs -f envoy

# Run the deployment-tooling test suite.
make test
```

That's it! The platform is available through Envoy at
`http://localhost:${RPG_API_HOST_PORT:-8080}`.

## 📦 What You Get

When you run the stack, you get:

- **rpg-api** - gRPC API server for D&D 5e game logic
- **Envoy Proxy** - Translates gRPC-Web for browser clients  
- **nginx-local** - Internal local route
- **Redis** - Session and character storage (private service DNS)
- **DND API** - D&D 5e reference data (private service DNS)
- **MongoDB** - DND API's database (private service DNS)

Only Envoy is host-published by the named local Compose contract.

## 🧪 Testing the API

### Quick Test - Is It Working?

```bash
# Test gRPC-Web is working (should return "entity_id is required")
echo -n "AAAAAAA=" | \
curl -X POST http://localhost:${RPG_API_HOST_PORT:-8080}/api.v1alpha1.DiceService/RollDice \
    -H "Content-Type: application/grpc-web-text" \
    --data-binary @- -i
```

If you see `grpc-message: entity_id is required`, it's working!

### Common API Calls

```bash
# List available races (for character creation)
echo -n "AAAAAAA=" | \
curl -X POST http://localhost:${RPG_API_HOST_PORT:-8080}/dnd5e.api.v1alpha1.CharacterService/ListRaces \
    -H "Content-Type: application/grpc-web-text" \
    --data-binary @- -i

# List available classes
echo -n "AAAAAAA=" | \
curl -X POST http://localhost:${RPG_API_HOST_PORT:-8080}/dnd5e.api.v1alpha1.CharacterService/ListClasses \
    -H "Content-Type: application/grpc-web-text" \
    --data-binary @- -i

# Roll dice (with proper input)
echo -n "AAAAABIKBHRlc3QSBHRlc3QaBDFkMjA=" | \
curl -X POST http://localhost:${RPG_API_HOST_PORT:-8080}/api.v1alpha1.DiceService/RollDice \
    -H "Content-Type: application/grpc-web-text" \
    --data-binary @- -i
```

### Understanding Responses

- **HTTP 200 + grpc-status: 0** = Success! Check response body for data
- **HTTP 200 + grpc-status: 3** = Invalid input (missing required fields)
- **HTTP 200 + grpc-status: 12** = Method not implemented yet
- **HTTP 504** = Service unreachable (check if containers are running)

## 🛠️ Development Workflows

### Option 1: Named pre-built environment (recommended for frontend devs)

Use a named environment when the web app only needs a backend:

```bash
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml up -d
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml logs -f envoy
```

- ✅ Quick startup
- ✅ Stable versions
- ✅ Isolated network and container names
- ❌ Can't modify backend code

### Option 2: Named local API image (for API changes)

Build an image in the API worktree and supply it to the named supervisor:

```bash
docker build -t rpg-api:local ../rpg-api
RPG_API_IMAGE=rpg-api:local docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml \
  -f docker-compose.local-api-src.yml up -d
```

- ✅ Uses local API changes
- ✅ Retains the isolated Compose contract
- ❌ Requires rebuilding the local API image

### Option 3: Host web development (most flexible)

Run the web app on the host against the named Envoy endpoint:

```bash
# Start the named backend first.
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml up -d

cd ../rpg-dnd5e-web
npm run dev
```

`docker-compose.local-src.yml` is the legacy containerized-web path and is
outside the named local supervisor.

## 🔌 Integration Points

### For Web Developers

Your React/Vue/Angular app should:

1. Use ConnectRPC or gRPC-Web client
2. Point to `http://localhost:${RPG_API_HOST_PORT:-8080}` (Envoy entry point)
3. Send requests as `application/grpc-web+proto` (binary) or `application/grpc-web-text` (base64)

Example with ConnectRPC:
```javascript
import { createGrpcWebTransport } from '@connectrpc/connect-web';

const selectedEnvoyPort = '18081'; // Set to this environment's RPG_API_HOST_PORT.
const transport = createGrpcWebTransport({
  baseUrl: `http://localhost:${selectedEnvoyPort}`,
});
```

### For Backend Developers

The rpg-api gRPC port is private to the named network. Use Envoy from the host,
or join a diagnostic container to the project-derived network:

```bash
docker run --rm --network "${RPG_COMPOSE_PROJECT}_rpg-network" \
  fullstorydev/grpcurl -plaintext rpg-api:50051 list
```

## 📊 Architecture

```
Browser/Client
      ↓
Envoy:${RPG_API_HOST_PORT:-8080} (gRPC-Web → gRPC; only host publication)
      ↓
rpg-api:50051 (private service DNS)
      ↓
   Redis:6379 (private service DNS)
```

## 🐛 Troubleshooting

### "Bad Gateway" Error
```bash
# Check this named environment and its services.
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml ps
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml logs rpg-api
```

### "Connection Refused"
```bash
# Make sure Envoy is healthy and restart only this named environment.
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml ps
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml restart envoy
```

### Services Won't Start
```bash
# Clean restart only this named environment.
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml down -v
docker compose -p "$RPG_COMPOSE_PROJECT" \
  -f docker-compose.local-dev.yml up -d --force-recreate
```

### Port Conflicts
Only `RPG_API_HOST_PORT` is published. Choose an unused value for each named
environment.

## 📚 Available Services

| Service | Internal Port | External Port | Purpose |
|---------|--------------|---------------|----------|
| nginx-local | 80 | - | Internal local route |
| Envoy | 8080 | `${RPG_API_HOST_PORT:-8080}` | gRPC-Web translation and only host publication |
| rpg-api | 50051 | - | Game logic API (private service DNS) |
| Redis | 6379 | - | Data storage (private service DNS) |
| DND API | 3000 | - | D&D reference data (private service DNS) |
| MongoDB | 27017 | - | D&D API database (private service DNS) |

## 🎮 What Can You Build?

With this platform running, you can build:

- Character creation tools
- Combat trackers
- Spell managers
- Inventory systems
- Party management
- Virtual tabletop features
- Discord activities
- Mobile apps

## 📖 Learn More

- [Detailed Local Development Guide](./LOCAL_DEV.md)
- [Architecture Documentation](./README.md)
- [API Protocol Buffer Definitions](https://github.com/KirkDiggler/rpg-api-protos)
- [React Web App Example](https://github.com/KirkDiggler/rpg-dnd5e-web)

## 💬 Need Help?

- Check the [troubleshooting section](#-troubleshooting)
- Review the test scripts: `./test-rpg-api.sh`
- Open an issue on GitHub
- Check one named environment: `docker compose -p "$RPG_COMPOSE_PROJECT" -f docker-compose.local-dev.yml ps`

---

**Ready to build something awesome? The platform is running and waiting for your creativity!** 🎲