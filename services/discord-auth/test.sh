#!/bin/bash

# Test script for Discord Auth Service

echo "Testing Discord Auth Service..."

# Test health endpoint
echo -n "Health check: "
curl -s http://localhost:8080/health
echo

# Test token endpoint with invalid code (expected to fail)
echo "Testing token exchange with invalid code:"
curl -X POST http://localhost:8080/api/discord/token \
  -H "Content-Type: application/json" \
  -d '{"code":"invalid_test_code"}' \
  -s | jq .

echo
echo "Note: This should fail with Discord API error since we're using a fake code."
echo "In production, the frontend will provide a real authorization code."