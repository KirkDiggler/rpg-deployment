#!/bin/bash

echo "🧪 Testing Discord Auth Service CORS Headers"
echo "==========================================="

# Test health endpoint
echo -e "\n1. Testing health endpoint:"
curl -i -X GET http://localhost:8080/health

# Test OPTIONS preflight request
echo -e "\n\n2. Testing CORS preflight (OPTIONS):"
curl -i -X OPTIONS http://localhost:8080/api/discord/token \
  -H "Origin: http://localhost:5173" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type"

# Test POST request
echo -e "\n\n3. Testing POST request with CORS:"
curl -i -X POST http://localhost:8080/api/discord/token \
  -H "Content-Type: application/json" \
  -H "Origin: http://localhost:5173" \
  -d '{"code":"test_code"}'

echo -e "\n\n✅ Test complete!"