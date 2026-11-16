# Architecture

Job Funnel tracks a job search: postings found by a daily automated search or added by hand, the owner's progress on each one, the skills those postings ask for, and how the search is performing.

The system has one real user and a public demonstration mode. Its distributed shape is deliberate; see [ADR 0001](./adr/0001-distributed-architecture-as-a-deliberate-choice.md).

Code is written in English. The user interface is bilingual, Portuguese and English.

## Overview

```
Search agent ──MCP/OAuth──┐
                          v
Web app ──REST──────> Catalog (API + worker) ── MongoDB
   │                      │
   │                      │ PostingCataloged, PostingRecataloged,
   │                      │ TaxonomyChanged
   │                      v
   │                  RabbitMQ ───────────────┐
   │                      │                   │
   │                      v                   v
   ├──REST + SignalR──> Funnel ── SQL Server  Dashboard ── MongoDB + Redis
   │                      │                   ^
   │                      └─ OpportunityStatusChanged
   └──REST────────────────────────────────────> Dashboard

Scheduler ──> Reminders function ──REST──> Funnel
                     └──> email
```

## Services

| Service | Responsibility | Data |
|---|---|---|
| **Catalog** | The single entry point for job postings, from the search agent and from manual entry. Stores postings, detects duplicates, normalizes terms and channels against the taxonomy, exposes curation, and recatalogs postings when the taxonomy changes. Runs as two processes: an API and a worker. | MongoDB |
| **Funnel** | Creates an opportunity when a posting is cataloged and keeps a snapshot of its display fields. Owns status, transitions, notes, discard reasons, follow-ups and reminder settings. Hosts the real-time hub. | SQL Server |
| **Dashboard** | Maintains one timeline per opportunity from the events of the other two services and computes the metrics by aggregation. | MongoDB, with Redis as a cache |
| **Reminders** | A scheduled function. Triggers deadline processing in Funnel, fetches the opportunities due for a follow-up and sends the reminder email. Holds no domain rules and no data. | none |

Each service's vocabulary is defined in its own `CONTEXT.md`; see the [context map](../CONTEXT-MAP.md). Fields and rules are in the [domain model](./domain-model.md).

## Rules that hold everywhere

- A service never reads another service's data store.
- Services inside the cluster communicate only through events. There are no synchronous calls between them.
- Every posting enters through Catalog. Funnel never creates an opportunity on its own.
- Every event is published through an outbox, and the outbox doubles as the permanent event log.
- Every event carries an id, the tenant, the time it occurred and the version of the aggregate it describes.
- Every consumer is idempotent: the record that an event was processed is written in the same transaction as its effect.
- Every table, collection, event and cache key carries the tenant.

## Events

| Event | Producer | Consumers | Carries |
|---|---|---|---|
| `PostingCataloged` | Catalog | Funnel, Dashboard | The full posting snapshot: title, company, link, channel, origin, work mode, level, fit assessment, canonical terms |
| `PostingRecataloged` | Catalog | Funnel, Dashboard | The same snapshot, after a taxonomy change or a duplicate merge |
| `TaxonomyChanged` | Catalog | Dashboard | Term, category and coverage |
| `OpportunityStatusChanged` | Funnel | Dashboard | Previous and new status, discard reason, date, actor, and whether earlier transitions were voided |

Events are fat on purpose: a consumer never has to call back to the producer.

## Messaging

- One topic exchange for domain events, one durable queue per consuming service.
- Publisher confirms on the producer side, manual acknowledgement on the consumer side.
- Failed messages are retried with increasing delay through delay queues. After the retry limit a message goes to a dead-letter queue, which raises an alert.
- Trace context travels in message headers, so one trace follows a posting from the search agent to the screen.
- A separate replay queue carries re-published events when a consumer rebuilds its data.

## Search agent interface (MCP)

The daily search and the fit assessment are performed by an LLM agent outside this system. It reaches Catalog through an MCP server.

| Tool | Purpose |
|---|---|
| `list_posting_ids` | Ids and aliases of every known posting, so the agent does not resubmit them |
| `read_taxonomy` | Canonical terms, their spellings and the known channels |
| `submit_postings` | A batch of postings with fit assessment, channel, origin and classified terms |
| `suggest_mapping` | A proposed mapping for an unknown spelling or channel, stored as a mapping suggestion |

The tools are append-only. They cannot read notes or salary, cannot change an opportunity, and cannot alter an existing posting. The server enforces schema validation, a batch size limit and a daily quota, because the agent reads untrusted web pages and email.

## Identity and tenancy

- One identity provider issues tokens for three kinds of caller: the owner (authorization code with PKCE), the search agent (a scope limited to ingestion) and the Reminders function (client credentials).
- Every request resolves to a tenant. An anonymous request resolves to the demonstration tenant, which is read-only and rate-limited.
- The demonstration tenant holds fictitious data and is served by the same API as the real one.

## Web app

The web app lives in a separate repository, as a lazy-loaded route of the owner's personal site (Angular), and is hosted apart from the backend. It follows the site's theme and language switch.

The backend API is versioned under `/v1` and publishes an OpenAPI document from its pipeline. The web app generates its request and response types from that document, so a breaking change in the API fails the web app's build.

## Infrastructure

| Concern | Choice |
|---|---|
| Cluster | k3s on a single spot instance, in an auto scaling group of one pinned to one availability zone. On start the instance re-attaches its data volume and its fixed address. |
| Data stores | SQL Server Express, MongoDB (single-node replica set), RabbitMQ and Redis run as pods on the data volume |
| Backups | SQL Server log backups hourly and full backups daily, MongoDB daily, all to object storage. A tested restore is part of the definition of done for the first release. |
| Ingress | The cluster's own ingress controller with automatically issued certificates. Only ports 80 and 443 are open. |
| Network | Public subnet guarded by security groups, no NAT gateway |
| Provisioning | Terraform for everything, including a managed Kubernetes cluster that is created on demand for demonstrations and receives only the demonstration tenant |
| Deployment | Helm, run on the instance through the cloud provider's remote command service, authorized by the pipeline's OIDC role |
| Database migrations | Run as a pipeline step before deployment, never at service start-up |
| Secrets | Kept in the cloud parameter store and injected at deployment |
| Scheduling and email | A scheduler triggers the Reminders function, which sends through the cloud email service |

Differences between the single-node cluster and the managed one, such as storage classes and ingress, live in per-environment Helm values. There is one environment; there is no staging.

## Technology

| Area | Technology |
|---|---|
| Runtime | .NET 10, ASP.NET Core |
| Relational data | SQL Server Express; EF Core for writes, Dapper for reads |
| Document data | MongoDB |
| Cache | Redis |
| Messaging | RabbitMQ through `RabbitMQ.Client` |
| Real time | SignalR |
| Agent interface | Model Context Protocol server |
| Identity | Amazon Cognito; JWT, OAuth 2 |
| Serverless | AWS Lambda, EventBridge Scheduler, SES |
| Containers | Docker, Kubernetes (k3s; EKS on demand), Helm |
| Cloud | AWS: EC2, S3, ECR, Systems Manager, Parameter Store |
| Provisioning | Terraform |
| Pipeline | GitHub Actions with OIDC |
| Instrumentation | OpenTelemetry for traces, metrics and logs |
| Logging | Serilog, structured, carrying the trace id |
| Telemetry collection | Grafana Alloy in the cluster |
| Telemetry storage and dashboards | Grafana Cloud: Tempo, Loki, Prometheus, Grafana |
| Alerting | Grafana Alerting |
| Health | ASP.NET Core health checks behind Kubernetes probes |
| Unit tests | xUnit, NSubstitute, Shouldly |
| Integration tests | Testcontainers, `WebApplicationFactory` |
| Architecture tests | NetArchTest |
| Coverage and static analysis | Coverlet, SonarQube Cloud with a quality gate on pull requests |
| Style | .NET analyzers, warnings as errors, `dotnet format` |
| Supply chain | Dependabot, CodeQL, secret scanning, Trivy for images and Terraform |
| Web app | Angular, TypeScript, Vitest, ESLint, Playwright |

## Alerts

| Alert | Meaning |
|---|---|
| No ingestion by mid-morning | The daily search did not deliver |
| Dead-letter queue not empty | A consumer cannot process a message |
| Outbox lag | Events are being written but not published |
| Service down | A health probe is failing |

## Testing

- **Domain rules** are tested as pure unit tests on the aggregates.
- **Each service** is tested through its public boundary: requests or incoming events go in, and responses, published events and later reads are asserted. Data stores and the broker are real, started by Testcontainers.
- **Layering** is enforced by architecture tests, so the domain cannot depend on infrastructure.
- **The web app** has component tests and one end-to-end flow: sign in, change a status, see the dashboard.

## Decisions

The reasons behind this design are recorded in [`docs/adr/`](./adr/).
