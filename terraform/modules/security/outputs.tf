output "baseline_security_group_id" {
  description = "ID of the baseline security group"
  value       = aws_security_group.baseline.id
}

output "baseline_security_group_name" {
  description = "Name of the baseline security group"
  value       = aws_security_group.baseline.name
}
