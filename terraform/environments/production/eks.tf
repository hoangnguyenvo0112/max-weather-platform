locals {
  eks_config = {
    version = 1.32
    node_groups = {
      default = {
        min_size     = var.eks_min_size
        max_size     = var.eks_max_size
        desired_size = var.eks_min_size
        instance_types = ["t3.medium"]
        capacity_type  = "SPOT"
      }
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "${local.name_prefix}-eks"
  cluster_version = local.eks_config.version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  eks_managed_node_groups = local.eks_config.node_groups

  tags = local.resource_tags.eks
}