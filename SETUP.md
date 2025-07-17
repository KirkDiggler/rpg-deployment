# RPG Platform Deployment Setup

Complete setup guide for deploying your RPG platform to AWS using GitHub Actions.

## 📋 Prerequisites Checklist

### AWS Requirements
- [ ] AWS account with billing enabled
- [ ] AWS CLI installed and configured locally (for testing)
- [ ] EC2 key pair created in us-east-1 region

### GitHub Requirements
- [ ] GitHub account
- [ ] Fork of this repository
- [ ] Access to your rpg-api and rpg-dnd5e-web repositories

## 🔑 Step 1: Create AWS Credentials

### Option A: IAM User (Recommended for personal projects)
1. Go to AWS Console → IAM → Users → Create User
2. User name: `rpg-deployment-github`
3. Attach policies:
   ```
   - AmazonEC2FullAccess
   - AmazonSSMFullAccess
   - CloudFormationFullAccess
   - IAMReadOnlyAccess
   ```
4. Create access key → Choose "Third-party service"
5. Save Access Key ID and Secret Access Key

### Option B: IAM Role (Recommended for production)
1. Set up OIDC provider for GitHub Actions
2. Create role with trust policy for your repository
3. Attach the same policies as above

## 🔧 Step 2: Create EC2 Key Pair

```bash
# Create key pair in us-east-1
aws ec2 create-key-pair \
  --key-name rpg-deployment \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/rpg-deployment.pem

# Set permissions
chmod 400 ~/.ssh/rpg-deployment.pem

# Verify it exists
aws ec2 describe-key-pairs --key-names rpg-deployment --region us-east-1
```

## 🤖 Step 3: Configure GitHub Secrets

Go to your repository → Settings → Secrets and variables → Actions

### Required Secrets:
```bash
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key
AWS_KEY_PAIR_NAME=rpg-deployment
```

### Optional Secrets (if using private repos):
```bash
GH_TOKEN=github-personal-access-token
```

## 🚀 Step 4: Test Deployment

### Method 1: Push to Main (Automatic)
```bash
git commit -m "Initial deployment" --allow-empty
git push origin main
# Watch GitHub Actions → Deploy RPG Platform
```

### Method 2: Manual Trigger
1. Go to GitHub Actions
2. Select "Deploy RPG Platform" workflow
3. Click "Run workflow" → "Run workflow"

## 📊 Step 5: Verify Deployment

### Check GitHub Actions
- Build job should complete in ~5-10 minutes
- Deploy job should complete in ~10-15 minutes
- Health check should show ✅ status

### Test Application
```bash
# Get your application URL from GitHub Actions output
curl http://YOUR-EC2-IP/health
# Should return: "healthy"

# Test frontend
curl http://YOUR-EC2-IP
# Should return HTML

# Test API endpoint
curl -H "Content-Type: application/grpc-web+proto" http://YOUR-EC2-IP/api/
```

## 🔍 Troubleshooting Setup

### Common Issues

#### "Key pair not found"
```bash
# List existing key pairs
aws ec2 describe-key-pairs --region us-east-1

# Create if missing
aws ec2 create-key-pair --key-name rpg-deployment --region us-east-1
```

#### "Access denied" errors
- Verify IAM policies are attached
- Check AWS credentials are correct
- Ensure you're using us-east-1 region

#### "Repository not found" during build
- Verify GH_TOKEN has access to private repos
- Check repository names in workflow file
- Ensure repositories exist and are accessible

#### "SSM not working"
- Wait 5-10 minutes after infrastructure deployment
- EC2 instance needs time to install SSM agent
- Check instance is running in AWS Console

## 📈 Next Steps

### Customize for Your Setup
1. **Update repository references** in `.github/workflows/deploy.yml`
2. **Modify AWS region** if not using us-east-1
3. **Adjust instance type** for your needs (t3.small, t3.medium, etc.)
4. **Configure SSL certificates** for HTTPS

### Monitor Your Deployment
- GitHub Actions provides deployment status
- Health checks run every 30 minutes
- AWS CloudWatch monitors infrastructure
- Check costs in AWS Billing dashboard

## 💡 Tips

### Cost Optimization
- Use AWS Free Tier eligible instance (t3.micro)
- Stop instance when not needed (re-run deployment to restart)
- Monitor data transfer usage

### Security Best Practices
- Never commit AWS credentials to git
- Use least-privilege IAM policies
- Consider using GitHub OIDC instead of access keys
- Regularly rotate access keys

### Development Workflow
- Test changes locally with `docker-compose up`
- Use feature branches for major changes
- Deploy to production via main branch only

---

**Need help?** Check the [main README](README.md) for detailed troubleshooting and monitoring guides.