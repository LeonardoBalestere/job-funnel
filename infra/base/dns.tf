# The owner's domain already has a public hosted zone; see infra/README.md if it is registered elsewhere.
data "aws_route53_zone" "owner" {
  name         = var.hosted_zone_name
  private_zone = false
}

resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.owner.zone_id
  name    = var.api_hostname
  type    = "A"
  ttl     = 300
  records = [aws_eip.node.public_ip]
}
