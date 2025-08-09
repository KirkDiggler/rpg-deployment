#!/bin/bash
# Docker cleanup script to free up disk space before deployment
# This script removes unused Docker resources while preserving running containers

set -e

echo "======================================"
echo "Docker Cleanup - $(date)"
echo "======================================"

# Show disk usage before cleanup
echo "Disk usage before cleanup:"
df -h / | grep -E "^/|Filesystem"
echo ""

# Show Docker disk usage
echo "Docker disk usage before cleanup:"
docker system df
echo ""

# Stop all containers except those that are currently running critical services
echo "Preserving running containers..."
RUNNING_CONTAINERS=$(docker ps -q)
if [ -n "$RUNNING_CONTAINERS" ]; then
    echo "Running containers that will be preserved:"
    docker ps --format "table {{.Names}}\t{{.Status}}"
fi
echo ""

# Remove stopped containers
echo "Removing stopped containers..."
docker container prune -f
echo ""

# Remove unused images (keeping those used by running containers)
echo "Removing unused images..."
docker image prune -a -f --filter "until=24h"
echo ""

# Remove unused volumes (be careful with this one!)
echo "Removing unused volumes..."
docker volume prune -f
echo ""

# Remove unused networks
echo "Removing unused networks..."
docker network prune -f
echo ""

# Remove build cache
echo "Removing build cache..."
docker builder prune -f
echo ""

# Final cleanup with system prune (excluding volumes by default)
echo "Running final system cleanup..."
docker system prune -f
echo ""

# Show disk usage after cleanup
echo "Disk usage after cleanup:"
df -h / | grep -E "^/|Filesystem"
echo ""

echo "Docker disk usage after cleanup:"
docker system df
echo ""

# Calculate space freed
AFTER_AVAILABLE=$(df / | awk 'NR==2 {print $4}')
echo "======================================"
echo "Cleanup completed successfully!"
echo "Available space: ${AFTER_AVAILABLE}K"
echo "======================================"