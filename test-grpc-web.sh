#!/bin/bash

echo "Testing gRPC-Web through nginx -> envoy -> rpg-api"
echo "=================================================="
echo ""

# Test 1: Health check
echo "1. Testing nginx health endpoint:"
curl -s http://localhost/health && echo "✓ Nginx is healthy" || echo "✗ Nginx health check failed"
echo ""

# Test 2: Direct DND API
echo "2. Testing DND API proxy:"
curl -s http://localhost/dnd-api/classes | head -c 100
echo ""
echo ""

# Test 3: List available services (using grpcurl through docker)
echo "3. Available gRPC services (direct to rpg-api):"
docker run --rm --network rpg-deployment_rpg-network fullstorydev/grpcurl -plaintext rpg-api:50051 list
echo ""

# Test 4: Test a simple gRPC call directly
echo "4. Testing CharacterService directly:"
echo '{"player_id": "test-player"}' | \
  docker run --rm -i --network rpg-deployment_rpg-network fullstorydev/grpcurl \
  -plaintext -d @ \
  rpg-api:50051 dnd5e.api.v1alpha1.CharacterService/ListCharacters
echo ""

# Test 5: Test gRPC-Web through nginx/envoy (this is what we want to work)
echo "5. Testing gRPC-Web through nginx/envoy:"
echo ""

# Create a simple protobuf message for ListCharacters
# The message format: 0x00 (uncompressed flag) + 4 bytes length + protobuf data
# For simplicity, we'll send an empty request which should trigger the "player_id required" error

# Try with empty body first (should get an error about missing player_id)
echo "Testing with empty request (should get player_id error):"
curl -X POST http://localhost/dnd5e.api.v1alpha1.CharacterService/ListCharacters \
  -H 'Content-Type: application/grpc-web+proto' \
  -H 'X-Grpc-Web: 1' \
  --data-binary $'\x00\x00\x00\x00\x00' \
  -s -v 2>&1 | grep -E "(< HTTP|grpc-status|grpc-message)" | head -10

echo ""
echo "=================================================="
echo "If test 5 shows 'grpc-status: 12' with 'unknown service', the routing isn't working."
echo "If it shows 'grpc-status: 3' with 'player ID cannot be empty', the routing IS working!"