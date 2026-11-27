mock_provider "aws" {
  override_during = plan

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      id  = "job-funnel-tfstate-111122223333"
      arn = "arn:aws:s3:::job-funnel-tfstate-111122223333"
    }
  }
}

variables {
  region = "us-east-1"
}

run "the_state_bucket_is_named_after_the_account" {
  command = plan

  assert {
    condition     = aws_s3_bucket.state.bucket == "job-funnel-tfstate-111122223333"
    error_message = "The bucket name must carry the account id."
  }
}

run "the_state_is_versioned_encrypted_and_private" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "State versions must be kept."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.state.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "State must be encrypted at rest."
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.state.block_public_acls,
      aws_s3_bucket_public_access_block.state.block_public_policy,
      aws_s3_bucket_public_access_block.state.ignore_public_acls,
      aws_s3_bucket_public_access_block.state.restrict_public_buckets,
    ])
    error_message = "All public access must be blocked."
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.state.policy).Statement[0].Condition.Bool["aws:SecureTransport"] == "false" && jsondecode(aws_s3_bucket_policy.state.policy).Statement[0].Effect == "Deny"
    error_message = "Requests without TLS must be denied."
  }
}
