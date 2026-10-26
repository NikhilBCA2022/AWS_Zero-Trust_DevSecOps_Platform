output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster certificate authority data"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_group_name" {
  description = "Name of the managed node group"
  value       = aws_eks_node_group.this.node_group_name
}

output "node_role_arn" {
  description = "IAM role ARN assigned to worker nodes"
  value       = aws_iam_role.node.arn
}
output "cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}