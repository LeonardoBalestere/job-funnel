---
status: accepted
---

# Single-node k3s on a spot instance, with data stores in the cluster

The permanent environment is k3s on one spot instance, with SQL Server, MongoDB, RabbitMQ and Redis running as pods on a persistent volume. A managed Kubernetes cluster costs several times more per month before any workload runs, and managed versions of each data store multiply that again. Everything is provisioned with Terraform, including a managed cluster that is created on demand and destroyed afterwards.

## Consequences

- Spot interruptions cause minutes of downtime. The instance runs in an auto scaling group of one, pinned to one availability zone, and re-attaches its data volume and fixed address on start.
- Durability depends on backups, not on replication: hourly SQL Server log backups and daily full backups to object storage, with restores tested.
- There is no load balancer and no NAT gateway. The cluster's ingress controller terminates TLS, and only ports 80 and 443 are open.
- The pipeline cannot reach the cluster API. Deployment runs Helm on the instance through the cloud provider's remote command service.
- Memory is tight: the node cannot run two versions of everything at once during a deployment.
- SQL Server rules out ARM instances, and must be the Express edition because the system is in real use.
