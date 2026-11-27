terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # The bucket is account-specific and comes from backend.hcl; see infra/README.md.
  # use_lockfile locks the state with an object next to it, so no DynamoDB table is needed.
  backend "s3" {
    key          = "base/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.name
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}
