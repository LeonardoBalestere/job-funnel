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

run "github_is_the_identity_provider_for_sts" {
  command = plan

  assert {
    condition     = aws_iam_openid_connect_provider.github.url == "https://token.actions.githubusercontent.com"
    error_message = "The identity provider must be GitHub Actions."
  }

  assert {
    condition     = toset(aws_iam_openid_connect_provider.github.client_id_list) == toset(["sts.amazonaws.com"])
    error_message = "Tokens must be issued for STS only."
  }
}

run "only_the_main_branch_of_this_repository_may_assume_the_deploy_role" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role.deploy.assume_role_policy).Statement[0].Principal.Federated == aws_iam_openid_connect_provider.github.arn
    error_message = "The deploy role must trust the GitHub identity provider."
  }

  assert {
    condition     = jsondecode(aws_iam_role.deploy.assume_role_policy).Statement[0].Action == "sts:AssumeRoleWithWebIdentity"
    error_message = "The deploy role must be assumed with a web identity."
  }

  assert {
    condition = jsondecode(aws_iam_role.deploy.assume_role_policy).Statement[0].Condition == {
      StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        "token.actions.githubusercontent.com:sub" = "repo:LeonardoBalestere/job-funnel:ref:refs/heads/main"
      }
    }
    error_message = "Trust must be restricted, by exact match, to the main branch of this repository."
  }

  assert {
    condition     = length(jsondecode(aws_iam_role.deploy.assume_role_policy).Statement) == 1
    error_message = "The trust policy must have no other statement."
  }
}

run "the_deploy_role_may_only_push_images_and_send_the_remote_command" {
  command = plan

  assert {
    condition = toset(flatten([
      for s in jsondecode(aws_iam_role_policy.deploy.policy).Statement : s.Action
      ])) == toset([
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ssm:SendCommand",
      "ssm:GetCommandInvocation",
    ])
    error_message = "The deploy role must be able to push images and send the remote command, and nothing else."
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.deploy.policy).Statement : s.Effect == "Allow" && !can(s.NotAction) && !can(s.NotResource)
    ])
    error_message = "The deploy policy must be a plain allow list."
  }
}

run "images_are_pushed_only_to_the_service_repositories" {
  command = plan

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.deploy.policy).Statement :
      toset(flatten([s.Resource])) == toset([for r in aws_ecr_repository.service : r.arn])
      if contains(flatten([s.Action]), "ecr:PutImage")
    ])
    error_message = "Images may be pushed only to the service repositories."
  }
}

run "the_remote_command_runs_only_the_shell_document_on_the_node" {
  command = plan

  assert {
    condition = toset(flatten([
      for s in jsondecode(aws_iam_role_policy.deploy.policy).Statement : s.Resource if contains(flatten([s.Action]), "ssm:SendCommand")
    ])) == toset(["arn:aws:ssm:us-east-1::document/AWS-RunShellScript", "arn:aws:ec2:us-east-1:111122223333:instance/*"])
    error_message = "The command may use only the shell document, on instances."
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.deploy.policy).Statement :
      s.Condition.StringEquals["ssm:resourceTag/JobFunnelRole"] == "node"
      if contains(flatten([s.Resource]), "arn:aws:ec2:us-east-1:111122223333:instance/*")
    ])
    error_message = "The command may target only the instance tagged as the node."
  }
}
