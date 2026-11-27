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

run "there_is_one_repository_per_service_image" {
  command = plan

  assert {
    condition     = toset([for r in aws_ecr_repository.service : r.name]) == toset(["job-funnel/catalog-api", "job-funnel/catalog-worker", "job-funnel/funnel-api", "job-funnel/dashboard-api"])
    error_message = "Each service image must have its own repository."
  }

  assert {
    condition     = alltrue([for r in aws_ecr_repository.service : r.image_tag_mutability == "IMMUTABLE" && r.image_scanning_configuration[0].scan_on_push])
    error_message = "Tags must be immutable and images scanned on push."
  }
}

run "every_repository_has_a_lifecycle_policy" {
  command = plan

  assert {
    condition     = keys(aws_ecr_lifecycle_policy.service) == keys(aws_ecr_repository.service)
    error_message = "Every repository must have a lifecycle policy."
  }

  assert {
    condition = alltrue([
      for p in aws_ecr_lifecycle_policy.service :
      [for rule in jsondecode(p.policy).rules : rule.selection.tagStatus] == ["untagged", "any"]
      && jsondecode(p.policy).rules[1].selection.countNumber == var.image_retention_count
    ])
    error_message = "Untagged images must expire first, then all but the most recent ones."
  }
}
