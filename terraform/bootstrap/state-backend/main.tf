terraform {
  required_version = ">= 1.7.5, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}

provider "aws" {
  region  = "ap-south-1"
  profile = "PowerUserAccess-774609032429"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "aws-zero-trust-tfstate-774609032429-ap-south-1"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "aws-zero-trust-terraform-state"
    Project   = "aws-zero-trust-platform"
    ManagedBy = "Terraform"
    Purpose   = "TerraformState"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "aws-zero-trust-tfstate-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "aws-zero-trust-terraform-locks"
    Project   = "aws-zero-trust-platform"
    ManagedBy = "Terraform"
    Purpose   = "TerraformStateLocking"
  }
}

output "state_bucket_name" {
  description = "S3 bucket used for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "lock_table_name" {
  description = "DynamoDB table used for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}
