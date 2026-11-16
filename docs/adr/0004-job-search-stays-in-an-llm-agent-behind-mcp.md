---
status: accepted
---

# Job search and fit assessment stay in an LLM agent, behind an MCP server

Finding postings across job boards and email alerts, reading them, extracting their terms and judging fit against the owner's profile are done by a scheduled LLM agent outside this system. The backend does not scrape or score; it exposes an MCP server through which the agent submits what it found.

## Considered options

- **Collectors written in .NET, calling an LLM API for extraction and scoring.** Rejected: it would rebuild inside the system a search that already works, and source-specific scrapers are the part most likely to break.
- **Deterministic keyword scoring without an LLM.** Rejected: fit depends on reading the posting, not on counting words.

## Consequences

- The agent reads untrusted web pages and email, so its tools are append-only and narrowly scoped: it cannot read notes or salary, change an opportunity, or alter an existing posting. Schema validation, batch limits and a daily quota are enforced server-side.
- Ingestion depends on an external scheduler. The absence of ingestion by mid-morning raises an alert.
- Submission is idempotent by posting id, so a failed run is repaired by the next one.
- The broker's traffic comes from cataloging, curation and recataloging, not from collection.
