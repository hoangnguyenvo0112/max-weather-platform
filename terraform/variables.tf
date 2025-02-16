# General Configuration
variable "project_name" {
  description = "The name of the project used for resource naming and tagging"
  type        = string
  default     = "max-weather-platform"
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Environment must be one of: production, staging, development."
  }
}

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-west-2"
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC network"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "azs" {
  description = "List of availability zones for resource distribution"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "private_subnets" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

# EKS Configuration
variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.32"

  validation {
    condition     = can(regex("^\\d+\\.\\d+$", var.eks_cluster_version))
    error_message = "EKS cluster version must be in the format 'X.Y'."
  }
}

variable "eks_instance_types" {
  description = "List of EC2 instance types for EKS node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_min_size" {
  description = "Minimum number of nodes in EKS node group"
  type        = number
  default     = 2

  validation {
    condition     = var.eks_min_size > 0
    error_message = "Minimum size must be greater than 0."
  }
}

variable "eks_max_size" {
  description = "Maximum number of nodes in EKS node group"
  type        = number
  default     = 5

  validation {
    condition     = var.eks_max_size >= var.eks_min_size
    error_message = "Maximum size must be greater than or equal to minimum size."
  }
}

variable "eks_desired_size" {
  description = "Desired number of nodes in EKS node group"
  type        = number
  default     = 2

  validation {
    condition     = var.eks_desired_size >= var.eks_min_size && var.eks_desired_size <= var.eks_max_size
    error_message = "Desired size must be between minimum and maximum size."
  }
}
