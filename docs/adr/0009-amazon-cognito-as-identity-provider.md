---
status: accepted
---

# Amazon Cognito as the identity provider

Cognito issues tokens for the owner (authorization code with PKCE), for the search agent's MCP connector (a scope limited to ingestion) and for the Reminders function (client credentials). It costs nothing at this volume and uses no memory on the cluster node.

## Considered options

- **Keycloak in the cluster.** Rejected: around a gigabyte of memory on a node that has none to spare.
- **OpenIddict inside a .NET service.** Kept as the fallback.

## Consequences

- MCP connectors commonly expect dynamic client registration, which Cognito does not offer. Whether the connector can be registered manually is validated before any feature work; see the roadmap. If it cannot, identity moves to OpenIddict.
