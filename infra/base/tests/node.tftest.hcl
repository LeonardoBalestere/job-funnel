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

run "the_node_is_one_spot_instance_in_the_chosen_zone" {
  command = plan

  assert {
    condition     = aws_autoscaling_group.node.min_size == 1 && aws_autoscaling_group.node.max_size == 1 && aws_autoscaling_group.node.desired_capacity == 1
    error_message = "The auto scaling group must hold exactly one instance."
  }

  assert {
    condition     = toset(aws_autoscaling_group.node.vpc_zone_identifier) == toset([aws_subnet.public.id])
    error_message = "The auto scaling group must launch only into the subnet of the chosen zone."
  }

  assert {
    condition = alltrue([
      for d in aws_autoscaling_group.node.mixed_instances_policy[0].instances_distribution :
      d.on_demand_base_capacity == 0 && d.on_demand_percentage_above_base_capacity == 0
    ])
    error_message = "The instance must be spot only."
  }

  assert {
    condition = toset([
      for o in aws_autoscaling_group.node.mixed_instances_policy[0].launch_template[0].override : o.instance_type
    ]) == toset(var.instance_types)
    error_message = "The instance types must be the configured ones."
  }
}

run "the_node_requires_imdsv2_and_runs_an_x86_image" {
  command = plan

  assert {
    condition     = aws_launch_template.node.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required."
  }

  assert {
    condition     = aws_launch_template.node.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "Instance metadata must not be reachable from pods."
  }

  assert {
    condition     = startswith(aws_launch_template.node.image_id, "resolve:ssm:") && strcontains(aws_launch_template.node.image_id, "/amd64/")
    error_message = "The image must be resolved from the x86 Ubuntu parameter."
  }
}

run "the_node_has_no_ssh_key_and_is_a_managed_node" {
  command = plan

  assert {
    condition     = aws_launch_template.node.key_name == null
    error_message = "The node must not have an SSH key pair."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.node_ssm.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "The node must be a Systems Manager managed node."
  }

  assert {
    condition     = jsondecode(aws_iam_role.node.assume_role_policy).Statement[0].Principal.Service == "ec2.amazonaws.com"
    error_message = "Only EC2 may assume the node role."
  }
}

run "the_data_volume_and_the_address_are_persistent" {
  command = plan

  assert {
    condition     = aws_ebs_volume.data.availability_zone == "us-east-1a" && aws_ebs_volume.data.encrypted
    error_message = "The data volume must be encrypted and in the node's zone."
  }

  assert {
    condition     = aws_eip.node.domain == "vpc"
    error_message = "The fixed address must be a VPC elastic IP."
  }
}

run "the_node_reattaches_its_volume_and_address_and_keeps_k3s_on_the_volume" {
  command = plan

  assert {
    condition     = strcontains(local.node_user_data, "vol-0123456789abcdef0") && strcontains(local.node_user_data, "eipalloc-0123456789abcdef0")
    error_message = "The start script must re-attach this data volume and this address."
  }

  assert {
    condition     = strcontains(local.node_user_data, "data-dir: /data/k3s") && strcontains(local.node_user_data, "node-name: job-funnel")
    error_message = "k3s must keep its data on the volume under a fixed node name."
  }
}

run "the_node_may_attach_only_its_own_volume_and_address" {
  command = plan

  assert {
    condition = toset(flatten([
      for s in jsondecode(aws_iam_role_policy.node.policy).Statement : s.Resource if contains(flatten([s.Action]), "ec2:AttachVolume")
    ])) == toset([aws_ebs_volume.data.arn, "arn:aws:ec2:us-east-1:111122223333:instance/*"])
    error_message = "The node may attach only the data volume, to a node instance."
  }

  assert {
    condition = toset(flatten([
      for s in jsondecode(aws_iam_role_policy.node.policy).Statement : s.Resource if contains(flatten([s.Action]), "ec2:AssociateAddress")
    ])) == toset([aws_eip.node.arn, "arn:aws:ec2:us-east-1:111122223333:instance/*", "arn:aws:ec2:us-east-1:111122223333:network-interface/*"])
    error_message = "The node may associate only the fixed address, with a node instance."
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.node.policy).Statement :
      s.Condition.StringEquals["aws:ResourceTag/JobFunnelRole"] == "node"
      if anytrue([for r in flatten([s.Resource]) : endswith(r, "/*")])
    ])
    error_message = "Instances and interfaces must be limited to the ones tagged as the node."
  }
}
