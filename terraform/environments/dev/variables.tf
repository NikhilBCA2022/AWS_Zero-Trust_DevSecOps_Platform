
variable "aws_region" {
  description = "AWS region for the Zero-Trust platform"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "aws-zero-trust-platform"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the Zero-Trust VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for the network"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for the compute instance"
  type        = string
  default     = "t3.micro"
}
variable "eks_endpoint_public_access_cidrs" {
  description = "Trusted public IPv4 CIDR blocks permitted to access the EKS API endpoint"
  type        = list(string)

  validation {
    condition = (
      length(var.eks_endpoint_public_access_cidrs) > 0 &&
      alltrue([
        for cidr in var.eks_endpoint_public_access_cidrs :
        can(cidrnetmask(cidr))
      ])
    )

    error_message = "Provide at least one valid IPv4 CIDR block for EKS API access."
  }
}
variable "github_owner" {
  description = "GitHub username or organization that owns the repository"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch authorized to deploy"
  type        = string
  default     = "main"
}
variable "database_subnet_cidrs" {
  description = "CIDR blocks for the dedicated database subnets"
  type        = list(string)
  default     = ["10.20.21.0/24", "10.20.22.0/24"]
}