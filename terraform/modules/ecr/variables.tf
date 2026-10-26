variable "name_prefix" {
  description = "Prefix used to name ECR resources"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to resources"
  type        = map(string)
  default     = {}
}
