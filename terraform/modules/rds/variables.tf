variable "name_prefix" {
  description = "Prefix used to name RDS resources"
  type        = string
}

variable "common_tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}

variable "database_subnet_ids" {
  description = "Dedicated database subnets used by the RDS subnet group"
  type        = list(string)

  validation {
    condition     = length(var.database_subnet_ids) >= 2
    error_message = "RDS requires at least two subnets in its DB subnet group."
  }
}
variable "vpc_id" {
  description = "VPC ID for the database security group"
  type        = string
}

variable "allowed_security_group_id" {
  description = "Security group permitted to connect to PostgreSQL"
  type        = string
}
