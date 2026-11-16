---
status: accepted
---

# The outbox is the permanent event log

Each producing service writes its events to an outbox in the same transaction as the state change, and never deletes them. Dashboard is built entirely from events, and RabbitMQ does not retain messages after delivery; keeping the outbox gives every consumer a way to be rebuilt without adopting event sourcing or a log-based broker.

## Consequences

- Each producer has a replay command that re-publishes its log to a dedicated replay queue.
- Every event carries the time it occurred and the version of its aggregate, so consumers tolerate replays and out-of-order delivery.
- The log grows without bound. At this volume that is negligible; revisit if it stops being so.
- State is still stored as current state. The log is for rebuilding consumers, not for reconstructing aggregates.
