# One public subnet in one zone, and no NAT gateway: the node reaches the internet through its own
# public address, and nothing reaches the node except ports 80 and 443 (ADR 0010).

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.name
  }
}

# Takes over the VPC's default security group and leaves it without rules, so nothing that falls
# back to it is reachable.
resource "aws_default_security_group" "main" {
  vpc_id  = aws_vpc.main.id
  ingress = []
  egress  = []

  tags = {
    Name = "${var.name}-default-unused"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = var.name
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  availability_zone = var.availability_zone
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 0)

  # The launch template asks for a public address on the node's interface instead, so nothing
  # else launched here gets one by accident.
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "node" {
  name        = "${var.name}-node"
  description = "The k3s node: HTTP and HTTPS in, anything out"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.name}-node"
  }
}

# The ingress controller serves the API to the public internet and answers the certificate
# authority's HTTP challenge, so both ports are open to every address by design.
resource "aws_vpc_security_group_ingress_rule" "node" {
  for_each = {
    http  = 80
    https = 443
  }

  security_group_id = aws_security_group.node.id
  description       = upper(each.key)
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value
  cidr_ipv4         = "0.0.0.0/0"
}

# Without a NAT gateway or VPC endpoints, the node reaches image registries, Systems Manager and
# the AWS APIs over the internet, at addresses that cannot be listed in advance.
#trivy:ignore:AVD-AWS-0104
resource "aws_vpc_security_group_egress_rule" "node_all" {
  security_group_id = aws_security_group.node.id
  description       = "Anything out"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
