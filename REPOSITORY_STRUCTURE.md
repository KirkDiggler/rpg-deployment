# RPG Deployment Repository Structure

This repository contains everything needed to deploy your RPG platform to AWS using GitHub Actions.

## 📁 File Structure

```
rpg-deployment/
├── README.md                    # Main documentation and usage guide
├── SETUP.md                     # Step-by-step setup instructions
├── LICENSE                      # MIT license
├── .gitignore                   # Git ignore patterns
├── REPOSITORY_STRUCTURE.md      # This file
│
├── .github/workflows/           # GitHub Actions CI/CD
│   ├── deploy.yml              # Main deployment pipeline
│   └── health-check.yml        # Automated health monitoring
│
├── aws/                        # AWS Infrastructure
│   ├── README-AWS.md           # AWS-specific documentation
│   ├── deploy-aws.sh           # Legacy manual deployment script
│   ├── ec2-setup.sh            # EC2 instance setup script
│   ├── cloudformation/
│   │   └── rpg-infrastructure.yaml  # AWS CloudFormation template
│   └── terraform/
│       └── main.tf             # Alternative Terraform config
│
├── docker-compose.yml          # Local development environment
├── docker-compose.prod.yml     # Production container orchestration
│
├── nginx/                      # Load balancer configuration
│   └── nginx.conf              # Nginx routing and SSL config
│
└── envoy/                      # gRPC-Web proxy
    └── envoy.yaml              # Envoy proxy configuration
```

## 🔧 Key Components

### GitHub Actions Workflows
- **deploy.yml**: Complete CI/CD pipeline that builds Docker images and deploys via AWS SSM
- **health-check.yml**: Automated monitoring that runs every 30 minutes

### AWS Infrastructure  
- **CloudFormation template**: Defines VPC, EC2, security groups, IAM roles
- **Deploy script**: Legacy manual deployment option
- **Setup script**: Configures EC2 instance with Docker and dependencies

### Container Configuration
- **docker-compose.yml**: For local development with all services
- **docker-compose.prod.yml**: Production deployment with registry images

### Networking
- **nginx.conf**: Load balancer, SSL termination, API routing
- **envoy.yaml**: gRPC-Web proxy for browser compatibility

## 🚀 How Components Work Together

### Development Flow
1. **Local testing**: `docker-compose up` runs everything locally
2. **Code changes**: Push to rpg-api or rpg-dnd5e-web repositories  
3. **Deployment**: Push to this repo triggers GitHub Actions

### Deployment Pipeline
1. **Build stage**: Pulls latest code, builds Docker images
2. **Infrastructure**: Deploys/updates AWS CloudFormation stack
3. **Application**: Uses SSM to deploy containers to EC2
4. **Verification**: Health checks and status reporting

### Production Architecture
```
Internet → nginx:80 → {
  / → rpg-web:80 (React + Discord SDK)
  /api → envoy:8080 → rpg-api:50051 (gRPC) ↔ redis:6379 (data store)
  /health → nginx (health check)
}
```

## 📋 Required Configuration

### GitHub Secrets
```bash
AWS_ACCESS_KEY_ID      # AWS credentials for deployment
AWS_SECRET_ACCESS_KEY  # AWS credentials for deployment  
AWS_KEY_PAIR_NAME      # EC2 key pair name
GH_TOKEN              # GitHub token for private repos (optional)
```

### Repository Dependencies
- **rpg-api**: Go gRPC server with Dockerfile
- **rpg-dnd5e-web**: React app with Dockerfile
- **rpg-deployment**: This orchestration repository

## 🔄 Customization Points

### Repository Names
Update `.github/workflows/deploy.yml` if your repositories have different names:
```yaml
repository: ${{ github.repository_owner }}/your-api-repo-name
repository: ${{ github.repository_owner }}/your-web-repo-name
```

### AWS Configuration
- **Region**: Change from us-east-1 in CloudFormation template
- **Instance type**: Modify in template (t3.micro, t3.small, etc.)
- **VPC settings**: Customize network configuration

### Application Configuration
- **Environment variables**: Add to docker-compose.prod.yml
- **SSL certificates**: Configure in nginx/ directory
- **Custom domains**: Update nginx.conf and CloudFormation

## 📚 Documentation

- **README.md**: Complete usage guide with troubleshooting
- **SETUP.md**: Step-by-step initial setup instructions  
- **aws/README-AWS.md**: AWS-specific deployment details

## 🎯 Getting Started

1. **Fork this repository**
2. **Follow SETUP.md** for initial configuration
3. **Push to main branch** to trigger first deployment
4. **Monitor via GitHub Actions** for deployment status

Your RPG platform will be live on AWS in ~15 minutes! 🎮