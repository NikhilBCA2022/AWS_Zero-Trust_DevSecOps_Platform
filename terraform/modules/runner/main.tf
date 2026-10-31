# Security group for the NAT instance.
resource "aws_security_group" "nat" {
  name        = "${var.name_prefix}-nat-sg"
  description = "Allow runner HTTPS traffic to pass through the NAT instance"
  vpc_id      = var.vpc_id

  ingress {
    description = "Forwarded HTTPS traffic from the dedicated runner subnet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_subnet.runner.cidr_block]
  }

  egress {
    description = "HTTPS outbound traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-nat-sg"
  })
}

# Security group for the private GitHub Actions runner.
resource "aws_security_group" "runner" {
  name        = "${var.name_prefix}-runner-sg"
  description = "Allow outbound HTTPS from the private GitHub Actions runner"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS outbound traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-runner-sg"
  })
}

# Look up the runner subnet CIDR for the NAT security-group rule.
data "aws_subnet" "runner" {
  id = var.runner_subnet_id
}

# IAM role for managing the NAT instance through AWS Systems Manager.
resource "aws_iam_role" "nat" {
  name = "${var.name_prefix}-nat-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "nat_ssm" {
  role       = aws_iam_role.nat.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nat" {
  name = "${var.name_prefix}-nat-profile"
  role = aws_iam_role.nat.name

  tags = var.common_tags
}

# Separate IAM role for managing the GitHub Actions runner through SSM.
resource "aws_iam_role" "runner" {
  name = "${var.name_prefix}-runner-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "runner_ssm" {
  role       = aws_iam_role.runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


resource "aws_iam_instance_profile" "runner" {
  name = "${var.name_prefix}-runner-profile"
  role = aws_iam_role.runner.name

  tags = var.common_tags
}
# Allow the private runner to retrieve metadata for the designated EKS cluster.
resource "aws_iam_role_policy" "runner_eks_describe" {
  name = "${var.name_prefix}-runner-eks-describe"
  role = aws_iam_role.runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:ap-south-1:774609032429:cluster/aws-zero-trust-platform-dev-eks"
      }
    ]
  })
}

# Latest Amazon Linux 2023 x86_64 AMI.
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# NAT instance: public subnet, no inbound SSH, and SSM-based management.
resource "aws_instance" "nat" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.nat_instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.nat.id]
  iam_instance_profile        = aws_iam_instance_profile.nat.name
  associate_public_ip_address = true
  source_dest_check           = false

  user_data = templatefile("${path.module}/nat-user-data.sh", {
    runner_subnet_cidr = data.aws_subnet.runner.cidr_block
    vpc_cidr           = var.vpc_cidr
  })

  user_data_replace_on_change = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-nat"
    Role = "NAT"
  })

  depends_on = [
    aws_iam_role_policy_attachment.nat_ssm
  ]
}

# Private EC2 instance for trusted GitHub Actions jobs.
resource "aws_instance" "runner" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.runner_instance_type
  subnet_id              = var.runner_subnet_id
  vpc_security_group_ids = [aws_security_group.runner.id]
  iam_instance_profile   = aws_iam_instance_profile.runner.name

  associate_public_ip_address = false

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-github-runner"
    Role = "GitHubActionsRunner"
  })

  depends_on = [
    aws_iam_role_policy_attachment.runner_ssm,
    aws_route.runner_default
  ]
}

# Route runner-subnet outbound traffic through the NAT instance.
resource "aws_route" "runner_default" {
  route_table_id         = var.runner_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat.primary_network_interface_id
}
