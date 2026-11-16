---
status: accepted
---

# Services communicate only through events

Catalog, Funnel and Dashboard never call each other synchronously; they exchange domain events over the broker, and events carry enough data that a consumer never needs to ask the producer for more. gRPC was planned for one internal call and dropped.

## Considered options

- **A synchronous call from ingestion to Funnel to learn which postings already exist.** Rejected for three reasons. Funnel only holds a derived copy created after the event is consumed, so it would answer late and wrongly for a posting still in flight. The call would make ingestion fail whenever Funnel is restarting, undoing the decoupling the queue exists to provide. And Catalog can answer from its own data.
- **gRPC for internal calls in general.** Rejected: it pays off for high-volume, low-latency internal calls, streaming, or contracts across teams in different languages. This system writes a handful of records a day, and no other internal synchronous call exists.

## Consequences

- Reads across services are eventually consistent; the dashboard can trail the funnel by seconds.
- A service can be down or deploying without failing the others.
- Revisit if a synchronous internal query with real volume appears.
