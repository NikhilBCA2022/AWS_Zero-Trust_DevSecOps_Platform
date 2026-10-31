output "runner_instance_id" {
  description = "EC2 instance ID of the private GitHub Actions runner"
  value       = aws_instance.runner.id
}

output "runner_private_ip" {
  description = "Private IP address of the GitHub Actions runner"
  value       = aws_instance.runner.private_ip
}

output "runner_security_group_id" {
  description = "Security group ID of the GitHub Actions runner"
  value       = aws_security_group.runner.id
}

output "nat_instance_id" {
  description = "EC2 instance ID of the NAT instance"
  value       = aws_instance.nat.id
}

output "nat_private_ip" {
  description = "Private IP address of the NAT instance"
  value       = aws_instance.nat.private_ip
}

output "nat_security_group_id" {
  description = "Security group ID of the NAT instance"
  value       = aws_security_group.nat.id
}
output "runner_role_arn" {
  description = "IAM role ARN used by the private GitHub Actions runner"
  value       = aws_iam_role.runner.arn
}