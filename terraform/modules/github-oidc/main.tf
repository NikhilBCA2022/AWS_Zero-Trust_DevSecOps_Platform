resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  # GitHub's OIDC endpoint certificate thumbprint.
  # Verify against current AWS/GitHub guidance before deployment.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-github-oidc"
  })
}

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_owner}/${var.github_repository}:ref:refs/heads/${var.github_branch}"
      ]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name                 = "${var.name_prefix}-github-deploy-role"
  assume_role_policy   = data.aws_iam_policy_document.github_assume_role.json
  max_session_duration = 3600

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-github-deploy-role"
  })
}

data "aws_iam_policy_document" "github_deploy_permissions" {
  statement {
    sid    = "AuthenticateToECR"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PublishImagesToProjectRepository"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories"
    ]

    resources = [var.ecr_repository_arn]
  }

  statement {
    sid    = "DescribeDeploymentCluster"
    effect = "Allow"

    actions = [
      "eks:DescribeCluster"
    ]

    resources = [var.eks_cluster_arn]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "${var.name_prefix}-github-deploy-policy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy_permissions.json
}

resource "aws_eks_access_entry" "github" {
  cluster_name  = var.eks_cluster_name
  principal_arn = aws_iam_role.github_deploy.arn
  type          = "STANDARD"

  tags = var.common_tags
}

resource "aws_eks_access_policy_association" "github_cloud_ops_namespace" {
  cluster_name  = var.eks_cluster_name
  principal_arn = aws_iam_role.github_deploy.arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type = "namespace"

    namespaces = [
      "cloud-ops"
    ]
  }

  depends_on = [
    aws_eks_access_entry.github
  ]
}
