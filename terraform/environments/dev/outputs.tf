output "aws_region" {
  description = "AWS region used by the project"
  value       = var.aws_region
}

output "vpc_id" {
  description = "ID of the Zero-Trust VPC"
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the Zero-Trust VPC"
  value       = module.network.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.network.private_subnet_ids
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = module.network.public_route_table_id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = module.network.private_route_table_id
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = module.ecr.repository_name
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "rds_endpoint" {
  description = "Private PostgreSQL endpoint"
  value       = module.rds.db_endpoint
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = module.rds.db_security_group_id
}
output "github_deploy_role_arn" {
  description = "IAM role ARN used by GitHub Actions"
  value       = module.github_oidc.github_deploy_role_arn
}
output "waf_web_acl_arn" {
  description = "ARN of the regional AWS WAF Web ACL"
  value       = module.edge.web_acl_arn
}

output "load_balancer_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller"
  value       = module.edge.load_balancer_controller_role_arn
}
output "rds_master_user_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret for RDS master credentials"
  value       = module.rds.db_master_user_secret_arn
  sensitive   = true
}
output "cloud_ops_api_role_arn" {
  description = "IAM role ARN for the Cloud Ops API"
  value       = module.edge.cloud_ops_api_role_arn
}
