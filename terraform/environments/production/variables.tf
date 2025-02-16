# ---------------------------------------------------------------------------------------------------------------------
# Required Variables
# ---------------------------------------------------------------------------------------------------------------------
variable "domain_name" {
  description = "Domain name for Route53 zone (required)"
  type        = string
  default     = "weahter-backend-api.com"

  validation {
    condition     = can(regex("^([a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid fully qualified domain name."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Network Configuration
# ---------------------------------------------------------------------------------------------------------------------
locals {
  network_config = {
    vpc_cidr         = "10.0.0.0/16"
    private_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block for the network infrastructure"
  type        = string
  default     = local.network_config.vpc_cidr

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "azs" {
  description = "List of AWS Availability Zones in the region"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]

  validation {
    condition     = length(var.azs) >= 2
    error_message = "At least 2 availability zones must be specified for high availability."
  }
}

variable "private_subnets" {
  description = "List of CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = local.network_config.private_subnets

  validation {
    condition     = length(var.private_subnets) >= 2
    error_message = "At least 2 private subnets must be specified for high availability."
  }
}

variable "public_subnets" {
  description = "List of CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = local.network_config.public_subnets

  validation {
    condition     = length(var.public_subnets) >= 2
    error_message = "At least 2 public subnets must be specified for high availability."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# EKS Cluster Configuration
# ---------------------------------------------------------------------------------------------------------------------
locals {
  eks_config = {
    min_size        = 2
    max_size        = 5
    desired_size    = 2
    instance_types  = ["t3.medium"]
    cluster_version = "1.32"
  }
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster (format: X.Y)"
  type        = string
  default     = local.eks_config.cluster_version

  validation {
    condition     = can(regex("^\\d+\\.\\d+$", var.eks_cluster_version))
    error_message = "EKS cluster version must be in the format 'X.Y'."
  }
}

variable "eks_instance_types" {
  description = "List of EC2 instance types for the EKS node groups"
  type        = list(string)
  default     = local.eks_config.instance_types

  validation {
    condition     = length(var.eks_instance_types) > 0
    error_message = "At least one instance type must be specified."
  }
}

variable "eks_min_size" {
  description = "Minimum number of nodes in the EKS node group"
  type        = number
  default     = local.eks_config.min_size

  validation {
    condition     = var.eks_min_size > 0
    error_message = "Minimum size must be greater than 0."
  }
}

variable "eks_max_size" {
  description = "Maximum number of nodes in the EKS node group"
  type        = number
  default     = local.eks_config.max_size

  validation {
    condition     = var.eks_max_size >= 2
    error_message = "Maximum size must be at least 2 for high availability."
  }
}

variable "eks_desired_size" {
  description = "Desired number of nodes in the EKS node group"
  type        = number
  default     = local.eks_config.desired_size

  validation {
    condition     = var.eks_desired_size >= 2
    error_message = "Desired size must be at least 2 for high availability."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Project Metadata
# ---------------------------------------------------------------------------------------------------------------------
variable "project_name" {
  description = "Name of the project used for resource naming and tagging"
  type        = string
  default     = "max-weather-platform"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment (production, staging, development)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be one of: production, staging, development."
  }
}

variable "region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-west-2"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d$", var.region))
    error_message = "Must be a valid AWS region identifier (e.g., us-west-2)."
  }
}
