# Plan-only tests: computed values are unknown during plan unless a default is given here,
# so every value an assertion reads through a reference gets a fixed, realistic default.

mock_data "aws_caller_identity" {
  defaults = {
    account_id = "111122223333"
  }
}

mock_data "aws_partition" {
  defaults = {
    partition = "aws"
  }
}

mock_data "aws_route53_zone" {
  defaults = {
    zone_id = "Z0123456789EXAMPLE"
  }
}

mock_resource "aws_vpc" {
  defaults = {
    id = "vpc-0123456789abcdef0"
  }
}

mock_resource "aws_subnet" {
  defaults = {
    id = "subnet-0123456789abcdef0"
  }
}

mock_resource "aws_security_group" {
  defaults = {
    id = "sg-0123456789abcdef0"
  }
}

mock_resource "aws_eip" {
  defaults = {
    id        = "eipalloc-0123456789abcdef0"
    arn       = "arn:aws:ec2:us-east-1:111122223333:elastic-ip/eipalloc-0123456789abcdef0"
    public_ip = "203.0.113.10"
  }
}

mock_resource "aws_ebs_volume" {
  defaults = {
    id  = "vol-0123456789abcdef0"
    arn = "arn:aws:ec2:us-east-1:111122223333:volume/vol-0123456789abcdef0"
  }
}

mock_resource "aws_ecr_repository" {
  defaults = {
    arn = "arn:aws:ecr:us-east-1:111122223333:repository/job-funnel/funnel-api"
  }
}

mock_resource "aws_iam_openid_connect_provider" {
  defaults = {
    arn = "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com"
  }
}

mock_resource "aws_iam_role" {
  defaults = {
    arn = "arn:aws:iam::111122223333:role/job-funnel"
  }
}

mock_resource "aws_iam_instance_profile" {
  defaults = {
    arn = "arn:aws:iam::111122223333:instance-profile/job-funnel-node"
  }
}

mock_resource "aws_launch_template" {
  defaults = {
    id             = "lt-0123456789abcdef0"
    latest_version = 1
  }
}

mock_resource "aws_internet_gateway" {
  defaults = {
    id = "igw-0123456789abcdef0"
  }
}
