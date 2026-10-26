provider "aws" {
  region  = var.aws_region
  profile = "PowerUserAccess-774609032429"

  default_tags {
    tags = {
      Project     = "AWS-Zero-Trust-Platform"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}