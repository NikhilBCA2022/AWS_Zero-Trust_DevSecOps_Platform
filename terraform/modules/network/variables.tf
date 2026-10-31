variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "name_prefix" {
  description = "Prefix used to name AWS resources"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to AWS resources"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block for the Zero-Trust VPC"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used by the network"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly two Availability Zones must be provided."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDRs must be provided."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly two private subnet CIDRs must be provided."
  }
}
variable "database_subnet_cidrs" {
  description = "CIDR blocks for the dedicated database subnets"
  type        = list(string)

  validation {
    condition     = length(var.database_subnet_cidrs) == 2
    error_message = "Exactly two database subnet CIDRs must be provided."
  }
}
variable "runner_subnet_cidr" {
  description = "Optional CIDR block for the dedicated private GitHub Actions runner subnet"
  type        = string
  default     = ""
}

variable "runner_subnet_az" {
  description = "Optional Availability Zone for the dedicated runner subnet"
  type        = string
  default     = ""
}
