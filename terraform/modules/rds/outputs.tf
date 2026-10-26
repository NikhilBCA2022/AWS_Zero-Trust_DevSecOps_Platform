output "db_instance_id" {
  description = "RDS database instance identifier"
  value       = aws_db_instance.this.identifier
}

output "db_endpoint" {
  description = "Private RDS endpoint hostname and port"
  value       = aws_db_instance.this.endpoint
}

output "db_port" {
  description = "PostgreSQL port"
  value       = aws_db_instance.this.port
}

output "db_security_group_id" {
  description = "Security group attached to RDS"
  value       = aws_security_group.database.id
}
output "db_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS master credentials"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
  sensitive   = true
}