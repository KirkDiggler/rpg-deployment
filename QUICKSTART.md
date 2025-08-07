# RPG Platform - Quick Start Guide for Developers

Get the entire RPG platform running locally in under 5 minutes!

## 🚀 TL;DR - Just Get It Running

```bash
# Clone and start everything
git clone https://github.com/KirkDiggler/rpg-deployment.git
cd rpg-deployment
docker compose -f docker-compose.local-dev.yml up -d

# Test it's working
curl http://localhost/health

# Run the test suite
./test-rpg-api.sh
```

That's it! The entire platform is now running at http://localhost

## 📦 What You Get

When you run the stack, you get:

- **rpg-api** - gRPC API server for D&D 5e game logic
- **Envoy Proxy** - Translates gRPC-Web for browser clients  
- **nginx** - Single entry point routing all traffic
- **Redis** - Session and character storage
- **DND API** - D&D 5e reference data (classes, races, spells, etc.)
- **MongoDB** - DND API's database

## 🧪 Testing the API

### Quick Test - Is It Working?

```bash
# Test gRPC-Web is working (should return "entity_id is required")
echo -n "AAAAAAA=" | \
curl -X POST http://localhost/api.v1alpha1.DiceService/RollDice \
    -H "Content-Type: application/grpc-web-text" \
    --data-binary @- -i
```

If you see `grpc-message: entity_id is required`, it's working!

### Common API Calls

```bash
# List available races (for character creation)
echo -n "AAAAAAA=" | \
curl -X POST http://localhost/dnd5e.api.v1alpha1.CharacterService/ListRaces \
    -H "Content-Type: application/grpc-web-text" \
    --data-binary @- -i

# List available classes
echo -n "AAAAAAA=" | \
curl -X POST http://localhost/dnd5e.api.v1alpha1.CharacterService/ListClasses \
    -H "Content-Type: application/grpc-web-text" \
    --data-binary @- -i

# Roll dice (with proper input)
echo -n "AAAAABIKBHRlc3QSBHRlc3QaBDFkMjA=" | \
curl -X POST http://localhost/api.v1alpha1.DiceService/RollDice \
    -H "Content-Type: application/grpc-web-text" \
    --data-binary @- -i
```

### Understanding Responses

- **HTTP 200 + grpc-status: 0** = Success! Check response body for data
- **HTTP 200 + grpc-status: 3** = Invalid input (missing required fields)
- **HTTP 200 + grpc-status: 12** = Method not implemented yet
- **HTTP 504** = Service unreachable (check if containers are running)

## 🛠️ Development Workflows

### Option 1: Using Pre-built Images (Recommended for Frontend Devs)

Best if you're working on the web app and just need the backend running:

```bash
docker compose -f docker-compose.local-dev.yml up -d
```

- ✅ Quick startup
- ✅ Stable versions
- ✅ No build required
- ❌ Can't modify backend code

### Option 2: Building from Local Source (For Full-Stack Devs)

Best if you're working on both frontend and backend:

```bash
# Assumes you have rpg-api and rpg-dnd5e-web cloned locally
docker compose -f docker-compose.local-src.yml up -d --build
```

- ✅ Use your local code changes
- ✅ Full control
- ❌ Slower startup (builds containers)
- ❌ Need all repos cloned

### Option 3: Hybrid Development (Most Flexible)

Run some services locally, others in Docker:

```bash
# Start just the infrastructure
docker compose -f docker-compose.local-dev.yml up -d redis dnd-database dnd-api envoy nginx-local

# Run rpg-api locally
cd ../rpg-api
make run

# Run web app locally  
cd ../rpg-dnd5e-web
npm run dev
```

## 🔌 Integration Points

### For Web Developers

Your React/Vue/Angular app should:

1. Use ConnectRPC or gRPC-Web client
2. Point to `http://localhost` (nginx entry point)
3. Send requests as `application/grpc-web+proto` (binary) or `application/grpc-web-text` (base64)

Example with ConnectRPC:
```javascript
import { createGrpcWebTransport } from '@connectrpc/connect-web';

const transport = createGrpcWebTransport({
  baseUrl: 'http://localhost',
});
```

### For Backend Developers

The rpg-api is pure gRPC on port 50051. You can:

1. Use grpcurl for testing:
```bash
docker run --rm --network rpg-deployment_rpg-network fullstorydev/grpcurl \
  -plaintext rpg-api:50051 list
```

2. Connect directly from your gRPC client:
```go
conn, err := grpc.Dial("localhost:50051", grpc.WithInsecure())
```

## 📊 Architecture

```
Browser/Client
      ↓
   nginx:80
      ↓
 Envoy:8080 (gRPC-Web → gRPC)
      ↓
rpg-api:50051 (gRPC)
      ↓
   Redis:6379
```

## 🐛 Troubleshooting

### "Bad Gateway" Error
```bash
# Check all services are running
docker compose -f docker-compose.local-dev.yml ps

# Check logs
docker logs rpg-api
docker logs rpg-envoy
```

### "Connection Refused"
```bash
# Make sure services are healthy
docker compose -f docker-compose.local-dev.yml ps

# Restart everything
docker compose -f docker-compose.local-dev.yml restart
```

### Services Won't Start
```bash
# Clean restart
docker compose -f docker-compose.local-dev.yml down -v
docker compose -f docker-compose.local-dev.yml up -d --force-recreate
```

### Port Conflicts
- Port 80: Stop local web server
- Port 6380: Stop local Redis
- Port 3002: Stop any service using this port

## 📚 Available Services

| Service | Internal Port | External Port | Purpose |
|---------|--------------|---------------|----------|
| nginx | 80 | 80 | Entry point for all traffic |
| Envoy | 8080 | - | gRPC-Web translation |
| rpg-api | 50051 | - | Game logic API |
| Redis | 6379 | 6380 | Data storage |
| DND API | 3000 | 3002 | D&D reference data |
| MongoDB | 27017 | - | DND API database |

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
- Check if services are healthy: `docker compose ps`

---

**Ready to build something awesome? The platform is running and waiting for your creativity!** 🎲