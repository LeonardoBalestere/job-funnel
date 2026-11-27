# The pipeline's identity: GitHub Actions exchanges its OIDC token for this role, with no stored
# AWS keys. The role can push the service images and run a command on the node, which is how
# deployments reach a cluster whose API is not exposed (ADR 0010).

locals {
  github_oidc_host = "token.actions.githubusercontent.com"
}

# One provider per account and URL. If the account already has it, import it; see infra/README.md.
# The thumbprint is not listed: AWS validates GitHub's certificate against its own trusted authorities.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.github_oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "deploy" {
  name        = "${var.name}-deploy"
  description = "Assumed by GitHub Actions on the main branch of ${var.github_repository}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        # Exact match: pull requests, other branches, tags and environments get a different subject.
        StringEquals = {
          "${local.github_oidc_host}:aud" = "sts.amazonaws.com"
          "${local.github_oidc_host}:sub" = "repo:${var.github_repository}:ref:refs/heads/main"
        }
      }
    }]
  })
}

# The registry token, instance lookup and command results cannot be limited to a resource.
resource "aws_iam_role_policy" "deploy" {
  name = "push-images-and-deploy"
  role = aws_iam_role.deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SignInToTheRegistry"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "PushServiceImages"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
        ]
        Resource = [for repository in aws_ecr_repository.service : repository.arn]
      },
      {
        Sid      = "UseTheShellDocument"
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:${data.aws_partition.current.partition}:ssm:${var.region}::document/AWS-RunShellScript"
      },
      {
        Sid       = "SendItToTheNode"
        Effect    = "Allow"
        Action    = "ssm:SendCommand"
        Resource  = "${local.ec2_arn_prefix}:instance/*"
        Condition = { StringEquals = { "ssm:resourceTag/${local.node_tag_key}" = local.node_tag_value } }
      },
      {
        # The auto scaling group replaces the instance, so the pipeline finds its current id by tag.
        Sid      = "FindTheNode"
        Effect   = "Allow"
        Action   = "ec2:DescribeInstances"
        Resource = "*"
      },
      {
        # Lets the pipeline wait for the command and fail when the deployment fails.
        Sid      = "ReadTheCommandResult"
        Effect   = "Allow"
        Action   = "ssm:GetCommandInvocation"
        Resource = "*"
      },
    ]
  })
}
