# Configure AWS Provider
// Provider configuration moved to environments/production/main.tf

locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"
}

locals {
  # Shorten project name even further to accommodate suffixes
  short_project_name = substr(var.project_name, 0, 10)
}

module "vpc" {
  source = "./modules/vpc/terraform-aws-vpc-master"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = var.environment
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

module "eks" {
   source = "./modules/eks/terraform-aws-eks-master"

  cluster_name    = local.name_with_suffix.eks
  cluster_version = var.eks_cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # Add this line to disable the name prefix for IAM roles
  iam_role_use_name_prefix = false

  eks_managed_node_groups = {
    default = {
      min_size     = var.eks_min_size
      max_size     = var.eks_max_size
      desired_size = var.eks_desired_size

      instance_types = var.eks_instance_types
      capacity_type  = "ON_DEMAND"

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 50
            volume_type = "gp3"
          }
        }
      }
    }
  }

  tags = {
    Environment = var.environment
  }
}

module "alb" {
  source = "./modules/alb/terraform-aws-alb-master"

  name = local.name_with_suffix.alb

  load_balancer_type = "application"
  internal           = false
  vpc_id            = module.vpc.vpc_id
  subnets           = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb.id]

  target_groups = [
    {
      name             = "ingress"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "ip"
      health_check = {
        enabled             = true
        interval           = 30
        path               = "/health"
        port               = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout            = 6
        protocol           = "HTTP"
      }
    }
  ]

  tags = {
    Environment = var.environment
  }
}

# CloudWatch Module Configuration
module "cloudwatch" {
  source = "./modules/cloudwatch/terraform-aws-cloudwatch-master"
}

# Target Group Configuration
locals {
  target_group_config = {
    name             = "${var.project_name}-${var.environment}-tg"
    backend_protocol = "HTTP"
    backend_port     = 80
    target_type      = "ip"

    health_check = {
      enabled             = true
      interval           = 30
      path               = "/health"
      port               = "traffic-port"
      healthy_threshold   = 3
      unhealthy_threshold = 3
      timeout            = 6
      protocol           = "HTTP"
      matcher            = "200-399"    # Added matcher for valid response codes
    }

    stickiness = {
      enabled         = false
      type           = "lb_cookie"
      cookie_duration = 86400
    }

    deregistration_delay = 300

    tags = {
      Environment = var.environment
      Project     = var.project_name
      Terraform   = "true"
      ManagedBy   = "terraform"
    }
  }
}
# Target Group Configuration
locals {

}
# S3 Bucket for ALB logs
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.project_name}-${var.environment}-alb-logs"

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Terraform   = "true"
  }
}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Terraform   = "true"
  }
}
# CloudWatch Module Configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.0"
}
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  name_with_suffix = {
    eks = "${local.name_prefix}-eks"
    vpc = "${local.name_prefix}-vpc"
    alb = "${local.name_prefix}-alb"
    api = "${local.name_prefix}-api"
  }
}
locals {
  eks_node_group_config = {
    min_size     = var.eks_min_size
    max_size     = var.eks_max_size
    desired_size = var.eks_desired_size
    instance_types = var.eks_instance_types
    capacity_type  = "ON_DEMAND"
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size = 50
          volume_type = "gp3"
        }
      }
    }
  }
}

# Create Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  # Allow inbound HTTP traffic
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound HTTPS traffic
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-sg"
    Environment = var.environment
  }
}
