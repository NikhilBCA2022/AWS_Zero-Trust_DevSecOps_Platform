# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.name_prefix}/flow-logs"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-vpc-flow-logs"
  })
}

# IAM policy document allowing VPC Flow Logs to assume the role
data "aws_iam_policy_document" "flow_logs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

# IAM role for VPC Flow Logs
resource "aws_iam_role" "flow_logs" {
  name               = "${var.name_prefix}-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role.json

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-flow-logs-role"
  })
}

# Permissions to publish records to the dedicated log group
data "aws_iam_policy_document" "flow_logs_permissions" {
  statement {
    sid    = "AllowCloudWatchLogPublishing"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]

    resources = [
      "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
    ]
  }
}

# IAM policy for the role
resource "aws_iam_policy" "flow_logs" {
  name        = "${var.name_prefix}-flow-logs-policy"
  description = "Allow VPC Flow Logs to publish to its CloudWatch Log Group"

  policy = data.aws_iam_policy_document.flow_logs_permissions.json

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-flow-logs-policy"
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "flow_logs" {
  role       = aws_iam_role.flow_logs.name
  policy_arn = aws_iam_policy.flow_logs.arn
}

# Capture all VPC traffic metadata and publish it to CloudWatch Logs
resource "aws_flow_log" "vpc" {
  vpc_id               = var.vpc_id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs.arn

  depends_on = [
    aws_iam_role_policy_attachment.flow_logs
  ]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-vpc-flow-log"
  })
}