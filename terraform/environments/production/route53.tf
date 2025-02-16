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