module "network" {
  source = "../../modules/network"

  project_name          = var.project_name
  environment           = var.environment
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs

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
    module.eks.cluster_security_group_id
  ]
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
}
