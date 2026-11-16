---
status: accepted
---

# Catalog is the single entry point for postings

Every job posting, whether submitted by the search agent or typed in by the owner, enters through Catalog; Funnel creates an opportunity only by consuming `PostingCataloged`. Receiving a posting and cataloging it are one service with an API process and a worker process, because both act on the same concept in the same store.

## Considered options

- **Manual postings created directly in Funnel.** Rejected: Catalog would not know about them, so the search agent would resubmit a posting the owner had already added by hand, and duplicate detection would have two sources of truth.
- **A separate ingestion service in front of Catalog.** Rejected: two services over one concept and one database, with no boundary between them worth defending.

## Consequences

- A manually added posting appears in the funnel asynchronously, about a second later, announced over the real-time hub.
- Funnel holds a copy of the posting's display fields, kept current by `PostingRecataloged` and guarded by the posting's version.
