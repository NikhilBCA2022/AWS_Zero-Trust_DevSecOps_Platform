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

variable "subnet_id" {
  description = "Private subnet ID for the EC2 instance"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for the EC2 instance"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile for Systems Manager access"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}