---
status: accepted
---

# RabbitMQ with the plain client, no messaging or mediator library

Domain events travel over RabbitMQ, published and consumed with `RabbitMQ.Client` directly. The outbox, retries, dead-lettering, idempotent consumption and trace propagation are implemented in this codebase. No in-process mediator library is used; handlers are called directly.

## Considered options

- **Kafka.** Rejected: the workload is a work queue with a few consumers, not an event stream with replay by offset, and a Kafka deployment costs far more to run on a single small node.
- **MassTransit, and MediatR for in-process dispatch.** Rejected: both moved to commercial licensing in their current major versions, and they hide the mechanics this project is meant to exercise.

## Consequences

- More code to write and maintain: topology declaration, delay queues, dead-letter handling, header propagation.
- Replay is not a broker feature here; see ADR 0007.
