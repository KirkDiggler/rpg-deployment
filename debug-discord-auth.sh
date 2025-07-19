#!/bin/bash

echo "🔍 Discord Auth Service Debug Script"
echo "===================================="

# Check if all services are running
echo -e "\n1. Checking service status..."
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(discord-auth|nginx|envoy|rpg-web)" || echo "Some services not running"

# Check Discord auth service logs
echo -e "\n2. Discord auth service logs (last 20 lines):"
docker logs rpg-discord-auth --tail 20 2>&1 || echo "Failed to get discord-auth logs"

# Check nginx logs for routing issues
echo -e "\n3. Nginx logs (last 10 lines):"
docker logs rpg-nginx --tail 10 2>&1 || echo "Failed to get nginx logs"

# Test health endpoint directly
echo -e "\n4. Testing health endpoint directly:"
docker exec rpg-discord-auth wget -qO- http://localhost:8080/health || echo "Health check failed"

# Test through nginx
echo -e "\n5. Testing through nginx (from inside container network):"
docker exec rpg-nginx wget -qO- http://discord-auth:8080/health || echo "Failed to reach discord-auth from nginx"

# Check environment variables
echo -e "\n6. Checking Discord environment variables:"
docker exec rpg-discord-auth printenv | grep DISCORD || echo "No Discord env vars found"

# Test the actual endpoint
echo -e "\n7. Testing token endpoint with curl:"
docker exec rpg-nginx curl -s -X POST http://discord-auth:8080/api/discord/token \
  -H "Content-Type: application/json" \
  -d '{"code":"test"}' | jq . || echo "Failed to test token endpoint"

# Check if nginx config has the right upstream
echo -e "\n8. Checking nginx configuration:"
docker exec rpg-nginx cat /etc/nginx/nginx.conf | grep -A5 "discord" || echo "No discord config found in nginx"

# Network connectivity test
echo -e "\n9. Testing network connectivity:"
docker exec rpg-nginx ping -c 1 discord-auth || echo "Cannot ping discord-auth service"

echo -e "\n✅ Debug complete!"