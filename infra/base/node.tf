# The single k3s node (ADR 0010): one spot instance in an auto scaling group of one, pinned to one
# zone. Everything that must survive an interruption lives on the data volume and behind the
# fixed address, which every new instance re-attaches when it starts.

locals {
  # Tags the node's instance and interface, so the node role and the deploy role can be limited to them.
  node_tag_key   = "JobFunnelRole"
  node_tag_value = "node"
  node_tag       = { (local.node_tag_key) = local.node_tag_value }
  node_tags      = merge(local.node_tag, { Name = var.name, Project = var.name })

  node_user_data = templatefile("${path.module}/templates/node-start.sh.tftpl", {
    region        = var.region
    volume_id     = aws_ebs_volume.data.id
    allocation_id = aws_eip.node.id
    node_name     = var.name
    k3s_channel   = var.k3s_channel
  })

  ec2_arn_prefix = "arn:${data.aws_partition.current.partition}:ec2:${var.region}:${data.aws_caller_identity.current.account_id}"
}

resource "aws_ebs_volume" "data" {
  availability_zone = var.availability_zone
  size              = var.data_volume_size_gb
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.name}-data"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_eip" "node" {
  domain = "vpc"

  tags = {
    Name = var.name
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_launch_template" "node" {
  name        = "${var.name}-node"
  description = "The k3s node"

  # Resolved by EC2 at every launch, so a replacement instance starts from the current image.
  image_id = "resolve:ssm:/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"

  user_data = base64encode(local.node_user_data)

  iam_instance_profile {
    arn = aws_iam_instance_profile.node.arn
  }

  # The interface needs a public address at launch to reach the AWS APIs before the fixed address
  # replaces it; there is no NAT gateway or VPC endpoint to reach them otherwise.
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = [aws_security_group.node.id]
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    # One hop: the host reaches instance metadata, pods behind the node's NAT do not.
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.root_volume_size_gb
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.node_tags
  }

  tag_specifications {
    resource_type = "network-interface"
    tags          = local.node_tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${var.name}-root", Project = var.name }
  }
}

resource "aws_autoscaling_group" "node" {
  name                = "${var.name}-node"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = [aws_subnet.public.id]
  health_check_type   = "EC2"

  # The data volume attaches to one instance at a time, so a replacement launched before the old
  # instance is gone would only wait for it.
  capacity_rebalance = false

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "price-capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.node.id
        version            = aws_launch_template.node.latest_version
      }

      dynamic "override" {
        for_each = var.instance_types

        content {
          instance_type = override.value
        }
      }
    }
  }

  # A change to the launch template replaces the instance. With one instance there is no capacity
  # to keep during the replacement, so the old one is terminated first and its volume released.
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 0
    }
  }

  tag {
    key                 = "Name"
    value               = var.name
    propagate_at_launch = false
  }
}

resource "aws_iam_role" "node" {
  name = "${var.name}-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.name}-node"
  role = aws_iam_role.node.name
}

# Session Manager replaces SSH, and Run Command carries the deployments.
resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Describe calls and the registry token cannot be limited to a resource.
resource "aws_iam_role_policy" "node" {
  name = "start-and-pull"
  role = aws_iam_role.node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "FindTheVolumeAndTheAddress"
        Effect   = "Allow"
        Action   = ["ec2:DescribeVolumes", "ec2:DescribeAddresses"]
        Resource = "*"
      },
      {
        Sid      = "AttachTheDataVolume"
        Effect   = "Allow"
        Action   = "ec2:AttachVolume"
        Resource = aws_ebs_volume.data.arn
      },
      {
        Sid       = "AttachToTheNode"
        Effect    = "Allow"
        Action    = "ec2:AttachVolume"
        Resource  = "${local.ec2_arn_prefix}:instance/*"
        Condition = { StringEquals = { "aws:ResourceTag/${local.node_tag_key}" = local.node_tag_value } }
      },
      {
        Sid      = "AssociateTheFixedAddress"
        Effect   = "Allow"
        Action   = "ec2:AssociateAddress"
        Resource = aws_eip.node.arn
      },
      {
        Sid    = "AssociateWithTheNode"
        Effect = "Allow"
        Action = "ec2:AssociateAddress"
        Resource = [
          "${local.ec2_arn_prefix}:instance/*",
          "${local.ec2_arn_prefix}:network-interface/*",
        ]
        Condition = { StringEquals = { "aws:ResourceTag/${local.node_tag_key}" = local.node_tag_value } }
      },
      {
        Sid      = "SignInToTheRegistry"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid      = "PullServiceImages"
        Effect   = "Allow"
        Action   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
        Resource = [for repository in aws_ecr_repository.service : repository.arn]
      },
    ]
  })
}
