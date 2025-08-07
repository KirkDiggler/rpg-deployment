#!/bin/bash

# Test script for character creation API endpoints
# These are the first endpoints typically used in character creation

echo "=================================================="
echo "RPG Character API Test Script"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to test an endpoint
test_endpoint() {
    local endpoint=$1
    local description=$2
    local base64_data=$3
    
    echo "Testing: $description"
    echo "Endpoint: $endpoint"
    
    if [ -z "$base64_data" ]; then
        # Empty request for list endpoints
        base64_data="AAAAAAA="
    fi
    
    # Send request and capture response
    response=$(echo -n "$base64_data" | \
        curl -X POST "http://localhost/$endpoint" \
        -H "Content-Type: application/grpc-web-text" \
        --data-binary @- \
        -s -i 2>&1)
    
    # Check if we got a successful response
    if echo "$response" | grep -q "HTTP/1.1 200 OK"; then
        echo -e "${GREEN}✓ Success${NC}"
        
        # Check for grpc-status
        grpc_status=$(echo "$response" | grep "grpc-status:" | cut -d' ' -f2)
        grpc_message=$(echo "$response" | grep "grpc-message:" | cut -d' ' -f2-)
        
        if [ -n "$grpc_status" ] && [ "$grpc_status" != "0" ]; then
            echo "  grpc-status: $grpc_status"
            echo "  grpc-message: $grpc_message"
        else
            # Try to decode response to see if we got data
            response_body=$(echo "$response" | tail -1)
            if [ -n "$response_body" ] && [ "$response_body" != "" ]; then
                # Response is base64 encoded, let's check its size
                decoded_size=$(echo -n "$response_body" | base64 -d 2>/dev/null | wc -c)
                if [ $decoded_size -gt 5 ]; then
                    echo -e "  ${GREEN}Response received: $decoded_size bytes of data${NC}"
                    
                    # Try to extract some readable text from the response
                    echo -n "$response_body" | base64 -d 2>/dev/null | strings | head -3 | sed 's/^/  > /'
                fi
            fi
        fi
    else
        echo -e "${RED}✗ Failed${NC}"
        http_status=$(echo "$response" | grep "HTTP/1.1" | head -1)
        echo "  $http_status"
    fi
    
    echo ""
}

# Test 1: ListRaces - Character creation typically starts with race selection
echo "1. CHARACTER CREATION - RACES"
echo "------------------------------"
test_endpoint "dnd5e.api.v1alpha1.CharacterService/ListRaces" "List all available races"

# Test 2: ListClasses - Next step is usually class selection
echo "2. CHARACTER CREATION - CLASSES"
echo "--------------------------------"
test_endpoint "dnd5e.api.v1alpha1.CharacterService/ListClasses" "List all available classes"

# Test 3: ListBackgrounds - Then background selection
echo "3. CHARACTER CREATION - BACKGROUNDS"
echo "------------------------------------"
test_endpoint "dnd5e.api.v1alpha1.CharacterService/ListBackgrounds" "List all available backgrounds"

# Test 4: RollDice - For ability score generation
echo "4. DICE ROLLING"
echo "----------------"
# Base64 for: entity_id="test", context="ability-scores", notation="4d6kh3"
# This is the standard D&D 5e ability score roll (4d6 keep highest 3)
test_endpoint "api.v1alpha1.DiceService/RollDice" \
    "Roll for ability scores (4d6 keep highest 3)" \
    "AAAAABoKBHRlc3QSDHF0aWxpdHktc2NvcmVzGgY0ZDZraDM="

# Test 5: CreateCharacterDraft - Start a new character
echo "5. CHARACTER DRAFT"
echo "-------------------"
# Base64 for: player_id="test-player"
# Field 1 (player_id): 0x0a + length (0x0b=11) + "test-player"
printf '\x0a\x0btest-player' > /tmp/draft_msg.bin
# Create gRPC frame
printf '\x00\x00\x00\x00\x0d' > /tmp/draft_frame.bin  # 0x0d = 13 bytes
cat /tmp/draft_msg.bin >> /tmp/draft_frame.bin
draft_base64=$(base64 -w0 /tmp/draft_frame.bin)
test_endpoint "dnd5e.api.v1alpha1.CharacterService/CreateCharacterDraft" \
    "Create a new character draft" \
    "$draft_base64"

# Test 6: ListCharacters - Check existing characters
echo "6. LIST CHARACTERS"
echo "-------------------"
# Same as draft - just player_id
test_endpoint "dnd5e.api.v1alpha1.CharacterService/ListCharacters" \
    "List player's characters" \
    "$draft_base64"

echo "=================================================="
echo "SUMMARY"
echo "=================================================="

# Quick connectivity test
if curl -s http://localhost/health | grep -q "healthy"; then
    echo -e "${GREEN}✓ Nginx is healthy${NC}"
else
    echo -e "${RED}✗ Nginx is not responding${NC}"
fi

# Test if services are registered
echo ""
echo "Available gRPC services (via direct connection):"
docker run --rm --network rpg-deployment_rpg-network fullstorydev/grpcurl \
    -plaintext rpg-api:50051 list 2>/dev/null | head -10

echo ""
echo "=================================================="
echo "To test with the web app:"
echo "1. Keep this stack running"
echo "2. cd /home/kirk/personal/rpg-dnd5e-web"
echo "3. npm run dev"
echo "4. Open http://localhost:5173"
echo "=================================================="