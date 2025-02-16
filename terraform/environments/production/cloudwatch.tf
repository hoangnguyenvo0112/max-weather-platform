locals {
  cloudwatch_config = {
    enable_logging    = true
    retention_days    = 30
    log_group_prefix  = "/${var.project_name}/${var.environment}"

    # Monitoring targets
    monitoring_targets = {
      eks = {
        cluster_name = module.eks.cluster_name
        log_types    = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
      }
      alb = {
        arn = module.alb.lb_arn
      }
      api_gateway = {
        id = module.api_gateway.apigatewayv2_api_id
      }
    }
  }
}

module "cloudwatch" {
  source = "terraform-aws-modules/cloudwatch/aws"
  version = "~> 4.0"

  enable_logging    = local.cloudwatch_config.enable_logging
  retention_days    = local.cloudwatch_config.retention_days
  log_group_prefix  = local.cloudwatch_config.log_group_prefix

  # EKS Monitoring
  eks_cluster_name  = local.cloudwatch_config.monitoring_targets.eks.cluster_name
  eks_log_types     = local.cloudwatch_config.monitoring_targets.eks.log_types

  # ALB Monitoring
  alb_arn          = local.cloudwatch_config.monitoring_targets.alb.arn

  # API Gateway Monitoring
  api_gateway_id   = local.cloudwatch_config.monitoring_targets.api_gateway.id

  depends_on = [
    module.eks,
    module.alb,
    module.api_gateway
  ]
}