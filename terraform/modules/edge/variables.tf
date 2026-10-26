variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to resources"
  type        = map(string)
}

variable "eks_oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster"
  type        = string
}
