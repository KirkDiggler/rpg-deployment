#!/bin/bash
# Health monitoring script to ensure services stay healthy
# Run this via cron every 5 minutes

set -e

LOG_FILE="/var/log/rpg-health-monitor.log"
RESTART_THRESHOLD=3

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Change to deployment directory
cd /opt/rpg-deployment

# Check if docker-compose is managing our services
if ! docker compose -f docker-compose.prod.yml ps >/dev/null 2>&1; then
    log "ERROR: Docker Compose not running. Starting services..."
    /opt/rpg-deployment/scripts/startup.sh
    exit 0
fi

# Check each service
unhealthy_services=""
for service in redis rpg-api envoy discord-auth rpg-web nginx; do
    container_name="rpg-${service}"
    if [ "$service" = "discord-auth" ]; then
        container_name="rpg-discord-auth"
    fi
    
    # Check if container exists and is running
    if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        log "WARNING: ${container_name} is not running"
        unhealthy_services="${unhealthy_services} ${service}"
        continue
    fi
    
    # Check health status for containers with health checks
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "${container_name}" 2>/dev/null || echo "none")
    
    if [ "$health_status" = "unhealthy" ]; then
        log "WARNING: ${container_name} is unhealthy"
        unhealthy_services="${unhealthy_services} ${service}"
    fi
done

# If services are unhealthy, try to restart them
if [ -n "$unhealthy_services" ]; then
    log "Unhealthy services detected:${unhealthy_services}"
    
    for service in $unhealthy_services; do
        log "Restarting ${service}..."
        docker compose -f docker-compose.prod.yml restart "${service}"
    done
    
    # Wait for services to recover
    sleep 30
    
    # Check again
    still_unhealthy=""
    for service in $unhealthy_services; do
        container_name="rpg-${service}"
        if [ "$service" = "discord-auth" ]; then
            container_name="rpg-discord-auth"
        fi
        
        if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
            still_unhealthy="${still_unhealthy} ${service}"
        fi
    done
    
    if [ -n "$still_unhealthy" ]; then
        log "ERROR: Services still unhealthy after restart:${still_unhealthy}"
        log "Attempting full restart..."
        docker compose -f docker-compose.prod.yml down
        docker compose -f docker-compose.prod.yml up -d
    else
        log "Services recovered after restart"
    fi
else
    # Only log every hour when everything is healthy
    if [ "$(date +%M)" = "00" ]; then
        log "All services healthy"
    fi
fi