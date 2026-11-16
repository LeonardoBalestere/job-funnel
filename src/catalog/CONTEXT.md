# Catalog

Everything known about what companies published. Catalog is the single way a job posting enters the system, and it owns the vocabulary used to compare postings with each other and with the owner's résumé.

## Language

### Postings

**Job Posting**:
What a company published about an open position: its text, requirements and link. It exists whether or not the owner is interested in it.
_Avoid_: Vacancy, job, opening, opportunity

**Alias**:
An additional id that resolves to a Job Posting, left behind by a merge or by a change in how ids are derived.

**Channel**:
The place where a Job Posting was found, such as a job board, a referral or a recruiter.
_Avoid_: Source

**Origin**:
The way a Job Posting entered the system: automated search, email alert or manual entry.
_Avoid_: Source

**Fit Assessment**:
A score from 0 to 100 with its justification, stating how well a Job Posting matches the owner's profile.
_Avoid_: Rating, match

**Duplicate Candidate**:
A pair of Job Postings with equivalent company and title but different links, awaiting a decision on whether they are the same posting.

### Taxonomy

**Term**:
A skill or requirement in its canonical form, such as "ASP.NET Core".
_Avoid_: Keyword, skill, tag

**Spelling**:
A form in which a Term appears in a Job Posting, such as ".NET Core" or "dotnet core". A Spelling belongs to one Term.
_Avoid_: Variant, synonym

**Requirement Level**:
The weight a Job Posting gives to a Term: required, nice to have, or mentioned.

**Coverage**:
The standing of a Term in the owner's résumé: have, partial, unconfirmed or gap.

**Evidence**:
The fact from the owner's experience that supports a Term's Coverage.

**Taxonomy**:
The set of Terms, their Spellings and the Channels, as curated by the owner.

### Curation

**Mapping Suggestion**:
An unknown Spelling or Channel waiting for the owner to approve, merge or ignore it.
_Avoid_: Pending item

**Curation**:
The owner's decisions over Mapping Suggestions and Duplicate Candidates, which shape the Taxonomy.

**Recataloging**:
Re-deriving a Job Posting's Terms and Channel after the Taxonomy changes or a duplicate is merged.

### Shared

**Tenant**:
The owner of a set of data: the real owner, or the demonstration data set.
