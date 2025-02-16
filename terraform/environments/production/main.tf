locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"
}

module "vpc" {
  source = "../../modules/vpc/terraform-aws-vpc-master"

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
  source = "../../modules/eks/terraform-aws-eks-master"

  cluster_name    = local.cluster_name
  cluster_version = var.eks_cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

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
  source = "../../modules/alb/terraform-aws-alb-master"

  name = "${var.project_name}-${var.environment}-alb"

  load_balancer_type = "application"
  internal           = false
  vpc_id            = module.vpc.vpc_id
  subnets           = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb.id]

  target_groups = [
    {
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
      }
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol          = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = var.environment
  }
}

module "api_gateway" {
  source = "../../modules/api-gateway/terraform-aws-apigateway-v2-master"

  name          = "${var.project_name}-${var.environment}-api"
  description   = "HTTP API Gateway for ${var.project_name} ${var.environment}"
  protocol_type = "HTTP"

  cors_configuration = {
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }

  vpc_links = {
    main = {
      name               = "${var.project_name}-${var.environment}-vpce"
      security_group_ids = [aws_security_group.vpce.id]
      subnet_ids         = module.vpc.private_subnets
    }
  }

  integrations = {
    "ANY /{proxy+}" = {
      connection_type    = "VPC_LINK"
      vpc_link          = "main"
      integration_type   = "HTTP_PROXY"
      integration_method = "ANY"
      integration_uri    = module.alb.lb_listener_arns[0]
    }
  }

  tags = {
    Environment = var.environment
  }
}

module "cloudwatch" {
  source = "../../modules/cloudwatch/terraform-aws-cloudwatch-master"

  enable_logging = true
  retention_days = 30

  eks_cluster_name = module.eks.cluster_name
  alb_arn         = module.alb.lb_arn
  api_gateway_id  = module.api_gateway.apigatewayv2_api_id

  tags = {
    Environment = var.environment
  }
}locals {
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
    }
  }
}

module "alb" {
  source = "../../modules/alb/terraform-aws-alb-master"

  # ... other configuration ...
  target_groups = [local.target_group_config]
}
locals {
  cors_config = {
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }
}

module "api_gateway" {
  # ... other configuration ...
  cors_configuration = local.cors_config
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.lb_dns_name
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.0"
}
