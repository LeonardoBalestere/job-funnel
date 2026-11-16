---
status: accepted
---

# Distributed architecture as a deliberate choice

The system serves one real user and stores a few thousand postings a year; a single service with one database would meet every functional need. We build it as separate services with a broker, several data stores and Kubernetes anyway, because the project exists to practise and demonstrate those techniques on a problem that is real and in daily use.

## Consequences

- Each technique must do a job the domain actually has. A component that only exists to be listed is removed; see ADR 0003 for one that was.
- Operational cost and complexity are far above what the load justifies, and are accepted.
- For the same problem under ordinary constraints, the right design is a modular monolith on one relational database.
