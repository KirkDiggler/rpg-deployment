terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro" # Free tier eligible
}

variable "key_pair_name" {
  description = "AWS Key Pair name for SSH access"
  type        = string
}

variable "allowed_cidr" {
  description = "CIDR block allowed to access the instance"
  type        = string
  default     = "0.0.0.0/0" # Change to your IP for better security
}

# Data sources
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "rpg_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "rpg-vpc"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "rpg_igw" {
  vpc_id = aws_vpc.rpg_vpc.id

  tags = {
    Name        = "rpg-igw"
    Environment = var.environment
  }
}

# Public Subnet
resource "aws_subnet" "rpg_public_subnet" {
  vpc_id                  = aws_vpc.rpg_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "rpg-public-subnet"
    Environment = var.environment
  }
}

# Route Table
resource "aws_route_table" "rpg_public_rt" {
  vpc_id = aws_vpc.rpg_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rpg_igw.id
  }

  tags = {
    Name        = "rpg-public-rt"
    Environment = var.environment
  }
}

# Route Table Association
resource "aws_route_table_association" "rpg_public_rta" {
  subnet_id      = aws_subnet.rpg_public_subnet.id
  route_table_id = aws_route_table.rpg_public_rt.id
}

# Security Group
resource "aws_security_group" "rpg_sg" {
  name_prefix = "rpg-sg"
  vpc_id      = aws_vpc.rpg_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "rpg-security-group"
    Environment = var.environment
  }
}

# EC2 Instance
resource "aws_instance" "rpg_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.rpg_sg.id]
  subnet_id              = aws_subnet.rpg_public_subnet.id

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    environment = var.environment
  }))

  tags = {
    Name        = "rpg-server"
    Environment = var.environment
  }
}

# Elastic IP
resource "aws_eip" "rpg_eip" {
  domain = "vpc"
  instance = aws_instance.rpg_server.id

  tags = {
    Name        = "rpg-eip"
    Environment = var.environment
  }
}

# Outputs
output "instance_ip" {
  description = "Public IP address of the RPG server"
  value       = aws_eip.rpg_eip.public_ip
}

output "instance_dns" {
  description = "Public DNS name of the RPG server"
  value       = aws_eip.rpg_eip.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_eip.rpg_eip.public_ip}"
}