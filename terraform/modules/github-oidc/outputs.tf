output "github_deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC authentication"
  value       = aws_iam_role.github_deploy.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC identity provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}
