# AWS Deployment Guide

## Why CloudFormation?

CloudFormation is the AWS-native Infrastructure as Code (IaC) solution:

- **AWS Native**: Tight integration with all AWS services
- **State Management**: AWS handles resource state automatically  
- **Rollback**: Automatic rollback on failures
- **Free**: No additional cost (unlike Terraform Cloud)
- **Change Sets**: Preview changes before applying
- **Cross-Service**: Easy integration with IAM, VPC, monitoring, etc.

## Quick Start

### 1. Prerequisites

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
```

### 2. Create EC2 Key Pair

```bash
# Create a new key pair
aws ec2 create-key-pair --key-name rpg-server --query 'KeyMaterial' --output text > ~/.ssh/rpg-server.pem
chmod 400 ~/.ssh/rpg-server.pem

# Or use existing key pair name
export KEY_PAIR_NAME=your-existing-key-pair
```

### 3. Deploy

```bash
# Set your key pair name
export KEY_PAIR_NAME=rpg-server

# Deploy to AWS
./aws/deploy-aws.sh
```

That's it! The script will:
- Deploy CloudFormation stack (VPC, EC2, Security Groups)
- Set up Docker on the EC2 instance
- Deploy your applications
- Give you the public URL

## Architecture

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
│  │  │               │ ┌──────────┐ │  ││ │
│  │  │               │ │ rpg-api  │ │  ││ │
│  │  │               │ │ :50051   │ │  ││ │
│  │  │               │ └──────────┘ │  ││ │
│  │  │               │ ┌──────────┐ │  ││ │
│  │  │               │ │ rpg-web  │ │  ││ │
│  │  │               │ │ :80      │ │  ││ │
│  │  │               │ └──────────┘ │  ││ │
│  │  │               └──────────────┘  ││ │
│  │  └─────────────────────────────────┘│ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
          │
          ▼
   Internet Gateway
          │
          ▼
      🌐 Internet
```

## Cost Breakdown

### Free Tier (First 12 months)
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

## Advanced Options

### Custom Parameters

```bash
# Deploy to different region
./aws/deploy-aws.sh --region us-west-2

# Use larger instance
./aws/deploy-aws.sh --instance-type t3.small

# Different environment
./aws/deploy-aws.sh --environment staging
```

### SSL Certificate (Optional)

Add SSL with AWS Certificate Manager:

```bash
# Request certificate (requires domain)
aws acm request-certificate \
    --domain-name your-domain.com \
    --validation-method DNS
```

### Auto Scaling (Future)

The CloudFormation template includes:
- IAM roles for future AWS service access
- CloudWatch integration
- VPC setup for load balancers

Easy to add Auto Scaling Groups and Application Load Balancers later.

## Monitoring

CloudWatch agent is installed automatically:

```bash
# View application logs
ssh -i ~/.ssh/rpg-server.pem ec2-user@YOUR-IP
docker-compose logs -f

# CloudWatch metrics available in AWS Console
```

## Cleanup

```bash
# Delete everything
aws cloudformation delete-stack --stack-name rpg-gaming-platform

# This removes:
# - EC2 instance
# - VPC and networking
# - Security groups  
# - Elastic IP
# - IAM roles
```

## Why This Setup Rocks

1. **AWS Native**: Uses CloudFormation, not third-party tools
2. **Cost Effective**: Free tier eligible, ~$11/month after
3. **Scalable**: Easy to add ALB, ASG, RDS later
4. **Secure**: Proper VPC, Security Groups, IAM roles
5. **Monitored**: CloudWatch integration included
6. **Maintainable**: Infrastructure as Code with version control