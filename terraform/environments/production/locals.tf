locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Common tags for all resources
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Owner       = "platform-team"
  }

  # Adding cluster configuration settings
  cluster_config = {
    version = "1.27"
    logging = ["api", "audit", "authenticator"]
  }

  # Common monitoring configuration
  monitoring_config = {
    cloudwatch = {
      enable_logging    = true
      retention_days    = 30
      log_group_prefix  = "/${var.project_name}/${var.environment}"
    }
  }

  # Target group configurations
  target_group_config = {
    port                = 80
    protocol            = "HTTP"
    target_type         = "ip"
    health_check = {
      enabled             = true
      healthy_threshold   = 2
      interval            = 30
      matcher            = "200"
      path               = "/health"
      port               = "traffic-port"
      protocol           = "HTTP"
      timeout            = 5
      unhealthy_threshold = 2
    }
  }
}