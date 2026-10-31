# Security group for interface VPC endpoints
resource "aws_security_group" "endpoints" {
  name        = "${var.name_prefix}-endpoints-sg"
  description = "Allow HTTPS from approved private workloads to VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from approved private workloads"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = var.endpoint_client_security_group_ids
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-endpoints-sg"
  })
}

# Interface endpoints for private access to AWS services
resource "aws_vpc_endpoint" "interface" {
  for_each = toset([
    "ssm",
    "ssmmessages",
    "ec2messages",
    "ecr.api",
    "ecr.dkr",
    "logs",
    "sts",
    "ec2",
    "secretsmanager",
    "elasticloadbalancing"
  ])

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(var.common_tags, {
    Name    = "${var.name_prefix}-${replace(each.key, ".", "-")}-endpoint"
    Service = each.key
  })
}

# Gateway endpoint for S3 access from private subnets
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = compact([
    var.private_route_table_id,
    var.runner_route_table_id
  ])

  tags = merge(var.common_tags, {
    Name    = "${var.name_prefix}-s3-endpoint"
    Service = "s3"
  })
}

data "aws_region" "current" {}