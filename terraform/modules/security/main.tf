resource "aws_security_group" "baseline" {
  name        = "${var.name_prefix}-baseline-sg"
  description = "Baseline security group for the AWS Zero-Trust platform"
  vpc_id      = var.vpc_id

  # No ingress rules are defined.
  # Access will be added explicitly when required.

  egress {
    description = "Allow HTTPS outbound traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-baseline-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}
