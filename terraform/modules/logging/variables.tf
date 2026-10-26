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

variable "vpc_id" {
  description = "ID of the VPC whose network traffic will be logged"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain network-flow logs"
  type        = number
  default     = 30
}