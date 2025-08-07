#!/bin/bash

# Simple test script for RPG API endpoints
# Tests the most common character creation endpoints

echo "=================================================="
echo "RPG API Quick Test"
echo "=================================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Base URL
BASE_URL="http://localhost"

echo -e "${BLUE}Testing Character Creation Endpoints...${NC}"
echo ""

# Test 1: ListRaces (empty request)
echo "1. ListRaces - Get available races:"
echo -n "AAAAAAA=" | \
curl -X POST "$BASE_URL/dnd5e.api.v1alpha1.CharacterService/ListRaces" \
    -H "Content-Type: application/grpc-web-text" \
    --data-binary @- \
    -s -i 2>&1 | head -20 | grep -E "(HTTP|grpc-status|grpc-message|Content-Length)"

echo ""
echo "----------------------------------------"

# Test 2: ListClasses (empty request)  
echo "2. ListClasses - Get available classes:"
echo -n "AAAAAAA=" | \
curl -X POST "$BASE_URL/dnd5e.api.v1alpha1.CharacterService/ListClasses" \
    -H "Content-Type: application/grpc-web-text" \
    --data-binary @- \
    -s -i 2>&1 | head -20 | grep -E "(HTTP|grpc-status|grpc-message|Content-Length)"

echo ""
echo "----------------------------------------"

# Test 3: RollDice with correct format
echo "3. RollDice - Roll a d20:"
# Create proper protobuf: entity_id="test", context="test", notation="1d20"
echo -n "AAAAABIKBHRlc3QSBHRlc3QaBDFkMjA=" | \
curl -X POST "$BASE_URL/api.v1alpha1.DiceService/RollDice" \
    -H "Content-Type: application/grpc-web-text" \
    --data-binary @- \
    -s -i 2>&1 | head -15 | grep -E "(HTTP|grpc-status|Transfer-Encoding)"

echo ""
echo "----------------------------------------"

# Test 4: CreateDraft - Start a new character
echo "4. CreateDraft - Create character draft:"
# Create protobuf with player_id="test-player"
printf '\x0a\x0btest-player' > /tmp/player.bin
printf '\x00\x00\x00\x00\x0d' > /tmp/frame.bin
cat /tmp/player.bin >> /tmp/frame.bin
base64 -w0 /tmp/frame.bin | \
curl -X POST "$BASE_URL/dnd5e.api.v1alpha1.CharacterService/CreateDraft" \
    -H "Content-Type: application/grpc-web-text" \
    --data-binary @- \
    -s -i 2>&1 | head -15 | grep -E "(HTTP|grpc-status|grpc-message|Transfer-Encoding)"

echo ""
echo "----------------------------------------"

# Test 5: ListCharacters with player_id
echo "5. ListCharacters - List player's characters:"
base64 -w0 /tmp/frame.bin | \
curl -X POST "$BASE_URL/dnd5e.api.v1alpha1.CharacterService/ListCharacters" \
    -H "Content-Type: application/grpc-web-text" \
    --data-binary @- \
    -s -i 2>&1 | head -15 | grep -E "(HTTP|grpc-status|grpc-message|Transfer-Encoding)"

echo ""
echo "=================================================="
echo -e "${BLUE}Quick Status Check:${NC}"
echo ""

# Check if services are healthy
if curl -s "$BASE_URL/health" | grep -q "healthy"; then
    echo -e "${GREEN}✓ Nginx proxy: OK${NC}"
else
    echo -e "${RED}✗ Nginx proxy: FAILED${NC}"
fi

# Check if we can reach the API
if echo -n "AAAAAAA=" | curl -s -X POST "$BASE_URL/api.v1alpha1.DiceService/RollDice" -H "Content-Type: application/grpc-web-text" --data-binary @- | grep -q "entity_id"; then
    echo -e "${GREEN}✓ gRPC-Web routing: OK${NC}"
else
    echo -e "${RED}✗ gRPC-Web routing: FAILED${NC}"
fi

# Check DND API
if curl -s "http://localhost:3002/api/2014/classes" | grep -q "Barbarian"; then
    echo -e "${GREEN}✓ DND API: OK${NC}"
else
    echo -e "${RED}✗ DND API: FAILED${NC}"
fi

echo ""
echo "=================================================="
echo -e "${BLUE}Interpretation:${NC}"
echo "- HTTP 200 with grpc-status: 0 = Success with data"
echo "- HTTP 200 with grpc-status: 3 = Invalid argument" 
echo "- HTTP 200 with grpc-status: 12 = Unimplemented"
echo "- HTTP 504 = Gateway timeout (service unreachable)"
echo ""
echo "If you see 'Transfer-Encoding: chunked', you're getting data!"
echo "==================================================">