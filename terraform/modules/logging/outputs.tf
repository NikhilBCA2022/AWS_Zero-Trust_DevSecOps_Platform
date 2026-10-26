output "vpc_flow_log_id" {
  description = "ID of the VPC Flow Log"
  value       = aws_flow_log.vpc.id
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}

output "flow_logs_iam_role_arn" {
  description = "ARN of the IAM role used by VPC Flow Logs"
  value       = aws_iam_role.flow_logs.arn
}