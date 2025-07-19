# RPG Deployment Stack

[![Deploy RPG Platform](https://github.com/KirkDiggler/rpg-deployment/actions/workflows/deploy.yml/badge.svg)](https://github.com/KirkDiggler/rpg-deployment/actions/workflows/deploy.yml)
[![Infrastructure Status](https://img.shields.io/badge/infrastructure-aws--cloudformation-orange)](https://aws.amazon.com/cloudformation/)
[![Deployment Method](https://img.shields.io/badge/deployment-github--actions--ssm-blue)](https://docs.aws.amazon.com/systems-manager/)

Complete deployment pipeline for the RPG gaming platform with modular architecture.

## 🏗️ Components

- **rpg-api**: Go gRPC server (separate repository)
- **rpg-dnd5e-web**: React frontend (separate repository)
- **rpg-deployment**: This orchestration repository
- **nginx**: Load balancer with automatic SSL via Let's Encrypt
- **envoy**: gRPC-Web proxy for browser compatibility
- **redis**: In-memory data store for session and character data

## 🚀 Quick Start (Automated GitHub Actions)

### Prerequisites

1. **GitHub repository** forked/cloned
2. **AWS account** with appropriate permissions
3. **GitHub Secrets** configured (see setup below)

### 1. Configure GitHub Secrets

Set these secrets in your GitHub repository settings:

**AWS Secrets:**
```bash
AWS_ACCESS_KEY_ID=your-aws-access-key
AWS_SECRET_ACCESS_KEY=your-aws-secret-key
AWS_KEY_PAIR_NAME=your-ec2-key-pair-name
```

**Discord OAuth Secrets:**
```bash
VITE_DISCORD_CLIENT_ID=your-discord-client-id   # Used for both frontend and backend
DISCORD_CLIENT_SECRET=your-discord-client-secret # From Discord Developer Portal (OAuth2 section)
```

**Optional:**
```bash
GH_TOKEN=github-token-for-private-repos  # If using private repos
DOMAIN_NAME=your-domain.com              # For SSL certificates
SSL_EMAIL=your-email@example.com         # For Let's Encrypt
```

### 2. Deploy via GitHub Actions

**Automatic deployment on every push to main:**
```bash
git push origin main
# ✅ GitHub Actions will automatically:
# 1. Build Docker images for rpg-api and rpg-dnd5e-web
# 2. Push to GitHub Container Registry
# 3. Deploy AWS infrastructure (if needed)
# 4. Deploy applications via AWS Systems Manager (no SSH!)
```

**Manual deployment:**
- Go to GitHub Actions → "Deploy RPG Platform" → "Run workflow"

### 3. Manual Deployment (Legacy)

<details>
<summary>Click to expand manual deployment instructions</summary>

#### Prerequisites
1. **AWS CLI configured** with your credentials
2. **EC2 Key Pair** for SSH access
3. **Git** installed locally

#### Steps
```bash
# Clone this repository
git clone <rpg-deployment-repo>
cd rpg-deployment

# Verify AWS access
aws sts get-caller-identity

# Create or use existing EC2 key pair
aws ec2 create-key-pair --key-name rpg-server --query 'KeyMaterial' --output text > ~/.ssh/rpg-server.pem
chmod 400 ~/.ssh/rpg-server.pem

# Set your key pair name
export KEY_PAIR_NAME=rpg-server

# Make script executable
chmod +x aws/deploy-aws.sh

# Deploy everything (takes ~5-10 minutes)
./aws/deploy-aws.sh
```
</details>

### 3. Access Your Application

After deployment completes, GitHub Actions will show you:
- **Application URL**: `http://YOUR-IP` (React frontend with Discord SDK)
- **API Endpoint**: `http://YOUR-IP/api/` (gRPC-Web via Envoy proxy)
- **Health Check**: `http://YOUR-IP/health`
- **Deployment Status**: Check the Actions tab for real-time progress

**For SSL/HTTPS Setup**: See [SSL_SETUP.md](SSL_SETUP.md) for automatic Let's Encrypt configuration

## 🔄 How It All Works

### The Complete Workflow

**1. Code Changes**
```bash
# Developer workflow - make changes to rpg-api or rpg-dnd5e-web
cd path/to/rpg-api
# Make your changes...
git commit -m "Add new feature"
git push origin main

# Or for the web app
cd path/to/rpg-dnd5e-web  
# Make your changes...
git commit -m "Update UI"
git push origin main
```

**2. Trigger Deployment**
```bash
# Update the deployment repo to trigger a deploy
cd path/to/rpg-deployment
git commit -m "Deploy latest changes" --allow-empty
git push origin main
# 🚀 This triggers the full deployment pipeline!
```

**3. GitHub Actions Pipeline**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  📦 BUILD JOBS  │    │  🚀 DEPLOY JOB  │    │  ✅ HEALTH CHK  │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ Checkout repos  │ -> │ AWS CloudForm   │ -> │ Verify app      │
│ Build API image │    │ Deploy via SSM  │    │ Update badges   │
│ Build Web image │    │ Health checks   │    │ Schedule mon.   │
│ Push to GHCR    │    │ Status reports  │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         |                       |                       |
    5-10 minutes            10-15 minutes             ongoing
```

**4. What Happens on AWS**
```bash
# GitHub Actions runs these commands on your EC2 instance via SSM:
# (No SSH required!)

cd /opt/rpg-deployment
git pull origin main                    # Get latest deployment config
docker-compose -f docker-compose.prod.yml pull  # Pull new images
docker-compose -f docker-compose.prod.yml down  # Stop old containers
docker-compose -f docker-compose.prod.yml up -d # Start new containers

# Your updated application is now live! 🎉
```

## 🏛️ Architecture

### Development Architecture
```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   rpg-api repo      │    │  rpg-dnd5e-web repo │    │ rpg-deployment repo │
│                     │    │                     │    │                     │
│ ├── Dockerfile      │    │ ├── Dockerfile      │    │ ├── docker-compose  │
│ ├── Go source code  │    │ ├── React source    │    │ ├── nginx config    │
│ └── Tests          │    │ └── Tests          │    │ └── AWS CloudForm   │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

### Runtime Architecture
```
┌─────────────────────────────────────────┐
│                AWS VPC                   │
│  ┌─────────────────────────────────────┐ │
│  │          Public Subnet              │ │
│  │  ┌─────────────────────────────────┐│ │
│  │  │        EC2 Instance             ││ │
│  │  │                                 ││ │
│  │  │  ┌──────────┐ ┌──────────────┐  ││ │
│  │  │  │   nginx  │ │  Docker      │  ││ │
│  │  │  │   :80    │ │  Compose     │  ││ │
│  │  │  └──────────┘ │              │  ││ │
│  │  │        ↓      │ ┌──────────┐ │  ││ │
│  │  │     Routes    │ │ rpg-api  │ │  ││ │
│  │  │   /api/* →    │ │ :50051   │ │  ││ │
│  │  │   /* →        │ └────┬─────┘ │  ││ │
│  │  │               │      │ gRPC  │  ││ │
│  │  │               │ ┌────▼─────┐ │  ││ │
│  │  │               │ │  envoy   │ │  ││ │
│  │  │               │ │ :8080    │ │  ││ │
│  │  │               │ └──────────┘ │  ││ │
│  │  │               │ ┌──────────┐ │  ││ │
│  │  │               │ │  redis   │ │  ││ │
│  │  │               │ │ :6379    │ │  ││ │
│  │  │               │ └─────▲────┘ │  ││ │
│  │  │               │       │data  │  ││ │
│  │  │               │ ┌─────┴────┐ │  ││ │
│  │  │               │ │ rpg-web  │ │  ││ │
│  │  │               │ │ :80      │ │  ││ │
│  │  │               │ └──────────┘ │  ││ │
│  │  │               └──────────────┘  ││ │
│  │  └─────────────────────────────────┘│ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘

GitHub Actions Pipeline:
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Checkout  │ -> │    Build    │ -> │   Deploy    │
│ rpg-api &   │    │   Docker    │    │   via SSM   │
│ rpg-web     │    │   Images    │    │  (no SSH)   │
└─────────────┘    └─────────────┘    └─────────────┘
```

## 💰 Cost Breakdown

### AWS Free Tier (First 12 months)
- **EC2 t3.micro**: 750 hours/month = FREE
- **EBS Storage**: 30GB = FREE  
- **Data Transfer**: 15GB out = FREE
- **CloudFormation**: FREE
- **Total**: $0/month 🎉

### After Free Tier
- **EC2 t3.micro**: ~$8.50/month
- **EBS Storage**: ~$3/month (30GB)
- **Elastic IP**: FREE (when attached)
- **Data Transfer**: $0.09/GB after 15GB
- **Total**: ~$11-15/month for low traffic

## 🔧 Development Workflow

### Working on Individual Services

```bash
# API Development
cd path/to/rpg-api
# Make changes, test with: make pre-commit
git commit && git push
# ✅ Ready for deployment!

# Frontend Development
cd path/to/rpg-dnd5e-web
# Make changes, test with: npm run dev
git commit && git push
# ✅ Ready for deployment!

# Each service is completely independent
```

### Testing Full Stack Locally

```bash
cd path/to/rpg-deployment

# Build and run both apps + nginx + envoy
docker-compose up -d

# View at:
# http://localhost          <- React app (Discord SDK)
# http://localhost/api      <- gRPC-Web via Envoy
# http://localhost/health   <- Health check

# View logs
docker-compose logs -f rpg-api    # gRPC server logs
docker-compose logs -f rpg-envoy  # Envoy proxy logs
docker-compose logs -f rpg-web    # React app logs
docker-compose logs -f rpg-nginx  # Load balancer logs
docker-compose logs -f redis      # Redis data store logs

# Connect to Redis for debugging (local dev only)
docker exec -it rpg-redis-dev redis-cli
# Redis commands: KEYS *, GET key, INFO, MONITOR
```

### Deploying Updates

#### ✅ Automatic (Recommended)
```bash
# Trigger deployment (builds latest from all repos)
cd path/to/rpg-deployment
git commit -m "Deploy latest changes" --allow-empty
git push origin main
# 🚀 GitHub Actions handles everything!
```

#### Manual (For debugging only)
```bash
# Connect via SSM Session Manager (no SSH keys needed!)
aws ssm start-session --target $(aws cloudformation describe-stacks \
  --stack-name rpg-gaming-platform \
  --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
  --output text)

# Check container status
docker-compose -f /opt/rpg-deployment/docker-compose.prod.yml ps
```

## 🛠️ Management Commands

### 📊 Monitoring & Health Checks

```bash
# Check deployment status
# 🔗 https://github.com/KirkDiggler/rpg-deployment/actions

# Get application URL
aws cloudformation describe-stacks \
  --stack-name rpg-gaming-platform \
  --query 'Stacks[0].Outputs[?OutputKey==`ApplicationURL`].OutputValue' \
  --output text

# Manual health check
curl http://YOUR-IP/health
# Should return: "healthy"

# Test API endpoint (gRPC-Web)
curl -H "Content-Type: application/grpc-web+proto" http://YOUR-IP/api/health
```

### 🖥️ Server Access (SSM Session Manager)

```bash
# Connect to server (no SSH keys required!)
aws ssm start-session --target $(aws cloudformation describe-stacks \
  --stack-name rpg-gaming-platform \
  --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
  --output text)

# Once connected, check container status
sudo -u ec2-user -i
cd /opt/rpg-deployment
docker-compose -f docker-compose.prod.yml ps
docker-compose -f docker-compose.prod.yml logs --tail=50

# Check resource usage
docker stats --no-stream
```

### ☁️ AWS Management
```bash
# View CloudFormation stack
aws cloudformation describe-stacks --stack-name rpg-gaming-platform

# Check EC2 instance health
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=production-rpg-server" \
  --query 'Reservations[0].Instances[0].State'

# View recent SSM commands (deployments)
aws ssm describe-instance-information \
  --filters "Key=tag:Name,Values=production-rpg-server"

# Check costs (current month)
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "1 month ago" +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost
```

## 🔍 Troubleshooting

### 🚨 GitHub Actions Issues

#### 1. "Deployment failed" 
```bash
# Check GitHub Actions logs
# 🔗 https://github.com/KirkDiggler/rpg-deployment/actions

# Common fixes:
# ✅ Verify GitHub Secrets are set correctly
# ✅ Check AWS credentials have proper permissions
# ✅ Ensure EC2 key pair exists in AWS
```

#### 2. "Images failed to build"
```bash
# Verify source repositories are accessible
# ✅ Check GH_TOKEN has access to rpg-api and rpg-dnd5e-web repos
# ✅ Ensure Dockerfiles exist in source repos
# ✅ Check for any build errors in the source code
```

#### 3. "SSM deployment timeout"
```bash
# Check EC2 instance status
aws ec2 describe-instances --filters "Name=tag:Name,Values=production-rpg-server"

# Verify SSM agent is running
aws ssm describe-instance-information \
  --filters "Key=tag:Name,Values=production-rpg-server"

# If instance is stopped, start it:
aws ec2 start-instances --instance-ids INSTANCE-ID
```

### 🐳 Application Issues

#### 1. Application not responding
```bash
# Get current deployment status
aws ssm list-command-invocations \
  --filters key=InstanceId,value=INSTANCE-ID \
  --details

# Connect via SSM and check containers
aws ssm start-session --target INSTANCE-ID
# Then: docker-compose -f /opt/rpg-deployment/docker-compose.prod.yml ps
```

#### 2. gRPC-Web not working
```bash
# Check Envoy proxy logs
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["docker-compose -f /opt/rpg-deployment/docker-compose.prod.yml logs rpg-envoy"]' \
  --targets "Key=tag:Name,Values=production-rpg-server"

# Verify routing: nginx -> envoy -> rpg-api
curl -v http://YOUR-IP/api/health
```

#### 3. Container health checks failing
```bash
# Check individual service health
curl http://YOUR-IP/health              # nginx health
curl http://YOUR-IP:8080/ready          # envoy health (if exposed)

# View all container statuses
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["docker ps --format \"table {{.Names}}\t{{.Status}}\t{{.Ports}}\""]' \
  --targets "Key=tag:Name,Values=production-rpg-server"
```

### 🏥 Health Monitoring

```bash
# Automated health checks run every 30 minutes
# 🔗 https://github.com/KirkDiggler/rpg-deployment/actions/workflows/health-check.yml

# Manual health verification
curl -f http://YOUR-IP/health && echo "✅ Healthy" || echo "❌ Unhealthy"

# Full stack test
curl -f http://YOUR-IP && echo "✅ Frontend OK"
curl -f -H "Content-Type: application/grpc-web+proto" http://YOUR-IP/api/ && echo "✅ API OK"
```

## 🔐 Security Considerations

### Network Security
- VPC with public subnet (private subnet for future database)
- Security Group allows only HTTP (80), HTTPS (443), and SSH (22)
- Elastic IP prevents IP changes

### Application Security
- nginx security headers enabled
- CORS configured for API access
- Rate limiting configured

### Access Security
- SSH key-based authentication only
- IAM roles for AWS service access
- CloudWatch logging enabled

## 📈 Scaling Options

### Vertical Scaling (Immediate)
```bash
# Update CloudFormation with larger instance type
./aws/deploy-aws.sh --instance-type t3.small
```

### Horizontal Scaling (Future)
The infrastructure is designed to easily add:
- Application Load Balancer
- Auto Scaling Groups
- Multiple AZ deployment
- RDS database
- Redis cache

### Database Integration
```yaml
# Add to docker-compose.yml when needed
postgres:
  image: postgres:15
  environment:
    POSTGRES_DB: rpg_db
    POSTGRES_USER: rpg_user
    POSTGRES_PASSWORD: ${DB_PASSWORD}
  volumes:
    - postgres_data:/var/lib/postgresql/data

redis:
  image: redis:alpine
  volumes:
    - redis_data:/data
```

## 🧹 Cleanup

### Remove Everything
```bash
# Delete CloudFormation stack (removes all AWS resources)
aws cloudformation delete-stack --stack-name rpg-gaming-platform

# This removes:
# - EC2 instance
# - VPC and networking  
# - Security groups
# - Elastic IP
# - IAM roles
```

### Partial Cleanup
```bash
# Just stop applications (keep infrastructure)
ssh -i ~/.ssh/rpg-server.pem ec2-user@YOUR-IP
docker-compose down

# Remove unused Docker images
docker system prune -a
```

## 📚 Additional Resources

- **SSL Setup Guide**: [SSL_SETUP.md](SSL_SETUP.md) - Automatic Let's Encrypt SSL configuration
- **AWS Documentation**: [CloudFormation User Guide](https://docs.aws.amazon.com/cloudformation/)
- **Docker Compose**: [Official Documentation](https://docs.docker.com/compose/)
- **nginx Configuration**: [nginx.org](https://nginx.org/en/docs/)

## 🎯 Why This Architecture?

### Modular Design
- **Independent repositories** for each service
- **Separate development** and deployment cycles
- **Easy testing** of individual components

### Cost Effective
- **Free tier eligible** for first year
- **Single server** for low traffic
- **No managed service overhead**

### AWS Native
- **CloudFormation** for infrastructure
- **EC2** for compute (familiar, flexible)
- **VPC** for network isolation
- **CloudWatch** for monitoring

### Scalable Foundation
- Easy to add load balancers
- Database-ready architecture
- Monitoring and logging built-in
- CI/CD pipeline ready

---

## 🚀 Get Started

1. **Fork this repository** and configure GitHub Secrets
2. **Push to main branch** - GitHub Actions handles everything!
3. **Monitor deployment** in the Actions tab
4. **Access your application** at the provided URL

Your modular RPG platform will be live in ~15 minutes! 🎮

## ✨ What Makes This Deployment Special

### 🎯 Zero SSH Required
- **AWS Systems Manager** handles all remote commands
- **No SSH keys to manage** or secure
- **Session Manager** for emergency access

### 🤖 Fully Automated CI/CD
- **Push to deploy** - no manual steps
- **Multi-architecture builds** (AMD64 + ARM64)
- **Health monitoring** with status badges
- **Rollback capability** via git revert

### 🏗️ Production-Ready Architecture
- **Load balancer** (nginx) with rate limiting and automatic SSL
- **gRPC-Web proxy** (Envoy) for browser compatibility
- **Container orchestration** with health checks
- **Resource monitoring** and cost tracking

### 🎮 RPG Gaming Optimized
- **Discord SDK integration** ready
- **Real-time gRPC communication** via WebSocket fallback
- **Character management** API endpoints
- **Game session handling** with persistent state

### 💰 Cost Effective
- **AWS Free Tier eligible** (first year)
- **Single instance deployment** for MVP
- **Scales horizontally** when needed
- **Infrastructure as Code** for easy replication

---

**Ready to deploy your RPG platform?** Just push to main! 🚀