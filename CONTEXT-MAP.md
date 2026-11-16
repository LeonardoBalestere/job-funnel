# Context Map

## Contexts

- [Catalog](./src/catalog/CONTEXT.md): receives every job posting, normalizes its terms and channel, and owns the taxonomy and its curation
- [Funnel](./src/funnel/CONTEXT.md): tracks the owner's process for each posting, from entering the funnel to its outcome
- [Dashboard](./src/dashboard/CONTEXT.md): turns what happened in Catalog and Funnel into metrics

## Relationships

- **Catalog → Funnel**: Catalog emits `PostingCataloged` and `PostingRecataloged`; Funnel consumes them to create an Opportunity and keep its Posting Snapshot current
- **Catalog → Dashboard**: Catalog emits `PostingCataloged`, `PostingRecataloged` and `TaxonomyChanged`; Dashboard consumes them to maintain Timelines and Term Coverage
- **Funnel → Dashboard**: Funnel emits `OpportunityStatusChanged`; Dashboard consumes it to maintain Timelines
- **Shared across all contexts**: Tenant, and the Job Posting's id as the key that links a Job Posting, its Opportunity and its Timeline
