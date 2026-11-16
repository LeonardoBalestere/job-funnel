---
status: accepted
---

# One data store per service, chosen by the shape of its data

Funnel uses SQL Server, with EF Core for writes and Dapper for reads: opportunities and their transitions are relational, transactional, and the owner's most valuable data. Catalog uses MongoDB: postings are documents whose shape varies with their origin. Dashboard uses its own MongoDB database, holding one timeline document per opportunity and computing metrics by aggregation, with Redis caching the results.

## Considered options for Dashboard

- **Counters and sorted sets kept directly in Redis.** Rejected: every new metric or filter would need a full replay of events, increments are not idempotent, and the dimensions would have to be fixed in advance.
- **MongoDB without a cache.** Aggregations over a few thousand documents take milliseconds, so the owner's use does not need one. The cache is kept for the anonymous traffic of the public demonstration mode.

## Consequences

- A new metric is a new aggregation over existing timelines, with no replay.
- Idempotent consumption in Dashboard is a write conditioned on the aggregate's version.
- The Redis cache is keyed by tenant and filter and invalidated by any event for that tenant.
- MongoDB runs as a single-node replica set, because the outbox needs transactions.
