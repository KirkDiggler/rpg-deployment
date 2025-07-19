#!/bin/bash
# Script to install systemd service for RPG platform

set -e

# Create systemd service file
sudo tee /etc/systemd/system/rpg-platform.service > /dev/null << 'EOF'
[Unit]
Description=RPG Platform Docker Compose Application
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/rpg-deployment
ExecStart=/opt/rpg-deployment/scripts/startup.sh
ExecStop=/usr/bin/docker compose -f /opt/rpg-deployment/docker-compose.prod.yml down
Restart=no
User=ubuntu
Group=ubuntu
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create systemd timer for health monitoring
sudo tee /etc/systemd/system/rpg-health-monitor.timer > /dev/null << 'EOF'
[Unit]
Description=RPG Platform Health Monitor Timer
Requires=rpg-platform.service
After=rpg-platform.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=rpg-health-monitor.service

[Install]
WantedBy=timers.target
EOF

# Create health monitor service
sudo tee /etc/systemd/system/rpg-health-monitor.service > /dev/null << 'EOF'
[Unit]
Description=RPG Platform Health Monitor
Requires=docker.service rpg-platform.service
After=docker.service rpg-platform.service

[Service]
Type=oneshot
ExecStart=/opt/rpg-deployment/scripts/health-monitor.sh
User=ubuntu
Group=ubuntu
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Make scripts executable
chmod +x /opt/rpg-deployment/scripts/startup.sh
chmod +x /opt/rpg-deployment/scripts/health-monitor.sh

# Create log directory
sudo mkdir -p /var/log
sudo touch /var/log/rpg-health-monitor.log
sudo chown ubuntu:ubuntu /var/log/rpg-health-monitor.log

# Reload systemd
sudo systemctl daemon-reload

# Enable services
sudo systemctl enable rpg-platform.service
sudo systemctl enable rpg-health-monitor.timer

echo "✅ Systemd services installed successfully!"
echo ""
echo "To start the platform:"
echo "  sudo systemctl start rpg-platform"
echo ""
echo "To check status:"
echo "  sudo systemctl status rpg-platform"
echo "  sudo systemctl status rpg-health-monitor.timer"
echo ""
echo "To view logs:"
echo "  journalctl -u rpg-platform -f"
echo "  journalctl -u rpg-health-monitor -f"