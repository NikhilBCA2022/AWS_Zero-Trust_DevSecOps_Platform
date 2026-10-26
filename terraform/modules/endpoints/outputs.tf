output "endpoint_security_group_id" {
  description = "Security group ID attached to the VPC endpoints"
  value       = aws_security_group.endpoints.id
}

output "interface_endpoint_ids" {
  description = "IDs of the interface VPC endpoints, keyed by service"
  value = {
    for name, endpoint in aws_vpc_endpoint.interface :
    name => endpoint.id
  }
}

output "s3_gateway_endpoint_id" {
  description = "ID of the S3 gateway VPC endpoint"
  value       = aws_vpc_endpoint.s3.id
}
