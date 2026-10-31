module "network" {
  source = "../../modules/network"

  project_name          = var.project_name
  environment           = var.environment
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
  runner_subnet_cidr    = var.runner_subnet_cidr
  runner_subnet_az      = var.runner_subnet_az

  name_prefix = local.name_prefix
  common_tags = local.common_tags

}

module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  environment  = var.environment
  name_prefix  = local.name_prefix
  common_tags  = local.common_tags

  vpc_id = module.network.vpc_id
}

module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment
  name_prefix  = local.name_prefix
  common_tags  = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
  environment  = var.environment
  name_prefix  = local.name_prefix
  common_tags  = local.common_tags

  subnet_id = module.network.private_subnet_ids[0]

  security_group_id = module.security.baseline_security_group_id

  instance_profile_name = module.iam.ssm_instance_profile_name

  instance_type = var.instance_type
}

module "endpoints" {
  source = "../../modules/endpoints"

  project_name       = var.project_name
  environment        = var.environment
  name_prefix        = local.name_prefix
  common_tags        = local.common_tags
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  private_route_table_id = module.network.private_route_table_id

  endpoint_client_security_group_ids = [
    module.security.baseline_security_group_id,
    module.eks.cluster_security_group_id,
    module.runner.runner_security_group_id,
    module.runner.nat_security_group_id
  ]
  runner_route_table_id = module.network.runner_route_table_id
}

module "logging" {
  source = "../../modules/logging"

  project_name = var.project_name
  environment  = var.environment
  name_prefix  = local.name_prefix
  common_tags  = local.common_tags

  vpc_id = module.network.vpc_id

  log_retention_days = 30
}

module "ecr" {
  source = "../../modules/ecr"

  name_prefix = local.name_prefix
  common_tags = local.common_tags
}
module "eks" {
  source = "../../modules/eks"

  name_prefix                  = local.name_prefix
  common_tags                  = local.common_tags
  cluster_version              = "1.36"
  vpc_id                       = module.network.vpc_id
  private_subnet_ids           = module.network.private_subnet_ids
  endpoint_public_access_cidrs = var.eks_endpoint_public_access_cidrs
}
module "rds" {
  source = "../../modules/rds"

  name_prefix               = local.name_prefix
  common_tags               = local.common_tags
  vpc_id                    = module.network.vpc_id
  database_subnet_ids       = module.network.database_subnet_ids
  allowed_security_group_id = module.eks.cluster_security_group_id
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  name_prefix       = local.name_prefix
  common_tags       = local.common_tags
  github_owner      = var.github_owner
  github_repository = var.github_repository
  github_branch     = var.github_branch

  ecr_repository_arn = module.ecr.repository_arn
  eks_cluster_name   = module.eks.cluster_name
  eks_cluster_arn    = module.eks.cluster_arn
}


module "edge" {
  source = "../../modules/edge"

  name_prefix         = local.name_prefix
  common_tags         = local.common_tags
  eks_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  database_secret_arn = module.rds.db_master_user_secret_arn
}


module "runner" {
  source = "../../modules/runner"

  name_prefix           = local.name_prefix
  common_tags           = local.common_tags
  vpc_id                = module.network.vpc_id
  vpc_cidr              = module.network.vpc_cidr
  public_subnet_id      = module.network.public_subnet_ids[0]
  runner_subnet_id      = module.network.runner_subnet_id
  runner_route_table_id = module.network.runner_route_table_id
  nat_instance_type     = var.nat_instance_type
  runner_instance_type  = var.runner_instance_type
}
# Allow the private GitHub Actions runner to reach the EKS Kubernetes API.
resource "aws_vpc_security_group_ingress_rule" "runner_to_eks_api" {
  security_group_id            = module.eks.cluster_security_group_id
  referenced_security_group_id = module.runner.runner_security_group_id

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  description = "Allow private GitHub Actions runner to access EKS API"
}
# Allow the private runner to authenticate to the EKS cluster.
resource "aws_eks_access_entry" "runner" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.runner.runner_role_arn
  type          = "STANDARD"

  tags = local.common_tags
}

# Grant read-only Kubernetes access to the private runner.
resource "aws_eks_access_policy_association" "runner_view" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.runner.runner_role_arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [
    aws_eks_access_entry.runner
  ]
}