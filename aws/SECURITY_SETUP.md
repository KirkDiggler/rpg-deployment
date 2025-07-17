# AWS Security Configuration for RPG Deployment

This guide follows AWS security best practices with least-privilege access and proper credential management.

## 🔐 Option 1: IAM User (Recommended for Personal Projects)

### Step 1: Create IAM Policy

```bash
# Create the custom policy
aws iam create-policy \
  --policy-name RPGDeploymentPolicy \
  --policy-document file://aws/iam-policy.json \
  --description "Least privilege policy for RPG platform deployment"
```

### Step 2: Create IAM User

```bash
# Create deployment user
aws iam create-user \
  --user-name rpg-deployment-github \
  --tags Key=Purpose,Value=GitHubActions Key=Project,Value=RPG-Platform

# Attach the custom policy
aws iam attach-user-policy \
  --user-name rpg-deployment-github \
  --policy-arn arn:aws:iam::YOUR-ACCOUNT-ID:policy/RPGDeploymentPolicy

# Create access key
aws iam create-access-key \
  --user-name rpg-deployment-github
```

**Save the Access Key ID and Secret Access Key securely!**

## 🏢 Option 2: OIDC Provider (Recommended for Production)

### Step 1: Create OIDC Provider

```bash
# Create GitHub OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### Step 2: Create IAM Role with Trust Policy

Create `github-trust-policy.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR-ACCOUNT-ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR-GITHUB-USERNAME/rpg-deployment:*"
        }
      }
    }
  ]
}
```

```bash
# Create the role
aws iam create-role \
  --role-name RPGDeploymentRole \
  --assume-role-policy-document file://github-trust-policy.json

# Attach the policy
aws iam attach-role-policy \
  --role-name RPGDeploymentRole \
  --policy-arn arn:aws:iam::YOUR-ACCOUNT-ID:policy/RPGDeploymentPolicy
```

### Step 3: Update GitHub Actions Workflow

For OIDC, update your workflow to use:
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::YOUR-ACCOUNT-ID:role/RPGDeploymentRole
    aws-region: us-west-2
```

## 🔑 EC2 Key Pair Setup

### Create Dedicated Key Pair
```bash
# Create key pair specifically for this deployment
aws ec2 create-key-pair \
  --key-name rpg-deployment-github \
  --key-type rsa \
  --key-format pem \
  --region us-west-2 \
  --tag-specifications 'ResourceType=key-pair,Tags=[{Key=Purpose,Value=RPGDeployment},{Key=CreatedBy,Value=GitHubActions}]' \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/rpg-deployment-github.pem

# Set proper permissions
chmod 400 ~/.ssh/rpg-deployment-github.pem

# Verify
aws ec2 describe-key-pairs --key-names rpg-deployment-github --region us-west-2
```

## 🛡️ Security Best Practices

### 1. Resource Tagging Strategy
All resources should be tagged consistently:
```json
{
  "Project": "RPG-Platform",
  "Environment": "production", 
  "ManagedBy": "GitHub-Actions",
  "Owner": "your-email@domain.com",
  "CostCenter": "personal-projects"
}
```

### 2. Network Security
- **VPC isolation**: Dedicated VPC for the application
- **Security groups**: Minimal required ports (22, 80, 443 only)
- **No public subnets** for databases (when added later)

### 3. Access Control
- **SSM Session Manager**: No direct SSH access needed
- **Temporary credentials**: OIDC eliminates long-lived keys
- **Audit trail**: CloudTrail logs all API calls

### 4. Cost Controls
```bash
# Set up billing alerts
aws budgets create-budget \
  --account-id YOUR-ACCOUNT-ID \
  --budget '{
    "BudgetName": "RPG-Platform-Monthly",
    "BudgetLimit": {
      "Amount": "25.00",
      "Unit": "USD"
    },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }'
```

## 🔍 Permission Breakdown

Our IAM policy includes only necessary permissions:

### EC2 Permissions
- ✅ **Instance management**: Start, stop, describe instances
- ✅ **VPC management**: Create/manage networking components  
- ✅ **Security groups**: Manage firewall rules
- ❌ **Other regions**: Restricted to us-west-2 only
- ❌ **Other instance types**: Can be restricted further if needed

### CloudFormation Permissions
- ✅ **Stack management**: Create, update, delete specific stack
- ✅ **Template operations**: Validate, describe
- ❌ **All stacks**: Limited to `rpg-gaming-platform` stack only

### SSM Permissions
- ✅ **Remote execution**: Send commands, get results
- ✅ **Session management**: Start sessions for debugging
- ❌ **Parameter store**: Not included (add if needed later)

### IAM Permissions
- ✅ **Role management**: Create/manage service roles
- ✅ **Instance profiles**: EC2 service permissions
- ❌ **User management**: Cannot create/modify other users
- ❌ **Policy creation**: Cannot create new policies

## 🚨 What This Policy CANNOT Do

The scoped policy prevents:
- ❌ Creating resources in other regions
- ❌ Managing other CloudFormation stacks
- ❌ Creating or modifying IAM users/policies
- ❌ Accessing other EC2 instances
- ❌ Managing RDS, Lambda, or other AWS services
- ❌ Deleting or modifying billing/account settings

## 📋 GitHub Secrets Configuration

### For IAM User Method:
```bash
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_KEY_PAIR_NAME=rpg-deployment-github
```

### For OIDC Method:
```bash
AWS_ROLE_TO_ASSUME=arn:aws:iam::YOUR-ACCOUNT-ID:role/RPGDeploymentRole
AWS_KEY_PAIR_NAME=rpg-deployment-github
```

## 🔄 Credential Rotation

### For IAM User:
```bash
# Rotate access keys every 90 days
aws iam create-access-key --user-name rpg-deployment-github
# Update GitHub secrets
aws iam delete-access-key --user-name rpg-deployment-github --access-key-id OLD-KEY-ID
```

### For OIDC:
No credential rotation needed - uses temporary tokens automatically.

## 🧹 Cleanup Commands

When you're done with the project:
```bash
# Delete CloudFormation stack (removes all resources)
aws cloudformation delete-stack --stack-name rpg-gaming-platform

# Clean up IAM resources
aws iam detach-user-policy --user-name rpg-deployment-github --policy-arn arn:aws:iam::YOUR-ACCOUNT-ID:policy/RPGDeploymentPolicy
aws iam delete-access-key --user-name rpg-deployment-github --access-key-id YOUR-KEY-ID
aws iam delete-user --user-name rpg-deployment-github
aws iam delete-policy --policy-arn arn:aws:iam::YOUR-ACCOUNT-ID:policy/RPGDeploymentPolicy

# Delete key pair
aws ec2 delete-key-pair --key-name rpg-deployment-github
```

## 🎯 Validation

Test your setup:
```bash
# Verify policy is working
aws sts get-caller-identity
aws ec2 describe-instances --region us-west-2
aws cloudformation describe-stacks --region us-west-2

# Test restricted access (should fail)
aws ec2 describe-instances --region us-west-2  # Should be denied
aws iam list-users  # Should be denied
```

---

**Security Note**: Always follow the principle of least privilege. Start with minimal permissions and add more only as needed.