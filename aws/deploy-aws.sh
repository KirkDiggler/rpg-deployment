#!/bin/bash
# AWS CloudFormation Deployment Script for RPG Platform

set -e

# Configuration
STACK_NAME="rpg-gaming-platform"
ENVIRONMENT="production"
REGION="us-east-1"
INSTANCE_TYPE="t3.micro"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install it first."
        exit 1
    fi
}

check_key_pair() {
    if [ -z "$KEY_PAIR_NAME" ]; then
        log_error "KEY_PAIR_NAME environment variable is required"
        log_info "Set it with: export KEY_PAIR_NAME=your-key-pair-name"
        exit 1
    fi
    
    # Check if key pair exists
    aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" --region "$REGION" >/dev/null 2>&1 || {
        log_error "Key pair '$KEY_PAIR_NAME' not found in region '$REGION'"
        log_info "Create one with: aws ec2 create-key-pair --key-name $KEY_PAIR_NAME --region $REGION"
        exit 1
    }
}

deploy_stack() {
    log_info "Deploying CloudFormation stack: $STACK_NAME"
    
    aws cloudformation deploy \
        --template-file aws/cloudformation/rpg-infrastructure.yaml \
        --stack-name "$STACK_NAME" \
        --parameter-overrides \
            Environment="$ENVIRONMENT" \
            InstanceType="$INSTANCE_TYPE" \
            KeyPairName="$KEY_PAIR_NAME" \
        --capabilities CAPABILITY_IAM \
        --region "$REGION" \
        --tags \
            Environment="$ENVIRONMENT" \
            Project="RPG-Gaming-Platform" \
            Owner="$(whoami)"
    
    if [ $? -eq 0 ]; then
        log_info "Stack deployment completed successfully!"
    else
        log_error "Stack deployment failed!"
        exit 1
    fi
}

get_outputs() {
    log_info "Getting stack outputs..."
    
    outputs=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs' \
        --output table)
    
    echo "$outputs"
    
    # Get specific values
    public_ip=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`PublicIP`].OutputValue' \
        --output text)
    
    ssh_command=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`SSHCommand`].OutputValue' \
        --output text)
    
    app_url=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ApplicationURL`].OutputValue' \
        --output text)
    
    log_info "Deployment Summary:"
    echo "🌐 Application URL: $app_url"
    echo "📡 Public IP: $public_ip"
    echo "🔑 SSH Command: $ssh_command"
}

setup_server() {
    if [ -z "$public_ip" ]; then
        log_error "Could not get public IP. Skipping server setup."
        return 1
    fi
    
    log_info "Setting up application on server..."
    log_warn "Waiting 60 seconds for instance to fully boot..."
    sleep 60
    
    # Copy deployment files to server
    scp -i ~/.ssh/${KEY_PAIR_NAME}.pem -r . ec2-user@${public_ip}:/home/ec2-user/rpg-deployment/
    
    # Run setup script on server
    ssh -i ~/.ssh/${KEY_PAIR_NAME}.pem ec2-user@${public_ip} << 'EOF'
        cd /home/ec2-user/rpg-deployment
        chmod +x aws/ec2-setup.sh
        ./aws/ec2-setup.sh
        
        # Start the application
        docker-compose up -d
        
        echo "🚀 Application started successfully!"
        echo "Check status with: docker-compose ps"
EOF
}

# Main execution
main() {
    log_info "Starting AWS deployment for RPG Gaming Platform"
    
    # Checks
    check_aws_cli
    check_key_pair
    
    # Deploy
    deploy_stack
    get_outputs
    
    # Setup application (optional)
    read -p "Do you want to set up the application now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_server
    else
        log_info "Skipping application setup. You can run it later with:"
        echo "  $ssh_command"
        echo "  cd /opt/rpg-deployment && docker-compose up -d"
    fi
    
    log_info "Deployment complete! 🎉"
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Environment Variables:"
    echo "  KEY_PAIR_NAME    AWS EC2 Key Pair name (required)"
    echo ""
    echo "Options:"
    echo "  --stack-name     CloudFormation stack name (default: rpg-gaming-platform)"
    echo "  --environment    Environment name (default: production)"
    echo "  --region         AWS region (default: us-east-1)"
    echo "  --instance-type  EC2 instance type (default: t3.micro)"
    echo "  --help           Show this help message"
    echo ""
    echo "Example:"
    echo "  export KEY_PAIR_NAME=my-key-pair"
    echo "  $0 --environment staging --region us-west-2"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --stack-name)
            STACK_NAME="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --instance-type)
            INSTANCE_TYPE="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main