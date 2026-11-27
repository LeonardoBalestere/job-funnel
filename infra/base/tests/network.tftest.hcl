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

run "the_subnet_is_public_and_in_the_chosen_zone" {
  command = plan

  assert {
    condition     = aws_subnet.public.availability_zone == "us-east-1a"
    error_message = "The subnet must be in the chosen availability zone."
  }

  assert {
    condition     = one([for r in aws_route_table.public.route : r.gateway_id if r.cidr_block == "0.0.0.0/0"]) == aws_internet_gateway.main.id
    error_message = "The subnet's default route must go to the internet gateway."
  }
}

run "there_is_no_nat_gateway" {
  command = plan

  assert {
    condition     = alltrue([for r in aws_route_table.public.route : r.nat_gateway_id == null || r.nat_gateway_id == ""])
    error_message = "No route may go through a NAT gateway."
  }
}

run "the_node_security_group_opens_only_80_and_443" {
  command = plan

  assert {
    condition     = toset([for rule in aws_vpc_security_group_ingress_rule.node : rule.from_port]) == toset([80, 443])
    error_message = "Only ports 80 and 443 may be open."
  }

  assert {
    condition     = alltrue([for rule in aws_vpc_security_group_ingress_rule.node : rule.from_port == rule.to_port && rule.ip_protocol == "tcp"])
    error_message = "Each ingress rule must open exactly one TCP port."
  }
}

run "the_default_security_group_allows_nothing" {
  command = plan

  assert {
    condition     = length(aws_default_security_group.main.ingress) == 0 && length(aws_default_security_group.main.egress) == 0
    error_message = "The VPC's default security group must have no rules."
  }
}
