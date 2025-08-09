#!/bin/bash
# Manual cleanup script for emergency disk space recovery
# This can be run when the server is critically low on space

set -e

echo "======================================"
echo "EMERGENCY Docker Cleanup - $(date)"
echo "======================================"

# Show current disk usage
echo "Current disk usage:"
df -h / | grep -E "^/|Filesystem"
echo ""

# More aggressive cleanup for emergency situations
echo "WARNING: This will perform aggressive cleanup!"
echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
sleep 5

# Stop all containers first (except critical system containers)
echo "Stopping RPG containers..."
docker compose -f /opt/rpg-deployment/docker-compose.prod.yml down || true
echo ""

# Remove ALL stopped containers
echo "Removing ALL stopped containers..."
docker container prune -f
echo ""

# Remove ALL unused images (no time filter)
echo "Removing ALL unused images..."
docker image prune -a -f
echo ""

# Remove ALL unused volumes
echo "Removing ALL unused volumes..."
docker volume prune -f
echo ""

# Remove ALL unused networks
echo "Removing ALL unused networks..."
docker network prune -f
echo ""

# Remove ALL build cache
echo "Removing ALL build cache..."
docker builder prune -a -f
echo ""

# Final aggressive cleanup
echo "Running final aggressive system cleanup..."
docker system prune -a -f --volumes
echo ""

# Clear package manager cache
echo "Clearing system package cache..."
if [ -f /etc/redhat-release ]; then
    # For RHEL/CentOS/Amazon Linux
    yum clean all
elif [ -f /etc/debian_version ]; then
    # For Debian/Ubuntu
    apt-get clean
    apt-get autoclean
fi
echo ""

# Clear journal logs older than 2 days
echo "Clearing old journal logs..."
journalctl --vacuum-time=2d 2>/dev/null || true
echo ""

# Show disk usage after cleanup
echo "Disk usage after cleanup:"
df -h / | grep -E "^/|Filesystem"
echo ""

echo "======================================"
echo "Emergency cleanup completed!"
echo "You can now restart services with:"
echo "  cd /opt/rpg-deployment"
echo "  docker compose -f docker-compose.prod.yml up -d"
echo "======================================"