# Domain model

Fields, rules and scenarios for each context. The vocabulary is defined in each context's `CONTEXT.md`; see the [context map](../CONTEXT-MAP.md).

Every aggregate, document and event carries a `tenantId`. It is omitted from the tables below.

## Catalog

### Job Posting

Aggregate root.

| Field | Type | Rule |
|---|---|---|
| `id` | string | First 16 hexadecimal characters of the SHA-1 of the normalized link |
| `aliases` | list of string | Ids of merged duplicates and ids derived before normalization. `list_posting_ids` returns them all |
| `url` | string | http or https, without tracking parameters |
| `title` | string | Required |
| `company` | string | Required |
| `location` | string | Free text |
| `workMode` | enum | `Remote`, `Hybrid`, `OnSite` |
| `level` | string | Free text, as published |
| `international` | boolean | |
| `salaryText` | string | As published; may be empty |
| `yearsRequired` | integer | Optional |
| `channelId` | reference | Null while the channel is a pending mapping suggestion |
| `rawChannel` | string | As received |
| `origin` | enum | `AutomatedSearch`, `EmailAlert`, `Manual` |
| `fit` | object | `score` (0 to 100), `reason`, `assessedAt`. Null for a manual posting |
| `terms` | list | Each with `rawSpelling`, `termId` (null while pending) and `requirementLevel` |
| `publishedAt` | date | Optional |
| `foundAt` | date-time | Required |
| `version` | integer | Incremented on every change; carried by events |

`requirementLevel` is one of `Required`, `NiceToHave`, `Mentioned`.

Rules:

1. Submitting an id or alias that already exists changes nothing.
2. A posting's content changes only through curation or a duplicate merge. The search agent never edits an existing posting.
3. A new posting whose normalized company and title match an existing one, under a different link, creates a duplicate candidate.
4. In a merge one posting survives and the other becomes its alias.

### Term

| Field | Type | Rule |
|---|---|---|
| `id` | string | |
| `name` | string | Canonical form; unique per tenant |
| `category` | string | |
| `spellings` | list of string | A spelling belongs to exactly one term |
| `coverage` | enum | `Have`, `Partial`, `Unconfirmed`, `Gap` |
| `evidence` | string | What supports the coverage |
| `updatedAt` | date-time | |

### Channel

`id`, `name`, `aliases`.

### Mapping Suggestion

| Field | Type | Rule |
|---|---|---|
| `id` | string | |
| `kind` | enum | `Term`, `Channel` |
| `rawValue` | string | The unknown spelling or channel |
| `suggestedTargetId` | reference | Existing term or channel proposed by the search agent; or |
| `suggestedNewName` | string | name proposed for a new one |
| `occurrences` | integer | How many postings carry the raw value |
| `status` | enum | `Pending`, `Approved`, `Merged`, `Ignored` |
| `decidedAt` | date-time | |

An ignored raw value is remembered, so it does not return as a new suggestion.

### Duplicate Candidate

`postingIdA`, `postingIdB`, `status` (`Pending`, `Merged`, `Distinct`), `decidedAt`.

### Curation flow

1. The search agent reads the taxonomy and submits terms and channels in canonical form when it recognizes them.
2. An unknown spelling or channel becomes a mapping suggestion, with the agent's proposed mapping.
3. The owner approves, merges or ignores it.
4. Each decision recatalogs the affected postings and publishes `TaxonomyChanged`.

## Funnel

### Opportunity

Aggregate root.

| Field | Type | Rule |
|---|---|---|
| `id` | GUID | |
| `postingId` | string | Unique per tenant |
| `status` | enum | `New`, `ToApply`, `Applied`, `Interview`, `Offer`, `Accepted`, `Discarded` |
| `discardReason` | enum | Set if and only if the status is `Discarded` |
| `notes` | string | Edited only by the owner |
| `appliedAt` | date-time | Set the first time the opportunity reaches `Applied` or a later status |
| `lastFollowUpAt` | date-time | Set when the owner records a follow-up |
| `createdAt`, `updatedAt` | date-time | |
| `version` | integer | Concurrency control; carried by events |
| Posting snapshot | columns | `title`, `company`, `url`, `location`, `workMode`, `level`, `international`, `salaryText`, `channel`, `origin`, `fitScore`, `fitReason`, `publishedAt`, `postingVersion` |

`discardReason` is one of `NotInterested`, `RejectedByCompany`, `NoResponse`, `PostingClosed`, `OfferDeclined`, `Duplicate`.

### Transition

Entity of the opportunity.

| Field | Type | Rule |
|---|---|---|
| `id` | GUID | |
| `fromStatus`, `toStatus` | enum | |
| `discardReason` | enum | Present when `toStatus` is `Discarded` |
| `occurredAt` | date-time | |
| `actor` | enum | `Owner`, `System` |
| `voided` | boolean | True when a later correction undid this transition |

### Reminder Settings

One per tenant.

| Field | Type | Default |
|---|---|---|
| `followUpDays` | integer | 7 |
| `noResponseDays` | integer | 30 |
| `emailEnabled` | boolean | |
| `emailSchedule` | day of week and time | |
| `timeZone` | string | |
| `recipientEmail` | string | |

### Rules

1. An opportunity is created only by consuming `PostingCataloged`. It starts as `New` when the posting's origin is automatic and as `ToApply` when it is manual.
2. Moving forward may skip statuses. Skipped statuses count as reached.
3. Moving to an earlier status is a correction: the transitions it undoes are voided and leave the metrics.
4. Reopening a discarded opportunity returns it to the status it had before the discard.
5. Discarding requires a reason.
6. An opportunity is due for a follow-up when its status is `Applied` or `Interview` and `followUpDays` have passed since the later of entering that status and the last follow-up. Editing notes does not restart the period.
7. The system discards an opportunity with reason `NoResponse` after `noResponseDays` in `Applied` without a transition. The owner can reopen it.
8. The posting snapshot is updated only when the received posting version is greater than the stored one.
9. When two postings are merged and both have an opportunity, the one further along survives and the other is discarded with reason `Duplicate`.
10. The search agent has no operation over opportunities.

### Reminders

On the scheduled day the Reminders function asks Funnel to process deadlines (rule 7) and then for the opportunities due for a follow-up (rule 6). With an empty list no email is sent.

## Dashboard

### Timeline

One document per opportunity.

| Field | Type |
|---|---|
| `opportunityId`, `postingId` | ids |
| `channel`, `origin`, `level`, `international` | from the posting |
| `fitScore` | integer |
| `foundAt`, `appliedAt` | date-time |
| `currentStatus`, `discardReason` | enum |
| `stagesReached` | list of status and date, excluding voided transitions |
| `terms` | list of `termId` and `requirementLevel` |
| `opportunityVersion`, `postingVersion` | integers; a write is applied only when the incoming version is greater |

### Term Coverage

One document per term: `termId`, `name`, `category`, `coverage`.

### Metrics

| Metric | Definition |
|---|---|
| Conversion between statuses | Of the opportunities that reached a status, the fraction that reached the next one |
| Average time per status | Mean number of days between entering and leaving each status |
| Response rate per channel | Responses divided by the opportunities applied to longer ago than the response window |
| Fit of those that advanced | Mean fit score of opportunities that reached `Interview`, against that of the discarded ones |
| New postings per day | Daily count, by origin |
| Term coverage | Coverage of the 20 terms that postings ask for most |

A response is an applied opportunity that reached `Interview` or `Offer`, or was discarded with reason `RejectedByCompany`. The response window is 14 days.

Metrics are computed by aggregation over timelines. The result is cached per tenant and filter, and the cache is invalidated when an event for that tenant arrives.

## Scenarios

| Scenario | Behaviour |
|---|---|
| A job board republishes, under another link, a posting the owner already applied to | It enters as a new posting and creates a duplicate candidate. On merge it becomes an alias, and its opportunity, if any, is discarded with reason `Duplicate` |
| The company reopens the same position months later | Same link: the submission is ignored and the owner reopens the opportunity by hand. New link: a new posting and a new opportunity |
| The owner changes a status by mistake | Moving back is a correction; the wrong transition does not count in conversion |
| The owner asks for a response and the company stays silent | Recording the follow-up restarts the period; the opportunity is due again after `followUpDays` |
| A term is merged into another during curation | The affected postings are recataloged and their timelines updated |
| The search agent resubmits a whole batch after a failure | Nothing is duplicated: the ids already exist |
| A position has several interview rounds | One `Interview` status; the rounds are kept in the notes |
| The owner adds a posting by hand that the search later finds | The manual posting already went through Catalog, so its id is known and the search agent skips it |
