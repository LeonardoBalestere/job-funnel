# Creates the bucket that keeps the Terraform state of every other stack. It cannot keep its own
# state there before the bucket exists, so this stack runs once with local state; see infra/README.md.

terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "region" {
  description = "AWS region of the state bucket; the same as the permanent environment's."
  type        = string
}

variable "name" {
  description = "Project name, used as the bucket name prefix."
  type        = string
  default     = "job-funnel"
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

# Bucket names are global; the account id keeps this one unique.
resource "aws_s3_bucket" "state" {
  bucket = "${var.name}-tfstate-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Every state write is a new version, so a broken apply can be rolled back.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3. Access to the state is controlled by IAM; a customer-managed key would add a monthly
# charge and a key policy to maintain without narrowing who can read it.
#trivy:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id

  # The public access block must exist first, or the policy could briefly be evaluated without it.
  depends_on = [aws_s3_bucket_public_access_block.state]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

output "state_bucket" {
  description = "Name of the state bucket, for infra/base/backend.hcl."
  value       = aws_s3_bucket.state.bucket
}
