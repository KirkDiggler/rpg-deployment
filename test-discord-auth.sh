#!/bin/bash

echo "🔍 Testing Discord Auth Integration"
echo "=================================="

# Check if services are running
echo "1. Checking if services are up..."
docker compose ps | grep -E "(discord-auth|nginx)" || echo "Services not running. Run: docker compose up -d"

# Test health endpoint
echo -e "\n2. Testing Discord Auth health endpoint..."
curl -s http://localhost:8080/health && echo " ✅ Direct health check passed" || echo " ❌ Direct health check failed"

# Test through nginx
echo -e "\n3. Testing Discord Auth through nginx..."
curl -s http://localhost/api/discord/token -X POST -H "Content-Type: application/json" -d '{"code":"test"}' | jq . || echo "Failed to reach auth service through nginx"

echo -e "\n4. Checking nginx logs for routing..."
docker logs rpg-nginx 2>&1 | tail -5

echo -e "\n✨ Test complete!"
echo "Note: The token exchange will fail with a test code - that's expected."
echo "The important thing is that the request reaches the service."