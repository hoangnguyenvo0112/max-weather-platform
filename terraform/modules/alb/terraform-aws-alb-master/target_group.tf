resource "aws_lb_target_group" "main" {
  name_prefix          = "eks"
  port                = 30080
  protocol            = "HTTP"
  vpc_id              = var.vpc_id
  target_type         = "instance"
  deregistration_delay = 10

  health_check {
    enabled             = true
    interval            = 30
    path               = "/healthz"
    port               = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout            = 6
  }

  lifecycle {
    create_before_destroy = true
  }
}