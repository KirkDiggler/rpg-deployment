#!/bin/bash

echo "Testing gRPC-Web exactly like deployed environment"
echo "=================================================="
echo ""

# Test with application/json like you do in deployed
echo "1. Testing with application/json (like your deployed tests):"
curl -X POST http://localhost/api.v1alpha1.DiceService/RollDice \
    -H "Content-Type: application/json" \
    -d '{"entity_id":"test","context":"test","notation":"1d20"}' \
    -s -v 2>&1 | grep -E "(< HTTP|grpc-status|grpc-message|result|notation)" | head -10

echo ""
echo "2. Testing with application/grpc-web-text:"
# Create base64 encoded JSON for grpc-web-text
echo '{"entity_id":"test","context":"test","notation":"1d20"}' | base64 -w0 > /tmp/grpc-request.txt
curl -X POST http://localhost/api.v1alpha1.DiceService/RollDice \
    -H "Content-Type: application/grpc-web-text" \
    --data-binary @/tmp/grpc-request.txt \
    -s -v 2>&1 | grep -E "(< HTTP|grpc-status|grpc-message|result)" | head -10

echo ""
echo "3. Testing CharacterService with application/json:"
curl -X POST http://localhost/dnd5e.api.v1alpha1.CharacterService/ListCharacters \
    -H "Content-Type: application/json" \
    -d '{"player_id":"test-player"}' \
    -s -v 2>&1 | grep -E "(< HTTP|grpc-status|grpc-message|characters)" | head -10

echo ""
echo "=================================================="
echo "The deployed envoy might have additional configuration"
echo "or there might be a transcoding proxy in front of it."