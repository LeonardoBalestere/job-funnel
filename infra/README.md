# Infrastructure

The permanent environment of [ADR 0010](../docs/adr/0010-single-node-k3s-with-in-cluster-data-stores.md), in Terraform.

| Stack | What it creates | State |
|---|---|---|
| [`bootstrap/`](./bootstrap) | The S3 bucket that holds the state of the other stacks: versioned, encrypted, private, TLS only | Local, run once |
| [`base/`](./base) | Network, the k3s node, its data volume and fixed address, ECR repositories, the API's DNS record, and the pipeline's OIDC deploy role | In the bucket, locked with an S3 lock file |

The identity provider (Cognito, [ADR 0009](../docs/adr/0009-amazon-cognito-as-identity-provider.md)) is not here yet; it arrives with the sign-in work.

## What `base` builds

- **Network.** A VPC with one public subnet in one availability zone and an internet gateway. No NAT gateway. The node's security group opens only TCP 80 and 443; the VPC's default security group is emptied.
- **Node.** An auto scaling group of one spot instance, x86 only, from a list of 8 GB instance types, in the same zone. Ubuntu 24.04, resolved from Canonical's public parameter at every launch. IMDSv2 required, with a hop limit of one so pods cannot reach instance metadata. No SSH key and no SSH port: access is through Session Manager.
- **Persistence.** An encrypted gp3 data volume and an elastic IP, both protected from `terraform destroy`. The start script ([`templates/node-start.sh.tftpl`](./base/templates/node-start.sh.tftpl)) of every new instance associates the address, waits for the volume to be released by the previous instance, attaches and mounts it at `/data`, and installs k3s with `--data-dir /data/k3s`. `/etc/rancher` is also kept on the volume, and the node always registers under the same name, so a replacement instance takes over the existing cluster rather than joining it as a new node.
- **Registry.** One ECR repository per service image (`job-funnel/<image>`), immutable tags, scan on push, and a lifecycle policy that expires untagged images after a day and keeps the 20 most recent.
- **DNS.** An `A` record for the API host in the owner's existing hosted zone, pointing at the elastic IP.
- **Deploy role.** A GitHub OIDC identity provider and a role whose trust requires, by exact match, the audience `sts.amazonaws.com` and the subject `repo:LeonardoBalestere/job-funnel:ref:refs/heads/main`. The role can push to the service repositories and send `AWS-RunShellScript` to the instance tagged `JobFunnelRole=node`, and read that command's result. Nothing else.

A change to the launch template, such as the start script or the k3s channel, replaces the instance through an instance refresh. With one node this means a few minutes of downtime, the same as a spot interruption.

## Tests and checks

Both stacks have `terraform test` suites that plan against a mocked AWS provider, so they need no credentials:

```sh
cd infra/base
terraform init -backend=false
terraform test
```

The `Infrastructure` workflow runs `terraform fmt -check`, `validate` and `test` for both stacks, and Trivy over `infra/`, failing on any high or critical finding. A finding accepted by design is ignored with a `#trivy:ignore:<id>` comment next to the resource, together with the reason.

## Owner setup

Needs the AWS CLI, Terraform 1.10 or later, credentials for the AWS account with administrator rights, and a domain with a public hosted zone in Route 53. If the domain is registered elsewhere, create the hosted zone in Route 53 first and point the registrar's name servers at it.

### 1. Bootstrap the state bucket (once)

```sh
cd infra/bootstrap
terraform init
terraform apply -var region=us-east-1
```

Note the `state_bucket` output. This stack keeps its state in `infra/bootstrap/terraform.tfstate`, which git ignores. Keep that file somewhere safe; if it is lost, the bucket is not affected, and the state can be rebuilt with `terraform import aws_s3_bucket.state <bucket>` and the same for the bucket's other settings.

### 2. Configure `base`

```sh
cd infra/base
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
```

Fill in the bucket and region in `backend.hcl`, and the region, availability zone, hosted zone and API host name in `terraform.tfvars`. Both files are ignored by git.

The account can have only one OIDC provider for `token.actions.githubusercontent.com`. If it already has one, import it before applying:

```sh
terraform import aws_iam_openid_connect_provider.github arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com
```

### 3. Apply

```sh
terraform init -backend-config=backend.hcl
terraform apply
```

The outputs give the API host, the fixed address, the repository URLs and the deploy role's ARN.

### 4. Verify

The instance takes a few minutes to start k3s. Find it and open a Session Manager session (needs the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) for the AWS CLI):

```sh
aws ec2 describe-instances --filters Name=tag:JobFunnelRole,Values=node Name=instance-state-name,Values=running --query 'Reservations[].Instances[].InstanceId' --output text
```

```sh
aws ssm start-session --target <instance-id>
```

Inside the session:

```sh
sudo k3s kubectl get nodes
```

The node `job-funnel` must be `Ready`. If it is not, the start script's log is in `/var/log/job-funnel-node-start.log`.

Then check that the API host resolves to the fixed address:

```sh
dig +short api.example.com
```

```sh
terraform output public_ip
```

To check recovery, terminate the instance from the EC2 console: the auto scaling group starts a replacement, which re-attaches the volume and the address, and `kubectl get nodes` shows the same node `Ready` again.
