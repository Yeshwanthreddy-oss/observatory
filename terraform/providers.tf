terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# AWS provider pointed at LocalStack. Dummy credentials, region overridable,
# credential/metadata validation skipped, and S3 path-style addressing so the
# whole stack runs locally with Docker only (no cloud account, no keys).
provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # Route every AWS service the stack touches to the LocalStack edge port.
  endpoints {
    s3     = var.localstack_endpoint
    ec2    = var.localstack_endpoint
    iam    = var.localstack_endpoint
    ecr    = var.localstack_endpoint
    logs   = var.localstack_endpoint
    lambda = var.localstack_endpoint
    sts    = var.localstack_endpoint
  }
}
