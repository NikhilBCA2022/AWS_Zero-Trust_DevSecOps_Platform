output "instance_id" {
  description = "ID of the private EC2 instance"
  value       = aws_instance.private.id
}

output "private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.private.private_ip
}

output "instance_arn" {
  description = "ARN of the private EC2 instance"
  value       = aws_instance.private.arn
}