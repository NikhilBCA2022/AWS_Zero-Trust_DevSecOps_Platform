variable "name_prefix" {
  description = "Prefix used to name EKS resources"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to AWS resources"
  type        = map(string)
  default     = {}
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC hosting EKS"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS and worker nodes"
  type        = list(string)
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to access the public Kubernetes API endpoint"
  type        = list(string)
}
