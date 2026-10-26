output "ssm_instance_role_arn" {
  description = "ARN of the IAM role for Systems Manager-managed EC2 instances"
  value       = aws_iam_role.ssm_instance.arn
}

output "ssm_instance_role_name" {
  description = "Name of the IAM role for Systems Manager-managed EC2 instances"
  value       = aws_iam_role.ssm_instance.name
}

output "ssm_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ssm_instance.name
}
