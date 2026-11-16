# Funnel

The owner's process for each job posting. Funnel knows where every process stands, how it got there, and when it needs the owner's attention.

## Language

**Opportunity**:
The owner's process regarding one Job Posting, from the moment it enters the funnel until its outcome.
_Avoid_: Application (it only exists after applying), vacancy, job

**Status**:
The stage an Opportunity is in: new, to apply, applied, interview, offer, accepted or discarded.
_Avoid_: Stage, state

**Transition**:
A change of an Opportunity's Status, with its date and who made it.

**Correction**:
A Transition back to an earlier Status, which voids the Transitions it undoes.
_Avoid_: Rollback, undo

**Discard Reason**:
Why an Opportunity was discarded: not interested, rejected by the company, no response, posting closed, offer declined, or duplicate.

**Follow-up**:
The owner's record of having asked the company for a response.
_Avoid_: Reminder, nudge

**Follow-up Period**:
The number of days without news after which an Opportunity is due for a Follow-up.

**No-response Period**:
The number of days an applied Opportunity may stay without any Transition before it is discarded for lack of response.

**Reminder**:
The scheduled email listing the Opportunities that are due for a Follow-up.

**Posting Snapshot**:
The copy of a Job Posting's display fields that an Opportunity carries.

**Actor**:
Who made a Transition: the owner or the system.

**Tenant**:
The owner of a set of data: the real owner, or the demonstration data set.
