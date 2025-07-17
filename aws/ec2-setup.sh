#!/bin/bash
# AWS EC2 Setup Script for RPG Deployment
# Run this on a fresh Amazon Linux 2023 or Ubuntu instance

set -e

echo "🚀 Setting up RPG deployment on AWS EC2..."

# Update system
if command -v yum &> /dev/null; then
    # Amazon Linux 2023
    sudo yum update -y
    sudo yum install -y docker git
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ec2-user
    
    # Install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
elif command -v apt &> /dev/null; then
    # Ubuntu
    sudo apt update
    sudo apt install -y docker.io docker-compose git
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker ubuntu
fi

# Create deployment directory
sudo mkdir -p /opt/rpg-deployment
sudo chown $USER:$USER /opt/rpg-deployment
cd /opt/rpg-deployment

# Clone deployment configuration
git clone https://github.com/YOUR_USERNAME/rpg-deployment.git .

# Create environment file
cat > .env << EOF
# AWS Configuration
AWS_REGION=us-east-1
ENVIRONMENT=production

# Container Registry
REGISTRY=public.ecr.aws/YOUR_REGISTRY
API_IMAGE=rpg-api
WEB_IMAGE=rpg-web

# Application Configuration
API_PORT=50051
WEB_PORT=80
NGINX_PORT=80
EOF

echo "✅ EC2 setup complete!"
echo ""
echo "Next steps:"
echo "1. Log out and back in to apply docker group changes"
echo "2. Run: cd /opt/rpg-deployment && docker-compose up -d"
echo "3. Your app will be available at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"