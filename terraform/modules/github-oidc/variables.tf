variable "name_prefix" {
  description = "Prefix used to name AWS resources"
  type        = string
}

variable "common_tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}

variable "github_owner" {
  description = "GitHub repository owner or organization"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "Branch permitted to deploy to AWS"
  type        = string
  default     = "main"
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository that GitHub Actions may publish images to"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_cluster_arn" {
  description = "EKS cluster ARN"
  type        = string
}
