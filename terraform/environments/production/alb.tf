# Load Balancer configuration
module "alb" {
  source = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name               = "${local.name_prefix}-alb"
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets           = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb.id]

  access_logs = {
    bucket = aws_s3_bucket.alb_logs.id
    prefix = "alb-logs"
    enabled = true
  }

  target_groups = [
    {
      name_prefix      = "main"
      backend_protocol = local.target_group_config.protocol
      backend_port     = local.target_group_config.port
      target_type      = local.target_group_config.target_type
      health_check     = local.target_group_config.health_check
    }
  ]

  tags = local.common_tags

  depends_on = [aws_s3_bucket.alb_logs]
}