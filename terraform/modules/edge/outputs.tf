output "web_acl_arn" {
  description = "ARN of the regional AWS WAF Web ACL"
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_id" {
  description = "ID of the AWS WAF Web ACL"
  value       = aws_wafv2_web_acl.this.id
}

output "load_balancer_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller"
  value       = aws_iam_role.load_balancer_controller.arn
}

output "eks_oidc_provider_arn" {
  description = "IAM OIDC provider ARN for the EKS cluster"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "cloud_ops_api_role_arn" {
  description = "IAM role ARN for the Cloud Ops API to access its dedicated database secret"
  value       = aws_iam_role.cloud_ops_api.arn
}
