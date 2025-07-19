#!/bin/bash
# Startup script to ensure all services are running
# This should be added to systemd or cron @reboot

set -e

echo "Starting RPG services at $(date)"

# Wait for Docker to be ready
for i in {1..30}; do
    if docker info >/dev/null 2>&1; then
        echo "Docker is ready"
        break
    fi
    echo "Waiting for Docker to be ready... ($i/30)"
    sleep 2
done

# Change to deployment directory
cd /opt/rpg-deployment

# Ensure environment file exists
if [ ! -f .env ]; then
    echo "ERROR: .env file not found!"
    exit 1
fi

# Start all services
echo "Starting services with docker-compose..."
docker compose -f docker-compose.prod.yml up -d

# Wait for services to be healthy
echo "Waiting for services to be healthy..."
for i in {1..60}; do
    healthy_count=$(docker ps --filter "name=rpg-" --filter "health=healthy" --format "{{.Names}}" | wc -l)
    total_count=$(docker ps --filter "name=rpg-" --format "{{.Names}}" | wc -l)
    
    echo "Health check $i/60: $healthy_count/$total_count services healthy"
    
    if [ "$healthy_count" -ge 5 ]; then
        echo "✅ Core services are healthy!"
        docker ps --filter "name=rpg-" --format "table {{.Names}}\t{{.Status}}"
        exit 0
    fi
    
    sleep 5
done

echo "❌ Services failed to become healthy after 5 minutes"
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs --tail=50
exit 1