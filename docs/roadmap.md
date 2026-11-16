# Roadmap

The system is built in five phases, ordered by dependency. Each phase ends with something running in production.

## Phase 0: validation

Three assumptions the design rests on are checked before any feature work. Each has a yes-or-no answer and a known fallback.

| Question | Why it matters | If the answer is no |
|---|---|---|
| Can the scheduled search agent call a custom MCP server authenticated by Amazon Cognito? | The whole ingestion path depends on it ([ADR 0004](./adr/0004-job-search-stays-in-an-llm-agent-behind-mcp.md), [ADR 0009](./adr/0009-amazon-cognito-as-identity-provider.md)) | If only the identity provider is the obstacle, move identity to OpenIddict. If the agent cannot use a custom MCP server at all, ADR 0004 is reopened before any code is written |
| Do k3s, SQL Server, MongoDB, RabbitMQ, Redis and four .NET processes fit in 8 GB, and does the node recover its data volume after a spot interruption? | The permanent environment depends on it ([ADR 0010](./adr/0010-single-node-k3s-with-in-cluster-data-stores.md)) | Use a larger instance, or move MongoDB to a managed free tier |
| Are MassTransit and MediatR still under commercial licences in their current versions? | It is one of the two reasons they were ruled out ([ADR 0005](./adr/0005-rabbitmq-with-the-plain-client.md)) | The decision stands on its other reason; the ADR is corrected |

## Phase 1: minimal funnel

- Terraform for the base: network, instance, container registry, DNS, identity provider.
- The Funnel service on SQL Server, with status, transitions, corrections, discard reasons and notes.
- Tenant on every table and event, with the demonstration tenant seeded.
- The web app route, with sign-in, theme and both languages.
- The full pipeline: build, tests, image, migrations, deployment.
- Backups, with a restore performed and verified.

Postings do not have an entry point yet. Funnel exposes its internal "register posting" command through a provisional endpoint, which phase 2 removes.

Outcome: a usable funnel with postings added by hand.

## Phase 2: ingestion

- The Catalog service on MongoDB, with the MCP server and duplicate detection.
- RabbitMQ, the outbox and idempotent consumers.
- Funnel creates opportunities from `PostingCataloged`; the provisional endpoint is removed and manual entry goes through Catalog.
- Import of the postings tracked before this system existed, through `submit_postings`, assigning a channel, an origin and, for discarded ones, a discard reason.
- The search agent is pointed at the MCP server after a week of running in parallel with the previous storage.

Outcome: the daily search writes to this system.

## Phase 3: curation and dashboard

- The taxonomy, seeded from the terms already collected, with mapping suggestions and the curation screen.
- Recataloging on taxonomy changes.
- The Dashboard service, timelines, the cache and the six metrics.
- Replay of the event logs to build the first timelines.

Outcome: the term ranking and the dashboard are current every day.

## Phase 4: reminders, real time and operations

- The Reminders function, its schedule and the email.
- Real-time notification of new opportunities.
- The managed cluster on demand, receiving only the demonstration tenant.
- Complete tracing across the broker, and the alerts.

Outcome: the design described in [architecture.md](./architecture.md) is fully in place.
