locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "Zero-Trust-Network"
  }

  availability_zones = {
    for index, az in var.availability_zones : index => az
  }

  public_subnet_cidrs = {
    for index, cidr in var.public_subnet_cidrs : index => cidr
  }

  private_subnet_cidrs = {
    for index, cidr in var.private_subnet_cidrs : index => cidr
  }
}