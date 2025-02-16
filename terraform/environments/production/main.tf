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
}

module "route53" {
  source = "../../modules/route53/terraform-aws-route53-master/modules/zones"

  create = true

  zones = {
    "maxweather.io" = {
      comment = "Public hosted zone for client access"
      vpc     = []
      tags    = {
        Environment = var.environment
      }
    }
    "maxweather.internal" = {
      comment = "Private hosted zone for internal communications"
      vpc = [{
        vpc_id = module.vpc.vpc_id
      }]
      tags    = {
        Environment = var.environment
      }
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# DNS Records configuration
module "route53_records" {
  source = "../../modules/route53/terraform-aws-route53-master/modules/records"

  create = true

  zone_name = "maxweather.io"

  records = [
    {
      name    = ""
      type    = "A"
      alias   = {
        name    = module.alb.lb_dns_name
        zone_id = module.alb.lb_zone_id
      }
    }
  ]

  depends_on = [module.route53]
}