data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"

      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "ssm_instance" {
  name               = "${var.name_prefix}-ssm-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ssm-instance-role"
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance" {
  name = "${var.name_prefix}-ssm-instance-profile"
  role = aws_iam_role.ssm_instance.name

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ssm-instance-profile"
  })
}
