output "api_hostname" {
  description = "Host name of the API."
  value       = aws_route53_record.api.fqdn
}

output "public_ip" {
  description = "The node's fixed public address."
  value       = aws_eip.node.public_ip
}

output "node_autoscaling_group" {
  description = "Auto scaling group of the node; its one instance is the Session Manager target."
  value       = aws_autoscaling_group.node.name
}

output "data_volume_id" {
  description = "The persistent data volume."
  value       = aws_ebs_volume.data.id
}

output "repository_urls" {
  description = "ECR repository URL per service image."
  value       = { for image, repository in aws_ecr_repository.service : image => repository.repository_url }
}

output "deploy_role_arn" {
  description = "Role the pipeline assumes through GitHub OIDC."
  value       = aws_iam_role.deploy.arn
}
