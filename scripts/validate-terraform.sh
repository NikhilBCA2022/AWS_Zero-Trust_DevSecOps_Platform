#!/usr/bin/env bash

set -u

PROJECT_DIR="/mnt/c/Users/admin/OneDrive/Desktop/aws-zero-trust"
TF_DIR="$PROJECT_DIR/terraform/environments/dev"
PROFILE="PowerUserAccess-774609032429"
REGION="ap-south-1"
EXPECTED_ACCOUNT="774609032429"

cd "$PROJECT_DIR" || exit 1

echo "===================================="
echo "AWS ZERO-TRUST SECURITY CHECKS"
echo "===================================="

echo
echo "CHECK 1: AWS identity"

if aws sts get-caller-identity \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query '{Account:Account,Arn:Arn}' \
  --output table; then
  echo "Identity request succeeded."
else
  echo "FAIL: AWS authentication failed."
  echo "If needed, run:"
  echo "aws sso login --profile $PROFILE"
  exit 1
fi

ACCOUNT=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --region "$REGION" \
  --query Account \
  --output text) || exit 1

if [ "$ACCOUNT" != "$EXPECTED_ACCOUNT" ]; then
  echo "FAIL: Unexpected AWS account: $ACCOUNT"
  exit 1
fi

echo
echo "CHECK 2: Terraform formatting"

if terraform fmt -check -recursive terraform/modules terraform/environments/dev; then
  echo "PASS: Terraform formatting"
else
  echo "FAIL: Formatting needs correction."
  echo "Run: terraform fmt -recursive terraform/modules terraform/environments/dev"
  exit 1
fi

echo
echo "CHECK 3: Terraform validation"

if terraform -chdir="$TF_DIR" validate; then
  echo "PASS: Terraform validation"
else
  echo "FAIL: Terraform validation"
  exit 1
fi

echo
echo "CHECK 4: Security configuration review"

echo "--- Security group rules ---"
grep -nE 'ingress|egress|cidr_blocks|security_groups|from_port|to_port' \
  terraform/modules/security/main.tf \
  terraform/modules/endpoints/main.tf || true

echo
echo "--- EC2 hardening ---"
grep -nE 'associate_public_ip_address|http_tokens|encrypted|volume_size|instance_type' \
  terraform/modules/compute/main.tf \
  terraform/modules/compute/variables.tf || true

echo
echo "--- Logging controls ---"
grep -nE 'traffic_type|retention_in_days|actions|resources|principals' \
  terraform/modules/logging/main.tf || true

echo
echo "CHECK 5: Check available static scanners"

if command -v checkov >/dev/null 2>&1; then
  checkov -d terraform/modules --framework terraform --compact
else
  echo "NOTICE: Checkov is not installed; no Checkov scan performed."
fi

if command -v tfsec >/dev/null 2>&1; then
  tfsec terraform/modules
else
  echo "NOTICE: tfsec is not installed; no tfsec scan performed."
fi

echo
echo "CHECK 6: Fresh Terraform plan"

echo "Creating a plan only; no resources will be deployed."

if terraform -chdir="$TF_DIR" plan \
  -input=false \
  -lock-timeout=60s \
  -out=tfplan; then
  echo
  echo "Planned resource changes:"
  terraform -chdir="$TF_DIR" show -no-color tfplan |
    grep -E '^  # |^Plan:' || true
else
  echo "FAIL: Terraform plan failed."
  exit 1
fi

echo
echo "CHECKS FINISHED"
echo "No terraform apply command was executed."
