terraform {
  backend "s3" {
    bucket         = "aws-zero-trust-tfstate-774609032429-ap-south-1"
    key            = "aws-zero-trust/dev/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "aws-zero-trust-tfstate-locks"
  }
}