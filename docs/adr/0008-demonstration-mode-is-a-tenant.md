---
status: accepted
---

# Demonstration mode is a tenant on the real API

The public demonstration is served by the same services and code paths as the owner's data, as a separate read-only tenant with fictitious content. Every table, collection, event and cache key carries a tenant id from the first release, and an anonymous request resolves to the demonstration tenant.

## Considered options

- **Fictitious data embedded in the web app.** Rejected: a visitor would see a mock, not the system.
- **A second deployment with its own data stores.** Rejected: stronger isolation, but it does not fit on a single node.

## Consequences

- A missing tenant filter would expose the owner's notes. Tenant filtering is applied globally in data access rather than per query, and is covered by tests.
- The demonstration tenant is rate-limited in the API.
- The on-demand managed cluster receives only the demonstration tenant.
