mock_provider "aws" {
  source          = "./tests/mocks"
  override_during = plan
}

variables {
  region            = "us-east-1"
  availability_zone = "us-east-1a"
  hosted_zone_name  = "example.com"
  api_hostname      = "api.example.com"
}

run "the_api_host_points_at_the_fixed_address" {
  command = plan

  assert {
    condition     = aws_route53_record.api.name == "api.example.com" && aws_route53_record.api.type == "A"
    error_message = "The API host must have an A record."
  }

  assert {
    condition     = aws_route53_record.api.zone_id == "Z0123456789EXAMPLE"
    error_message = "The record must be in the owner's hosted zone."
  }

  assert {
    condition     = toset(aws_route53_record.api.records) == toset(["203.0.113.10"])
    error_message = "The record must point at the fixed address."
  }
}

run "the_api_host_must_be_inside_the_zone" {
  command = plan

  variables {
    api_hostname = "api.example.org"
  }

  expect_failures = [var.api_hostname]
}
