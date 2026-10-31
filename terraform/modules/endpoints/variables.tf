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
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for interface endpoints"
  type        = list(string)
}

variable "private_route_table_id" {
  description = "Route table associated with private subnets"
  type        = string
}

variable "endpoint_client_security_group_ids" {
  description = "Security groups allowed to connect to interface endpoints"
  type        = list(string)

  validation {
    condition     = length(var.endpoint_client_security_group_ids) > 0
    error_message = "At least one client security group ID must be supplied."
  }
}

variable "runner_route_table_id" {
  description = "Optional route table ID for the private runner subnet"
  type        = string
  default     = null
}
